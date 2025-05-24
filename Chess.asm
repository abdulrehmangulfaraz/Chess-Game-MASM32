.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdiplus.inc
include \masm32\include\masm32.inc

includelib \masm32\lib\user32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdiplus.lib
includelib \masm32\lib\masm32.lib

.const
    SquareSizev equ 120
    BoardSizev equ SquareSizev*8
    MAX_INPUTv equ 128
    BorderSizev equ 30  ; Space for algebraic notation labels

.data
    ClassNamev db "ChessGameClass", 0
    AppNamev db "Chess Game - MASM32", 0
    FontNamev db "Segoe UI Symbol", 0
    PromptTextv db 0Dh, 0Ah, "Enter move (e.g., 'e2 e4' or 'O-O' for castling): ", 0
    InvalidMoveTextv db 0Dh, 0Ah, "Invalid move! Please try again.", 0Dh, 0Ah, 0
    CheckTextv db 0Dh, 0Ah, "Check!", 0Dh, 0Ah, 0
    CheckmateTextv db 0Dh, 0Ah, "Checkmate! Game over.", 0
    BlueWinsTextv db 0Dh, 0Ah, "Blue wins!", 0Dh, 0Ah, 0
    RedWinsTextv db 0Dh, 0Ah, "Red wins!", 0Dh, 0Ah, 0
    SeparatorTextv db "--------------------------------------------------", 0
    CmdWindowTitlev db 0Dh, 0Ah, "Chess Command Input", 0
    Player1MoveTextv db 0Dh, 0Ah, "Player 1 (Blue) move: ", 0
    Player2MoveTextv db 0Dh, 0Ah, "Player 2 (Red) move: ", 0
    PromoteTextv db 0Dh, 0Ah, "Pawn promotion! Enter piece (Q, R, B, N): ", 0
    PromotedTextv db 0Dh, 0Ah, "Pawn promoted to ", 0
    RankLabelsv db "12345678", 0
    FileLabelsv db "abcdefgh", 0

    ; Unicode chess symbols
    EmptySquarev dw 0

    ; Initial piece positions
    InitialBoardv dw 2656h, 2658h, 2657h, 2655h, 2654h, 2657h, 2658h, 2656h  ; White back row
                 dw 2659h, 2659h, 2659h, 2659h, 2659h, 2659h, 2659h, 2659h  ; White pawns
                 dw 8 dup(0)                                                 ; Empty rows
                 dw 8 dup(0)
                 dw 8 dup(0)
                 dw 8 dup(0)
                 dw 265Fh, 265Fh, 265Fh, 265Fh, 265Fh, 265Fh, 265Fh, 265Fh  ; Black pawns
                 dw 265Ch, 265Eh, 265Dh, 265Bh, 265Ah, 265Dh, 265Eh, 265Ch  ; Black back row

.data?
    hInstv HINSTANCE ?
    hwndMainv HWND ?
    msgv MSG <>
    wcv WNDCLASSEX <>
    xCoordv dd ?
    yCoordv dd ?
    hFontv dd ?
    CurrentBoardv dw 64 dup(?)  ; 8x8 board
    hInputv dd ?
    hOutputv dd ?
    InputBufferv db MAX_INPUTv dup(?)
    MoveFromXv db ?
    MoveFromYv db ?
    MoveToXv db ?
    MoveToYv db ?
    Turnv db ?  ; 0 = white (Blue), 1 = black (Red)
    GameOverv db ?  ; 0 = ongoing, 1 = game over
    WhiteCanCastleKingsidev db ?  ; 1 = can castle kingside
    WhiteCanCastleQueensidev db ?  ; 1 = can castle queenside
    BlackCanCastleKingsidev db ?  ; 1 = can castle kingside
    BlackCanCastleQueensidev db ?  ; 1 = can castle queenside
    EnPassantTargetXv db ?  ; X-coordinate of en passant target square
    EnPassantTargetYv db ?  ; Y-coordinate of en passant target square
    EnPassantAvailablev db ?  ; 1 = en passant available this turn

.code

; Forward declarations
InputThreadv proto Paramv:DWORD
CreateChessFontv proto hdcv:HDC
DrawPiecev proto hdcv:HDC, xPosv:DWORD, yPosv:DWORD, piecev:WORD
InitializeBoardv proto
GetPieceAtv proto xPosv:BYTE, yPosv:BYTE
SetPieceAtv proto xPosv:BYTE, yPosv:BYTE, piecev:WORD
ParseMovev proto
HandleCastlingv proto
HandleEnPassantv proto
HandlePawnPromotionv proto
GetUserMovev proto
IsValidMovev proto piecev:WORD, fromXv:BYTE, fromYv:BYTE, toXv:BYTE, toYv:BYTE
IsKingInCheckv proto isWhitev:BYTE
IsCheckmatev proto isWhitev:BYTE
IsPathClearv proto fromXv:BYTE, fromYv:BYTE, toXv:BYTE, toYv:BYTE

CreateChessFontv proc hdcv:HDC
    invoke CreateFont, SquareSizev/2, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, 
                      DEFAULT_CHARSET, OUT_OUTLINE_PRECIS, CLIP_DEFAULT_PRECIS, 
                      CLEARTYPE_QUALITY, VARIABLE_PITCH, addr FontNamev
    ret
CreateChessFontv endp

