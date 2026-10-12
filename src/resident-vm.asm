; LR35902-resident interpreter for the standalone VM cartridge.
; Entry ABI: the image begins at $c000, CGB bank-1 WRAM is writable, the
; runtime replaces the stack, and execution does not return.
INCLUDE "isa.inc"
DEF CART EQU $d000
DEF REGS EQU $d200
DEF PC EQU $d210
DEF FLAGS EQU $d212
DEF SEED EQU $d213
DEF LENGTH EQU $d214
DEF READY EQU $d220
DEF SHADOW EQU $d300

SECTION "resident image", ROM0[$0000]
image:
LOAD "resident addresses", WRAM0[$c000]
vmStart:
 di
 ld sp, $d800
 xor a
 ldh [$ff0f], a
 ld [$ffff], a
 call disableLcd ; turn off at VBlank if entry inherited a running LCD
 xor a
 ldh [$ff4f], a
 ld a, 1
 ldh [$ff70], a
 xor a
 ldh [$ff42], a
 ldh [$ff43], a
 ld hl, $d000
 ld bc, $0400
 call clear
 ld hl, $9800
 ld bc, $0400
 call clear
 ; CGB tile-map attribute bank is zeroed separately.
 ld a, 1
 ldh [$ff4f], a
 ld hl, $9800
 ld bc, $0400
 call clear
 xor a
 ldh [$ff4f], a
 ld hl, tiles
 ld de, $8000
 call unpackTiles
 ld hl, dmaRoutine
 ld c, $80
 ld b, dmaRoutineEnd - dmaRoutine
.dmaInstall:
 ld a, [hli]
 ldh [c], a
 inc c
 dec b
 jr nz, .dmaInstall
 ld a, $e4
 ldh [$ff47], a
 ldh [$ff48], a
 ld a, $80
 ldh [$ff68], a
 ldh [$ff6a], a
 ld hl, palette
 ld b, 8
.palette:
 ld a, [hli]
 ldh [$ff69], a
 ldh [$ff6b], a
 dec b
 jr nz, .palette
 ld a, $91
 ldh [$ff40], a
 ; Native reveal: sixteen occupied columns on the original VBlank schedule.
 ; No controls, labels, or graphics are supplied by a host-side overlay.
 ld b, 36
.arrival:
 call waitFrame
 dec b
 jr nz, .arrival
 ld hl, bootMap
 ld de, $9842
 ld b, 16
.reveal:
 ld c, 6
.revealHold:
 call waitFrame
 dec c
 jr nz, .revealHold
 push bc
 push de
 ld bc, $010e
 call rectangle
 pop de
 inc de
 pop bc
 dec b
 jr nz, .reveal
 ld b, 37
.settle:
 call waitFrame
 dec b
 jr nz, .settle
 ld a, $56
 ld [READY], a ; native boot is complete; no bytecode cartridge yet
 ld a, 1
 ld [READY+1], a
 ; Preserve the receiver and all subsequent native/asset addresses exactly.
 ASSERT @ <= $c0c6, "native boot animation exceeds the existing setup budget"
 ds $c0c6 - @, 0

waitPacket:
 call sample
 cp $0f
 jr nz, waitPacket
.release:
 call sample
 and a
 jr nz, .release
 xor a
 ld e, a
 call checkedByte
 cp $56
 jp nz, fault
 call checkedByte
 cp $4d
 jp nz, fault
 call checkedByte
 cp 1
 jp nz, fault
 call checkedByte
 ld [LENGTH], a
 ld c, a
 call checkedByte
 ld [LENGTH+1], a
 ld b, a
 cp 3
 jp nc, fault
 cp 2
 jr nz, .nonzero
 ld a, c
 and a
 jp nz, fault ; at most 512 bytes
.nonzero:
 ld a, b
 or c
 jp z, fault
 call checkedByte
 ld [SEED], a
 ld hl, CART
.receive:
 call checkedByte
 ld [hli], a
 dec bc
 ld a, b
 or c
 jr nz, .receive
 call readByte
 xor e
 jp nz, fault
 ld hl, CART
 ld a, l
 ld [PC], a
 ld a, h
 ld [PC+1], a
 ld a, 2
 ld [READY+1], a

