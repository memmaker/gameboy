; Memory:
; My ROM:               $0000 - $7fff
; Video RAM:            $8000 - $a000
; OAM (For Sprites):    $FE00 - $FE9F
; Work RAM:             $C000 - $DFFF
; HI-RAM:               $FF80 - $FFFE

; Wir benutzen die Definitionen aus "hardware.inc"
INCLUDE "hardware.inc"

; Konstanten
BUTTON_RIGHT  EQU 0
BUTTON_LEFT   EQU 1
BUTTON_UP     EQU 2
BUTTON_DOWN   EQU 3

; Interrupt Handler für den VBlank Interrupt
SECTION "VBlank interrupt", ROM0[$0040]
    push hl
    ld hl, VBlankFlag
    ld [hl], 1          ; Wir setzen einfach nur das VBlankFlag im RAM
    pop hl
    reti

; Bei $100 beginnt unser ROM im Speicher 
; Aber bis $14F muß noch Platz für den Header bleiben
SECTION "Header", ROM0[$100]
    ; Wir springen direkt zu unserem "richtigen" Einstiegspunkt
    jp EntryPoint
    ; Damit wir hier noch den Platz für den ROM Header reservieren können
    ds $150 - @, 0

SECTION "PostHeader", ROM0[$150]
; Wir müssen viel kopieren also schreiben wir dafür eine kleine Funktion
; de = Quelle-Adresse
; hl = Ziel-Adresse
; bc = Länge der Daten in bytes
CopyRoutine:
    ld a, [de]      ; Das erste byte aus der Quelle in den Akku kopieren
    ld [hli], a     ; Das erste byte aus dem Akku zum Ziel kopieren und den Pointer in hl inkrementieren
    inc de          ; Pointer in de inkrementieren
    dec bc          ; Anzahl zu kopierender Bytes dekrementieren
    ld a, b         ; Hi-Byte der Restanzahl in den Akku kopieren
    or a, c         ; Or zwischen Hi-Byte und Lo-Byte der Restanzahl Bytes
    jp nz, CopyRoutine ; Falls "not zero" -> es gibt noch Bytes, springe zurück
    ret

EntryPoint:
    ; Audio abschalten
    ld a, 0
    ld [rNR52], a

    ; Das LCD darf auf KEINEN FALL ausserhalb des VBlank abgeschaltet werden
    ; Daher -> Warten auf VBlank

WaitVBlank:
    ld a, [rLY]         ; Auslesen der Zeile, die gerade gezeichnet wird
    cp 144              ; Falls wir bei Zeile 144 sind, sind wir im VBlank
    jp c, WaitVBlank

    ; Ab hier sind wir im VBlank
    call Initialisation

    ; Initialisierung ist abgeschlossen, wir warten jetzt einfach
GameLoop:
    halt    ; Schickt den Prozessor Schlafen bis zum nächsten Interrupt
    ld a, [VBlankFlag]
    and a
    jr z, GameLoop

    xor a, a                ; set a to zero
    ld [VBlankFlag], a

    call _HRAM

    call HandleInput
    call MoveSprite

    jp GameLoop

Initialisation:
    ld a, 0
    ld [rLCDC], a   ; LCD abschalten

    ; Tiles in den VRAM kopieren
    ld de, Tiles            ; Quelle
    ld hl, $9000            ; Ziel
    ld bc, TilesEnd - Tiles ; Länge

    call CopyRoutine

    ; Tilemap kopieren
    ld de, Tilemap
    ld hl, $9800                ; $9800-$9BFF   BG Map Data 1
    ld bc, TilemapEnd - Tilemap

    call CopyRoutine

    ; Sprite kopieren
    ld de, Sprite
    ld hl, $8400                ; In den VRAM
    ld bc, SpriteEnd - Sprite

    call CopyRoutine

    ; DMA Transfer Funktion kopieren
    ld de, RunDMA
    ld hl, _HRAM                ; In den High-RAM
    ld bc, RunDMAEnd - RunDMA

    call CopyRoutine

    ; Hintergrund Palette setzen
    ld a, %00000111
    ld [rBGP], a

    ; Sprite Palette #0 setzen
    ld a, %01101100
    ld [rOBP0], a

    ; Wir schreiben die Sprite Attribute erstmal in einen Puffer im RAM
    ld hl, OAMBuffer
    
    ; y coord
    ld a, 64
    ld [hli], a

    ; x coord
    ld [hli], a
    
    ; tile index
    ld a, $40
    ld [hli], a

    ; attribute
    ld a, %00000000
    ld [hli], a

    ; Wir füllen die Attribute für die nicht genutzten Sprites mit null
    ld a, 0
    ld b, 39 * 4
