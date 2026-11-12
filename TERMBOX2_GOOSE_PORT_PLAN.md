# Termbox2 → Goose: Full Porting Plan

**Source:** `termbox/termbox2` (https://github.com/termbox/termbox2), single-header C library (~4,200 lines, `termbox2.h`, MIT licensed)
**Target:** Goose (aardappel/goose), `.goose` source files compiling to C via the Goose compiler
**Goal:** A fully ported, standalone termbox2 implementation in Goose with the same public API, behavior, and test coverage.

---

## 1. What termbox2 Is

termbox2 is a terminal I/O library for building TUIs. It is a slim ncurses alternative with:
- A **back buffer** (what you draw to) and a **front buffer** (what was last sent to the terminal)
- `tb_present()` diffs the two and emits only the changed cells as escape sequences
- An **escape-sequence input parser** (cap_trie) that turns raw TTY bytes into `tb_event` structs (keys, mouse, resize)
- Built-in **terminfo** fallbacks for xterm, linux, screen, rxvt, Eterm (no terminfo DB required)
- Multiple output modes: normal (8 colors), 256, 216, grayscale, truecolor (24-bit)
- Extended grapheme cluster (EGC) support (optional, compile-time)
- Configurable attribute width (16/32/64 bit)

It uses POSIX only: `termios`, `ioctl(TIOCGWINSZ)`, `select`/`poll`, `fcntl`, `unistd`, `signal`. No external dependencies beyond libc.

---

## 2. API Surface to Port (from `termbox2.h`)

### Constants / Macros
| Category | Items |
|----------|-------|
| Version | `TB_VERSION_STR` |
| Keys (ASCII) | `TB_KEY_CTRL_TILDE`…`TB_KEY_CTRL_7`, `TB_KEY_ESC`, `TB_KEY_ENTER`, `TB_KEY_TAB`, `TB_KEY_BACKSPACE`, `TB_KEY_SPACE`, `TB_KEY_BACKSPACE2` |
| Keys (terminfo, `0xffff - i`) | `TB_KEY_F1`…`F12`, `TB_KEY_INSERT`, `TB_KEY_DELETE`, `TB_KEY_HOME`, `TB_KEY_END`, `TB_KEY_PGUP`, `TB_KEY_PGDN`, `TB_KEY_ARROW_*`, `TB_KEY_BACK_TAB`, `TB_KEY_MOUSE_*`, `TB_KEY_MOUSE_WHEEL_*` |
| Cap indices | `TB_CAP_F1`…`TB_CAP__COUNT_KEYS` (23), `TB_CAP_ENTER_CA`…`TB_CAP__COUNT` (38) |
| Hard caps | `TB_HARDCAP_ENTER_MOUSE`, `TB_HARDCAP_EXIT_MOUSE`, `TB_HARDCAP_STRIKEOUT`, `TB_HARDCAP_UNDERLINE_2`, `TB_HARDCAP_OVERLINE` |
| Colors / attrs | `TB_DEFAULT`, `TB_BLACK`…`TB_WHITE`, `TB_BOLD`, `TB_UNDERLINE`, `TB_REVERSE`, `TB_ITALIC`, `TB_BLINK`, `TB_HI_BLACK`, TB_BRIGHT, TB_DIM` (+ `TB_STRIKEOUT`, `TB_UNDERLINE_2`, `TB_OVERLINE`, `TB_INVISIBLE` when 64-bit) |
| Event types | `TB_EVENT_KEY` (1), `TB_EVENT_RESIZE` (2), `TB_EVENT_MOUSE` (3) |
| Modifiers | `TB_MOD_ALT` (1), `TB_MOD_CTRL` (2), `TB_MOD_SHIFT` (4), `TB_MOD_MOTION` (8) |
| Input modes | `TB_INPUT_CURRENT` (0), `TB_INPUT_ESC` (1), `TB_INPUT_ALT` (2), `TB_INPUT_MOUSE` (4) |
| Output modes | `TB_OUTPUT_CURRENT` (0), `TB_OUTPUT_NORMAL` (1), `TB_OUTPUT_256` (2), `TB_OUTPUT_216` (3), `TB_OUTPUT_GRAYSCALE` (4), `TB_OUTPUT_TRUECOLOR` (5) |
| Error codes | `TB_OK` (0), `TB_ERR` (-1)…`TB_ERR_RESIZE_SSCANF` (-21), `TB_ERR_CAP_COLLISION` (-22) |

### Structs
- `tb_cell` { `ch: u32`, `fg: uintattr_t`, `bg: uintattr_t`, [EGC:] `ech: u32*`, `nech: size_t`, `cech: size_t` }
- `tb_event` { `type: u8`, `mod: u8`, `key: u16`, `ch: u32`, `w: i32`, `h: i32`, `x: i32`, `y: i32` }

### Functions (30+)
`tb_init`, `tb_init_file`, `tb_init_fd`, `tb_init_rwfd`, `tb_shutdown`, `tb_width`, `tb_height`, `tb_clear`, `tb_set_clear_attrs`, `tb_present`, `tb_invalidate`, `tb_set_cursor`, `tb_hide_cursor`, `tb_set_cell`, `tb_set_cell_ex`, `tb_extend_cell`, `tb_get_cell`, `tb_set_input_mode`, `tb_set_output_mode`, `tb_peek_event`, `tb_poll_event`, `tb_get_fds`, `tb_print`, `tb_printf`, `tb_print_ex`, `tb_printf_ex`, `tb_send`, `tb_sendf`, `tb_utf8_char_length`, `tb_utf8_char_to_unicode`, `tb_utf8_unicode_to_char`, `tb_last_errno`, `tb_strerror`, `tb_has_truecolor`, `tb_has_egc`, `tb_attr_width`, `tb_version`, `tb_iswprint`, `tb_wcwidth`

---

## 3. Goose Language Constraints & Mapping Strategy

### Constraint 1: No heap / no malloc / no free
termbox2 uses `malloc`/`realloc`/`free` for cell buffers, byte buffers, terminfo strings, and cap_trie nodes.

**Mapping:** Use Goose's data-stack memory model.
- **Global state → `root struct` global.** A `root struct` may own multiple resizable fields (`T[>..]`, `T[>..<]`) in any field position, all sharing one lifetime. This is the escape hatch for termbox2's single `static struct tb_global` that contains *several* growable buffers (`in`, `out`, `back.cells`, `front.cells`, `terminfo`).
- **Cell buffers** → `tb_cell[>..]` fields inside the root struct. Terminal width×height is dynamic but bounded in practice; we grow on resize.
- **Input/output byte buffers** → `u8[>..]` fields.
- **Terminfo string** → `u8[>..]` field (or fixed `u8[4096]`).
- **cap_trie** → pointer-based tree in C → **index-based trie** in Goose: arrays of nodes with `children: i32[>..]` (child indices instead of pointers). No heap allocation needed; nodes are pushed into a growable array.

### Constraint 2: At most one resizable value per stack, topmost
This applies to ordinary locals. A `root struct` global is exempt — it can own several resizable fields. We will keep all mutable library state in one `root struct` global so we never violate the per-stack rule.

### Constraint 3: No variadic functions in extern fn
`tb_printf`, `tb_sendf`, `tb_printf_ex` are variadic in C. Goose `extern fn` cannot declare variadic signatures.

**Mapping:** Provide a **C sidecar** (`termbox2.build` + small `.c` adapter) that exports non-variadic wrappers:
```c
// termbox2_adapter.c
int tb_printf_va(int x, int y, uintattr_t fg, uintattr_t buf/*...*/);
```
Or simpler: drop `tb_printf`/`tb_sendf` from the pure Goose API and offer `tb_print`/`tb_send` (non-variadic) plus a `tb_vprint`-style builder. Users who need `printf` formatting can use Goose's `format` builtin and call `tb_print`. We will include `tb_printf`/`tb_sendf` via a sidecar adapter that uses `vsnprintf` into a fixed buffer, then calls the internal send path.

### Constraint 4: Pointers and references
termbox2 uses `struct tb_cell *`, `struct cap_trie *children`, `uint32_t *ech`, etc.

**Mapping:**
- `T&` (Goose reference) for pass-by-pointer to flat structs.
- Index-based arrays instead of pointer-linked trees (cap_trie).
- `u32[>..]` for `ech` (resizable tail field of `tb_cell`).

### Constraint 5: Compile-time options (`TB_OPT_ATTR_W`, `TB_OPT_EGC`, etc.)
termbox2 is configured via `#define` at compile time.

**Mapping:** Use Goose `const` declarations at the top of the module. `TB_OPT_ATTR_W` determines `uintattr_t` width (`u16` / `u32` / `u64`). Since Goose is monomorphized per compile, we can parameterize with a type alias:
```goose
const TB_OPT_ATTR_W = 16
// uintattr_t = u16 | u32 | u64 based on the const
```
Goose doesn't have conditional type aliases directly, so we'll use `u64` as the widest form (works for all modes; wastes bits in 16-bit mode but is correct). Or we can generate three variants via a build flag. Simplest: default to `u64` (`TB_OPT_ATTR_W == 64`) for maximum feature parity, with a note that `u16`/`u32` variants can be added via const-generic-like duplication.

`TB_OPT_EGC` → a `const TB_OPT_EGC = false` gate; when true, include `ech`/`nech`/`cech` fields in `tb_cell`.

---

## 4. Data Structure Mapping (C → Goose)

### `uintattr_t`
C: `uint16_t` / `uint32_t` / `uint64_t` depending on `TB_OPT_ATTR_W`.
Goose: `u64` universally (simplest, correct in all modes). Constant `TB_ATTR_WIDTH` reports 16/32/64.

### `tb_cell`
```goose
struct tb_cell {
    ch: u32,
    fg: u64,
    bg: u64,
    // TB_OPT_EGC:
    ech: u32[>..],   // last field, resizable tail → struct becomes resizable
    nech: i64,
    cech: i64,
}
```
When EGC is off, `ech`/`nech`/`cech` are omitted (use a `const` gate and two struct variants, or always include them as zero-length — simpler to always include but gate the usage).

### `tb_event`
```goose
struct tb_event {
    type: u8,
    mod: u8,
    key: u16,
    ch: u32,
    w: i32,
    h: i32,
    x: i32,
    y: i32,
}
```

### `cellbuf`
C: `{ int width, height; struct tb_cell *cells; }`
Goose:
```goose
struct cellbuf {
    width: i32,
    height: i32,
    cells: tb_cell[>..],   // resizable tail
}
```

### `cap_trie` (pointer-based tree → index-based)
C:
```c
struct cap_trie {
    char c;
    struct cap_trie *children;
    size_t nchildren;
    int is_leaf;
    uint16_t key;
    uint8_t mod;
};
```
Goose:
```goose
struct cap_trie_node {
    c: u8,
    children: i32[>..],   // indices into the node pool
    is_leaf: i32,
    key: u16,
    mod: u8,
}
```
All nodes live in one `cap_trie_node[>..]` pool (a field of the global root struct). `nchildren` is `children.len`.

### `tb_global` → `root struct tb_global`
All mutable state in one global root struct so multiple resizable fields are legal:
```goose
root struct tb_global {
    ttyfd: i32,
    rfd: i32,
    wfd: i32,
    ttyfd_open: i32,
    resize_pipefd: [2]i32,
    width: i32,
    height: i32,
    cursor_x: i32,
    cursor_y: i32,
    last_x: i32,
    last_y: i32,
    fg: u64,
    bg: u64,
    last_fg: u64,
    last_bg: u64,
    input_mode: i32,
    output_mode: i32,
    terminfo: u8[>..],
    nterminfo: i64,
    caps: [38]const u8[:],       // fixed array of string views
    cap_trie: cap_trie_node[>..], // index-based node pool
    in: u8[>..],
    out: u8[>..],
    back: cellbuf,
    front: cellbuf,
    orig_tios: termios,          // flat fixed struct, crosses FFI
    has_orig_tios: i32,
    last_errno: i32,
    initialized: i32,
    errbuf: [1024]u8,
}
```
*Note:* `cellbuf` itself contains a resizable `cells` field, making `cellbuf` resizable. As a field of a `root struct`, this is allowed.

### `termios`
Flat fixed-size struct. Crosses FFI by reference (`termios&`). Declared in Goose matching C layout, or kept opaque as a byte array `[56]u8` (size is platform-dependent; safer to pass by reference through FFI with a fixed-size buffer).

---

## 5. FFI Declarations (POSIX)

All declared as `extern fn` in Goose. These map 1:1 to libc functions:

```goose
extern fn tcgetattr(fd: i32, termios_p: u8&) -> i32;
extern fn tcsetattr(fd: i32, optional_actions: i32, termios_p: const u8&) -> i32;
extern fn tcsetattr(fd: i32, optional_actions: i32, termios_p: const u8&) -> i32;
extern fn ioctl(fd: i32, request: u64, ...: u64) -> i32;   // variadic → adapter needed
extern fn select(nfds: i32, readfds: u8&, writefds: u8&, exceptfds: u8&, timeout: u8&) -> i32;
extern fn poll(fds: u8&, nfds: u64, timeout: i64) -> i32;
extern fn fcntl(fd: i32, cmd: i32, ...: u64) -> i32;       // variadic → adapter
extern fn read(fd: i32, buf: u8&, count: u64) -> i64;
extern fn write(fd: i32, buf: const u8&, count: u64) -> i64;
extern fn open(path: const u8&, flags: i32, ...: u64) -> i32;   // variadic → adapter
extern fn close(fd: i32) -> i32;
extern fn pipe(pipefd: u8&) -> i32;
extern fn signal(signum: i32, handler: u64) -> u64;          // handler = function pointer → adapter
extern fn sigaction(signum: i32, act: const u8&, oldact: u8&) -> i32;
extern fn sigaddset(set: u8&, signum: i32) -> i32;
extern fn sigemptyset(set: u8&) -> i32;
extern fn errno_location() -> i32&;                          // *errno
extern fn isatty(fd: i32) -> i32;
extern fn ttyname(fd: i32) -> u64;                           // returns const char * → u64, use ffi::cstr
extern fn strsignal(signum: i32) -> u64;
```

**Variadic problem:** `ioctl`, `fcntl`, `open`, `signal` are variadic. Goose cannot bind them directly.
**Solution:** C sidecar (`termbox2.build`) provides thin non-variadic wrappers:
- `tb_ioctl_termios(fd, &tios)` → wraps `ioctl(fd, TCGETS, &tios)`
- `tb_ioctl_winsize(fd, &ws)` → wraps `ioctl(fd, TIOCGWINSZ, &ws)`
- `tb_fcntl_setblock(fd)` → wraps `fcntl(fd, F_SETFL, O_NONBLOCK)`
- `tb_signal_install(signum, handler_addr)` → wraps `signal()`

The sidecar is compiled and linked via `goose build` (the TinyCC in-process backend cannot link custom C; use `goose build` for the final binary).

---

## 6. Phase-by-Phase Implementation Plan

### Phase 0 — Project scaffolding
- Create directory structure (see §7)
- Write `termbox2.build` sidecar (C sources + headers for FFI adapters)
- Write `Makefile` / build script using `goose build`
- Verify `goose build` works end-to-end with a trivial `.goose` + `.c` sidecar

### Phase 1 — Constants, types, error codes
- Port all `#define` constants as Goose `const`
- Define `tb_cell`, `tb_event`, `cellbuf`, `cap_trie_node` structs
- Define `uintattr_t` type alias (`u64`)
- Define error code constants (`TB_OK`…`TB_ERR_CAP_COLLISION`)

### Phase 2 — Global state (`root struct tb_global`)
- Declare the single global root struct
- Initialize all fields to zero (Goose zero-initializes globals)
- Accessor: `fn global() -> tb_global&` (or direct global variable)

### Phase 3 — UTF-8 helpers (pure Goose, no FFI)
- `tb_utf8_char_length(c: i8) -> i32`
- `tb_utf8_char_to_unicode(out: u32&, c: const u8[:]) -> i32`
- `tb_utf8_unicode_to_char(out: u8[:], c: u32) -> i32`
- `tb_iswprint(ch: u32) -> i32`
- `tb_wcwidth(ch: u32) -> i32` (Unicode width table — port the C table)

### Phase 4 — Cell buffer operations
- `tb_clear()` — fill back buffer with default attrs
- `tb_set_clear_attrs(fg, bg)`
- `tb_set_cell(x, y, ch, fg, bg)` / `tb_set_cell_ex()` / `tb_extend_cell()`
- `tb_get_cell(x, y, back, cell&)` — bounds check, return pointer via `tb_cell&`
- `tb_width()` / `tb_height()`
- Buffer resize on terminal dimension change (realloc equivalent = `push`/resize on `tb_cell[>..]`)

### Phase 5 — TTY initialization (heavy FFI)
- `tb_init()` → `tb_init_file("/dev/tty")`
- `tb_init_file(path)` — open TTY, save original termios, set raw mode, set non-blocking, create resize pipe, install SIGWINCH handler
- `tb_init_fd(ttyfd)` / `tb_init_rwfd(rfd, wfd)`
- `tb_shutdown()` — restore termios, close fds, exit alternate screen, reset cursor

### Phase 6 — Terminfo & capability table
- Port `builtin_terms` (xterm, linux, screen, rxvt-256color, rxvt-unicode, Eterm) as static string arrays
- Port `terminfo_cap_indexes` and `xterm_caps`/`linux_caps`/etc.
- Terminfo detection: try `$TERMINFO`, then `/usr/share/terminfo`, fall back to built-in table
- `tb_has_truecolor()`, `tb_has_egc()`, `tb_attr_width()`

### Phase 7 — Escape-sequence parser (cap_trie)
- Build the cap_trie from built-in caps (index-based node pool)
- `extract_esc_pre` / `extract_esc_post` — match incoming bytes against trie
- Handle modifier keys (`TB_MOD_ALT/CTRL/SHIFT` on arrows and mouse)
- This is the most algorithmically complex part; port function-by-function from C

### Phase 8 — Input / event polling
- `tb_poll_event(event&)` / `tb_peek_event(event&, timeout_ms)`
- Read from TTY fd into `in` buffer
- Parse escape sequences → produce `tb_event`
- Handle resize: SIGWINCH writes to resize pipe; `ioctl(TIOCGWINSZ)` gets new dimensions → `TB_EVENT_RESIZE`
- Handle mouse events (`TB_KEY_MOUSE_*`)
- `tb_get_fds(ttyfd&, resizefd&)` for external poll integration
- `tb_set_input_mode(mode)`

### Phase 9 — Output / `tb_present`
- Diff back buffer vs front buffer
- Emit escape sequences: cursor movement (`\033[...H`), SGR attributes (`\033[...m`), cell characters
- Handle wide characters (`wcwidth >= 2` → skip following cells)
- Handle output mode translation (normal → 256 → truecolor)
- `tb_invalidate()` — force full redraw (clear front buffer)
- `tb_set_cursor(cx, cy)` / `tb_hide_cursor()`

### Phase 10 — Printing functions
- `tb_print(x, y, fg, bg, str)` — UTF-8 string → cells, with newline handling
- `tb_print_ex` / `tb_printf_ex` (with `out_w`)
- `tb_send(buf, nbuf)` — raw bytes to TTY
- `tb_printf` / `tb_sendf` — **via C sidecar adapter** (vsnprintf into fixed buffer, then `tb_send`)

### Phase 11 — Utility functions
- `tb_last_errno()`, `tb_strerror(err)`
- `tb_version()`
- `tb_set_output_mode(mode)` / `tb_set_input_mode(mode)`

### Phase 12 — Demo programs (validate the port)
Port the C demo programs to Goose:
- `demo/example.goose` — basic "hello world" TUI loop
- `demo/keyboard.goose` — key event viewer
- `demo/readline.goose` — line editing

### Phase 13 — Test suite
Port the PHP-based tests to Goose (or shell + Goose):
- `test_basic`, `test_print`, `test_set_get`, `test_color_8bit`, `test_color_true`, `test_egc`, `test_wcwidth`, `test_resize`, `test_mouse`, `test_invalid_utf8`, `test_non_printable`, `test_invalidate`, `test_output_mode`, `test_error`, `test_mod`, `test_large_input`, `test_fd_leak`
- Compare output against `expected.ansi` files

### Phase 14 — Polish & release
- Add `tb_build`-level feature flags (`TB_OPT_ATTR_W`, `TB_OPT_EGC`)
- Add `README.md`, `LICENSE` (MIT), `CHANGELOG.md`
- `goose check` + `goose build` + run all tests green

---

## 7. File Structure

```
goosebox2/
├── TERMBOX2_GOOSE_PORT_PLAN.md   (this file)
├── termbox2.goose                # Main module: all API + logic
├── termbox2.build                # Sidecar: c_sources, c_headers, dylibs
├── adapter.c                     # C FFI adapters (ioctl, fcntl, signal, printf)
├── adapter.h                     # Adapter declarations
├── Makefile                      # Build: goose build + link
├── demo/
│   ├── example.goose
│   ├── keyboard.goose
│   └── readline.goose
└── tests/
    ├── run.sh                    # Test runner (compare to expected.ansi)
    ├── test_basic/
    │   ├── test.goose            # (ported from test.php)
    │   └── expected.ansi
    ├── test_color_8bit/, test_color_true/, test_egc/, ... (one per C test)
    └── expected.ansi files (copied from termbox2 repo)
```

### `termbox2.build` (sidecar)
```
c_sources = ["adapter.c"];
c_headers = ["adapter.h"];
```
No shared libraries needed (pure POSIX libc). On `goose build`, the C compiler links libc automatically.

### `adapter.c` — variadic / function-pointer wrappers
```c
#include <termios.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "termbox2.h"   // for TB_OPT_PRINTF_BUF

int tb_adapter_ioctl_termios(int fd, int request, struct termios *t) {
    return ioctl(fd, request, t);
}
int tb_adapter_fcntl_setblock(int fd, int flags) {
    return fcntl(fd, F_SETFL, flags);
}
int tb_adapter_open_tty(const char *path, int flags) {
    return open(path, flags);
}
// tb_printf / tb_sendf vsnprintf wrapper:
int tb_adapter_vprintf(char *buf, size_t bufsz, const char *fmt, va_list ap) {
    return vsnprintf(buf, bufsz, fmt, ap);
}
void tb_adapter_sigwinch_handler(int signum) { /* write to resize pipe */ }
```

---

## 8. Build Commands

```bash
# Typecheck only
goose check termbox2.goose

# Emit C for inspection
goose -o termbox2.c termbox2.goose

# Build final binary (links adapter.c via sidecar)
goose build termbox2.goose && ./termbox2

# Run a demo
goose build demo/example.goose && ./example
```

---

## 9. Testing Strategy

1. **Unit-level:** `goose check` passes (typecheck), `goose build` produces a binary.
2. **Smoke test:** `demo/example` runs, draws a colored screen, responds to keys, exits on `q`.
3. **Parity test:** Port each `tests/*/test.php` to a Goose program that drives termbox2 and captures ANSI output; diff against `tests/*/expected.ansi`.
4. **Interactive test:** Run `demo/keyboard`, press keys, verify event types/modifiers match.
5. **Resize test:** Trigger SIGWINCH, verify `TB_EVENT_RESIZE` and new `tb_width()`/`tb_height()`.

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Multiple resizable buffers violate "one per stack"** | Use a single `root struct tb_global` global; root structs may own several resizable fields |
| **Variadic `tb_printf`/`tb_sendf` can't be `extern fn`** | C sidecar adapter with `vsnprintf`; or expose only `tb_print`/`tb_send` in pure Goose |
| **Pointer-based `cap_trie`** | Index-based trie: `children: i32[>..]` into a node pool array |
| **`termios` size/layout is platform-dependent** | Pass by reference through FFI using a fixed-size byte buffer; never inspect fields in Goose |
| **SIGWINCH handler needs a C function pointer** | Install handler from adapter.c; it writes a byte to the resize pipe which Goose polls |
| **`tb_cell` with EGC `ech` field must be last resizable field** | Put `ech`/`nech`/`cech` as the tail; gate with `const TB_OPT_EGC` |
| **Goose in-process backend (TinyCC) can't link custom C** | Use `goose build` (real C compiler) for anything needing `adapter.c` |
| **Unicode width table is large** | Embed as static const array; it's read-only data, fine in Goose |

---

## 11. Estimated Effort

- **Lines of Goose:** ~2,500–3,500 (termbox2.h is ~4,200 lines but much is comments/codegen tables; Goose is more concise)
- **Phases:** 14 (as above)
- **Most complex:** Phase 7 (escape parser), Phase 5 (TTY init), Phase 9 (present/diff rendering)
- **Lowest risk:** Phases 1–4 (constants, types, UTF-8, cell buffer)

---

## 12. Success Criteria

- [ ] `goose check termbox2.goose` passes with zero errors
- [ ] `goose build` produces a working binary that links `adapter.c`
- [ ] `demo/example` runs and responds to keyboard input
- [ ] All `tests/*/expected.ansi` outputs match when run through the Goose port
- [ ] Public API matches termbox2.h (all 30+ functions present with identical signatures/semantics)
- [ ] MIT license preserved; credit to Adam Saponara / nsf
