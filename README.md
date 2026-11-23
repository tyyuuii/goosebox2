# goosebox2

**termbox2 terminal I/O library, ported to the Goose systems language.**

A port of [termbox2](https://github.com/termbox/termbox2) — a minimal terminal
I/O library — to [Goose](https://github.com/aardappel/goose), a memory-safe
systems language without garbage collection or `malloc`/`free` that compiles to
C.

- **License:** MIT
- **Upstream:** termbox2 by Adam Saponara and nsf (MIT licensed)
- **Port:** goosebox2 (`TB_VERSION_STR = "3.0.0-goose"`)

---

## Overview

`goosebox2` brings termbox2's double-buffered cell rendering, extended grapheme
clusters (`TB_OPT_EGC = 1`), binary terminfo parsing, keyboard/mouse escape
sequence decoding, and `SIGWINCH` resize handling to Goose, along with working
interactive TUI applications (`demo`, Conway's Game of Life `cgol`, and
`sudoku`) and an automated test suite (`test_termbox2.goose`).

### Implemented features

- Double-buffered `tb_cell` front/back rendering with diffing in `tb_present()`
  and sanitization of raw control characters in rendered cells
- Extended grapheme clusters (`TB_OPT_EGC = 1`) backed by a pooled `egc_node`
  freelist (`tb_extend_cell()`, `tb_set_cell_slice()`, automatic combining-mark
  attachment in `tb_print_ex()`)
- SVr4/ncurses binary terminfo loader & parser (`0x011a` legacy and `0x021e`
  extended headers across `$TERMINFO`, `$HOME/.terminfo`,
  `$PREFIX/share/terminfo`, `/etc/terminfo`, `/lib/terminfo`,
  `/usr/share/terminfo`) with built-in fallback tables (`xterm`/`alacritty`/
  `foot`/`kitty`/`wezterm`/`ghostty`/`gnome`/`vte`, dedicated `screen`/`tmux`,
  dedicated `rxvt`/`Eterm`, and `linux`)
- Index-based capability trie (`cap_trie`) plus Kitty keyboard (`CSI u`),
  `modifyOtherKeys` (`CSI 27;...~`), rxvt shift/ctrl arrow decoding,
  OSC/DCS/APC/PM/SOS string-escape skipping, and `Alt+[` disambiguation
- Mouse input parsing: X10 (`\x1b[M...`) and SGR (`\x1b[<b;x;yM/m`) with
  modifiers, drag motion, and scroll wheel events
- Color output modes: `TB_OUTPUT_NORMAL`, `TB_OUTPUT_256`, `TB_OUTPUT_216`,
  `TB_OUTPUT_GRAYSCALE`, and `TB_OUTPUT_TRUECOLOR` (24-bit RGB)
- 64-bit attributes (`TB_BOLD`, `TB_UNDERLINE`, `TB_REVERSE`, `TB_ITALIC`,
  `TB_BLINK`, `TB_HI_BLACK`, `TB_BRIGHT`, `TB_DIM`, `TB_STRIKEOUT`,
  `TB_UNDERLINE_2`, `TB_OVERLINE`, `TB_INVISIBLE`)
- UTF-8 validation, encoding/decoding helpers, expanded `tb_wcwidth()` /
  `tb_iswprint()` (combining marks, ZWJ/variation selectors, Hangul Jamo,
  regional indicators, CJK/emoji), wide-char orphan cleanup, and right-edge
  clipping
- Non-blocking TTY & pipe/socket I/O via `poll()`, `O_NONBLOCK` save/restore on
  `tb_shutdown()`, `EINTR`/`EAGAIN` retries, and `POLLOUT` output flushing
- `SIGWINCH` resize handling via an async-signal-safe self-pipe (preserving and
  restoring any prior `SIGWINCH` `sigaction`), with back-buffer row re-striding
  and front-buffer invalidation for clean reflow/zoom
- Thin C11 sidecar (`adapter.c` / `adapter.h`) wrapping POSIX APIs that Goose's
  `extern fn` cannot declare directly (`termios`, `ioctl`, `fcntl`, `open`,
  `pipe`, `poll`, `sigaction`, `clock_gettime`, `nanosleep`, `getenv`, binary
  file reads, `errno`)

---

## Requirements

- [Goose](https://github.com/aardappel/goose) compiler (`goose` v2026.4+ / nightly)
- A C11 compiler (`cc` / `clang` / `gcc`, invoked by `goose build` to link
  `adapter.c`)
- A POSIX terminal (`/dev/tty` or `tb_init_rwfd` pipe/PTY file descriptors)

---

## Project layout

```text
goosebox2/
├── LICENSE                       # MIT license
├── README.md                     # Documentation & API reference (this file)
├── PLAN.md                       # Design notes for the Conway's Game of Life demo
├── TERMBOX2_GOOSE_PORT_PLAN.md   # Original porting plan & Goose constraint analysis
├── termbox2.goose                # Core termbox2 library implementation
├── termbox2.build                # Sidecar config linking adapter.c / adapter.h
├── adapter.c                     # C11 POSIX FFI adapters
├── adapter.h                     # C11 header declarations
├── test_termbox2.goose           # Automated unit & pipe-based integration test suite
├── test_termbox2.build           # Sidecar config for test_termbox2.goose
├── demo.goose                    # Minimal key-event demo
├── demo.build                    # Sidecar config for demo.goose
├── cgol.goose                    # Conway's Game of Life TUI app
├── cgol.build                    # Sidecar config for cgol.goose
├── sudoku.goose                  # Interactive Sudoku TUI game
└── sudoku.build                  # Sidecar config for sudoku.goose
```

---

## Building & running

> **Note:** `goose check` accepts a single `.goose` file per invocation. Always
> use `goose build` (not `goose run`) for binaries so `adapter.c` is compiled
> and linked via the matching `.build` file.

### Typecheck

```bash
goose check termbox2.goose
goose check test_termbox2.goose
goose check demo.goose
goose check cgol.goose
goose check sudoku.goose
```

### Verify C adapter independently

```bash
cc -std=c11 -Wall -Wextra -Werror -fsyntax-only adapter.c
```

### Run automated tests

```bash
goose build test_termbox2.goose -o test_termbox2
./test_termbox2
```

### Build and run demos

```bash
# Minimal hello/key-viewer demo
goose build demo.goose -o demo
./demo

# Conway's Game of Life (supports mouse, speed toggle, presets, resize)
goose build cgol.goose -o cgol
./cgol

# Interactive Sudoku (adaptive Termux zoom/resize layout, mouse + keyboard)
goose build sudoku.goose -o sudoku
./sudoku
```

---

## API reference

Constants and functions closely mirror upstream `termbox2.h` with adjustments
required by Goose's type system.

### Key & event constants

- **Keys (`TB_KEY_*`):** `TB_KEY_F1`..`TB_KEY_F12`, `TB_KEY_INSERT`,
  `TB_KEY_DELETE`, `TB_KEY_HOME`, `TB_KEY_END`, `TB_KEY_PGUP`, `TB_KEY_PGDN`,
  `TB_KEY_ARROW_UP`, `TB_KEY_ARROW_DOWN`, `TB_KEY_ARROW_LEFT`,
  `TB_KEY_ARROW_RIGHT`, `TB_KEY_BACK_TAB`, `TB_KEY_MOUSE_LEFT`,
  `TB_KEY_MOUSE_RIGHT`, `TB_KEY_MOUSE_MIDDLE`, `TB_KEY_MOUSE_RELEASE`,
  `TB_KEY_MOUSE_WHEEL_UP`, `TB_KEY_MOUSE_WHEEL_DOWN`, plus `TB_KEY_CTRL_*`,
  `TB_KEY_ESC`, `TB_KEY_ENTER`, `TB_KEY_TAB`, `TB_KEY_BACKSPACE`,
  `TB_KEY_BACKSPACE2`, `TB_KEY_SPACE`.
- **Modifiers (`TB_MOD_*`):** `TB_MOD_ALT`, `TB_MOD_CTRL`, `TB_MOD_SHIFT`,
  `TB_MOD_MOTION`.
- **Event types (`TB_EVENT_*`):** `TB_EVENT_KEY`, `TB_EVENT_RESIZE`,
  `TB_EVENT_MOUSE`.

### Modes & colors

- **Input modes:** `TB_INPUT_CURRENT` (`0`), `TB_INPUT_ESC` (`1`),
  `TB_INPUT_ALT` (`2`), `TB_INPUT_MOUSE` (`4`). Combine with `|` when setting
  (e.g., `TB_INPUT_ESC | TB_INPUT_MOUSE`).
- **Output modes:** `TB_OUTPUT_CURRENT`, `TB_OUTPUT_NORMAL`, `TB_OUTPUT_256`,
  `TB_OUTPUT_216`, `TB_OUTPUT_GRAYSCALE`, `TB_OUTPUT_TRUECOLOR`.
- **Colors:** `TB_DEFAULT`, `TB_BLACK`, `TB_RED`, `TB_GREEN`, `TB_YELLOW`,
  `TB_BLUE`, `TB_MAGENTA`, `TB_CYAN`, `TB_WHITE`, `TB_HI_BLACK`.
- **Attribute masks (`uintattr_t = u64`):** `TB_BOLD`, `TB_UNDERLINE`,
  `TB_REVERSE`, `TB_ITALIC`, `TB_BLINK`, `TB_BRIGHT`, `TB_DIM`,
  `TB_STRIKEOUT`, `TB_UNDERLINE_2`, `TB_OVERLINE`, `TB_INVISIBLE`,
  `TB_TRUECOLOR_BOLD`, `TB_TRUECOLOR_UNDERLINE`, `TB_TRUECOLOR_REVERSE`,
  `TB_TRUECOLOR_ITALIC`, `TB_TRUECOLOR_BLINK`, `TB_TRUECOLOR_BLACK`.

### Return codes

`TB_OK` (`0`), `TB_ERR` (`-1`), `TB_ERR_NEED_MORE` (`-2`),
`TB_ERR_INIT_ALREADY` (`-3`), `TB_ERR_INIT_OPEN` (`-4`), `TB_ERR_MEM` (`-5`),
`TB_ERR_NO_EVENT` (`-6`), `TB_ERR_NO_TERM` (`-7`), `TB_ERR_NOT_INIT` (`-8`),
`TB_ERR_OUT_OF_BOUNDS` (`-9`), `TB_ERR_READ` (`-10`),
`TB_ERR_RESIZE_IOCTL` (`-11`), `TB_ERR_RESIZE_PIPE` (`-12`),
`TB_ERR_RESIZE_SIGACTION` (`-13`), `TB_ERR_POLL` (`-14`),
`TB_ERR_TCGETATTR` (`-15`), `TB_ERR_TCSETATTR` (`-16`),
`TB_ERR_UNSUPPORTED_TERM` (`-17`), `TB_ERR_RESIZE_WRITE` (`-18`),
`TB_ERR_RESIZE_POLL` (`-19`), `TB_ERR_RESIZE_READ` (`-20`),
`TB_ERR_RESIZE_SSCANF` (`-21`), `TB_ERR_CAP_COLLISION` (`-22`).

### Core data types

```goose
struct tb_cell {
    ch: u32,
    fg: uintattr_t,
    bg: uintattr_t,
}

struct tb_event {
    kind: u8,
    mod: u8,
    key: u16,
    ch: u32,
    w: i32,
    h: i32,
    x: i32,
    y: i32,
}
```

### Functions

#### Lifecycle

```goose
fn tb_init() -> i32
fn tb_init_file(path: const u8[:]) -> i32
fn tb_init_fd(ttyfd: i32) -> i32
fn tb_init_rwfd(rfd: i32, wfd: i32) -> i32
fn tb_shutdown() -> i32
```

- `tb_init()` opens `/dev/tty`, saves original `termios`, enables raw mode and
  non-blocking reads, queries `TIOCGWINSZ`, loads binary terminfo (falling back
  to `builtin_terms`, or returning `TB_ERR_NO_TERM` / `TB_ERR_UNSUPPORTED_TERM`),
  builds `cap_trie`, installs the `SIGWINCH` handler, enters alternate screen
  (`smcup`), enables keypad transmit mode (`smkx`), hides the cursor, and clears
  the screen.
- `tb_init_file(path)` behaves like `tb_init()` for an arbitrary TTY device path
  and returns `TB_ERR_INIT_ALREADY` if already initialized.
- `tb_init_fd(ttyfd)` / `tb_init_rwfd(rfd, wfd)` return `TB_ERR_INIT_ALREADY` if
  already initialized and accept both TTYs (`termios` + `TIOCGWINSZ`) and
  non-TTY pipe/socket fds (using an `80x24` default viewport when
  `!isatty(rfd)`).
- `tb_shutdown()` disables mouse reporting if active, shows the cursor, emits
  `sgr0` + `rmkx` + `rmcup`, restores the prior `SIGWINCH` handler, restores
  `termios` and original `O_NONBLOCK` descriptor flags, closes the resize pipe
  (and owned `ttyfd`), and resets internal capability/buffer state so re-init
  succeeds cleanly.

#### Display & cell buffer

```goose
fn tb_width() -> i32
fn tb_height() -> i32
fn tb_set_clear_attrs(fg: uintattr_t, bg: uintattr_t) -> i32
fn tb_clear() -> i32
fn tb_set_cell(x: i32, y: i32, ch: u32, fg: uintattr_t, bg: uintattr_t) -> i32
fn tb_set_cell_ex(x: i32, y: i32, ch: const u32&, nch: i64, fg: uintattr_t, bg: uintattr_t) -> i32
fn tb_set_cell_slice(x: i32, y: i32, chs: const u32[:], fg: uintattr_t, bg: uintattr_t) -> i32
fn tb_extend_cell(x: i32, y: i32, ch: u32) -> i32
fn tb_get_cell(x: i32, y: i32, back: i32, cell: tb_cell&) -> i32
fn tb_present() -> i32
fn tb_invalidate() -> i32
fn tb_set_cursor(cx: i32, cy: i32) -> i32
fn tb_hide_cursor() -> i32
```

- `tb_set_cell` clears orphaned wide-char halves automatically when overwriting
  column `x`.
- `tb_extend_cell(x, y, ch)` appends combining/trailing codepoints to an
  existing cell's extended grapheme cluster (`TB_OPT_EGC == 1`).
- `tb_set_cell_slice(x, y, chs, fg, bg)` is a Goose-safe helper accepting a slice
  `const u32[:]` for multi-codepoint clusters in one call.
- `tb_invalidate()` resets all front-buffer cells to sentinel values so the next
  `tb_present()` repaints every visible cell cleanly.
- `tb_set_cursor(cx, cy)` shows and positions the cursor on `tb_present()` (any
  negative coordinate calls `tb_hide_cursor()`).
- `tb_hide_cursor()` emits `TB_CAP_HIDE_CURSOR` (falling back to `\x1b[?25l`)
  and resets cursor coordinates to `(-1, -1)`.
- `tb_get_cell(x, y, back, cell)` is a Goose-safe addition replacing C's
  `tb_cell_buffer()` pointer return (`back != 0` reads the back buffer, `0`
  reads the front buffer).

#### Input & modes

```goose
fn tb_peek_event(event: tb_event&, timeout_ms: i32) -> i32
fn tb_poll_event(event: tb_event&) -> i32
fn tb_get_fds(ttyfd: i32&, resizefd: i32&) -> i32
fn tb_set_input_mode(mode: i32) -> i32
fn tb_set_output_mode(mode: i32) -> i32
```

- `tb_peek_event(event, timeout_ms)` waits up to the remaining `timeout_ms`
  (`-1` blocks indefinitely, `0` polls immediately) on both `rfd` and the
  `SIGWINCH` pipe, handling `Alt+[` disambiguation and string-escape skipping. On
  resize, it resizes/re-strides `back`, recycles EGC nodes cleanly, resets
  `front` and SGR/cursor caches, and emits `TB_EVENT_RESIZE`.
- `tb_poll_event(event)` loops over `tb_peek_event(event, -1)` until an event
  arrives or a fatal error occurs.
- `tb_set_input_mode(mode)` returns the active mode (`TB_INPUT_CURRENT` to
  query) and emits `TB_HARDCAP_ENTER_MOUSE` / `TB_HARDCAP_EXIT_MOUSE` when
  toggling `TB_INPUT_MOUSE`.

#### Printing & raw output

```goose
fn tb_print(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32
fn tb_print_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, str: const u8[:]) -> i32
fn tb_send(buf: const u8[:], nbuf: i64) -> i32
fn tb_sendf(fmt: const u8[:]) -> i32
fn tb_printf(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, fmt: const u8[:]) -> i32
fn tb_printf_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, fmt: const u8[:]) -> i32
```

- `tb_print` / `tb_print_ex` decode UTF-8, handle `\n` (returning to column `x`
  on the next row), attach zero-width combining/ZWJ/variation codepoints via
  `tb_extend_cell()`, replace non-printable codepoints with `U+FFFD`, clip past
  the right margin, and report max rendered column width in `out_w`.
- Because Goose does not support variadic functions, `tb_sendf`, `tb_printf`,
  and `tb_printf_ex` do **not** perform `printf`-style `%` formatting — they emit
  `fmt` literally (with `tb_printf_ex` computing `out_w` column width). Format
  strings in caller code before passing to `tb_print()` / `tb_send()`.

#### Diagnostics, UTF-8 & width helpers

```goose
fn tb_version() -> const u8[:]
fn tb_last_errno() -> i32
fn tb_strerror(err: i32) -> const u8[:]
fn tb_has_truecolor() -> i32
fn tb_has_egc() -> i32
fn tb_attr_width() -> i32
fn tb_utf8_char_length(c: i8) -> i32
fn tb_utf8_char_to_unicode(out: u32&, c: const u8[:]) -> i32
fn tb_utf8_unicode_to_char(out: u8[7]&, c: u32) -> i32
fn tb_iswprint(ch: u32) -> i32
fn tb_wcwidth(ch: u32) -> i32
```

- `tb_has_truecolor()` returns `1` unconditionally (matching upstream `termbox2.h`).
- `tb_has_egc()` returns `1` (`TB_OPT_EGC == 1`).
- `tb_attr_width()` returns `64`.

---

## Example

```goose
import termbox2;

fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("tb_init failed: ", rv);
        return;
    }

    let _ = tb_clear();
    let _ = tb_print(0, 0, TB_WHITE, TB_BLACK, "Hello, termbox2 on Goose!");
    let _ = tb_print(0, 1, TB_CYAN, TB_BLACK, "Press 'q' or ESC to quit.");
    let _ = tb_present();

    loop {
        var ev = tb_event { .. };
        let erv = tb_poll_event(ev);
        if erv == TB_ERR_NO_EVENT { continue; }
        if erv != TB_OK { break; }
        if ev.kind == TB_EVENT_KEY {
            if ev.key == TB_KEY_ESC || ev.ch == 'q' { break; }
        } else if ev.kind == TB_EVENT_RESIZE {
            let _ = tb_clear();
            let _ = tb_present();
        }
    }

    let _ = tb_shutdown();
}
```

---

## Design notes & Termux behavior

### Goose memory model

Goose has no heap, no garbage collector, and no `malloc`/`free`; resizable
arrays (`T[>..]`) obey a one-resizable-per-stack rule unless owned by a `root
struct`. Therefore:

- **`root struct tb_global`** owns `back`, `front`, `egc_pool`, `back_ech_head`,
  `front_ech_head`, `inbuf`, `outbuf`, `cap_trie`, and `terminfo` in a single
  module-level global.
- **Linked-index `cap_trie` & `egc_pool`** use integer indices into module-owned
  pools (`egc_free_head_p1` 1-based freelist) instead of heap pointers or nested
  resizable arrays.
- **`uintattr_t = u64`** supports 64-bit attribute masks across all color modes.

### Terminal & Termux notes

- **`smkx` & Arrow Keys:** `tb_init` emits `TB_CAP_ENTER_KEYPAD` (`\x1b[?1h\x1b=`)
  so terminals match capability sequences consistently, and `cap_trie_build()`
  registers both the active terminal's caps and standard CSI/SS3 fallbacks
  (`\x1b[A..D`, `\x1b[H/F/Z`).
- **Termux Zoom / Resize Reflow:** Pinch-zooming or resizing in Termux triggers
  `SIGWINCH`. `drain_resize_and_fill()` re-strides `g.back` (and `back_ech_head`)
  across width changes, invalidates `g.front`, and resets cached cursor/SGR
  tracking so the next `tb_present()` repaints the full viewport cleanly.
  `sudoku.goose` also adapts its layout dynamically for narrow zoom widths
  (`< 74` cols) and redraws menu/win overlays on `TB_EVENT_RESIZE`.

### C sidecar (`adapter.c`)

`adapter.c` wraps `tcgetattr`, `tcsetattr`, `ioctl(TIOCGWINSZ)`,
`fcntl(F_GETFL/F_SETFL)`, `open`, `close`, `read`, `write`, `pipe`, `poll`,
`isatty`, `ttyname_r`, `getenv`, `sigaction(SIGWINCH)` save/restore,
`clock_gettime`, `nanosleep`, bounded binary file reads, and `errno` predicates
(`EINTR`, `EAGAIN`/`EWOULDBLOCK`).

---

## Known limitations vs upstream `termbox2.h`

1. **No `tb_set_func` runtime callback hooks:** Goose function values are
   compile-time only and cannot be stored in structs for runtime dispatch.
2. **No variadic `printf` formatting:** `tb_printf`, `tb_printf_ex`, and
   `tb_sendf` emit `fmt` literally (though `tb_printf_ex` accurately computes
   `out_w` column width).
3. **Partial Unicode `EastAsianWidth` table:** `tb_wcwidth` covers ASCII,
   combining marks, Hangul Jamo, ZWJ/variation selectors, regional indicators,
   and main CJK/emoji ranges rather than embedding the full Unicode UAX #11
   database.

---

## Credits

- **termbox2** — Adam Saponara, nsf — https://github.com/termbox/termbox2 — MIT
- **Goose** — Wouter van Oortmerssen (aardappel) — https://github.com/aardappel/goose
- **goosebox2** — MIT licensed, 2026
