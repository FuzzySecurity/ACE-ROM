# ACE-ROM design

ACE-ROM is a 32 KiB, CGB-only, ROM-only cartridge. It packages two programs:
a native LR35902 runtime and a compact Pong program for that runtime's
bytecode VM. The CPU starts in the cartridge wrapper, copies the native image
to work RAM, and gives it control. After the loading sequence, the wrapper
copies the Pong cartridge into the VM's bytecode buffer and enters the
interpreter.

```text
ROM $0100             WRAM $c000                 WRAM $d000
bootstrap ──copy──> native runtime ──install──> Pong bytecode
                         │                           │
                         └─ loading screen           └─ VM dispatch loop
```

## Native runtime

`src/resident-vm.asm` assembles as a position-fixed 2,304-byte image at
`$c000..$c8ff`. Startup disables interrupts, moves the stack to `$d800`,
selects CGB work RAM bank 1, clears mutable VM state and both tile-map banks,
and installs a ten-byte OAM DMA routine in high RAM. It expands the packed
tile stream directly into VRAM, installs the shared background and sprite
palette, enables the LCD, and draws the loading image.

The interpreter bounds every bytecode fetch against the installed cartridge
length. Register operands must be below 16, branch destinations must remain in
the 512-byte cartridge window, tile coordinates are limited to 20 by 18, and
sprite slots are limited to 40. Invalid data sets the runtime status to
`$56,$ff` and stops on a frame wait.

The source retains a controller packet receiver so the native image stays the
same as its original build. For this standalone ROM, `src/rom.asm` replaces
the receiver's first three bytes in WRAM with a jump to the ROM installer.
The embedded native image remains byte-for-byte unchanged.

## Loading screen

The runtime clears the screen to charcoal, waits 36 VBlanks, and reveals the
sixteen occupied tile columns at six VBlanks per column. A final 37 VBlanks
leaves the complete `VM LOADING` and `0xb33f` image on screen. The standalone
installer holds that completed frame for another 90 VBlanks before starting
Pong.

`assets/boot-tiles.packbits.bin` is a 1,094-byte PackBits-style encoding of
the 1,488-byte tile set. Control bytes `$00..$7f` copy 1..128 literal bytes;
`$80..$fe` repeat the following byte 3..129 times; `$ff` ends the stream.
`assets/boot-map.bin` is a 16 by 14 rectangle stored by columns, matching the
reveal order. The word `LOADING` starts at x=50 beneath the `VM` mark, two
native pixels right of its original position.

## VM state and memory map

All end addresses below are exclusive.

| Range | Purpose |
|---|---|
| ROM `$0000..$4000` | Header, bootstrap, installer, resident image, Pong image |
| WRAM `$c000..$c900` | Native runtime and loading assets |
| WRAM `$d000..$d200` | Bytecode cartridge, at most 512 bytes |
| WRAM `$d200..$d210` | Sixteen one-byte VM registers |
| WRAM `$d210..$d216` | PC, flags, seed, and cartridge length |
| WRAM `$d220..$d222` | Two-byte runtime status |
| WRAM `$d300..$d3a0` | 40-entry OAM shadow buffer |
| WRAM `$d400..$d800` | Stack reservation; SP begins at `$d800` |
| HRAM `$ff80..$ff8a` | OAM DMA routine |

The status is `$56,$01` after the native loading sequence and `$56,$02` after
the standalone installer has copied the bytecode, seed, length, and program
counter into place.

## Instruction set

The VM has sixteen one-byte opcodes. Operands follow the opcode. Register
numbers select one of the sixteen bytes at `$d200`; immediates are one byte;
branch and jump targets are little-endian offsets from `$d000`.

| Opcode | Mnemonic | Operands | Effect |
|---:|---|---|---|
| `$00` | `FRAME` | none | Wait for VBlank and copy shadow OAM to hardware OAM |
| `$01` | `SET` | register, immediate | Store an immediate byte |
| `$02` | `MOV` | destination, source | Copy one register to another |
| `$03` | `ADD` | destination, source | Add registers modulo 256 |
| `$04` | `ADDI` | register, immediate | Add an immediate modulo 256 |
| `$05` | `ANDI` | register, immediate | Bitwise AND with an immediate |
| `$06` | `CMPI` | register, immediate | Save CPU flags from an unsigned comparison |
| `$07` | `CMPR` | left, right | Save CPU flags from an unsigned register comparison |
| `$08` | `BR` | condition, offset16 | Branch on EQ, NE, unsigned LT, or unsigned GE |
| `$09` | `JMP` | offset16 | Jump within the installed cartridge |
| `$0a` | `KEYS` | register | Sample controls into a register |
| `$0b` | `SPR` | slot, x-reg, y-reg, tile | Write one sprite in shadow OAM |
| `$0c` | `TILE` | x-reg, y-reg, tile-reg | Write one background tile during VBlank |
| `$0d` | `CLEAR` | none | Clear the background and shadow OAM |
| `$0e` | `SEED` | register | Copy the cartridge seed into a register |
| `$0f` | `STOP` | none | Wait forever on VBlank |

Arithmetic wraps at eight bits. The compare operations preserve the LR35902
zero and carry flags used by the four branch conditions. `src/isa.inc`
provides RGBDS macros for the variable-length encodings.

## Cartridge format and Pong

The runtime's generic wire format begins with a held `$f` controller marker
and release. Byte pairs then carry the magic `VM`, version 1, a little-endian
16-bit length, one-byte seed, payload, and XOR checksum. The standalone
cartridge does not serialize that envelope: the same 499 payload bytes are
already in ROM, so the installer writes the payload, length 499, and seed 37
directly to VM state. Execution begins at bytecode offset zero.

`src/pong.asm` owns all game behavior. Its registers hold ball position and
velocity, paddle positions, scores, sampled keys, constants, and drawing
coordinates. `KEYS` returns Right, Left, Up, Down, A, B, Select, and Start in
bits 0 through 7. Pong uses Up and Down to move the left paddle, A to release
the served ball, and a simple ball-following rule for the right paddle. Court
tiles and scores go through `TILE`; the moving objects go through `SPR` and
become visible on the next `FRAME`.

## Build layout

`tools/build.py` assembles the native runtime and Pong independently, checks
their byte identities and the artwork identities, then generates the runtime
addresses consumed by `src/rom.asm`. RGBDS links the wrapper as a 32 KiB ROM,
and `rgbfix` supplies the standard Game Boy header fields and checksums. The
script then verifies cartridge size, CGB flag, mapper and RAM fields, platform
logo field, and both checksums. Generated objects, symbols, maps, binaries, and
the machine-readable manifest live under `build/`.