DrawPiecev proc hdcv:HDC, xPosv:DWORD, yPosv:DWORD, piecev:WORD
    LOCAL pieceRectv:RECT
    LOCAL oldFontv:HANDLE
    LOCAL wbufv[2]:WORD
    
    cmp piecev, 0
    je @F
    
    mov ax, piecev
    mov wbufv[0], ax
    mov wbufv[2], 0
    
    mov eax, xPosv
    add eax, SquareSizev/4
    mov pieceRectv.left, eax
    add eax, SquareSizev/2
    mov pieceRectv.right, eax
    
    mov eax, yPosv
    add eax, SquareSizev/4
    mov pieceRectv.top, eax
    add eax, SquareSizev/2
    mov pieceRectv.bottom, eax
    
    .if piecev >= 265Ah && piecev <= 265Fh  ; Red (Black) pieces
        invoke SetTextColor, hdcv, 000000FFh
    .else  ; Blue (White) pieces
        invoke SetTextColor, hdcv, 00FF0000h
    .endif
    
    invoke CreateChessFontv, hdcv
    mov hFontv, eax
    invoke SelectObject, hdcv, hFontv
    mov oldFontv, eax
    
    invoke SetBkMode, hdcv, TRANSPARENT
    invoke DrawTextW, hdcv, addr wbufv, 1, addr pieceRectv, DT_CENTER or DT_VCENTER or DT_SINGLELINE
    
    invoke SelectObject, hdcv, oldFontv
    invoke DeleteObject, hFontv
    
@@:
    ret
DrawPiecev endp

InitializeBoardv proc
    mov esi, offset InitialBoardv
    mov edi, offset CurrentBoardv
    mov ecx, 64
    rep movsw
    mov Turnv, 0
    mov GameOverv, 0
    mov WhiteCanCastleKingsidev, 1
    mov WhiteCanCastleQueensidev, 1
    mov BlackCanCastleKingsidev, 1
    mov BlackCanCastleQueensidev, 1
    mov EnPassantAvailablev, 0
    mov EnPassantTargetXv, 0
    mov EnPassantTargetYv, 0
    ret
InitializeBoardv endp

GetPieceAtv proc xPosv:BYTE, yPosv:BYTE
    xor eax, eax
    mov al, yPosv
    shl eax, 3
    xor ebx, ebx
    mov bl, xPosv
    add eax, ebx
    mov ax, word ptr [CurrentBoardv + eax*2]
    ret
GetPieceAtv endp

SetPieceAtv proc xPosv:BYTE, yPosv:BYTE, piecev:WORD
    xor eax, eax
    mov al, yPosv
    shl eax, 3
    xor ebx, ebx
    mov bl, xPosv
    add eax, ebx
    mov bx, piecev
    mov word ptr [CurrentBoardv + eax*2], bx
    ret
SetPieceAtv endp

IsPathClearv proc fromXv:BYTE, fromYv:BYTE, toXv:BYTE, toYv:BYTE
    LOCAL deltaXv:BYTE, deltaYv:BYTE, currentXv:BYTE, currentYv:BYTE
    LOCAL stepXv:BYTE, stepYv:BYTE
    LOCAL absDeltaXv:BYTE, absDeltaYv:BYTE
    
    mov al, toXv
    sub al, fromXv
    mov deltaXv, al
    .if al >= 0
        mov absDeltaXv, al
    .else
        neg al
        mov absDeltaXv, al
    .endif
    
    mov al, toYv
    sub al, fromYv
    mov deltaYv, al
    .if al >= 0
        mov absDeltaYv, al
    .else
        neg al
        mov absDeltaYv, al
    .endif
    
    ; Determine step direction
    xor al, al
    cmp deltaXv, 0
    jg @PositiveX
    jl @NegativeX
    mov stepXv, 0
    jmp @CheckY
@NegativeX:
    mov stepXv, 0FFh
    jmp @CheckY
@PositiveX:
    mov stepXv, 1
@CheckY:
    cmp deltaYv, 0
    jg @PositiveY
    jl @NegativeY
    mov stepYv, 0
    jmp @DoneSteps
@NegativeY:
    mov stepYv, 0FFh
    jmp @DoneSteps
@PositiveY:
    mov stepYv, 1
@DoneSteps:
    
    mov al, fromXv
    add al, stepXv
    mov currentXv, al
    mov al, fromYv
    add al, stepYv
    mov currentYv, al
    
@CheckLoop:
    mov al, currentXv
    cmp al, toXv
    jne @Continue
    mov al, currentYv
    cmp al, toYv
    je @PathClear
@Continue:
    invoke GetPieceAtv, currentXv, currentYv
    cmp ax, 0
    jne @PathBlocked
    
    mov al, currentXv
    add al, stepXv
    mov currentXv, al
    mov al, currentYv
    add al, stepYv
    mov currentYv, al
    jmp @CheckLoop
    
@PathBlocked:
    xor eax, eax
    ret
@PathClear:
    mov eax, 1
    ret
IsPathClearv endp

IsValidMovev proc piecev:WORD, fromXv:BYTE, fromYv:BYTE, toXv:BYTE, toYv:BYTE
    LOCAL deltaXv:BYTE, deltaYv:BYTE
    LOCAL absDeltaXv:BYTE, absDeltaYv:BYTE
    LOCAL targetPiecev:WORD
    
    ; Get the piece at the target square
    invoke GetPieceAtv, toXv, toYv
    mov targetPiecev, ax
    
    ; Check if the target square has a piece of the same color
    .if targetPiecev != 0
        mov ax, piecev
        .if (ax >= 265Ah && ax <= 265Fh && targetPiecev >= 265Ah && targetPiecev <= 265Fh) || \
            (ax < 265Ah && targetPiecev < 265Ah)
            xor eax, eax
            ret
        .endif
    .endif
    
    ; Calculate deltas
    mov al, toXv
    sub al, fromXv
    mov deltaXv, al
    .if al >= 0
        mov absDeltaXv, al
    .else
        neg al
        mov absDeltaXv, al
    .endif
    
    mov al, toYv
    sub al, fromYv
    mov deltaYv, al
    .if al >= 0
        mov absDeltaYv, al
    .else
        neg al
        mov absDeltaYv, al
    .endif
    
    ; Pawn
    .if piecev == 2659h  ; White pawn (Blue)
        mov al, Turnv
        cmp al, 0
        jne @InvalidPawn
        mov al, deltaXv
        cmp al, 0
        jne @CheckWhitePawnCapture
        ; Forward move
        mov al, deltaYv
        cmp al, 1
        je @WhitePawnSingle
        cmp al, 2
        jne @InvalidPawn
        mov al, fromYv
        cmp al, 1
        jne @InvalidPawn
        cmp targetPiecev, 0
        jne @InvalidPawn
        invoke GetPieceAtv, fromXv, 2
        cmp ax, 0
        jne @InvalidPawn
        mov eax, 1
        ret
