6502-BIN
========

A 6502 assembly language raw binary template for the [AC6502](https://github.com/acwright/6502-ACE) family of computer systems.

> 📖 **Guide:** [AC6502 Documentation](https://acwright.github.io/6502-DOCS/) — the user's and programmer's guide for the whole family.

## Overview

Binaries for this system are loaded into RAM at `$0800` and entered directly — no BASIC involved. Unlike a `.prg` (which begins with a tokenized BASIC line so that `RUN` can reach it), a `.bin` is pure machine code from its very first byte, and that first byte *is* the entry point.

That makes this the template to reach for when BASIC is in the way rather than in the picture: a program that takes the machine over, a routine you call with `SYS` (or from the Monitor on BIOS 1.x), or anything you want to paste in over serial through Wozmon.

The template builds two ways from the same source: `make` for any ACE on BIOS 1.x with a TMS9918A, and `make VDP=1` for an ACE converted to a [6502-PICOVDP](https://github.com/acwright/6502-PICOVDP) on BIOS 2.x. See [Building for the 6502-PICOVDP](#building-for-the-6502-picovdp). BIOS 2.x has no Monitor: the Monitor routes below are 1.x only.

### How It Works

1. The binary is loaded into RAM at `$0800` — from CompactFlash, over XMODEM, or pasted into Wozmon
2. You jump to `$0800` — BASIC `SYS 2048`, Wozmon `800R`, or on BIOS 1.x Monitor `G 0800` / `J 0800`
3. Your program runs with full access to the Kernal jump table
4. How you leave depends on how you arrived — see [Entering and leaving](#entering-and-leaving)

### `.bin` vs `.prg`

| | `.bin` (this template) | [`.prg`](https://github.com/acwright/6502-PRG) |
|---|---|---|
| First bytes | Your code | 12-byte tokenized `10 SYS 2060` stub |
| Entry point | `$0800` | `$080C` |
| Started with | `SYS 2048` / `800R` / (1.x) `G` / `J` | BASIC `RUN` |
| Loads with Wozmon | **Yes** | No — the machine code is lost on the first variable assignment |
| BASIC still usable | Only if you return | Yes, `RTS` goes back |

### Memory Layout

| Range | Contents |
|-------|----------|
| `$0000–$0039` | Zero page — system pointers, BASIC, and Kernal scratch (see `6502.inc` for details) |
| `$003A–$00FF` | Zero page — free once you have taken the machine over (198 bytes) |
| `$0100–$01FF` | CPU stack |
| `$0200–$02FF` | Input ring buffer (managed by Kernal) |
| `$0300–$03FF` | Kernal variables (vectors, cursor, HW flags, etc.) |
| `$0400–$05FF` | BASIC's input line and tokenizing buffers |
| `$0600–$07FF` | CompactFlash sector buffer — clobbered by any filesystem call |
| `$0800` | **Entry point** — the first byte of your binary |
| `$0800–$7FFF` | **Your program code and data** (30 KB available) |
| `$8000–$9FFF` | I/O hardware registers |
| `$A000–$A0FF` | Kernal jump table (stable API) |

Zero page `$3A–$FF` is yours only when nothing else is interpreting underneath you. If you enter with `SYS` and intend to `RTS` back to BASIC, BASIC is still live and still using that range as it runs — treat it as off limits. A program that never returns can have all of it.

### Entering and leaving

The binary has no idea how it was started, so pick an ending that matches:

| Launch | What it does | How to end |
|--------|--------------|------------|
| BASIC `SYS 2048` | `JSR` — pushes a return address | `RTS` back to BASIC |
| Wozmon `800R` | `JMP` — no return address | Loop, `BRK`, or `JMP ($FFFC)` to reboot |
| Monitor `J 0800` (1.x) | `JSR` — pushes a return address | `RTS` back to the Monitor |
| Monitor `G 0800` (1.x) | `JMP` via `RTI` — no return address | Same as Wozmon |

`BRK` enters the Monitor on BIOS 1.x. On 2.x it prints where it happened and the registers, then returns to BASIC with the program kept:

```
BREAK $00 AT $0812
A=09 X=00 Y=00 P=31 S=FD
```

On 2.x, `SYS` also takes registers, `SYS 2048,a,x,y`, and leaves what the routine returned in `A`, `X`, `Y` and `P` at `PEEK(787)`, `PEEK(788)`, `PEEK(789)` and `PEEK(784)`.

The template ends in `RTS`, with the alternatives sitting commented out beside it.

If you are taking the machine over outright, uncomment the block at the top of `Start:` — it resets the stack pointer, calls `KernalInit` to re-probe and re-initialize every card, and re-enables interrupts. Doing that throws away the return address that `J` or `SYS` pushed, so it is a one-way door.

### Kernal Services

The system is already initialized by the time your binary runs, because a loader got it there. Key entry points:

| Address | Routine | Description |
|---------|---------|-------------|
| `$A000` | `Chrout` | Output character (routed by IO_MODE) |
| `$A003` | `Chrin` | Read character from input buffer (non-blocking — C=1 with the character in A, C=0 if none; loop for blocking behaviour) |
| `$A00C` | `BufferSize` | Number of unread bytes in input buffer |
| `$A018` | `VideoClear` | Clear screen and reset cursor |
| `$A01B` | `VideoPutChar` | Write character at cursor position |
| `$A01E` | `VideoSetCursor` | Set cursor position (X=col, Y=row) |
| `$A027` | `VideoSetColor` | Set text color (A = fg<<4 \| bg); on BIOS 2.x the pen for text printed from then on, and the border |
| `$A033` | `SidPlayNote` | Play note (A=voice, X=freqLo, Y=freqHi) |
| `$A075` | `SysDelay` | Delay A=lo, X=hi centiseconds |
| `$A078` | `KernalInit` | Re-initialize all hardware; reset the stack pointer first, `CLI` afterwards |
| `$A048` | `ReadJoystick1` | Read joystick 1 bitmask |
| `$A090` | `PrintStr` | Print a NUL-terminated string (A=lo, Y=hi) |

See `6502.inc` for the complete jump table with calling conventions. On BIOS 2.x the jump table grew by thirteen PICOVDP entries (`VdpInfo` through `VdpStatus`, `$A0B1–$A0D5`): see Section 4 of `6502-VDP.inc`.

### Hardware Detection

Check `HW_PRESENT` (`$030D`) before using optional hardware:

```asm
lda HW_PRESENT
and #HW_SID            ; Is SID present?
beq @NoSound           ; Skip sound code if not
jsr SidPlayNote
@NoSound:
```

## Building for the 6502-PICOVDP

`make VDP=1` builds `Binary-VDP.bin` with `6502-VDP.inc` instead of `6502.inc`. `Binary.asm` picks the include with the `VDP` symbol, which the Makefile passes to ca65:

```asm
.ifdef VDP
.include "6502-VDP.inc"
.else
.include "6502.inc"
.endif
```

Start from `6502-VDP.inc` when the binary needs anything BIOS 2.x adds: the PICOVDP's modes, layers, palette and sprites (`VC_*` register names), or the Kernal's VDP entries. A binary built that way needs an ACE converted to a 6502-PICOVDP, running BIOS 2.0 or later, and **does not run on a TMS9918A**. Its build checks `KernalVersion` at `Start` and, on BIOS 1.x, prints `NEEDS BIOS 2 AND A 6502-PICOVDP` and returns.

A binary built with `6502.inc` that only calls the jump table needs no VDP build: it runs on 2.x as it is, launched with `SYS` or Wozmon.

The font is in the card on 2.x: a binary that overwrote the pattern table or changed modes gets the text console back with `InitVideo`, which returns after the next vertical blank.

## Building

### Prerequisites

#### CC65 Compiler

On macOS, install via Homebrew:
```bash
brew install cc65
```

For other platforms, see the [cc65 project](https://github.com/cc65/cc65).

#### bin2woz (optional — for Wozmon loading)

```bash
npm install -g bin2woz
```

Converts the binary to a format loadable via the Wozmon serial monitor. See the [bin2woz project](https://github.com/acwright/bin2woz).

#### cffs (optional — for CompactFlash images)

```bash
npm install -g cffs-image-tool
```

Creates CompactFlash disk images with the binary file. See the [cffs project](https://github.com/acwright/cffs).

#### 6502 CLI (optional — for `make run`)

Installed via the [6502-EMULATOR](https://github.com/acwright/6502-EMULATOR) app's Settings → Command Line → Install.

### Build Commands

| Command | Description |
|---------|-------------|
| `make` | Build all targets (`.bin`, `.woz`, and CF image) |
| `make VDP=1` | Build all targets for the 6502-PICOVDP / BIOS 2.x (`Binary-VDP.*`) |
| `make build` | Assemble only (`Binary.bin`) |
| `make view` | Display hexdump of the built binary |
| `make woz` | Create Wozmon-compatible file (`Binary.woz`) |
| `make cf` | Create CompactFlash disk image with the binary |
| `make run` | Launch the emulator app with the binary loaded at `$0800` (`make VDP=1 run` selects the PICOVDP card; add `ROM=path/to/BIOS.bin` to boot a local BIOS image) |
| `make clean` | Remove build artifacts |

### Build Output

```bash
make
```

Produces:
- `Binary.bin` — Raw binary, load address `$0800`, entry point `$0800`
- `Binary.woz` — Wozmon-compatible format for serial upload
- `Binary.lst` — Assembly listing file for debugging
- `Binary.img` — CompactFlash disk image with the binary

`make VDP=1` writes the same four files named `Binary-VDP.*`. The file inside `Binary-VDP.img` is still `BINARY.BIN`.

`make run` loads the image into the emulator's memory but does not start it. BIOS 2.x boots to BASIC: type `SYS 2048`. BIOS 1.x boots to the menu: press `ESC` for the Monitor, then `G 0800`.

### Loading & Running

**From CompactFlash, via BASIC** — the usual case on BIOS 2.x, and on 1.x when you want BASIC back afterwards:
```
BLOAD 2048,"BINARY.BIN"
SYS 2048
```
`BLOAD` takes a decimal address, so `$0800` is `2048`.

**Over serial with XMODEM, via BASIC** (BIOS 2.x), with no CF card:
```
BLOAD 2048
```
Then send `Binary.bin` from the host with any terminal that speaks XMODEM
(128-byte blocks, checksum mode). The transfer is padded up to a block boundary,
which is harmless. Then `SYS 2048`.

**Over serial with Wozmon**, when you have nothing but a terminal — from BASIC
on 2.x:
```
SYS 65280
```
or on 1.x from the Monitor, `G FF00`. Paste the contents of `Binary.woz`, then type `800R` to run it. `R` jumps rather than calls, so give the program an ending that does not rely on `RTS`.

**From the Monitor** (BIOS 1.x only):
```
L "BINARY.BIN"
J 0800
```
`L` loads to `$0800` by default. `J` is right for the template as shipped, which ends in `RTS`; use `G 0800` for a program that takes the machine over and never comes back. With no CF card, `L` alone receives the file over XMODEM, then `J 0800` (or `G 0800`).

#### Why Wozmon works here

Wozmon writes bytes one at a time with no notion of a length, which is fatal for a `.prg`: BASIC never learns how long the image is, `VARTAB` lands on top of the machine code, and the first variable assignment destroys it. A `.bin` never asks BASIC for anything, so that whole problem disappears. Paste it in, jump to `$0800`, done.

This is the reason to pick this template over [6502-PRG](https://github.com/acwright/6502-PRG) when you are working over a serial line.

## Template Structure

| File | Purpose |
|------|---------|
| `Binary.asm` | Main source — entry point at `$0800`, example code |
| `6502.inc` | System include file for BIOS 1.x and the TMS9918A — Kernal jump table, hardware registers, constants |
| `6502-VDP.inc` | System include file for BIOS 2.x and the 6502-PICOVDP (identical to 6502-ASM's) |
| `6502.cfg` | Linker configuration — memory layout for RAM binaries |
| `Makefile` | Build system |

## Customizing

1. Edit `Binary.asm` — replace the example code after the `Start:` label with your program
2. Keep `Start:` first — the very first byte assembled lands at `$0800` and is the entry point, so no data may precede it
3. Choose an ending that matches how you launch it (see [Entering and leaving](#entering-and-leaving))
4. Add additional `.asm` files and `.include` them as needed
5. You have 30 KB of RAM (`$0800–$7FFF`) for code and data

## Related

- [6502-ACE](https://github.com/acwright/6502-ACE) — the hardware, and the index of the whole family
- [6502-BIOS](https://github.com/acwright/6502-BIOS) — the firmware behind the Kernal jump table: `6502.inc` is its 1.6 API, `6502-VDP.inc` its 2.x API
- [6502-PICOVDP](https://github.com/acwright/6502-PICOVDP) — the video card `6502-VDP.inc` is for
- [6502-EMULATOR](https://github.com/acwright/6502-EMULATOR) — run a binary without hardware (`make run`)
- [6502-PRG](https://github.com/acwright/6502-PRG) — the same idea for programs launched from BASIC with `RUN`
- [6502-CRT](https://github.com/acwright/6502-CRT) — the same idea for cartridge ROMs
- [6502-ASM](https://github.com/acwright/6502-ASM) — worked assembly examples
- [6502-DOCS](https://github.com/acwright/6502-DOCS) — the documentation site: the cross-development and assembly guides, and the printable reference cards
- [cffs](https://github.com/acwright/cffs) / [bin2woz](https://github.com/acwright/bin2woz) — the tools behind `make cf` and `make woz`

## License

MIT License — see [LICENSE](LICENSE).
