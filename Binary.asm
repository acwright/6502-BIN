.setcpu "65C02"

; make VDP=1 builds for an ACE with a 6502-PICOVDP on BIOS 2.x;
; the default builds for the TMS9918A on BIOS 1.x.
.ifdef VDP
.include "6502-VDP.inc"
.else
.include "6502.inc"
.endif

.segment "CODE"

; =============================================================================
;   Start — Program entry point ($0800)
; =============================================================================
;   This is a raw binary image, not a BASIC program.  There is no tokenized
;   startup stub: the first byte of the file is the first byte of code, and it
;   lands at $0800 (PROGRAM_START).  Nothing may be placed before Start —
;   put data after the code, or behind a jump.
;
;   The system is already fully initialized by the time your program runs,
;   because a loader (Monitor, BASIC, Wozmon) put it there:
;     - Hardware probed and initialized (HW_PRESENT is set)
;     - Interrupts enabled, keyboard active
;     - IO_MODE set (video or serial console)
;     - All Kernal jump table routines available
;
;   Because BASIC is not running underneath you, the whole of zero page from
;   $3A-$FF is yours, and so is all of $0800-$7FFF.
;
;   Launching:
;     BASIC    SYS 2048   calls here; RTS returns to BASIC
;     Wozmon   0800R      jumps here; nothing to return to
;     Monitor  G 0800     jumps here; nothing to return to (BIOS 1.x only)
;     Monitor  J 0800     calls here; RTS returns to the Monitor (BIOS 1.x only)
; =============================================================================

Start:
.ifdef VDP
  ; --- VDP build only: refuse to run on BIOS 1.x ---
  ; A binary built with 6502-VDP.inc may call 2.x Kernal entries that are
  ; bare RTS slots on 1.x, so it says so and returns instead.
  jsr KernalVersion             ; A = major, X = minor
  cmp #2
  bcs @Bios2
  lda #<NeedsBios2Msg
  ldy #>NeedsBios2Msg
  jsr PrintStr
  rts                           ; Return to the caller (Monitor J / BASIC SYS)
@Bios2:
.endif

  ; === Your program starts here ===

  ; --- Optional: take the machine over completely ---
  ;   Reset the stack, re-probe and re-initialize every card, and install the
  ;   default interrupt handlers.  Only needed if you intend never to return;
  ;   it discards the return address that J / SYS pushed for you.
  ; ldx #$ff
  ; txs                         ; Reset the stack pointer
  ; jsr KernalInit              ; Re-initialize all hardware (leaves IRQs off)
  ; cli                         ; Enable interrupts

  ; Example: clear screen and print a message
  jsr VideoClear                ; Clear video screen

  lda #<HelloMsg
  ldy #>HelloMsg
  jsr PrintStr                  ; Print the message

@WaitKey:
  jsr Chrin                     ; Poll for a keypress (non-blocking)
  bcc @WaitKey                  ; Loop until character available (C=1)

  jsr VideoClear                ; Clear screen before leaving

; =============================================================================
;   Exit
; =============================================================================
;   RTS returns to whoever called you — BASIC after SYS, the Monitor after J.
;   It is not valid after a G or a Wozmon R, which jump rather than call: there
;   is no return address on the stack.  A program launched that way should end
;   in a loop, BRK, or reboot through the RESET vector as shown below.  On
;   BIOS 1.x BRK enters the Monitor; on 2.x it prints the registers and
;   returns to BASIC.
; =============================================================================

  rts                           ; Return to the caller (BASIC SYS / Monitor J)

  ; brk                         ; Alternative: the Monitor (1.x) or a BRK report and BASIC (2.x)
  ; jmp ($FFFC)                 ; Alternative: reboot (the boot menu on 1.x, BASIC on 2.x)

; =============================================================================
;   Data
; =============================================================================

HelloMsg:
  .byte "Hello from Binary!", CHAR_CR, CHAR_LF
  .byte "Press any key to exit.", CHAR_CR, CHAR_LF, $00

.ifdef VDP
NeedsBios2Msg:
  .byte "NEEDS BIOS 2 AND A 6502-PICOVDP", CHAR_CR, CHAR_LF, $00
.endif
