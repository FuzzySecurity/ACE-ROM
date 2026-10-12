; Cartridge ISA v1. Every register operand is 0..15; all branch offsets
; are little-endian offsets from cartridge start, not native addresses.
DEF I_FRAME EQU $00
DEF I_SET EQU $01
DEF I_MOV EQU $02
DEF I_ADD EQU $03
DEF I_ADDI EQU $04
DEF I_ANDI EQU $05
DEF I_CMPI EQU $06
DEF I_CMPR EQU $07
DEF I_BR EQU $08
DEF I_JMP EQU $09
DEF I_KEYS EQU $0a
DEF I_SPR EQU $0b
DEF I_TILE EQU $0c
DEF I_CLEAR EQU $0d
DEF I_SEED EQU $0e
DEF I_STOP EQU $0f
DEF C_EQ EQU 0
DEF C_NE EQU 1
DEF C_LT EQU 2
DEF C_GE EQU 3

MACRO vSET
 db I_SET, \1, \2
ENDM
MACRO vMOV
 db I_MOV, \1, \2
ENDM
MACRO vADD
 db I_ADD, \1, \2
ENDM
MACRO vADDI
 db I_ADDI, \1, (\2) & $ff
ENDM
MACRO vANDI
 db I_ANDI, \1, \2
ENDM
MACRO vCMPI
 db I_CMPI, \1, \2
ENDM
MACRO vCMPR
 db I_CMPR, \1, \2
ENDM
MACRO vBR
 db I_BR, \1
 dw \2
ENDM
MACRO vJMP
 db I_JMP
 dw \1
ENDM
MACRO vSPR
 db I_SPR, \1, \2, \3, \4
ENDM
MACRO vTILE
 db I_TILE, \1, \2, \3
ENDM