Fill:   
    ld [hli], a
    dec b
    jp nz, Fill

    ; Dann rufen wir unsere DMA Startfunktion im High-RAM auf
    call _HRAM

    ; Aktivieren des VBlank interrupts
    ld a, IEF_VBLANK
    ldh [rIE], a
    ei

    ; LCD anschalten und Hintergrund anzeigen, Objekte (Sprites aktivieren)
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

    ret

HandleInput:
    ld a, P1F_GET_DPAD ; Wir wollen das D-Pad auslesen
    ld [rP1], a
    ld a, [rP1]        ; Mehrmals lesen zum stabilisieren
    ld a, [rP1]
    cpl                ; Komplement bilden, sprich alle Bits negieren
    and a, $0f         ; Wir brauchen nur die unteren 4 Bits
    
    ;ld [Buttons], a
    ret

; Diese Funktion erwartet D-Pad Inputs in den unteren 4 Bits des Akkus
MoveSprite:
    ld hl, OAMBuffer ; Pointer zum OAMBuffer laden
    ld b, [hl]       ; b = Y Koordinate
    inc hl           ; Pointer++
    ld c, [hl]       ; c = X Koordinate

CheckLeft:
    bit BUTTON_LEFT, a
    jr z, CheckRight
    dec c ; Nach links

CheckRight:
    bit BUTTON_RIGHT, a
    jr z, CheckUp
    inc c ; Nach rechts

CheckUp:
    bit BUTTON_UP, a
    jr z, CheckDown
    dec b ; Nach oben

CheckDown:
    bit BUTTON_DOWN, a
    jr z, InputDone
    inc b ; Nach unten

InputDone:
    ; Die neuen Koordinaten werden zurück in den OAMBuffer geschrieben
    ld [hl], c
    dec hl
    ld [hl], b

    ret

; Wir reservieren noch zwei weitere benannte Speicherbereiche
SECTION "Tile data", ROM0
Tiles:
    ; Direktes einlesen einer Binärdatei, der Inhalt wird an diese Stelle im ROM kopiert
    INCBIN "tileset.bin"
TilesEnd:

SECTION "Tilemap", ROM0
Tilemap:
    INCBIN "tilemap.bin"
TilemapEnd:

SECTION "Sprite data", ROM0
Sprite:
    INCBIN "sprite.bin"
SpriteEnd:

; Wir reservieren hier noch 1 Byte für eine Variable im RAM
SECTION "Variables", WRAM0[$C000]
VBlankFlag:
    ds 1;

; Hier speichern wir die Attribute für die Sprites
; Dieser Teil wird später durch den DMA Transfer in die OAM geschrieben
SECTION "OAM Buffer", WRAM0[$C100]
OAMBuffer:
    ds 4 * 40;

; Diese Funktion wird nachher in den High-RAM kopiert und den Transfer ausführen
SECTION "DMA Function for HI-RAM", ROM0
RunDMA:
    ld a, OAMBuffer / $100  ; Offset anhand der Startadresse berechnen
    ld [rDMA], a            ; Offset setzen, startet den DMA Transfer
    ld  a, $28              ; Warten bis der RAM wieder nutzbar ist
WaitForDMA:                 ; Insgesamt 4x40 = 160 cycles
    dec a                   ; 1 cycle
    jr  nz,WaitForDMA       ; 3 cycles
    ret
RunDMAEnd:
