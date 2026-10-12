; Pong cartridge v1: game state and behavior exist only in these bytecodes.
; r0/r1 ball x/y, r2/r3 velocities, r4/r5 paddle y, r6/r7 scores,
; r8 keys/temp, r9 scratch, r10 left x, r11 right x, r12 scratch,
; r13 seed, r14/r15 drawing coordinates. OAM coordinates include hardware offsets.
INCLUDE "isa.inc"
SECTION "Pong bytecodes", ROM0[$0000]
cartridge:
 db I_CLEAR
 vSET 4, 72
 vSET 5, 72
 vSET 6, 0
 vSET 7, 0
 vSET 10, 20
 vSET 11, 156
 db I_SEED, 13
 ; Native tiles: 1 two-tone rail, 2 ribbed paddle, 3 ball, 4..13 score glyphs.
 vSET 8, 1
 vSET 14, 1
 vSET 15, 3
court:
 vTILE 14, 15, 8
 vSET 15, 16
 vTILE 14, 15, 8
 vSET 15, 3
 vADDI 14, 1
 vCMPI 14, 19
 vBR C_LT, court
 ; Broken gray edge rails and a restrained center net. These are static
 ; tile writes; every motion, key, collision, score and serve branch is intact.
 vSET 8, 14
 vSET 15, 4
courtVertical:
 vSET 14, 0
 vTILE 14, 15, 8
 vSET 14, 19
 vTILE 14, 15, 8
 vSET 14, 10
 vTILE 14, 15, 8
 vADDI 15, 1
 vCMPI 15, 16
 vBR C_LT, courtVertical
 ; A compact framed score inset leaves the rest of the upper margin dark.
 vSET 8, 1
 vSET 14, 6
 vSET 15, 0
scoreInset:
 vTILE 14, 15, 8
 vSET 15, 2
 vTILE 14, 15, 8
 vSET 15, 0
 vADDI 14, 1
 vCMPI 14, 14
 vBR C_LT, scoreInset
 vJMP score
serve:
 vSET 0, 86
 vMOV 1, 13
 vANDI 1, 63
 vADDI 1, 52
 vSET 2, 2
 vSET 3, 1
 vMOV 8, 13
 vANDI 8, 1
 vCMPI 8, 0
 vBR C_EQ, positive
 vSET 3, 255
positive:
 vADDI 13, 1
 ; Ball remains centered until A is pressed; D-pad is live while waiting.
 vSET 12, 1
 vJMP draw

frame:
 db I_KEYS, 8
 vMOV 9, 8
 vANDI 9, 4
 vCMPI 9, 0
 vBR C_EQ, down
 vCMPI 4, 41
 vBR C_LT, down
 vADDI 4, -3
down:
 vMOV 9, 8
 vANDI 9, 8
 vCMPI 9, 0
 vBR C_EQ, ai
 vCMPI 4, 120
 vBR C_GE, ai
 vADDI 4, 3
ai:
 vMOV 9, 5
 vADDI 9, 10
 vCMPR 9, 1
 vBR C_GE, aiUp
 vCMPI 5, 120
 vBR C_GE, motion
 vADDI 5, 1
 vJMP motion
aiUp:
 vCMPI 5, 41
 vBR C_LT, motion
 vADDI 5, -1
motion:
 vCMPI 12, 0
 vBR C_EQ, moveBall
 vANDI 8, 16
 vCMPI 8, 0
 vBR C_EQ, draw
 vSET 12, 0
moveBall:
 vADD 0, 2
 vADD 1, 3
 vCMPI 1, 41
 vBR C_GE, bottom
 vSET 3, 1
bottom:
 vCMPI 1, 140
 vBR C_LT, left
 vSET 3, 255
left:
 vCMPI 0, 28
 vBR C_GE, right
 ; Half-open 4px ball and 24px paddle spans overlap when the ball's last
 ; pixel (ballY+3) reaches the paddle and ballY remains below paddleY+24.
 vMOV 9, 1
 vADDI 9, 3
 vCMPR 9, 4
 vBR C_LT, pointRight
 vMOV 9, 4
 vADDI 9, 24
 vCMPR 1, 9
 vBR C_GE, pointRight
 vSET 0, 28
 vSET 2, 2
right:
 vCMPI 0, 152
 vBR C_LT, draw
 vMOV 9, 1
 vADDI 9, 3
 vCMPR 9, 5
 vBR C_LT, pointLeft
 vMOV 9, 5
 vADDI 9, 24
 vCMPR 1, 9
 vBR C_GE, pointLeft
 vSET 0, 152
 vSET 2, 254
 vJMP draw
pointLeft:
 vADDI 6, 1
 vCMPI 6, 10
 vBR C_LT, score
 vSET 6, 0
 vJMP score
pointRight:
 vADDI 7, 1
 vCMPI 7, 10
 vBR C_LT, score
 vSET 7, 0
score:
 vSET 14, 7
 vSET 15, 1
 vMOV 9, 6
 vADDI 9, 4
 vTILE 14, 15, 9
 vSET 14, 12
 vMOV 9, 7
 vADDI 9, 4
 vTILE 14, 15, 9
 vJMP serve
draw:
 vSPR 0, 0, 1, 3
 vMOV 9, 4
 vSPR 1, 10, 9, 2
 vADDI 9, 8
 vSPR 2, 10, 9, 2
 vADDI 9, 8
 vSPR 3, 10, 9, 2
 vMOV 9, 5
 vSPR 4, 11, 9, 2
 vADDI 9, 8
 vSPR 5, 11, 9, 2
 vADDI 9, 8
 vSPR 6, 11, 9, 2
 db I_FRAME
 vJMP frame
cartridgeEnd:
ASSERT cartridgeEnd - cartridge <= 512, "Pong cartridge exceeds packet budget"
