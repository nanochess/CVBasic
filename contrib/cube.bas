' --------------------------------------------------
' Vector Cube Demo - XOR rotate Engine (CVBasic-clean)
' --------------------------------------------------
' Matthew Eggleston. Feb/10/2026

MODE 1

' --------------------------------------------------
' Animation variables
' --------------------------------------------------
#ANGLE = 0
#SIN_VAL = 0

CUBE_SIZE = 24
DEPTH = 12
CENTER_X = 80
CENTER_Y = 88   ' <-- moved further UP

' --------------------------------------------------
' Main loop
' --------------------------------------------------
WHILE 1
    GOSUB DrawCube

    WAIT
    WAIT

    GOSUB DrawCube

    #ANGLE = #ANGLE + 6
    IF #ANGLE >= 360 THEN #ANGLE = 0

    FOR I = 1 TO 16
    NEXT I
WEND

' --------------------------------------------------
' Draw cube routine
' --------------------------------------------------
DrawCube: PROCEDURE

GOSUB CalcSIN
#ROT = #SIN_VAL

' Front square
FX1 = CENTER_X - CUBE_SIZE
FY1 = CENTER_Y - CUBE_SIZE
FX2 = CENTER_X + CUBE_SIZE
FY2 = CENTER_Y - CUBE_SIZE
FX3 = CENTER_X + CUBE_SIZE
FY3 = CENTER_Y + CUBE_SIZE
FX4 = CENTER_X - CUBE_SIZE
FY4 = CENTER_Y + CUBE_SIZE

' Rotate front square
DX = #ROT / 3
DY = #ROT / 4
FX1 = FX1 + DX: FY1 = FY1 - DY
FX2 = FX2 + DY: FY2 = FY2 + DX
FX3 = FX3 - DX: FY3 = FY3 + DY
FX4 = FX4 - DY: FY4 = FY4 - DX

' Back square
BX1 = FX1 + DEPTH
BY1 = FY1 - DEPTH
BX2 = FX2 + DEPTH
BY2 = FY2 - DEPTH
BX3 = FX3 + DEPTH
BY3 = FY3 - DEPTH
BX4 = FX4 + DEPTH
BY4 = FY4 - DEPTH

' Draw edges
AX = FX1: AY = FY1: BX = FX2: BY = FY2: GOSUB Draw_Line_Sub
AX = FX2: AY = FY2: BX = FX3: BY = FY3: GOSUB Draw_Line_Sub
AX = FX3: AY = FY3: BX = FX4: BY = FY4: GOSUB Draw_Line_Sub
AX = FX4: AY = FY4: BX = FX1: BY = FY1: GOSUB Draw_Line_Sub

AX = BX1: AY = BY1: BX = BX2: BY = BY2: GOSUB Draw_Line_Sub
AX = BX2: AY = BY2: BX = BX3: BY = BY3: GOSUB Draw_Line_Sub
AX = BX3: AY = BY3: BX = BX4: BY = BY4: GOSUB Draw_Line_Sub
AX = BX4: AY = BY4: BX = BX1: BY = BY1: GOSUB Draw_Line_Sub

AX = FX1: AY = FY1: BX = BX1: BY = BY1: GOSUB Draw_Line_Sub
AX = FX2: AY = FY2: BX = BX2: BY = BY2: GOSUB Draw_Line_Sub
AX = FX3: AY = FY3: BX = BX3: BY = BY3: GOSUB Draw_Line_Sub
AX = FX4: AY = FY4: BX = BX4: BY = BY4: GOSUB Draw_Line_Sub

RETURN
END

' --------------------------------------------------
' Integer SIN approximation
' --------------------------------------------------
CalcSIN: PROCEDURE
#A = #ANGLE
IF #A < 90 THEN
    #SIN_VAL = #A
ELSEIF #A < 180 THEN
    #SIN_VAL = 180 - #A
ELSEIF #A < 270 THEN
    #SIN_VAL = -(#A - 180)
ELSE
    #SIN_VAL = -(360 - #A)
END IF
RETURN
END

' --------------------------------------------------
' Bresenham line (XOR)
' --------------------------------------------------
SIGNED #ERR

Draw_Line_Sub: PROCEDURE
IF BX < AX THEN
    #DX = AX - BX : SX = -1
ELSE
    #DX = BX - AX : SX = 1
END IF

IF BY < AY THEN
    #DY = AY - BY : SY = -1
ELSE
    #DY = BY - AY : SY = 1
END IF

IF #DX > #DY THEN
    #ERR = 2 * #DY - #DX
    WHILE 1
        GOSUB PSET_Sub
        IF AX = BX THEN RETURN
        IF #ERR < 0 THEN
            #ERR = #ERR + 2 * #DY
        ELSE
            #ERR = #ERR + 2 * (#DY - #DX)
            AY = AY + SY
        END IF
        AX = AX + SX
    WEND
ELSE
    #ERR = 2 * #DX - #DY
    WHILE 1
        GOSUB PSET_Sub
        IF AY = BY THEN RETURN
        IF #ERR < 0 THEN
            #ERR = #ERR + 2 * #DX
        ELSE
            #ERR = #ERR + 2 * (#DX - #DY)
            AX = AX + SX
        END IF
        AY = AY + SY
    WEND
END IF
RETURN
END

' --------------------------------------------------
' XOR pixel plot
' --------------------------------------------------
PSET_Sub: PROCEDURE
#C = ((AX) AND $F8) + ((192-AY)/8*256) + ((192-AY) AND 7)
VPOKE #C, VPEEK(#C) XOR BIT_TABLE(AX AND 7)
RETURN
END

' --------------------------------------------------
' Bit table for XOR pixels
' --------------------------------------------------
BIT_TABLE:
DATA BYTE $80,$40,$20,$10,$08,$04,$02,$01