@WhitePawnSingle:
        cmp targetPiecev, 0
        jne @InvalidPawn
        mov eax, 1
        ret
@CheckWhitePawnCapture:
        mov al, absDeltaXv
        cmp al, 1
        jne @CheckWhiteEnPassant
        mov al, deltaYv
        cmp al, 1
        jne @InvalidPawn
        cmp targetPiecev, 0
        je @CheckWhiteEnPassant
        mov ax, targetPiecev
        cmp ax, 265Ah
        jl @InvalidPawn  ; Cannot capture white piece
        mov eax, 1
        ret
@CheckWhiteEnPassant:
        mov al, absDeltaXv
        cmp al, 1
        jne @InvalidPawn
        mov al, deltaYv
        cmp al, 1
        jne @InvalidPawn
        cmp EnPassantAvailablev, 1
        jne @InvalidPawn
        mov al, toXv
        cmp al, EnPassantTargetXv
        jne @InvalidPawn
        mov al, toYv
        cmp al, EnPassantTargetYv
        jne @InvalidPawn
        mov eax, 1
        ret
    .elseif piecev == 265Fh  ; Black pawn (Red)
        mov al, Turnv
        cmp al, 1
        jne @InvalidPawn
        mov al, deltaXv
        cmp al, 0
        jne @CheckBlackPawnCapture
        ; Forward move
        mov al, deltaYv
        cmp al, 0FFh  ; -1
        je @BlackPawnSingle
        cmp al, 0FEh  ; -2
        jne @InvalidPawn
        mov al, fromYv
        cmp al, 6
        jne @InvalidPawn
        cmp targetPiecev, 0
        jne @InvalidPawn
        invoke GetPieceAtv, fromXv, 5
        cmp ax, 0
        jne @InvalidPawn
        mov eax, 1
        ret
@BlackPawnSingle:
        cmp targetPiecev, 0
        jne @InvalidPawn
        mov eax, 1
        ret
@CheckBlackPawnCapture:
        mov al, absDeltaXv
        cmp al, 1
        jne @CheckBlackEnPassant
        mov al, deltaYv
        cmp al, 0FFh  ; -1
        jne @InvalidPawn
        cmp targetPiecev, 0
        je @CheckBlackEnPassant
        mov ax, targetPiecev
        cmp ax, 265Ah
        jge @InvalidPawn  ; Cannot capture black piece
        mov eax, 1
        ret
@CheckBlackEnPassant:
        mov al, absDeltaXv
        cmp al, 1
        jne @InvalidPawn
        mov al, deltaYv
        cmp al, 0FFh  ; -1
        jne @InvalidPawn
        cmp EnPassantAvailablev, 1
        jne @InvalidPawn
        mov al, toXv
        cmp al, EnPassantTargetXv
        jne @InvalidPawn
        mov al, toYv
        cmp al, EnPassantTargetYv
        jne @InvalidPawn
        mov eax, 1
        ret
@InvalidPawn:
        xor eax, eax
        ret
    
    ; Knight
    .elseif piecev == 2658h || piecev == 265Eh
        mov al, absDeltaXv
        mov ah, absDeltaYv
        .if (al == 2 && ah == 1) || (al == 1 && ah == 2)
            mov eax, 1
            ret
        .endif
        xor eax, eax
        ret
    
    ; Bishop
    .elseif piecev == 2657h || piecev == 265Dh
        mov al, absDeltaXv
        cmp al, absDeltaYv
        jne @InvalidBishop
        invoke IsPathClearv, fromXv, fromYv, toXv, toYv
        cmp eax, 0
        je @InvalidBishop
        mov eax, 1
        ret
@InvalidBishop:
        xor eax, eax
        ret
    
    ; Rook
    .elseif piecev == 2656h || piecev == 265Ch
        mov al, deltaXv
        cmp al, 0
        je @CheckRookPath
        mov al, deltaYv
        cmp al, 0
        je @CheckRookPath
        xor eax, eax
        ret
@CheckRookPath:
        invoke IsPathClearv, fromXv, fromYv, toXv, toYv
        cmp eax, 0
        je @InvalidRook
        mov eax, 1
        ret
@InvalidRook:
        xor eax, eax
        ret
    
    ; Queen
    .elseif piecev == 2655h || piecev == 265Bh
        mov al, deltaXv
        cmp al, 0
        je @CheckQueenPath
        mov al, deltaYv
        cmp al, 0
        je @CheckQueenPath
        mov al, absDeltaXv
        cmp al, absDeltaYv
        jne @InvalidQueen
@CheckQueenPath:
        invoke IsPathClearv, fromXv, fromYv, toXv, toYv
        cmp eax, 0
        je @InvalidQueen
        mov eax, 1
        ret
@InvalidQueen:
        xor eax, eax
        ret
    
    ; King
    .elseif piecev == 2654h || piecev == 265Ah
        mov al, absDeltaXv
        cmp al, 1
        jg @InvalidKing
        mov al, absDeltaYv
        cmp al, 1
        jg @InvalidKing
        mov eax, 1
        ret
@InvalidKing:
        xor eax, eax
        ret
    .endif
    
    xor eax, eax
    ret
IsValidMovev endp

