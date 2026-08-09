.setcpu "65C02"

.include "6502.inc"

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
;     Monitor  G 0800     jumps here; nothing to return to (see Exit below)
;     Monitor  J 0800     calls here; RTS returns to the Monitor
;     BASIC    SYS 2048   calls here; RTS returns to BASIC
;     Wozmon   0800R      jumps here; nothing to return to
; =============================================================================

Start:
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
;   RTS returns to whoever called you — the Monitor after J, BASIC after SYS.
;   It is not valid after a G or a Wozmon R, which jump rather than call: there
;   is no return address on the stack.  A program launched that way should end
;   in a loop, drop into the Monitor with BRK, or reboot through the RESET
;   vector as shown below.
; =============================================================================

  rts                           ; Return to the caller (Monitor J / BASIC SYS)

  ; brk                         ; Alternative: break into the Monitor
  ; jmp ($FFFC)                 ; Alternative: reboot to the boot menu

; =============================================================================
;   Data
; =============================================================================

HelloMsg:
  .byte "Hello from Binary!", CHAR_CR, CHAR_LF
  .byte "Press any key to exit.", CHAR_CR, CHAR_LF, $00
