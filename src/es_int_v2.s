
            ORG     $0
            DC.L    $8000
            DC.L    INICIO

*--- EQUIVALENCIAS ---
MR1A        EQU     $EFFC01
SRA         EQU     $EFFC03
CSRA        EQU     $EFFC03
CRA         EQU     $EFFC05
TBA         EQU     $EFFC07
RBA         EQU     $EFFC07
MR1B        EQU     $EFFC11
SRB         EQU     $EFFC13
CSRB        EQU     $EFFC13
CRB         EQU     $EFFC15
TBB         EQU     $EFFC17
RBB         EQU     $EFFC17
IMR         EQU     $EFFC0B
ISR         EQU     $EFFC0B
IVR         EQU     $EFFC19

BIT_TXA     EQU     $01
BIT_RXA     EQU     $02
BIT_TXB     EQU     $10
BIT_RXB     EQU     $20
M_NO_TXA    EQU     $FE
M_NO_TXB    EQU     $EF

*--- VARIABLES ---
            ORG     $5000
            DS.W 0
IMR_SHADOW  DC.B    $00
            DC.B    $00
            DS.W 0
BUFFER_USR  DS.B    2000

*--- PROGRAMA ---
            ORG     $500
INICIO:
            MOVEA.L #$8000,A7
            MOVE.W  #$2700,SR
            BSR     INIT
            MOVE.W  #$2000,SR
BUCLE_PR:
            MOVE.W  #10,-(A7)
            MOVE.W  #0,-(A7)
            PEA     BUFFER_USR
            BSR     SCAN
            LEA     8(A7),A7
            TST.L   D0
            BLE     PROBAR_B
            MOVE.W  D0,-(A7)
            MOVE.W  #1,-(A7)
            PEA     BUFFER_USR
            BSR     PRINT
            LEA     8(A7),A7
PROBAR_B:
            MOVE.W  #1,-(A7)
            MOVE.W  #1,-(A7)
            PEA     BUFFER_USR
            BSR     SCAN
            LEA     8(A7),A7
            TST.L   D0
            BLE     BUCLE_PR
            MOVE.W  D0,-(A7)
            MOVE.W  #0,-(A7)
            PEA     BUFFER_USR
            BSR     PRINT
            LEA     8(A7),A7
            BRA     BUCLE_PR

*===========================================================================
* SCAN Y PRINT
*===========================================================================
            DS.W    0
SCAN:
            LINK    A6,#-16             * Reservamos espacio para variables locales
            MOVEM.L D1-D7/A0-A5,-(A7)   * Salvaguardamos registros del llamador

            MOVE.L  8(A6),-4(A6)        * Buffer ptr
            MOVE.W  12(A6),-6(A6)       * Descriptor
            MOVE.W  14(A6),-8(A6)       * Tamaño
            CLR.L   -12(A6)             * Caracteres leídos

            CMP.W   #1,-6(A6)
            BHI     .S_ERR

.S_LOOP:    TST.W   -8(A6)
            BEQ     .S_FIN

            MOVE.W  SR,-(A7)
            ORI.W   #$0700,SR
            MOVE.W  -6(A6),D0
            AND.L   #$0000FFFF,D0
            BSR     LEECAR

            MOVE.W  (A7)+,SR
            CMP.L   #$FFFFFFFF,D0
            BEQ     .S_FIN

            MOVEA.L -4(A6),A0
            MOVE.B  D0,(A0)+
            MOVE.L  A0,-4(A6)           * Actualizamos puntero

            ADDQ.L  #1,-12(A6)          * Incrementa leídos
            SUBQ.W  #1,-8(A6)           * Decrementa tamaño restante
            BRA     .S_LOOP

.S_FIN:     MOVE.L  -12(A6),D0          * Retorna caracteres leídos
            BRA     .S_OUT
.S_ERR:     MOVE.L  #$FFFFFFFF,D0
.S_OUT:     MOVEM.L (A7)+,D1-D7/A0-A5
            UNLK    A6
            RTS

            DS.W    0
PRINT:
            LINK    A6,#-16
            MOVEM.L D1-D7/A0-A5,-(A7)

            MOVE.L  8(A6),-4(A6)        * Buffer ptr
            MOVE.W  12(A6),-6(A6)       * Descriptor
            MOVE.W  14(A6),-8(A6)       * Tamaño
            CLR.L   -12(A6)             * Caracteres escritos

            CMP.W   #1,-6(A6)
            BHI     .P_ERR
            TST.W   -8(A6)
            BEQ     .P_CERO

