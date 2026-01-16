; Main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

; NSF File
.include "nsfdata.asm"

; NSF Header data
NSFHeaderSize = $80
NSFHeader:
.incbin NSFFile, 0, NSFHeaderSize

; Song numbers
TOTAL_SONGS := NSFHeader+6
DEFAULT_SONG := NSFHeader+7

; NSF load/init/play address constants
NSFInit := NSFHeader+10
NSFPlay := NSFHeader+12

; String metadata
Title := NSFHeader+14
Artist := Title+32
Copyright := Artist+32

; We need to store a few variables, so we might as well use the normally unused 'NESM\x1A' identifier
Frames := NSFHeader
CurrentSong := NSFHeader+1
P1_PRESSED := NSFHeader+2
P1_HELD := NSFHeader+3

; OAM DMA sync for glitch-free controller reads
OAMDMA_Controller_Sync:
		lda #>oam										; sprites aren't being rendered anyway
		sta $4014          ; ------ OAM DMA ------
		ldx #1             ; get put          <- strobe code must take an odd number of cycles total
		stx temp+0      ; get put get      <- buttons must be in the zeropage
		stx $4016          ; put get put get
		dex                ; put get
		stx $4016          ; put get put get
@loop:
		lda $4017          ; put get put GET  <- loop code must take an even number of cycles total
		and #3             ; put get
		cmp #1             ; put get
		rol temp+1,x   ; put get put get put get (X = 0; waste 1 cycle for alignment)
		lda $4016          ; put get put GET
		and #3             ; put get
		cmp #1             ; put get
		rol temp+0      ; put get put get put
		bcc @loop           ; get put [get]    <- this branch must not be allowed to cross a page
		lda temp+0
		sta P1_HELD										; only care about P1
		rts

; Reset handler
; Much of the init tasks are already done by the BIOS reset handler, including the PPU warmup loops.
Reset:  sei
		jsr DrawScreen
		ldx #$00
		txa
@init:
		sta $00,x
		cpx #$04
		bcc :+
		sta $0100,x										; preserve BIOS stack variables
:
		sta $0200,x
		sta $0300,x
		sta $0400,x
		sta $0500,x
		sta $0600,x
		sta $0700,x
		inx
		bne @init
		sta Frames
;		sta P1_PRESSED
		sta P1_HELD
		lda DEFAULT_SONG
		sta CurrentSong
		lda #$60										; RTS opcode
		sta CallPlay
;		jsr CallInit
		bit PPU_STATUS
		lda #$80
		sta PPU_CTRL
;		cli

Main:
; Save held buttons from previous frame
		lda P1_HELD
		sta P1_PRESSED
		
; Wait for NMI
		lda Frames
:
		cmp Frames
		beq :-

; Check pressed buttons and change song as needed
		lda P1_PRESSED
		eor #$ff
		and P1_HELD
		sta P1_PRESSED
		and #(BUTTON_LEFT | BUTTON_RIGHT | BUTTON_START)
		beq Main
		
		and #BUTTON_LEFT
		beq @CheckRight
		ldy CurrentSong
		dey
		bne :+
		ldy TOTAL_SONGS
:
		sty CurrentSong
		
@CheckRight:
		lda P1_PRESSED
		and #BUTTON_RIGHT
		beq @CheckStart
		ldy CurrentSong
		cpy TOTAL_SONGS
		bne :+
		ldy #$00
:
		iny
		sty CurrentSong

; Init the selected song, but have the Start button toggle the playback start
@CheckStart:
		lda P1_PRESSED
		and #BUTTON_START
		beq :+

		lda CallPlay
		eor #$0C										; toggle between RTS/JMP indirect
		sta CallPlay
		cmp #$60										; did we just stop playback?
		bne :+
		
		lda #$80
		sta FDS_WAVE_ENV								; mute FDS wave just in case
		sta SND_CHN										; same with 2A03 APU (bit 7 ignored)
:
; Evil optimisation: push Main (start of loop) as a return address before falling through to CallInit
		lda #>(Main-1)
		pha
		lda #<(Main-1)
		pha
	
CallInit:
		ldy CurrentSong									; decrement song number first
		dey
		tya
		ldx #$00										; always NTSC
		ldy #$00										; no NSF2 non-returning init
		jmp (NSFInit)
		
CallPlay:
		jmp (NSFPlay)

NMI:
		pha
		txa
		pha
		tya
		pha
		lda temp
		pha
		lda temp+1
		pha
		
		jsr OAMDMA_Controller_Sync
		
