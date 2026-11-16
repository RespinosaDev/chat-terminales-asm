*===========================================================================
* SECCIÓN 1: VECTORES (Dirección $0)
*===========================================================================
            ORG     $0
            DC.L    $8000           * Pila inicial
            DC.L    INICIO          * Reset PC

*===========================================================================
* SECCIÓN 2: EQUIVALENCIAS DUART MC68681
*===========================================================================
            ORG     $400

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

ACR         EQU     $EFFC09
IMR         EQU     $EFFC0B
ISR         EQU     $EFFC0B
IVR         EQU     $EFFC19

* Bits del ISR e IMR
BIT_TXA     EQU     $01             * Bit 0
BIT_RXA     EQU     $02             * Bit 1
BIT_TXB     EQU     $10             * Bit 4
BIT_RXB     EQU     $20             * Bit 5

* Máscaras de apagado
M_NO_TXA    EQU     $FE             * %11111110
M_NO_TXB    EQU     $EF             * %11101111

* IDs de buffer para bib_aux.s
ID_RXA      EQU     0
ID_RXB      EQU     1
ID_TXA      EQU     2
ID_TXB      EQU     3

*===========================================================================
* SECCIÓN 3: VARIABLES GLOBALES
*===========================================================================
            ORG     $1000
IMR_SHADOW  DC.B    $00
            DC.B    $00             * Alineación
BUFFER_USR  DS.B    100             * Buffer temporal de usuario

*===========================================================================
* SECCIÓN 4: PROGRAMA PRINCIPAL (Eco Cruzado A <-> B)
*===========================================================================
            ORG     $500
INICIO
            * Instalar manejadores de excepciones básicos
            MOVE.L  #EXCEP,$8
            MOVE.L  #EXCEP,$C
            MOVE.L  #EXCEP,$10

            MOVE.W  #$2700,SR       * Parar interrupciones
            BSR     INIT
            MOVE.W  #$2000,SR       * Arrancar interrupciones

BUCLE_PR:
* --- PASO 1: LEER DE A -> MANDAR A B ---
            MOVE.W  #1,-(A7)        * N=1
            MOVE.W  #0,-(A7)        * Desc=0 (A)
            PEA     BUFFER_USR
            BSR     SCAN
            LEA     8(A7),A7

            TST.L   D0
            BEQ     .PROBAR_B

            MOVE.W  #1,-(A7)
            MOVE.W  #1,-(A7)        * Desc=1 (B)
            PEA     BUFFER_USR
            BSR     PRINT
            LEA     8(A7),A7

* --- PASO 2: LEER DE B -> MANDAR A A ---
.PROBAR_B:
            MOVE.W  #1,-(A7)
            MOVE.W  #1,-(A7)        * Desc=1 (B)
            PEA     BUFFER_USR
            BSR     SCAN
            LEA     8(A7),A7

            TST.L   D0
            BEQ     BUCLE_PR

            MOVE.W  #1,-(A7)
            MOVE.W  #0,-(A7)        * Desc=0 (A)
            PEA     BUFFER_USR
            BSR     PRINT
            LEA     8(A7),A7

            BRA     BUCLE_PR

EXCEP       BREAK
            NOP

*===========================================================================
* SECCIÓN 5: SUBRUTINAS
*===========================================================================

INIT
            MOVEM.L D0/A0,-(A7)
            BSR     INI_BUFS
            MOVE.L  #RTI,$100       * Vector $40

            * Configuración Línea A (38400, 8N1)
            MOVE.B  #$10,CRA
            MOVE.B  #$13,MR1A
            MOVE.B  #$07,MR1A
            MOVE.B  #$CC,CSRA
            MOVE.B  #$05,CRA

            * Configuración Línea B (38400, 8N1)
            MOVE.B  #$10,CRB
            MOVE.B  #$13,MR1B
            MOVE.B  #$07,MR1B
            MOVE.B  #$CC,CSRB
            MOVE.B  #$05,CRB

            MOVE.B  #$40,IVR
            MOVE.B  #$22,IMR_SHADOW * Solo RX activos al inicio
            MOVE.B  IMR_SHADOW,IMR
            MOVEM.L (A7)+,D0/A0
            RTS

SCAN
            LINK    A6,#0
            MOVEM.L D1-D3/A0,-(A7)

            MOVEA.L 8(A6),A0        * Buffer destino
            MOVE.W  12(A6),D1       * Descriptor
            MOVE.W  14(A6),D2       * N

            * Validación de descriptor (Solo 0 o 1)
            CMP.W   #1,D1
            BHI     .ERR_SCAN

            CLR.L   D3              * Contador de éxito
.L_SCAN     TST.W   D2
            BEQ     .F_SCAN
            MOVE.L  D1,D0           * ID Buffer (0 o 1)
            BSR     LEECAR
            CMP.L   #-1,D0
            BEQ     .F_SCAN
            MOVE.B  D0,(A0)+
            ADDQ.L  #1,D3
            SUBQ.W  #1,D2
            BRA     .L_SCAN