IsKingInCheckv proc isWhitev:BYTE
    LOCAL kingXv:BYTE, kingYv:BYTE
    LOCAL currentXv:BYTE, currentYv:BYTE
    LOCAL piecev:WORD
    LOCAL isOpponentPiecev:BYTE
    
    ; Set flag to identify opponent pieces
    mov isOpponentPiecev, 0
    .if isWhitev == 0
        mov isOpponentPiecev, 1  ; Flag for black pieces
    .endif
    
    ; Find the king's position
    mov kingXv, 0FFh
    mov kingYv, 0FFh
    mov currentYv, 0
    .while currentYv < 8
        mov currentXv, 0
        .while currentXv < 8
            invoke GetPieceAtv, currentXv, currentYv
            mov piecev, ax
            .if isWhitev == 1 && piecev == 2654h  ; White king
                mov al, currentXv
                mov kingXv, al
                mov al, currentYv
                mov kingYv, al
                jmp @FoundKing
            .elseif isWhitev == 0 && piecev == 265Ah  ; Black king
                mov al, currentXv
                mov kingXv, al
                mov al, currentYv
                mov kingYv, al
                jmp @FoundKing
            .endif
            inc currentXv
        .endw
        inc currentYv
    .endw
    
@FoundKing:
    ; Ensure king was found
    cmp kingXv, 0FFh
    je @NoCheck
    cmp kingYv, 0FFh
    je @NoCheck
    
    ; Check all opponent pieces
    mov currentYv, 0
    .while currentYv < 8
        mov currentXv, 0
        .while currentXv < 8
            invoke GetPieceAtv, currentXv, currentYv
            mov piecev, ax
            .if piecev != 0
                mov ax, piecev
                .if isOpponentPiecev == 1 && ax >= 265Ah && ax <= 265Fh  ; Black pieces
                    invoke IsValidMovev, piecev, currentXv, currentYv, kingXv, kingYv
                    .if eax == 1
                        mov eax, 1
                        ret
                    .endif
                .elseif isOpponentPiecev == 0 && ax < 265Ah  ; White pieces
                    invoke IsValidMovev, piecev, currentXv, currentYv, kingXv, kingYv
                    .if eax == 1
                        mov eax, 1
                        ret
                    .endif
                .endif
            .endif
            inc currentXv
        .endw
        inc currentYv
    .endw
    
@NoCheck:
    xor eax, eax
    ret
IsKingInCheckv endp

IsCheckmatev proc isWhitev:BYTE
    LOCAL currentXv:BYTE, currentYv:BYTE, targetXv:BYTE, targetYv:BYTE
    LOCAL piecev:WORD
    LOCAL tempPiecev:WORD
    LOCAL originalPiecev:WORD
    
    ; Check if king is in check
    invoke IsKingInCheckv, isWhitev
    cmp eax, 0
    je @NotCheckmate
    
    ; Try all possible moves for the player's pieces
    mov currentYv, 0
    .while currentYv < 8
        mov currentXv, 0
        .while currentXv < 8
            invoke GetPieceAtv, currentXv, currentYv
            mov piecev, ax
            .if piecev != 0
                .if (isWhitev == 1 && piecev < 265Ah) || (isWhitev == 0 && piecev >= 265Ah)
                    mov targetYv, 0
                    .while targetYv < 8
                        mov targetXv, 0
                        .while targetXv < 8
                            invoke IsValidMovev, piecev, currentXv, currentYv, targetXv, targetYv
                            .if eax == 1
                                ; Simulate the move
                                invoke GetPieceAtv, targetXv, targetYv
                                mov tempPiecev, ax
                                invoke GetPieceAtv, currentXv, currentYv
                                mov originalPiecev, ax
                                invoke SetPieceAtv, targetXv, targetYv, originalPiecev
                                invoke SetPieceAtv, currentXv, currentYv, 0
                                
                                ; Check if still in check
                                invoke IsKingInCheckv, isWhitev
                                push eax
                                
                                ; Restore board
                                invoke SetPieceAtv, currentXv, currentYv, originalPiecev
                                invoke SetPieceAtv, targetXv, targetYv, tempPiecev
                                
                                pop eax
                                cmp eax, 0
                                je @NotCheckmate
                            .endif
                            inc targetXv
                        .endw
                        inc targetYv
                    .endw
                .endif
            .endif
            inc currentXv
        .endw
        inc currentYv
    .endw
    
    mov eax, 1
    ret
    
@NotCheckmate:
    xor eax, eax
    ret
IsCheckmatev endp

