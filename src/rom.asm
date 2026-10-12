; Standalone cartridge entry. This wrapper owns its ROM and CGB WRAM.
INCLUDE "resident-addresses.inc"

SECTION "cartridge header", ROM0[$0100]
 nop
 jp standaloneStart
 ds $0150 - @, 0 ; RGBFIX supplies the hardware header and checksums.

SECTION "standalone bootstrap", ROM0[$0150]
standaloneStart:
 di
 ld sp, $fffe
 ld a, 1
 ldh [$ff70], a
 ld hl, residentSource
 ld de, VM_START
 ld bc, residentSourceEnd - residentSource
 call copyBytes
 ; The original resident remains byte-identical in ROM. Redirect exactly
 ; the first CALL sample at waitPacket after the native loading reveal.
 ld hl, VM_WAIT_PACKET
 ld a, $c3 ; JP absolute
 ld [hli], a
 ld a, LOW(standaloneInstallCartridge)
 ld [hli], a
 ld a, HIGH(standaloneInstallCartridge)
 ld [hl], a
 jp VM_START

standaloneInstallCartridge:
 ; Resident initialization has cleared mutable WRAM and completed its exact
 ; 169-VBlank reveal. Keep the completed mark visible for another 90 frames.
 ld b, 90
.hold:
 call VM_WAIT_FRAME
 dec b
 jr nz, .hold
 ld hl, cartridgeSource
 ld de, $d000
 ld bc, cartridgeSourceEnd - cartridgeSource
 call copyBytes
 ld a, LOW(cartridgeSourceEnd - cartridgeSource)
 ld [$d214], a ; LENGTH, little endian
 ld a, HIGH(cartridgeSourceEnd - cartridgeSource)
 ld [$d215], a
 ld a, 37
 ld [$d213], a ; same fixed seed as the original Pong packet
 xor a
 ld [$d210], a ; PC = $d000
 ld a, $d0
 ld [$d211], a
 ld a, 2
 ld [$d221], a ; READY = $56,$02: bytecode installed
 jp VM_DISPATCH

copyBytes:
 ld a, [hli]
 ld [de], a
 inc de
 dec bc
 ld a, b
 or c
 jr nz, copyBytes
 ret

residentSource:
 INCBIN "resident-vm.bin"
residentSourceEnd:
cartridgeSource:
 INCBIN "pong-cartridge.bin"
cartridgeSourceEnd:
ASSERT residentSourceEnd - residentSource == 2304
ASSERT cartridgeSourceEnd - cartridgeSource == 499
ASSERT @ <= $4000, "demo must fit entirely in unbanked ROM0"