; Print song number
SongNumAddr := ($2000 + (22 << 5) + 10)
;		lda #$80
;		sta PPU_CTRL
		lda #>SongNumAddr
		sta PPU_ADDR
		lda #<SongNumAddr
		sta PPU_ADDR
		lda CurrentSong
		pha
		lsr
		lsr
		lsr
		lsr
		tay
		lda NybbleToChar,y
		sta PPU_DATA
		pla
		and #$0f
		tay
		lda NybbleToChar,y
		sta PPU_DATA
		lda #$00
		sta PPU_SCROLL
		sta PPU_SCROLL
		lda #$80
		sta PPU_CTRL
		
		pla
		sta temp+1
		pla
		sta temp
		
		jsr CallPlay
		inc Frames
		pla
		tay
		pla
		tax
		pla
		rti

VINTWait_Safe:
		bit PPU_STATUS
		jmp VINTWait

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$28										; bottom-left

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

DrawScreen:
		jsr VINTWait_Safe
		jsr DisPFObj
		jsr InitNametables
		lda DEFAULT_SONG
		ldx #$00
		jsr BinToDec
		lda TOTAL_SONGS
		jsr BinToDec
		
		lda #BUFFER_SIZE
		sta VRAM_BUFFER_SIZE
		vram_addr_string $2000, 7, 11, Title, TitleLine1Length
		vram_addr_string $2000, 7, 12, Title + TitleLine1Length, FIELD_SIZE - TitleLine1Length
		vram_addr_string $2000, 7, 15, Artist, ArtistLine1Length
		vram_addr_string $2000, 7, 16, Artist + ArtistLine1Length, FIELD_SIZE - ArtistLine1Length
		vram_addr_string $2000, 7, 19, Copyright, CopyrightLine1Length
		vram_addr_string $2000, 7, 20, Copyright + CopyrightLine1Length, FIELD_SIZE - CopyrightLine1Length
		
		jsr VINTWait_Safe
		jsr VRAMStructWrite
	.addr BGData
		jsr WriteVRAMBuffer
		
		jsr VINTWait_Safe
		jsr EnPF
		jmp SetScroll

; A = binary value, X = offset to write in SongNum VRAM struct (0, 3)
BinToDec:
		pha
		lsr
		lsr
		lsr
		lsr
		tay
		lda NybbleToChar,y
		sta SongNum,x
		inx
		pla
		and #$0f
		tay
		lda NybbleToChar,y
		sta SongNum,x
		inx
		inx
		rts

NybbleToChar:
	.byte "0123456789ABCDEF"

; VRAM transfer structure
BGData:

; Just write to all 16 entries so PPUADDR safely leaves the palette RAM region
; PPUADDR ends at $3F20 before the next write (avoids rare palette corruption)
; (palette entries will never be changed anyway, so we might as well set them all)
Palettes:
	.dbyt $3f00
	encode_length INC1, COPY, PaletteDataSize

.proc PaletteData
	.repeat 8
	.byte $0f, $00, $10, $20
	.endrepeat
.endproc
PaletteDataSize = .sizeof(PaletteData)

TextData:
	vram_addr $2000, 8, 4
	encode_string INC1, COPY, "FDS NSF Player"
	vram_addr $2000, 8, 5
	encode_string INC1, COPY, "by TakuikaNinja"
	
	vram_addr $2000, 4, 10
	encode_string INC1, COPY, "Title:"
	vram_addr $2000, 4, 14
	encode_string INC1, COPY, "Artist:"
	vram_addr $2000, 4, 18
	encode_string INC1, COPY, "Copyright:"
	
	vram_addr $2000, 4, 22
	encode_string INC1, COPY, "Song:"
	vram_addr $2000, 10, 22
	encode_length INC1, COPY, 5
SongNum:
	.byte "00/00"
	
	encode_terminator

; Padding based on NSF load address, disk vectors will be overwritten after loading!
Offset = NSFLoad - $6000
.out .sprintf ("NSFLoad = $%04X", NSFLoad)
.out .sprintf ("Offset = $%04X", Offset)
Padding = Offset+NSFHeader-*
.out .sprintf ("Padding = $%04X bytes", Padding)
.res Padding, 0
.assert * = NSFLoad, error, "Can't fit NSF data!"

.ifdef NSFDataSize
	.out .sprintf ("NSFDataSize = $%04X", NSFDataSize)
	.incbin NSFFile, NSFHeaderSize, NSFDataSize
.else
	.incbin NSFFile, NSFHeaderSize
.endif

; Pad rest of PRG-RAM
.res $8000+NSFHeader-*, 0

