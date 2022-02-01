; Memory:
; My ROM:               $0000 - $7fff
; Video RAM:            $8000 - $a000

; Wir benutzen die Definitionen aus "hardware.inc"
INCLUDE "hardware.inc"

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

    ; Hintergrund Palette setzen
    ld a, %00000111
    ld [rBGP], a

    ; LCD anschalten und Hintergrund anzeigen
    ld a, LCDCF_ON | LCDCF_BGON
    ld [rLCDC], a

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