HandleCastlingv proc
    LOCAL isWhitev:BYTE
    
    mov bl, Turnv
    mov isWhitev, bl
    
    ; Check if input is "O-O" (kingside) or "O-O-O" (queenside)
    invoke lstrlen, addr InputBufferv
    .if eax == 3  ; "O-O"
        .if byte ptr [InputBufferv] == 'O' && byte ptr [InputBufferv+1] == '-' && byte ptr [InputBufferv+2] == 'O'
            .if isWhitev == 0
                .if WhiteCanCastleKingsidev == 0
                    jmp InvalidMove
                .endif
                ; White kingside: king from E1 (4,0) to G1 (6,0), rook from H1 (7,0) to F1 (5,0)
                invoke GetPieceAtv, 4, 0
                cmp ax, 2654h
                jne InvalidMove
                invoke GetPieceAtv, 7, 0
                cmp ax, 2656h
                jne InvalidMove
                invoke IsPathClearv, 4, 0, 6, 0
                cmp eax, 0
                je InvalidMove
                invoke IsKingInCheckv, 1
                cmp eax, 1
                je InvalidMove
                ; Check if king passes through check
                invoke SetPieceAtv, 5, 0, 2654h
                invoke SetPieceAtv, 4, 0, 0
                invoke IsKingInCheckv, 1
                push eax
                invoke SetPieceAtv, 4, 0, 2654h
                invoke SetPieceAtv, 5, 0, 0
                pop eax
                cmp eax, 1
                je InvalidMove
                ; Perform castling
                invoke SetPieceAtv, 6, 0, 2654h
                invoke SetPieceAtv, 5, 0, 2656h
                invoke SetPieceAtv, 4, 0, 0
                invoke SetPieceAtv, 7, 0, 0
                mov WhiteCanCastleKingsidev, 0
                mov WhiteCanCastleQueensidev, 0
            .else
                .if BlackCanCastleKingsidev == 0
                    jmp InvalidMove
                .endif
                ; Black kingside: king from E8 (4,7) to G8 (6,7), rook from H8 (7,7) to F8 (5,7)
                invoke GetPieceAtv, 4, 7
                cmp ax, 265Ah
                jne InvalidMove
                invoke GetPieceAtv, 7, 7
                cmp ax, 265Ch
                jne InvalidMove
                invoke IsPathClearv, 4, 7, 6, 7
                cmp eax, 0
                je InvalidMove
                invoke IsKingInCheckv, 0
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 5, 7, 265Ah
                invoke SetPieceAtv, 4, 7, 0
                invoke IsKingInCheckv, 0
                push eax
                invoke SetPieceAtv, 4, 7, 265Ah
                invoke SetPieceAtv, 5, 7, 0
                pop eax
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 6, 7, 265Ah
                invoke SetPieceAtv, 5, 7, 265Ch
                invoke SetPieceAtv, 4, 7, 0
                invoke SetPieceAtv, 7, 7, 0
                mov BlackCanCastleKingsidev, 0
                mov BlackCanCastleQueensidev, 0
            .endif
            mov eax, 1
            ret
        .endif
    .elseif eax == 5  ; "O-O-O"
        .if byte ptr [InputBufferv] == 'O' && byte ptr [InputBufferv+1] == '-' && byte ptr [InputBufferv+2] == 'O' && byte ptr [InputBufferv+3] == '-' && byte ptr [InputBufferv+4] == 'O'
            .if isWhitev == 0
                .if WhiteCanCastleQueensidev == 0
                    jmp InvalidMove
                .endif
                ; White queenside: king from E1 (4,0) to C1 (2,0), rook from A1 (0,0) to D1 (3,0)
                invoke GetPieceAtv, 4, 0
                cmp ax, 2654h
                jne InvalidMove
                invoke GetPieceAtv, 0, 0
                cmp ax, 2656h
                jne InvalidMove
                invoke IsPathClearv, 4, 0, 2, 0
                cmp eax, 0
                je InvalidMove
                invoke IsKingInCheckv, 1
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 3, 0, 2654h
                invoke SetPieceAtv, 4, 0, 0
                invoke IsKingInCheckv, 1
                push eax
                invoke SetPieceAtv, 4, 0, 2654h
                invoke SetPieceAtv, 3, 0, 0
                pop eax
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 2, 0, 2654h
                invoke SetPieceAtv, 3, 0, 2656h
                invoke SetPieceAtv, 4, 0, 0
                invoke SetPieceAtv, 0, 0, 0
                mov WhiteCanCastleKingsidev, 0
                mov WhiteCanCastleQueensidev, 0
            .else
                .if BlackCanCastleQueensidev == 0
                    jmp InvalidMove
                .endif
                ; Black queenside: king from E8 (4,7) to C8 (2,7), rook from A8 (0,7) to D8 (3,7)
                invoke GetPieceAtv, 4, 7
                cmp ax, 265Ah
                jne InvalidMove
                invoke GetPieceAtv, 0, 7
                cmp ax, 265Ch
                jne InvalidMove
                invoke IsPathClearv, 4, 7, 2, 7
                cmp eax, 0
                je InvalidMove
                invoke IsKingInCheckv, 0
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 3, 7, 265Ah
                invoke SetPieceAtv, 4, 7, 0
                invoke IsKingInCheckv, 0
                push eax
                invoke SetPieceAtv, 4, 7, 265Ah
                invoke SetPieceAtv, 3, 7, 0
                pop eax
                cmp eax, 1
                je InvalidMove
                invoke SetPieceAtv, 2, 7, 265Ah
                invoke SetPieceAtv, 3, 7, 265Ch
                invoke SetPieceAtv, 4, 7, 0
                invoke SetPieceAtv, 0, 7, 0
                mov BlackCanCastleKingsidev, 0
                mov BlackCanCastleQueensidev, 0
            .endif
            mov eax, 1
            ret
        .endif
    .endif
    
InvalidMove:
    xor eax, eax
    ret
HandleCastlingv endp

HandleEnPassantv proc
    mov EnPassantAvailablev, 0
    
    invoke GetPieceAtv, MoveFromXv, MoveFromYv
    .if ax == 2659h  ; White pawn
        mov al, MoveToYv
        sub al, MoveFromYv
        cmp al, 2
        jne @NoEnPassant
        mov al, MoveFromYv
        cmp al, 1
        jne @NoEnPassant
        mov al, MoveToXv
        mov EnPassantTargetXv, al
        mov al, MoveToYv
        dec al
        mov EnPassantTargetYv, al
        mov EnPassantAvailablev, 1
        ret
    .elseif ax == 265Fh  ; Black pawn
        mov al, MoveFromYv
        sub al, MoveToYv
        cmp al, 2
        jne @NoEnPassant
        mov al, MoveFromYv
        cmp al, 6
        jne @NoEnPassant
        mov al, MoveToXv
        mov EnPassantTargetXv, al
        mov al, MoveToYv
        inc al
        mov EnPassantTargetYv, al
        mov EnPassantAvailablev, 1
        ret
    .endif
    
@NoEnPassant:
    ret
HandleEnPassantv endp

HandlePawnPromotionv proc
    LOCAL piecev:WORD
    LOCAL promoteBufferv[8]:BYTE
    
    invoke GetPieceAtv, MoveToXv, MoveToYv
    mov piecev, ax
    
    .if piecev == 2659h && MoveToYv == 7  ; White pawn at rank 8
        invoke StdOut, addr PromoteTextv
        invoke StdIn, addr promoteBufferv, 8
        mov al, byte ptr [promoteBufferv]
        .if al == 'Q' || al == 'q'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 2655h  ; White queen
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'R' || al == 'r'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 2656h  ; White rook
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'B' || al == 'b'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 2657h  ; White bishop
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'N' || al == 'n'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 2658h  ; White knight
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .else
            invoke SetPieceAtv, MoveToXv, MoveToYv, 2655h  ; Default to queen
            invoke StdOut, addr PromotedTextv
            mov byte ptr [promoteBufferv], 'Q'
            invoke StdOut, addr promoteBufferv
        .endif
    .elseif piecev == 265Fh && MoveToYv == 0  ; Black pawn at rank 1
        invoke StdOut, addr PromoteTextv
        invoke StdIn, addr promoteBufferv, 8
        mov al, byte ptr [promoteBufferv]
        .if al == 'Q' || al == 'q'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 265Bh  ; Black queen
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'R' || al == 'r'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 265Ch  ; Black rook
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'B' || al == 'b'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 265Dh  ; Black bishop
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .elseif al == 'N' || al == 'n'
            invoke SetPieceAtv, MoveToXv, MoveToYv, 265Eh  ; Black knight
            invoke StdOut, addr PromotedTextv
            invoke StdOut, addr promoteBufferv
        .else
            invoke SetPieceAtv, MoveToXv, MoveToYv, 265Bh  ; Default to queen
            invoke StdOut, addr PromotedTextv
            mov byte ptr [promoteBufferv], 'Q'
            invoke StdOut, addr promoteBufferv
        .endif
    .endif
    invoke StdOut, addr SeparatorTextv
    ret
HandlePawnPromotionv endp

ParseMovev proc uses esi edi
    LOCAL tempPiecev:WORD
    LOCAL piecev:WORD
    LOCAL isWhitev:BYTE
    LOCAL inputLen:DWORD
    
    ; Check for castling
    invoke HandleCastlingv
    cmp eax, 1
    je MoveSuccessful
    
    ; Parse the move input (e.g., "e2 e4")
    invoke lstrlen, addr InputBufferv
    mov inputLen, eax
    cmp eax, 5  ; Expecting "e2 e4" format
    jne InvalidMove
    
    movzx eax, byte ptr [InputBufferv]
    .if al >= 'a' && al <= 'h'
        sub al, 'a'
    .elseif al >= 'A' && al <= 'H'
        sub al, 'A'
    .else
        jmp InvalidMove
    .endif
    mov MoveFromXv, al
    
    movzx eax, byte ptr [InputBufferv+1]
    sub al, '1'
    .if al < 0 || al > 7
        jmp InvalidMove
    .endif
    mov MoveFromYv, al
    
    .if byte ptr [InputBufferv+2] != ' '
        jmp InvalidMove
    .endif
    
    movzx eax, byte ptr [InputBufferv+3]
    .if al >= 'a' && al <= 'h'
        sub al, 'a'
    .elseif al >= 'A' && al <= 'H'
        sub al, 'A'
    .else
        jmp InvalidMove
    .endif
    mov MoveToXv, al
    
    movzx eax, byte ptr [InputBufferv+4]
    sub al, '1'
    .if al < 0 || al > 7
        jmp InvalidMove
    .endif
    mov MoveToYv, al
    
    ; Validate coordinates
    cmp MoveFromXv, 7
    jg InvalidMove
    cmp MoveFromYv, 7
    jg InvalidMove
    cmp MoveToXv, 7
    jg InvalidMove
    cmp MoveToYv, 7
    jg InvalidMove
    
    ; Get the piece at the source square
    invoke GetPieceAtv, MoveFromXv, MoveFromYv
    mov piecev, ax
    cmp ax, 0
    je InvalidMove
    
    ; Check if the piece belongs to the current player
    mov bl, Turnv
    mov isWhitev, bl
    .if bl == 0  ; White's turn (Blue)
        cmp ax, 265Ah
        jge InvalidMove  ; Should be < 265Ah for white pieces
    .else  ; Black's turn (Red)
        cmp ax, 265Ah
        jl InvalidMove   ; Should be >= 265Ah for black pieces
    .endif
    
    ; Validate the move
    invoke IsValidMovev, piecev, MoveFromXv, MoveFromYv, MoveToXv, MoveToYv
    cmp eax, 0
    je InvalidMove
    
    ; Temporarily make the move to check for king safety
    invoke GetPieceAtv, MoveToXv, MoveToYv
    mov tempPiecev, ax
    invoke SetPieceAtv, MoveToXv, MoveToYv, piecev
    invoke SetPieceAtv, MoveFromXv, MoveFromYv, 0
    
    ; Handle en passant capture
    .if piecev == 2659h || piecev == 265Fh
        mov al, MoveToXv
        cmp al, EnPassantTargetXv
        jne @NoEnPassantCapture
        mov al, MoveToYv
        cmp al, EnPassantTargetYv
        jne @NoEnPassantCapture
        cmp EnPassantAvailablev, 1
        jne @NoEnPassantCapture
        ; Remove the captured pawn
        mov al, MoveToYv
        .if piecev == 2659h
            dec al
        .else
            inc al
        .endif
        invoke SetPieceAtv, MoveToXv, al, 0
@NoEnPassantCapture:
    .endif
    
    ; Check if the move puts the moving player's king in check
    invoke IsKingInCheckv, isWhitev
    .if eax == 1
        invoke SetPieceAtv, MoveFromXv, MoveFromYv, piecev
        invoke SetPieceAtv, MoveToXv, MoveToYv, tempPiecev
        jmp InvalidMove
    .endif
    
    ; Update castling availability
    .if piecev == 2654h  ; White king
        mov WhiteCanCastleKingsidev, 0
        mov WhiteCanCastleQueensidev, 0
    .elseif piecev == 265Ah  ; Black king
        mov BlackCanCastleKingsidev, 0
        mov BlackCanCastleQueensidev, 0
    .elseif piecev == 2656h  ; White rook
        mov al, MoveFromXv
        .if al == 0 && MoveFromYv == 0
            mov WhiteCanCastleQueensidev, 0
        .elseif al == 7 && MoveFromYv == 0
            mov WhiteCanCastleKingsidev, 0
        .endif
    .elseif piecev == 265Ch  ; Black rook
        mov al, MoveFromXv
        .if al == 0 && MoveFromYv == 7
            mov BlackCanCastleQueensidev, 0
        .elseif al == 7 && MoveFromYv == 7
            mov BlackCanCastleKingsidev, 0
        .endif
    .endif
    
    ; Set up en passant possibility
    invoke HandleEnPassantv
    
    ; Handle pawn promotion
    invoke HandlePawnPromotionv
    
    ; Check if the opponent's king is in check
    mov al, Turnv
    xor al, 1  ; Check the opponent's king
    invoke IsKingInCheckv, al
    .if eax == 1
        invoke StdOut, addr CheckTextv
        invoke IsCheckmatev, al
        .if eax == 1
            invoke StdOut, addr CheckmateTextv
            mov al, Turnv
            .if al == 0
                invoke StdOut, addr BlueWinsTextv
            .else
                invoke StdOut, addr RedWinsTextv
            .endif
            mov GameOverv, 1
        .endif
    .endif
    
    ; Switch turns
    xor Turnv, 1
    
MoveSuccessful:
    invoke InvalidateRect, hwndMainv, NULL, TRUE
    invoke UpdateWindow, hwndMainv
    invoke StdOut, addr SeparatorTextv
    mov eax, 1
    ret
    
InvalidMove:
    invoke StdOut, addr InvalidMoveTextv
    invoke StdOut, addr SeparatorTextv
    xor eax, eax
    ret
ParseMovev endp

GetUserMovev proc
    .if GameOverv == 1
        xor eax, eax
        ret
    .endif
    
    mov al, Turnv
    .if al == 0
        invoke StdOut, addr Player1MoveTextv
    .else
        invoke StdOut, addr Player2MoveTextv
    .endif
    
    invoke StdIn, addr InputBufferv, MAX_INPUTv
    invoke lstrlen, addr InputBufferv
    .if eax < 3  ; Minimum length for "O-O" or "a1 b2"
        invoke StdOut, addr InvalidMoveTextv
        invoke StdOut, addr SeparatorTextv
        xor eax, eax
        ret
    .endif
    
    invoke ParseMovev
    ret  ; Return value is in eax from ParseMovev
GetUserMovev endp

WndProcv proc uses ebx edi esi hWndv:HWND, uMsgv:UINT, wParamv:WPARAM, lParamv:LPARAM
    LOCAL hdcv:HDC
    LOCAL psv:PAINTSTRUCT
    LOCAL brushv:HBRUSH
    LOCAL rectv:RECT
    LOCAL hOldFontv:HANDLE
    LOCAL piecev:WORD
    LOCAL labelBufferv[2]:BYTE
    LOCAL labelRectv:RECT
    LOCAL hOldBrushv:HANDLE
    
    .if uMsgv == WM_DESTROY
        invoke PostQuitMessage, 0
        xor eax, eax
        ret

    .elseif uMsgv == WM_PAINT
        invoke BeginPaint, hWndv, addr psv
        mov hdcv, eax

        ; Clear entire background
        invoke CreateSolidBrush, COLOR_WINDOW+1
        mov brushv, eax
        mov rectv.left, 0
        mov rectv.top, 0
        mov eax, BoardSizev
        add eax, BorderSizev*2
        mov rectv.right, eax
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        invoke DeleteObject, brushv

        ; Draw dark gray background for border areas
        invoke CreateSolidBrush, 00323232h  ; Dark gray (RGB(50,50,50))
        mov brushv, eax
        ; Top border
        mov rectv.left, 0
        mov rectv.top, 0
        mov eax, BoardSizev
        add eax, BorderSizev*2
        mov rectv.right, eax
        mov eax, BorderSizev
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        ; Bottom border
        mov rectv.left, 0
        mov eax, BoardSizev
        add eax, BorderSizev
        mov rectv.top, eax
        mov eax, BoardSizev
        add eax, BorderSizev*2
        mov rectv.right, eax
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        ; Left border
        mov rectv.left, 0
        mov rectv.top, BorderSizev
        mov eax, BorderSizev
        mov rectv.right, eax
        mov eax, BoardSizev
        add eax, BorderSizev
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        ; Right border
        mov eax, BoardSizev
        add eax, BorderSizev
        mov rectv.left, eax
        mov rectv.top, BorderSizev
        mov eax, BoardSizev
        add eax, BorderSizev*2
        mov rectv.right, eax
        mov eax, BoardSizev
        add eax, BorderSizev
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        invoke DeleteObject, brushv

        ; Draw board
        mov yCoordv, BorderSizev
        mov esi, 0
RowLoop:
        mov xCoordv, BorderSizev
        mov edi, 0
ColLoop:
        ; Calculate square color
        mov eax, esi
        add eax, edi
        and eax, 1
        .if eax == 0
            invoke CreateSolidBrush, 0FFFFFFh  ; White
        .else
            invoke CreateSolidBrush, 0000000h  ; Black
        .endif
        mov brushv, eax
        invoke SelectObject, hdcv, brushv
        mov hOldBrushv, eax
        
        ; Draw square
        mov eax, xCoordv
        mov rectv.left, eax
        add eax, SquareSizev
        mov rectv.right, eax
        mov eax, yCoordv
        mov rectv.top, eax
        add eax, SquareSizev
        mov rectv.bottom, eax
        invoke FillRect, hdcv, addr rectv, brushv
        
        ; Restore and clean up brush
        invoke SelectObject, hdcv, hOldBrushv
        invoke DeleteObject, brushv
        
        ; Draw piece
        mov eax, edi
        mov dl, al        ; Move lower 8 bits of edi to dl for xPosv (BYTE)
        mov eax, esi
        mov cl, al        ; Move lower 8 bits of esi to cl for yPosv (BYTE)
        invoke GetPieceAtv, dl, cl
        mov piecev, ax
        invoke DrawPiecev, hdcv, xCoordv, yCoordv, piecev
        
        add xCoordv, SquareSizev
        inc edi
        cmp edi, 8
        jl ColLoop
        add yCoordv, SquareSizev
        inc esi
        cmp esi, 8
        jl RowLoop

        ; Draw file labels (a-h) at top and bottom
        invoke CreateFont, 20, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, 
                          DEFAULT_CHARSET, OUT_OUTLINE_PRECIS, CLIP_DEFAULT_PRECIS, 
                          CLEARTYPE_QUALITY, VARIABLE_PITCH, addr FontNamev
        mov hFontv, eax
        invoke SelectObject, hdcv, hFontv
        mov hOldFontv, eax
        invoke SetTextColor, hdcv, 00FFFFFFh  ; White text
        invoke SetBkMode, hdcv, TRANSPARENT
        mov esi, offset FileLabelsv
        mov xCoordv, BorderSizev
        mov edi, 0