.P_LOOP:    TST.W   -8(A6)
            BEQ     .P_ACT

            MOVEA.L -4(A6),A0           * Recuperar puntero seguro
            MOVE.B  (A0)+,D1            * Cargar carácter a D1
            MOVE.L  A0,-4(A6)

            MOVE.W  -6(A6),D0
            AND.L   #$0000FFFF,D0
            ADDQ.L  #2,D0               * Sumar 2 para obtener descriptor de TX

            MOVE.W  SR,-(A7)
            ORI.W   #$0700,SR
            BSR     ESCCAR
            MOVE.W  (A7)+,SR

            CMP.L   #$FFFFFFFF,D0
            BEQ     .P_ACT

            ADDQ.L  #1,-12(A6)
            SUBQ.W  #1,-8(A6)
            BRA     .P_LOOP

.P_ACT:     MOVE.L  -12(A6),D0
            BEQ     .P_OUT              * Si escribió 0 caracteres, no activar TX

            MOVE.W  SR,-(A7)
            ORI.W   #$0700,SR

            CMP.W   #0,-6(A6)
            BNE     .P_ACT_B
            OR.B    #BIT_TXA,IMR_SHADOW
            BRA     .P_SET
.P_ACT_B:   OR.B    #BIT_TXB,IMR_SHADOW
.P_SET:     MOVE.B  IMR_SHADOW,IMR

            MOVE.W  (A7)+,SR

            MOVE.L  -12(A6),D0          * Retornamos escritos
            BRA     .P_OUT

.P_CERO:    CLR.L   D0
            BRA     .P_OUT
.P_ERR:     MOVE.L  #$FFFFFFFF,D0
.P_OUT:     MOVEM.L (A7)+,D1-D7/A0-A5
            UNLK    A6
            RTS

*===========================================================================
* INIT Y RTI
*===========================================================================
            DS.W    0
INIT:
            MOVEM.L D0/A0,-(A7)
            BSR     INI_BUFS
            MOVE.L  #RTI,$100
            MOVE.B  #$10,CRA
            MOVE.B  #$13,MR1A
            MOVE.B  #$07,MR1A
            MOVE.B  #$CC,CSRA
            MOVE.B  #$05,CRA
            MOVE.B  #$10,CRB
            MOVE.B  #$13,MR1B
            MOVE.B  #$07,MR1B
            MOVE.B  #$CC,CSRB
            MOVE.B  #$05,CRB
            MOVE.B  #$40,IVR
            MOVE.B  #$22,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR
            MOVEM.L (A7)+,D0/A0
            RTS

            DS.W    0
RTI:
            MOVEM.L D0-D7/A0-A6,-(A7)   * Salvaguardamos todo el sistema
            MOVE.B  ISR,D0
            AND.B   IMR_SHADOW,D0
            MOVE.W  D0,-(A7)            * Guardamos los bits pendientes en la pila

.R_RXA:     BTST    #1,1(A7)
            BEQ     .R_TXA
            MOVE.B  RBA,D1
            CLR.L   D0
            BSR     ESCCAR
.R_TXA:     BTST    #0,1(A7)
            BEQ     .R_RXB
            MOVE.L  #2,D0
            BSR     LEECAR
            CMP.L   #$FFFFFFFF,D0
            BEQ     .R_DA
            MOVE.B  D0,TBA
            BRA     .R_RXB
.R_DA:      AND.B   #M_NO_TXA,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR
.R_RXB:     BTST    #5,1(A7)
            BEQ     .R_TXB
            MOVE.B  RBB,D1
            MOVE.L  #1,D0
            BSR     ESCCAR
.R_TXB:     BTST    #4,1(A7)
            BEQ     .R_FIN
            MOVE.L  #3,D0
            BSR     LEECAR
            CMP.L   #$FFFFFFFF,D0
            BEQ     .R_DB
            MOVE.B  D0,TBB
            BRA     .R_FIN
.R_DB:      AND.B   #M_NO_TXB,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR

.R_FIN:     ADDQ.L  #2,A7               * Limpiamos la variable temporal de la pila
            MOVEM.L (A7)+,D0-D7/A0-A6   * Restauramos la ejecución
            RTE

*===========================================================================
* BIBLIOTECA
*===========================================================================
            DS.W    0
            INCLUDE bib_aux.s
