
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

			TOTAL_AB:  DC.L    0
			TOTAL_BA:  DC.L    0
IMR_SHADOW  DC.B    $00
            DC.B    $00
            DS.W 0
BUFFER_USR  DS.B    2000

*--- PROGRAMA
            ORG     $500
TOTAL       DC.W    0

INICIO:     MOVEA.L #$8000,A7
            MOVE.W  #$2700,SR
            BSR     INIT
            MOVE.W  #$2000,SR

T8_BUCLE:   MOVE.W  #16,-(A7)
            MOVE.W  #0,-(A7)        * leer de A
            PEA     BUFFER_USR
            BSR     SCAN
            LEA     8(A7),A7
            TST.L   D0
            BLE     T8_BA
            ADD.L   D0,TOTAL_AB

            MOVE.W  D0,-(A7)
            MOVE.W  #1,-(A7)        * escribir en B
            PEA     BUFFER_USR
            BSR     PRINT
            LEA     8(A7),A7

T8_BA:      MOVE.W  #16,-(A7)
            MOVE.W  #1,-(A7)        * leer de B
            PEA     BUFFER_USR+200
            BSR     SCAN
            LEA     8(A7),A7
            TST.L   D0
            BLE     T8_CHECK
            ADD.L   D0,TOTAL_BA

            MOVE.W  D0,-(A7)
            MOVE.W  #0,-(A7)        * escribir en A
            PEA     BUFFER_USR+200
            BSR     PRINT
            LEA     8(A7),A7

T8_CHECK:   CMP.L   #40,TOTAL_AB
            BLT     T8_BUCLE
            CMP.L   #40,TOTAL_BA
            BLT     T8_BUCLE

T8_FIN:     BREAK                   * Si no se cuelga y sin caracteres perdidos
            NOP                     * o duplicados entonces es correcto
            BRA     T8_FIN

*===========================================================================
* SCAN Y PRINT
*===========================================================================
            DS.W    0
SCAN:
            LINK    A6,#-16
            MOVEM.L D1/A0,-(A7)         * Conservamos los registros del llamador

            MOVE.L  8(A6),-4(A6)        * Buffer ptr
            MOVE.W  12(A6),-6(A6)       * Descriptor
            MOVE.W  14(A6),-8(A6)       * Tamaño
            CLR.L   -12(A6)             * Caracteres leídos

            CMP.W   #1,-6(A6)
            BHI     .S_ERR

            MOVE.W  SR,-(A7)            *  Inicio seccion critica
            ORI.W   #$0700,SR

.S_LOOP:    TST.W   -8(A6)
            BEQ     .S_FIN

            MOVE.W  -6(A6),D0
            BSR     LEECAR

            CMP.L   #$FFFFFFFF,D0
            BEQ     .S_FIN

            MOVEA.L -4(A6),A0
            MOVE.B  D0,(A0)+
            MOVE.L  A0,-4(A6)           * Actualizamos puntero

            ADDQ.L  #1,-12(A6)          * Incrementa leídos
            SUBQ.W  #1,-8(A6)           * Decrementa tamaño restante
            BRA     .S_LOOP

.S_FIN:     MOVE.W  (A7)+,SR            * Fin seccion critica
            MOVE.L  -12(A6),D0          * Retorna caracteres leídos
            BRA     .S_OUT
.S_ERR:     MOVE.L  #$FFFFFFFF,D0
.S_OUT:     MOVEM.L (A7)+,D1/A0
            UNLK    A6
            RTS

            DS.W    0
PRINT:
            LINK    A6,#-16
            MOVEM.L D1/A0,-(A7)         * Conservamos los registros del llamador

            MOVE.L  8(A6),-4(A6)        * Buffer ptr
            MOVE.W  12(A6),-6(A6)       * Descriptor
            MOVE.W  14(A6),-8(A6)       * Tamaño
            CLR.L   -12(A6)             * Caracteres escritos

            CMP.W   #1,-6(A6)
            BHI     .P_ERR
            TST.W   -8(A6)
            BEQ     .P_CERO

            MOVE.W  SR,-(A7)            *  Inicio seccion critica
            ORI.W   #$0700,SR

.P_LOOP:    TST.W   -8(A6)
            BEQ     .P_LEND

            MOVEA.L -4(A6),A0           * Recuperar puntero seguro
            MOVE.B  (A0)+,D1            * Cargar carácter a D1
            MOVE.L  A0,-4(A6)

            MOVE.W  -6(A6),D0
            ADDQ.L  #2,D0               * Sumar 2 para obtener descriptor de TX
            BSR     ESCCAR

            CMP.L   #$FFFFFFFF,D0
            BEQ     .P_LEND

            ADDQ.L  #1,-12(A6)
            SUBQ.W  #1,-8(A6)
            BRA     .P_LOOP

.P_LEND:    MOVE.W  (A7)+,SR            * Fin seccion critica

.P_ACT:     MOVE.L  -12(A6),D0
            BEQ     .P_OUT

            MOVE.W  SR,-(A7)            * IMR + kickstart
            ORI.W   #$0700,SR

            CMP.W   #0,-6(A6)
            BNE     .P_ACT_B

            OR.B    #BIT_TXA,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR
            BTST    #2,SRA              * ¿Línea A YA lista para transmitir?
            BEQ     .P_SET              * No -> ya se encargará la interrupción
            MOVE.L  #2,D0               * Sí -> empujamos el primer carácter a mano
            BSR     LEECAR
            CMP.L   #$FFFFFFFF,D0
            BEQ     .P_SET
            MOVE.B  D0,TBA
            BRA     .P_SET

.P_ACT_B:   OR.B    #BIT_TXB,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR
            BTST    #2,SRB
            BEQ     .P_SET
            MOVE.L  #3,D0
            BSR     LEECAR
            CMP.L   #$FFFFFFFF,D0
            BEQ     .P_SET
            MOVE.B  D0,TBB

.P_SET:     MOVE.W  (A7)+,SR

            MOVE.L  -12(A6),D0
            BRA     .P_OUT

.P_CERO:    CLR.L   D0
            BRA     .P_OUT
.P_ERR:     MOVE.L  #$FFFFFFFF,D0
.P_OUT:     MOVEM.L (A7)+,D1/A0
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
            MOVEM.L D0-D1,-(A7)         * Solo D0/D1
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
            MOVEM.L (A7)+,D0-D1         * Restauramos la ejecución
            RTE

*===========================================================================
* BIBLIOTECA
*===========================================================================
            DS.W    0
            INCLUDE bib_aux.s
