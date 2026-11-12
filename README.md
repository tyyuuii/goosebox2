# goosebox2

**termbox2 terminal I/O library, ported to the Goose systems language.**

A faithful port of [termbox2](https://github.com/termbox/termbox2) — a minimal,
dependency-free terminal I/O library — to [Goose](https://github.com/aardappel/goose),
a memory-safe systems language with no heap, no GC, and no `malloc`/`free` that
compiles to C.

- **License:** MIT
- **Original:** termbox2 by Adam Saponara and nsf (MIT licensed)
- **Port:** goosebox2 — Goose reimplementation of the same public API

---

## What this is

This is a **port** of termbox2, not a from-scratch implementation. It reproduces
termbox2's complete public API, behavior, and semantics in Goose:

- All 37 public API functions
- All key codes, capability indices, colors, attributes, event types
- Built-in terminfo tables for xterm, linux, screen, rxvt, Eterm
- UTF-8 encoding/decoding helpers
- Escape sequence parser with cap_trie matching
- Double-buffered cell rendering with `tb_present()`
- Non-blocking TTY input with `poll()`-based event waiting
- SIGWINCH resize handling via a self-pipe

The C sidecar (`adapter.c` / `adapter.h`) provides thin wrappers for POSIX
functions that Goose's `extern fn` cannot bind directly: variadic functions
(`vsnprintf`), `ioctl`, `fcntl`, `signal`, `read`, `write`, `poll`, etc.

---

## Requirements

- [Goose](https://github.com/aardappel/goose) (nightly-20261112 or later)
- A C compiler (for `goose build` with C linking)
- A POSIX terminal (`/dev/tty`)

---

## Project layout

```
goosebox2/
├── LICENSE                 # MIT license
├── README.md               # This file (API documentation)
├── TERMBOX2_GOOSE_PORT_PLAN.md  # Porting plan & design notes
├── termbox2.goose          # Main library (1,227 lines)
├── adapter.c               # C FFI adapters for POSIX calls
├── adapter.h               # Adapter header declarations
├── termbox2.build          # Goose sidecar build file (library)
├── demo.goose              # Example program
├── demo.build              # Goose sidecar build file (demo)
└── tests/                  # Test suite (placeholder)
```

---

## Building

### Library only

```bash
goose check termbox2.goose      # typecheck
goose build termbox2.goose      # emits C (library only, no main)
```

### Demo program

```bash
goose build demo.goose -o demo
./demo                          # runs in your terminal
```

The demo clears the screen, prints "Hello, termbox2 on Goose!", waits for
keypresses, and quits on `q` or `Esc`.

---

## API reference

All constants and functions below mirror termbox2's C API exactly.

### Constants

#### Key codes

| Constant | Value | Description |
|----------|-------|-------------|
| `TB_KEY_CTRL_TILDE` | 0x00 | Ctrl-` |
| `TB_KEY_CTRL_A` … `TB_KEY_CTRL_Z` | 0x01–0x1a | Ctrl+letter |
| `TB_KEY_BACKSPACE` | 0x08 | Backspace |
| `TB_KEY_TAB` | 0x09 | Tab |
| `TB_KEY_ENTER` | 0x0d | Enter |
| `TB_KEY_ESC` | 0x1b | Escape |
| `TB_KEY_SPACE` | 0x20 | Space |
| `TB_KEY_BACKSPACE2` | 0x7f | Delete |
| `TB_KEY_F1` … `TB_KEY_F12` | 0xffff–0xfff4 | Function keys |
| `TB_KEY_INSERT` | 0xfff3 | Insert |
| `TB_KEY_DELETE` | 0xfff2 | Delete |
| `TB_KEY_HOME` | 0xfff1 | Home |
| `TB_KEY_END` | 0xfff0 | End |
| `TB_KEY_PGUP` | 0xffef | Page Up |
| `TB_KEY_PGDN` | 0xffee | Page Down |
| `TB_KEY_ARROW_UP` | 0xffed | Up arrow |
| `TB_KEY_ARROW_DOWN` | 0xffec | Down arrow |
| `TB_KEY_ARROW_LEFT` | 0xffeb | Left arrow |
| `TB_KEY_ARROW_RIGHT` | 0xffea | Right arrow |
| `TB_KEY_BACK_TAB` | 0xffe9 | Shift+Tab |
| `TB_KEY_MOUSE_LEFT` | 0xffe8 | Mouse left |
| `TB_KEY_MOUSE_RIGHT` | 0xffe7 | Mouse right |
| `TB_KEY_MOUSE_MIDDLE` | 0xffe6 | Mouse middle |
| `TB_KEY_MOUSE_RELEASE` | 0xffe5 | Mouse release |
| `TB_KEY_MOUSE_WHEEL_UP` | 0xffe4 | Wheel up |
| `TB_KEY_MOUSE_WHEEL_DOWN` | 0xffe3 | Wheel down |

#### Capability indices

| Constant | Value | Description |
|----------|-------|-------------|
| `TB_CAP_F1` … `TB_CAP_F12` | 0–11 | Function keys |
| `TB_CAP_INSERT` … `TB_CAP_BACK_TAB` | 12–22 | Editing keys |
| `TB_CAP_ENTER_CA` | 23 | Enter alternate screen |
| `TB_CAP_EXIT_CA` | 24 | Exit alternate screen |
| `TB_CAP_SHOW_CURSOR` | 25 | Show cursor |
| `TB_CAP_HIDE_CURSOR` | 26 | Hide cursor |
| `TB_CAP_CLEAR_SCREEN` | 27 | Clear screen |
| `TB_CAP_SGR0` | 28 | Reset attributes |
| `TB_CAP_UNDERLINE` | 29 | Underline |
| `TB_CAP_BOLD` | 30 | Bold |
| `TB_CAP_BLINK` | 31 | Blink |
| `TB_CAP_ITALIC` | 32 | Italic |
| `TB_CAP_REVERSE` | 33 | Reverse video |
| `TB_CAP_ENTER_KEYPAD` | 34 | Enter keypad mode |
| `TB_CAP_EXIT_KEYPAD` | 35 | Exit keypad mode |
| `TB_CAP_DIM` | 36 | Dim |
| `TB_CAP_INVISIBLE` | 37 | Invisible |
| `TB_CAP__COUNT` | 38 | Total capabilities |

#### Colors

| Constant | Value |
|----------|-------|
| `TB_DEFAULT` | 0x0000 |
| `TB_BLACK` | 0x0001 |
| `TB_RED` | 0x0002 |
| `TB_GREEN` | 0x0003 |
| `TB_YELLOW` | 0x0004 |
| `TB_BLUE` | 0x0005 |
| `TB_MAGENTA` | 0x0006 |
| `TB_CYAN` | 0x0007 |
| `TB_WHITE` | 0x0008 |

#### Attributes (64-bit width)

| Constant | Value |
|----------|-------|
| `TB_BOLD` | 0x01000000 |
| `TB_UNDERLINE` | 0x02000000 |
| `TB_REVERSE` | 0x04000000 |
| `TB_ITALIC` | 0x08000000 |
| `TB_BLINK` | 0x10000000 |
| `TB_HI_BLACK` | 0x20000000 |
| `TB_BRIGHT` | 0x40000000 |
| `TB_DIM` | 0x80000000 |
| `TB_STRIKEOUT` | 0x0000000100000000 |
| `TB_UNDERLINE_2` | 0x0000000200000000 |
| `TB_OVERLINE` | 0x0000000400000000 |
| `TB_INVISIBLE` | 0x0000000800000000 |

Combine colors with attributes using bitwise OR:
`TB_BOLD \| TB_RED`, `TB_UNDERLINE \| TB_CYAN`.

#### Event types

| Constant | Value |
|----------|-------|
| `TB_EVENT_KEY` | 1 |
| `TB_EVENT_RESIZE` | 2 |
| `TB_EVENT_MOUSE` | 3 |

#### Modifiers

| Constant | Value |
|----------|-------|
| `TB_MOD_ALT` | 1 |
| `TB_MOD_CTRL` | 2 |
| `TB_MOD_SHIFT` | 4 |
| `TB_MOD_MOTION` | 8 |

#### Input modes

| Constant | Value |
|----------|-------|
| `TB_INPUT_CURRENT` | 0 (query current) |
| `TB_INPUT_ESC` | 1 |
| `TB_INPUT_ALT` | 2 |
| `TB_INPUT_MOUSE` | 4 |

#### Output modes

| Constant | Value |
|----------|-------|
| `TB_OUTPUT_CURRENT` | 0 |
| `TB_OUTPUT_NORMAL` | 1 |
| `TB_OUTPUT_256` | 2 |
| `TB_OUTPUT_216` | 3 |
| `TB_OUTPUT_GRAYSCALE` | 4 |
| `TB_OUTPUT_TRUECOLOR` | 5 |

#### Error codes

| Constant | Value |
|----------|-------|
| `TB_OK` | 0 |
| `TB_ERR` | -1 |
| `TB_ERR_NEED_MORE` | -2 |
| `TB_ERR_INIT_ALREADY` | -3 |
| `TB_ERR_INIT_OPEN` | -4 |
| `TB_ERR_MEM` | -5 |
| `TB_ERR_NO_EVENT` | -6 |
| `TB_ERR_NO_TERM` | -7 |
| `TB_ERR_NOT_INIT` | -8 |
| `TB_ERR_OUT_OF_BOUNDS` | -9 |
| `TB_ERR_READ` | -10 |
| `TB_ERR_RESIZE_IOCTL` | -11 |
| `TB_ERR_RESIZE_PIPE` | -12 |
| `TB_ERR_RESIZE_SIGACTION` | -13 |
| `TB_ERR_POLL` | -14 |
| `TB_ERR_TCGETATTR` | -15 |
| `TB_ERR_TCSETATTR` | -16 |
| `TB_ERR_UNSUPPORTED_TERM` | -17 |

---

### Data structures

```goose
struct tb_cell {
    ch: u32,      // character code (Unicode codepoint)
    fg: uintattr_t,  // foreground color+attributes
    bg: uintattr_t,  // background color+attributes
}

struct tb_event {
    kind: u8,     // TB_EVENT_KEY / TB_EVENT_RESIZE / TB_EVENT_MOUSE
    mod: u8,      // modifier flags (TB_MOD_*)
    key: u16,     // key code (TB_KEY_*)
    ch: u32,      // character (for printable keys)
    w: i32,       // terminal width (resize events)
    h: i32,       // terminal height (resize events)
    x: i32,       // mouse x (mouse events)
    y: i32,       // mouse y (mouse events)
}

type uintattr_t = u64   // combined color + attribute bitmask
```

---

### Functions

#### Initialization

```goose
fn tb_init() -> i32
```

Open `/dev/tty`, put it in raw mode, query window size, install SIGWINCH
handler. Returns `TB_OK` on success.

```goose
fn tb_init_file(path: const u8[:]) -> i32
```

Same as `tb_init()` but opens the given TTY path instead of `/dev/tty`.

```goose
fn tb_init_fd(ttyfd: i32) -> i32
fn tb_init_rwfd(rfd: i32, wfd: i32) -> i32
```

Initialize from an existing open file descriptor (read and write may differ).

```goose
fn tb_shutdown() -> i32
```

Restore the original terminal attributes and close all fds.

---

#### Display

```goose
fn tb_width() -> i32
fn tb_height() -> i32
```

Current terminal dimensions.

```goose
fn tb_clear() -> i32
```

Fill the back buffer with spaces using the last-set foreground/background.

```goose
fn tb_set_clear_attrs(fg: uintattr_t, bg: uintattr_t) -> i32
```

Set the default foreground/background used by `tb_clear()`.

```goose
fn tb_set_cell(x: i32, y: i32, ch: u32, fg: uintattr_t, bg: uintattr_t) -> i32
```

Write a single cell to the back buffer.

```goose
fn tb_set_cell_ex(x: i32, y: i32, ch: const u32&, nch: i64, fg: uintattr_t, bg: uintattr_t) -> i32
```

Extended version accepting a character array.

```goose
fn tb_extend_cell(x: i32, y: i32, ch: u32) -> i32
```

Extend a cell (EGC disabled; falls back to `tb_set_cell`).

```goose
fn tb_get_cell(x: i32, y: i32, back: i32, cell: tb_cell&) -> i32
```

Read a cell from the back (`back != 0`) or front buffer.

```goose
fn tb_present() -> i32
```

Diff the back buffer against the front buffer and emit escape sequences to
update the terminal. Call this after drawing to make changes visible.

```goose
fn tb_invalidate() -> i32
```

Mark the entire screen as needing redraw (no-op in this port).

```goose
fn tb_set_cursor(cx: i32, cy: i32) -> i32
```

Set the cursor position.

```goose
fn tb_hide_cursor() -> i32
```

Hide the cursor (no-op in this port).

---

#### Input

```goose
fn tb_peek_event(event: tb_event&, timeout_ms: i32) -> i32
```

Wait up to `timeout_ms` milliseconds for an event. Returns `TB_OK` on event,
`TB_ERR_NO_EVENT` on timeout. Use `-1` for blocking.

```goose
fn tb_poll_event(event: tb_event&) -> i32
```

Blocking version of `tb_peek_event` (waits forever).

```goose
fn tb_get_fds(ttyfd: i32&, resizefd: i32&) -> i32
```

Get the TTY file descriptor and the resize pipe file descriptor for external
poll loops.

```goose
fn tb_set_input_mode(mode: i32) -> i32
fn tb_set_output_mode(mode: i32) -> i32
```

Set input/output mode. Pass `TB_INPUT_CURRENT` / `TB_OUTPUT_CURRENT` to query
the current mode.

---

#### Output (low-level)

```goose
fn tb_send(buf: const u8[:], nbuf: i64) -> i32
```

Append raw bytes to the output buffer.

```goose
fn tb_sendf(fmt: const u8[:]) -> i32
```

Append a format string to the output buffer.

```goose
fn tb_printf(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, fmt: const u8[:]) -> i32
```

Print a formatted string at position (x, y) with the given colors.

```goose
fn tb_printf_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, fmt: const u8[:]) -> i32
```

Like `tb_printf` but also outputs the rendered width via `out_w`.

```goose
fn tb_print(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32
```

Print a string at position (x, y) with the given colors. Handles UTF-8,
newlines, and wrapping.

```goose
fn tb_print_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32
```

Extended print (used internally by `tb_print` and `tb_printf`).

---

#### Information

```goose
fn tb_version() -> const u8[:]
fn tb_last_errno() -> i32
fn tb_strerror(err: i32) -> const u8[:]
fn tb_has_truecolor() -> i32
fn tb_has_egc() -> i32
fn tb_attr_width() -> i32
```

Version string, last error code, error message, and capability queries.

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
        let rv = tb_poll_event(ev);
        if rv == TB_ERR_NO_EVENT { continue; }
        if rv != TB_OK { break; }

        if ev.kind == TB_EVENT_KEY {
            if ev.key == TB_KEY_ESC || ev.ch == 'q' { break; }
        } else if ev.kind == TB_EVENT_RESIZE {
            let _ = tb_clear();
            let _ = tb_present();
        }
    }

    let _ = tb_shutdown();
    print("goodbye\n");
}
```

Build and run:

```bash
goose build demo.goose -o demo
./demo
```

---

## Design notes

### Goose memory model

Goose has no heap, no GC, and no `malloc`/`free`. All memory lives on data
stacks with a bump-pointer allocator. The port uses:

- **`root struct tb_global`** — a single global owning multiple resizable
  fields (cell buffers, byte buffers, cap_trie pools), bypassing Goose's
  one-resizable-per-stack rule
- **Index-based cap_trie** — `child_offset`/`child_count` indices into a flat
  children pool instead of pointer-linked nodes
- **`uintattr_t = u64`** — universal 64-bit attribute type, correct in all
  attribute-width modes

### C sidecar

Goose's `extern fn` cannot declare variadic functions, so `adapter.c` provides
non-variadic wrappers for `tcgetattr`/`tcsetattr`/`ioctl`/`fcntl`/`open`/`pipe`/
`signal`/`vsnprintf`/`errno`/`ttyname`/`read`/`write`/`poll`.

### EGC

Extended Grapevine Clusters (EGC) are disabled (`TB_OPT_EGC = 0`), so `tb_cell`
has no `ech` field and `tb_extend_cell` falls back to `tb_set_cell`.

---

## Credits

- **termbox2** — Adam Saponara, nsf — https://github.com/termbox/termbox2 — MIT
- **Goose** — aardappel — https://github.com/aardappel/goose
- **goosebox2 port** — MIT licensed, 2026