.F_SCAN     MOVE.L  D3,D0
            BRA     .OUT_SCAN
.ERR_SCAN   MOVE.L  #$FFFFFFFF,D0
.OUT_SCAN   MOVEM.L (A7)+,D1-D3/A0
            UNLK    A6
            RTS

PRINT
            LINK    A6,#0
            MOVEM.L D1-D4/A0/A1,-(A7)

			MOVE.W  SR,-(A7)        * [1] GUARDAR SR ACTUAL (con interrupciones)
            MOVE.W  #$2700,SR       * [2] DESHABILITAR INTERRUPCIONES TEMPORALMENTE

            MOVEA.L 8(A6),A0        * Buffer origen
            MOVE.W  12(A6),D4       * Descriptor (Guardar en D4)
            MOVE.W  14(A6),D2       * N

            * Validación de descriptor
            CMP.W   #1,D4
            BHI     .ERR_PRINT

            * Calcular ID de Buffer TX (Desc 0 -> ID 2, Desc 1 -> ID 3)
            MOVE.L  D4,D3
            ADDQ.L  #2,D3

            CLR.L   D1              * Contador de éxito
.L_PRINT    TST.W   D2
            BEQ     .P_ACT
            MOVE.L  D3,D0           * ID Buffer TX
            MOVE.B  (A0)+,D1
            BSR     ESCCAR
            CMP.L   #-1,D0
            BEQ     .P_ACT
            ADDQ.L  #1,D1
            SUBQ.W  #1,D2
            BRA     .L_PRINT

.P_ACT      * Activar interrupción en IMR_SHADOW
            CMP.W   #0,D4
            BNE     .P_B
            OR.B    #BIT_TXA,IMR_SHADOW
            MOVEA.L #SRA,A1         * Preparar A1 para el parche (Status A)
            BRA     .P_SET
.P_B        OR.B    #BIT_TXB,IMR_SHADOW
            MOVEA.L #SRB,A1         * Preparar A1 para el parche (Status B)

.P_SET      MOVE.B  IMR_SHADOW,IMR

            * --- EMPUJE INTELIGENTE ---
            * Si el transmisor está vacío (bit 2 de SR), la RTI no saltará.
            * Forzamos el primer carácter manualmente.
            BTST    #2,(A1)         * Mirar TXEMP en el SR seleccionado
            BEQ     .P_EXIT         * Si está ocupado, la RTI ya se encargará

            MOVE.L  D3,D0           * ID Buffer TX
            BSR     LEECAR          * Intentar sacar el que acabamos de meter
            CMP.L   #-1,D0
            BEQ     .P_EXIT

            * ¿A qué registro físico enviamos?
            CMP.W   #0,D4
            BNE     .SEND_B
            MOVE.B  D0,TBA          * Hardware A
            BRA     .P_EXIT
.SEND_B     MOVE.B  D0,TBB          * Hardware B

.P_EXIT     MOVE.L  D1,D0
            MOVE.W  (A7)+,SR        * [3] RESTAURAR SR (vuelven las interrupciones)
            MOVEM.L (A7)+,D1-D4/A0/A1
            UNLK    A6
            RTS
.ERR_PRINT  MOVE.L  #$FFFFFFFF,D0
.OUT_PRINT  MOVEM.L (A7)+,D1-D4/A0/A1
            UNLK    A6
            RTS

*===========================================================================
* SECCIÓN 6: RTI
*===========================================================================
RTI
            MOVEM.L D0-D1/A0,-(A7)
            MOVE.B  ISR,D0
            AND.B   IMR_SHADOW,D0

            * RX A
            BTST    #1,D0
            BEQ     .T_A
            MOVE.B  RBA,D1
            MOVE.L  #ID_RXA,D0
            BSR     ESCCAR
            BRA     .F_RTI

            * TX A
.T_A        BTST    #0,D0
            BEQ     .R_B
            MOVE.L  #ID_TXA,D0
            BSR     LEECAR
            CMP.L   #-1,D0
            BEQ     .OFF_A
            MOVE.B  D0,TBA
            BRA     .F_RTI
.OFF_A      AND.B   #M_NO_TXA,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR
            BRA     .F_RTI

            * RX B
.R_B        BTST    #5,D0
            BEQ     .T_B
            MOVE.B  RBB,D1
            MOVE.L  #ID_RXB,D0
            BSR     ESCCAR
            BRA     .F_RTI

            * TX B
.T_B        BTST    #4,D0
            BEQ     .F_RTI
            MOVE.L  #ID_TXB,D0
            BSR     LEECAR
            CMP.L   #-1,D0
            BEQ     .OFF_B
            MOVE.B  D0,TBB
            BRA     .F_RTI
.OFF_B      AND.B   #M_NO_TXB,IMR_SHADOW
            MOVE.B  IMR_SHADOW,IMR

.F_RTI      MOVEM.L (A7)+,D0-D1/A0
            RTE

            INCLUDE bib_aux.s