dispatch:
 call fetch
 cp 16
 jp nc, fault
 add a
 ld e, a
 ld d, 0
 ld hl, handlers
 add hl, de
 ld a, [hli]
 ld h, [hl]
 ld l, a
 jp hl

opFrame:
 call waitFrame
 call $ff80 ; HRAM-owned DMA; no game VBlank ISR
 jp dispatch
opSet:
 call dest
 call fetch
 ld [hl], a
 jp dispatch
opMov:
 call dest
 call regValue
 ld [hl], a
 jp dispatch
opAdd:
 call dest
 call regValue
 add [hl]
 ld [hl], a
 jp dispatch
opAddi:
 call dest
 call fetch
 add [hl]
 ld [hl], a
 jp dispatch
opAndi:
 call dest
 call fetch
 and [hl]
 ld [hl], a
 jp dispatch
opCmpi:
 call dest
 call fetch
 ld b, a
 ld a, [hl]
 cp b
 jr saveFlags
opCmpr:
 call dest
 call regValue
 ld b, a
 ld a, [hl]
 cp b
saveFlags:
 push af
 pop bc
 ld a, c
 ld [FLAGS], a
 jp dispatch
opBranch:
 call fetch
 ld b, a
 call offset
 ld a, b
 cp 4
 jp nc, fault
 ld a, [FLAGS]
 bit 1, b
 jr nz, .carry
 and $80
 jr .condition
.carry:
 and $10
.condition:
 ; conditions 0/2 require flag set; 1/3 require flag clear.
 jr z, .clear
 bit 0, b
 jp nz, dispatch
 jr setPc
.clear:
 bit 0, b
 jp z, dispatch
 jr setPc
opJump:
 call offset
setPc:
 ld a, e
 ld [PC], a
 ld a, d
 ld [PC+1], a
 jp dispatch
opKeys:
 call dest
 call sample
 ; Right=1 Left=2 Up=4 Down=8; A=$10 B=$20 Select=$40 Start=$80.
 swap a
 ld [hl], a
 jp dispatch
opSeed:
 call dest
 ld a, [SEED]
 ld [hl], a
 jp dispatch
opSprite:
 call fetch
 cp 40
 jp nc, fault
 add a
 add a
 ld l, a
 ld h, HIGH(SHADOW)
 call regValue
 ld b, a ; x
 call regValue
 ld [hli], a ; y
 ld a, b
 ld [hli], a
 call fetch
 ld [hli], a
 xor a
 ld [hl], a
 jp dispatch
opTile:
 call regValue
 cp 20
 jp nc, fault
 ld c, a ; x
 call regValue
 cp 18
 jp nc, fault
 ld l, a
 ld h, 0
 REPT 5
 add hl, hl
 ENDR
 ld b, $98
 add hl, bc
 call regValue
 push af
 call waitFrame ; single tile write always within VBlank
 pop af
 ld [hl], a
 jp dispatch
opClear:
 call disableLcd
 ld hl, $9800
 ld bc, $0400
 call clear
 ld hl, SHADOW
 ld bc, 160
 call clear
 ld a, $93
 ldh [$ff40], a
 jp dispatch
fault:
 ld a, $ff
 ld [READY+1], a
opStop:
 call waitFrame
 jr opStop

; Bounded fetch, register indices, and cartridge-relative jumps. Generic
; interpreter internals; no Pong mechanics, symbols, or expected state.
fetch:
 push hl
 push de
 ld a, [PC]
 ld l, a
 ld a, [PC+1]
 ld h, a
 push bc
 ld a, [LENGTH]
 ld c, a
 ld a, [LENGTH+1]
 add HIGH(CART)
 ld b, a
 ld a, h
 cp b
 jr c, .valid
 jp nz, fault
 ld a, l
 cp c
 jp nc, fault
.valid:
 ld a, [hli]
 ld b, a
 ld a, l
 ld [PC], a
 ld a, h
 ld [PC+1], a
 ld a, b
 pop bc
 pop de
 pop hl
 ret
dest:
 call fetch
 cp 16
 jp nc, fault
 ld l, a
 ld h, HIGH(REGS)
 ret
regValue:
 push hl
 call dest
 ld a, [hl]
 pop hl
 ret