@FileLabelLoop:
        mov al, byte ptr [esi + edi]
        mov labelBufferv[0], al
        mov labelBufferv[1], 0
        mov eax, xCoordv
        add eax, SquareSizev/2 - 10
        mov labelRectv.left, eax
        add eax, 20
        mov labelRectv.right, eax
        mov labelRectv.top, 5
        mov labelRectv.bottom, BorderSizev
        invoke DrawText, hdcv, addr labelBufferv, 1, addr labelRectv, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        mov eax, xCoordv
        add eax, SquareSizev/2 - 10
        mov labelRectv.left, eax
        add eax, 20
        mov labelRectv.right, eax
        mov eax, BoardSizev
        add eax, BorderSizev
        mov labelRectv.top, eax
        add eax, BorderSizev - 5
        mov labelRectv.bottom, eax
        invoke DrawText, hdcv, addr labelBufferv, 1, addr labelRectv, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        add xCoordv, SquareSizev
        inc edi
        cmp edi, 8
        jl @FileLabelLoop

        ; Draw rank labels (1-8) on left and right in reverse order (8 to 1)
        mov esi, offset RankLabelsv
        mov yCoordv, BoardSizev + BorderSizev
        mov edi, 7  ; Start with "8" (index 7)
@RankLabelLoop:
        mov al, byte ptr [esi + edi]
        mov labelBufferv[0], al
        mov labelBufferv[1], 0
        mov labelRectv.left, 5
        mov labelRectv.right, BorderSizev
        mov eax, yCoordv
        sub eax, SquareSizev
        add eax, SquareSizev/2 - 10
        mov labelRectv.top, eax
        add eax, 20
        mov labelRectv.bottom, eax
        invoke DrawText, hdcv, addr labelBufferv, 1, addr labelRectv, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        mov eax, BoardSizev
        add eax, BorderSizev
        mov labelRectv.left, eax
        add eax, BorderSizev - 5
        mov labelRectv.right, eax
        mov eax, yCoordv
        sub eax, SquareSizev
        add eax, SquareSizev/2 - 10
        mov labelRectv.top, eax
        add eax, 20
        mov labelRectv.bottom, eax
        invoke DrawText, hdcv, addr labelBufferv, 1, addr labelRectv, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        sub yCoordv, SquareSizev
        dec edi
        jge @RankLabelLoop

        invoke SelectObject, hdcv, hOldFontv
        invoke DeleteObject, hFontv
        invoke EndPaint, hWndv, addr psv
        xor eax, eax
        ret

    .elseif uMsgv == WM_CREATE
        call InitializeBoardv
        invoke AllocConsole
        invoke GetStdHandle, STD_INPUT_HANDLE
        mov hInputv, eax
        invoke GetStdHandle, STD_OUTPUT_HANDLE
        mov hOutputv, eax
        invoke SetConsoleTitle, addr CmdWindowTitlev
        invoke CreateThread, NULL, 0, addr InputThreadv, NULL, 0, NULL
        xor eax, eax
        ret
        
    .endif

    invoke DefWindowProc, hWndv, uMsgv, wParamv, lParamv
    ret
WndProcv endp

InputThreadv proc Paramv:DWORD
InputLoop:
    .if GameOverv == 1
        ret
    .endif
    call GetUserMovev
    cmp eax, 0
    je InputLoop
    jmp InputLoop
    ret
InputThreadv endp

start:
    invoke GetModuleHandle, NULL
    mov hInstv, eax
    mov wcv.cbSize, SIZEOF WNDCLASSEX
    mov wcv.style, CS_HREDRAW or CS_VREDRAW
    mov wcv.lpfnWndProc, offset WndProcv
    mov wcv.cbClsExtra, 0
    mov wcv.cbWndExtra, 0
    mov eax, hInstv
    mov wcv.hInstance, eax
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wcv.hIcon, eax
    mov wcv.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wcv.hCursor, eax
    mov wcv.hbrBackground, COLOR_WINDOW+1
    mov wcv.lpszMenuName, NULL
    mov wcv.lpszClassName, offset ClassNamev
    invoke RegisterClassEx, addr wcv
    invoke CreateWindowEx, 0, addr ClassNamev, addr AppNamev,\
        WS_OVERLAPPEDWINDOW,\
        CW_USEDEFAULT, CW_USEDEFAULT,\
        BoardSizev + BorderSizev*2 + 16, BoardSizev + BorderSizev*2 + 39,\
        NULL, NULL, hInstv, NULL
    mov hwndMainv, eax
    .if eax == NULL
        invoke GetLastError
        invoke ExitProcess, eax
    .endif
    invoke ShowWindow, hwndMainv, SW_SHOWNORMAL
    invoke UpdateWindow, hwndMainv

MainLoop:
    invoke GetMessage, addr msgv, NULL, 0, 0
    cmp eax, 0
    je EndLoop
    invoke TranslateMessage, addr msgv
    invoke DispatchMessage, addr msgv
    jmp MainLoop

EndLoop:
    invoke ExitProcess, 0

end start