offset:
 call fetch
 ld e, a
 call fetch
 cp 2
 jp nc, fault
 add HIGH(CART)
 ld d, a
 ret ; next fetch additionally enforces loaded length

checkedByte:
 call readByte
 ld d, a
 xor e
 ld e, a
 ld a, d
 ret
readByte:
 push de
 call readNibble
 ld d, a
 call readNibble
 swap a
 or d
 pop de
 ret
readNibble:
.press:
 call sample
 bit 6, a
 jr z, .press
 push af
.release:
 call sample
 bit 6, a
 jr nz, .release
 pop af
 and $0f
 ret
sample:
 push bc
 call waitFrame
 ld a, $20
 ldh [$ff00], a
 REPT 6
 ldh a, [$ff00]
 ENDR
 cpl
 and $0f
 swap a
 ld b, a
 ld a, $10
 ldh [$ff00], a
 REPT 10
 ldh a, [$ff00]
 ENDR
 cpl
 and $0f
 or b
 ld b, a
 ld a, $30
 ldh [$ff00], a
 ld a, b
 pop bc
 ret
waitFrame:
.visible:
 ldh a, [$ff44]
 cp 144
 jr nc, .visible
.blank:
 ldh a, [$ff44]
 cp 144
 jr c, .blank
 ret
disableLcd:
 ldh a, [$ff40]
 bit 7, a
 ret z
 call waitFrame
 xor a
 ldh [$ff40], a
 ret
clear:
 xor a
 ld [hli], a
 dec bc
 ld a, b
 or c
 jr nz, clear
 ret
rectangle:
.row:
 push bc
.column:
 ld a, [hli]
 ld [de], a
 inc de
 dec b
 jr nz, .column
 pop bc
 push hl
 ld hl, 32
 add hl, de
 ld a, l
 sub b
 ld e, a
 ld a, h
 sbc 0
 ld d, a
 pop hl
 dec c
 jr nz, .row
 ret
copy:
 ld a, [hli]
 ld [de], a
 inc de
 dec bc
 ld a, b
 or c
 jr nz, copy
 ret
handlers:
 dw opFrame, opSet, opMov, opAdd, opAddi, opAndi, opCmpi, opCmpr
 dw opBranch, opJump, opKeys, opSprite, opTile, opClear, opSeed, opStop
dmaRoutine:
 ld a, HIGH(SHADOW)
 ldh [$ff46], a
 ld a, 80
.wait:
 dec a
 jr nz, .wait
 ret
dmaRoutineEnd:
palette:
 ; CGB: charcoal, faded red, warm stone, off-white. DMG keeps four shades.
 dw $0842, $2132, $296b, $677b
unpackTiles:
 ; PackBits-like stream: 0..127 copies 1..128 literals; 128..254 repeats
 ; one byte 3..129 times. $ff ends the stream.
.next:
 ld a, [hli]
 cp $ff
 ret z
 bit 7, a
 jr nz, .repeat
 inc a
 ld b, a
.literal:
 ld a, [hli]
 ld [de], a
 inc de
 dec b
 jr nz, .literal
 jr .next
.repeat:
 and $7f
 add 3
 ld b, a
 ld a, [hli]
.repeatByte:
 ld [de], a
 inc de
 dec b
 jr nz, .repeatByte
 jr .next
nativeEnd:
tiles:
 INCBIN "boot-tiles.packbits.bin"
tilesEnd:
bootMap:
 INCBIN "boot-map.bin"
bootMapEnd:
 ASSERT @ <= $c900, "native artwork exceeds accepted 2304-byte resident"
 ds $c900 - @, 0
vmEnd:
ENDL
imageEnd:
ASSERT vmEnd <= $d000, "resident exceeds 4096-byte memory budget"
ASSERT nativeEnd <= CART, "native code overlaps mutable cartridge memory"
ASSERT CART + $200 <= REGS, "cartridge overlaps VM registers"
ASSERT REGS + 16 <= PC, "VM registers overlap interpreter state"
ASSERT READY + 2 <= SHADOW, "interpreter state overlaps OAM shadow"
ASSERT SHADOW + 160 <= $d400, "OAM shadow exceeds its reserved page"
