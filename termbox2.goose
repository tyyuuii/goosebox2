// termbox2.goose — termbox2 terminal I/O library, ported to Goose
// Port of https://github.com/termbox/termbox2 (MIT license)
// Original authors: Adam Saponara, nsf
//
// Architecture:
//   - All mutable library state lives in a single `root struct tb_global` so
//     Goose's "one resizable value per stack" rule is satisfied.
//   - POSIX syscalls requiring variadic libc signatures or platform structs
//     (termios, winsize, ioctl, fcntl, poll, sigaction) live in adapter.c.
//
// Build:
//   goose check termbox2.goose
//   goose build <app>.goose -o <app>   (links adapter.c via <app>.build)

const TB_VERSION_STR = "3.0.0-goose";

// ---------------------------------------------------------------------------
// Compile-time options (mirrors termbox2.h TB_OPT_*)
// ---------------------------------------------------------------------------

// 64-bit attribute width (matches uintattr_t = u64).
const TB_OPT_ATTR_W = 64;
// Extended Grapheme Clusters (1 = enabled via pooled egc_node chains).
const TB_OPT_EGC = 1;
const TB_OPT_READ_BUF = 64;

// ---------------------------------------------------------------------------
// Type alias
// ---------------------------------------------------------------------------

type uintattr_t = u64;

// ===========================================================================
// CONSTANTS
// ===========================================================================

// --- ASCII key constants ---
const TB_KEY_CTRL_TILDE      = 0x00;
const TB_KEY_CTRL_2          = 0x00;
const TB_KEY_CTRL_A          = 0x01;
const TB_KEY_CTRL_B          = 0x02;
const TB_KEY_CTRL_C          = 0x03;
const TB_KEY_CTRL_D          = 0x04;
const TB_KEY_CTRL_E          = 0x05;
const TB_KEY_CTRL_F          = 0x06;
const TB_KEY_CTRL_G          = 0x07;
const TB_KEY_BACKSPACE       = 0x08;
const TB_KEY_CTRL_H          = 0x08;
const TB_KEY_TAB             = 0x09;
const TB_KEY_CTRL_I          = 0x09;
const TB_KEY_CTRL_J          = 0x0a;
const TB_KEY_CTRL_K          = 0x0b;
const TB_KEY_CTRL_L          = 0x0c;
const TB_KEY_ENTER           = 0x0d;
const TB_KEY_CTRL_M          = 0x0d;
const TB_KEY_CTRL_N          = 0x0e;
const TB_KEY_CTRL_O          = 0x0f;
const TB_KEY_CTRL_P          = 0x10;
const TB_KEY_CTRL_Q          = 0x11;
const TB_KEY_CTRL_R          = 0x12;
const TB_KEY_CTRL_S          = 0x13;
const TB_KEY_CTRL_T          = 0x14;
const TB_KEY_CTRL_U          = 0x15;
const TB_KEY_CTRL_V          = 0x16;
const TB_KEY_CTRL_W          = 0x17;
const TB_KEY_CTRL_X          = 0x18;
const TB_KEY_CTRL_Y          = 0x19;
const TB_KEY_CTRL_Z          = 0x1a;
const TB_KEY_ESC             = 0x1b;
const TB_KEY_SPACE           = 0x20;
const TB_KEY_BACKSPACE2      = 0x7f;

// --- Terminfo-dependent keys (0xffff - i) ---
fn tb_key_i(i: i32) -> u16 {
    return 0xffff - i as u16;
}

const TB_KEY_F1               = 0xffff - 0;
const TB_KEY_F2               = 0xffff - 1;
const TB_KEY_F3               = 0xffff - 2;
const TB_KEY_F4               = 0xffff - 3;
const TB_KEY_F5               = 0xffff - 4;
const TB_KEY_F6               = 0xffff - 5;
const TB_KEY_F7               = 0xffff - 6;
const TB_KEY_F8               = 0xffff - 7;
const TB_KEY_F9               = 0xffff - 8;
const TB_KEY_F10              = 0xffff - 9;
const TB_KEY_F11              = 0xffff - 10;
const TB_KEY_F12              = 0xffff - 11;
const TB_KEY_INSERT           = 0xffff - 12;
const TB_KEY_DELETE           = 0xffff - 13;
const TB_KEY_HOME             = 0xffff - 14;
const TB_KEY_END              = 0xffff - 15;
const TB_KEY_PGUP             = 0xffff - 16;
const TB_KEY_PGDN             = 0xffff - 17;
const TB_KEY_ARROW_UP         = 0xffff - 18;
const TB_KEY_ARROW_DOWN       = 0xffff - 19;
const TB_KEY_ARROW_LEFT       = 0xffff - 20;
const TB_KEY_ARROW_RIGHT      = 0xffff - 21;
const TB_KEY_BACK_TAB         = 0xffff - 22;
const TB_KEY_MOUSE_LEFT       = 0xffff - 23;
const TB_KEY_MOUSE_RIGHT      = 0xffff - 24;
const TB_KEY_MOUSE_MIDDLE     = 0xffff - 25;
const TB_KEY_MOUSE_RELEASE    = 0xffff - 26;
const TB_KEY_MOUSE_WHEEL_UP   = 0xffff - 27;
const TB_KEY_MOUSE_WHEEL_DOWN = 0xffff - 28;

// --- Capability indices ---
const TB_CAP_F1               = 0;
const TB_CAP_F2               = 1;
const TB_CAP_F3               = 2;
const TB_CAP_F4               = 3;
const TB_CAP_F5               = 4;
const TB_CAP_F6               = 5;
const TB_CAP_F7               = 6;
const TB_CAP_F8               = 7;
const TB_CAP_F9               = 8;
const TB_CAP_F10              = 9;
const TB_CAP_F11              = 10;
const TB_CAP_F12              = 11;
const TB_CAP_INSERT           = 12;
const TB_CAP_DELETE           = 13;
const TB_CAP_HOME             = 14;
const TB_CAP_END              = 15;
const TB_CAP_PGUP             = 16;
const TB_CAP_PGDN             = 17;
const TB_CAP_ARROW_UP         = 18;
const TB_CAP_ARROW_DOWN       = 19;
const TB_CAP_ARROW_LEFT       = 20;
const TB_CAP_ARROW_RIGHT      = 21;
const TB_CAP_BACK_TAB         = 22;
const TB_CAP__COUNT_KEYS      = 23;
const TB_CAP_ENTER_CA         = 23;
const TB_CAP_EXIT_CA          = 24;
const TB_CAP_SHOW_CURSOR      = 25;
const TB_CAP_HIDE_CURSOR      = 26;
const TB_CAP_CLEAR_SCREEN     = 27;
const TB_CAP_SGR0             = 28;
const TB_CAP_UNDERLINE        = 29;
const TB_CAP_BOLD             = 30;
const TB_CAP_BLINK            = 31;
const TB_CAP_ITALIC           = 32;
const TB_CAP_REVERSE          = 33;
const TB_CAP_ENTER_KEYPAD     = 34;
const TB_CAP_EXIT_KEYPAD      = 35;
const TB_CAP_DIM              = 36;
const TB_CAP_INVISIBLE        = 37;
const TB_CAP__COUNT           = 38;

// --- Hard-coded capabilities ---
const TB_HARDCAP_ENTER_MOUSE  = "\x1b[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h";
const TB_HARDCAP_EXIT_MOUSE   = "\x1b[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l";
const TB_HARDCAP_STRIKEOUT    = "\x1b[9m";
const TB_HARDCAP_UNDERLINE_2  = "\x1b[21m";
const TB_HARDCAP_OVERLINE     = "\x1b[53m";

// --- Colors ---
const TB_DEFAULT              = 0x0000;
const TB_BLACK                = 0x0001;
const TB_RED                  = 0x0002;
const TB_GREEN                = 0x0003;
const TB_YELLOW               = 0x0004;
const TB_BLUE                 = 0x0005;
const TB_MAGENTA              = 0x0006;
const TB_CYAN                 = 0x0007;
const TB_WHITE                = 0x0008;

// --- Attributes (64-bit width) ---
const TB_BOLD                 = 0x01000000;
const TB_UNDERLINE            = 0x02000000;
const TB_REVERSE              = 0x04000000;
const TB_ITALIC               = 0x08000000;
const TB_BLINK                = 0x10000000;
const TB_HI_BLACK             = 0x20000000;
const TB_BRIGHT               = 0x40000000;
const TB_DIM                  = 0x80000000;
const TB_STRIKEOUT            = 0x0000000100000000;
const TB_UNDERLINE_2          = 0x0000000200000000;
const TB_OVERLINE             = 0x0000000400000000;
const TB_INVISIBLE            = 0x0000000800000000;
const TB_STYLE_MASK: uintattr_t =
    TB_BOLD | TB_UNDERLINE | TB_REVERSE | TB_ITALIC | TB_BLINK |
    TB_DIM | TB_STRIKEOUT | TB_UNDERLINE_2 | TB_OVERLINE | TB_INVISIBLE;

// --- Event types ---
const TB_EVENT_KEY    = 1;
const TB_EVENT_RESIZE = 2;
const TB_EVENT_MOUSE  = 3;

// --- Modifiers ---
const TB_MOD_ALT      = 1;
const TB_MOD_CTRL     = 2;
const TB_MOD_SHIFT    = 4;
const TB_MOD_MOTION   = 8;

// --- Input modes ---
const TB_INPUT_CURRENT = 0;
const TB_INPUT_ESC     = 1;
const TB_INPUT_ALT     = 2;
const TB_INPUT_MOUSE   = 4;

// --- Output modes ---
const TB_OUTPUT_CURRENT   = 0;
const TB_OUTPUT_NORMAL    = 1;
const TB_OUTPUT_256       = 2;
const TB_OUTPUT_216       = 3;
const TB_OUTPUT_GRAYSCALE = 4;
const TB_OUTPUT_TRUECOLOR = 5;

// --- Error codes ---
const TB_OK                   = 0;
const TB_ERR                  = -1;
const TB_ERR_NEED_MORE        = -2;
const TB_ERR_INIT_ALREADY     = -3;
const TB_ERR_INIT_OPEN        = -4;
const TB_ERR_MEM              = -5;
const TB_ERR_NO_EVENT         = -6;
const TB_ERR_NO_TERM          = -7;
const TB_ERR_NOT_INIT         = -8;
const TB_ERR_OUT_OF_BOUNDS    = -9;
const TB_ERR_READ             = -10;
const TB_ERR_RESIZE_IOCTL     = -11;
const TB_ERR_RESIZE_PIPE      = -12;
const TB_ERR_RESIZE_SIGACTION = -13;
const TB_ERR_POLL             = -14;
const TB_ERR_TCGETATTR        = -15;
const TB_ERR_TCSETATTR        = -16;
const TB_ERR_UNSUPPORTED_TERM = -17;
const TB_ERR_RESIZE_WRITE     = -18;
const TB_ERR_RESIZE_POLL      = -19;
const TB_ERR_RESIZE_READ      = -20;
const TB_ERR_RESIZE_SSCANF    = -21;
const TB_ERR_CAP_COLLISION    = -22;

const TB_ERR_SELECT           = TB_ERR_POLL;
const TB_ERR_RESIZE_SELECT    = TB_ERR_RESIZE_POLL;

const TB_PATH_MAX = 4096;

// ===========================================================================
// DATA STRUCTURES
// ===========================================================================

// Single terminal cell in the front/back cell buffers.
struct tb_cell {
    ch: u32,         // Base Unicode codepoint (additional combining chars live in cellbuf EGC chains)
    fg: uintattr_t,  // Foreground color index / RGB + TB_* attribute flags
    bg: uintattr_t,  // Background color index / RGB + TB_* attribute flags
}

// Input or resize event populated by tb_peek_event() / tb_poll_event().
// Note: `kind` corresponds to `type` in C termbox2.h (`type` is a Goose keyword).
struct tb_event {
    kind: u8,   // TB_EVENT_KEY (1), TB_EVENT_RESIZE (2), or TB_EVENT_MOUSE (3)
    mod: u8,    // Bitmask of TB_MOD_ALT, TB_MOD_CTRL, TB_MOD_SHIFT, TB_MOD_MOTION
    key: u16,   // Special/control key constant (TB_KEY_*), or 0 when `ch` is set
    ch: u32,    // Decoded Unicode codepoint for printable keys, or 0
    w: i32,     // New terminal width in columns (TB_EVENT_RESIZE)
    h: i32,     // New terminal height in rows (TB_EVENT_RESIZE)
    x: i32,     // Zero-based column (TB_EVENT_MOUSE)
    y: i32,     // Zero-based row (TB_EVENT_MOUSE)
}

// Linked node in `tb_global.egc_pool` storing extra codepoints for grapheme clusters.
struct egc_node {
    ch: u32,
    next: i32,
}

struct cellbuf {
    width: i32,
    height: i32,
    cells: tb_cell[>..],
}

struct cap_trie_node {
    c: u8,
    first_child: i32,
    next_sibling: i32,
    is_leaf: i32,
    key: u16,
    mod: u8,
}

root struct tb_global {
    ttyfd: i32,
    rfd: i32,
    wfd: i32,
    ttyfd_open: i32,
    fd_owned: i32,
    rfd_is_tty: i32,
    orig_rfd_flags: i32,
    has_orig_rfd_flags: i32,
    has_resize_pipe: i32,
    resize_pipefd: i32[2],
    width: i32,
    height: i32,
    cursor_x: i32,
    cursor_y: i32,
    cursor_hidden: i32,
    last_x: i32,
    last_y: i32,
    fg: uintattr_t,
    bg: uintattr_t,
    last_fg: uintattr_t,
    last_bg: uintattr_t,
    input_mode: i32,
    output_mode: i32,
    terminfo: u8[>..],
    nterminfo: i64,
    caps: const u8[:][TB_CAP__COUNT],
    cap_trie: cap_trie_node[>..],
    cap_trie_len: i32,
    cap_trie_root: i32,
    term_index: i32,
    inbuf: u8[>..],
    inbuf_pos: i64,
    inbuf_len: i64,
    outbuf: u8[>..],
    outbuf_len: i64,
    back: cellbuf,
    front: cellbuf,
    back_ech_head: i32[>..],
    front_ech_head: i32[>..],
    egc_pool: egc_node[>..],
    egc_free_head_p1: i32,
    has_orig_tios: i32,
    last_errno: i32,
    initialized: i32,
}

var global: tb_global;

fn gbl() -> tb_global& {
    return global;
}

// ===========================================================================
// FFI DECLARATIONS
// ===========================================================================

extern fn tb_adapter_save_termios(fd: i32) -> i32;
extern fn tb_adapter_restore_termios(fd: i32) -> i32;
extern fn tb_adapter_get_winsize(fd: i32, out_w: i32&, out_h: i32&) -> i32;
extern fn tb_adapter_fcntl_getfl(fd: i32) -> i32;
extern fn tb_adapter_fcntl_setfl(fd: i32, flags: i32) -> i32;
extern fn tb_adapter_set_nonblock(fd: i32) -> i32;
extern fn tb_adapter_save_and_set_nonblock(fd: i32, out_orig_flags: i32&) -> i32;
extern fn tb_adapter_restore_fd_flags(fd: i32, orig_flags: i32) -> i32;
extern fn tb_adapter_open_tty_rw(path: const u8&) -> i32;
extern fn tb_adapter_close(fd: i32) -> i32;
extern fn tb_adapter_write(fd: i32, buf: const u8&, n: u64) -> i64;
extern fn tb_adapter_read(fd: i32, buf: u8&, n: u64) -> i64;
extern fn tb_adapter_poll(fd: i32, timeout_ms: i32) -> i32;
extern fn tb_adapter_poll_out(fd: i32, timeout_ms: i32) -> i32;
extern fn tb_adapter_poll_multi(fd1: i32, fd2: i32, timeout_ms: i32) -> i32;
extern fn tb_adapter_poll_is_in(idx: i32) -> i32;
extern fn tb_adapter_poll_is_err(idx: i32) -> i32;
extern fn tb_adapter_pipe(pipefd: i32[2]&) -> i32;
extern fn tb_adapter_isatty(fd: i32) -> i32;
extern fn tb_adapter_errno() -> i32;
extern fn tb_adapter_is_eintr() -> i32;
extern fn tb_adapter_is_again() -> i32;
extern fn tb_adapter_setup_signwinch(pipe_fd: i32) -> i32;
extern fn tb_adapter_clear_signwinch() -> i32;
extern fn tb_adapter_set_raw_mode(fd: i32) -> i32;
extern fn tb_adapter_get_term(buf: u8&, bufsz: u64) -> i32;
extern fn tb_adapter_getenv(name: const u8&, buf: u8&, bufsz: u64) -> i32;
extern fn tb_adapter_read_file(path: const u8&, buf: u8&, max_bytes: u64) -> i64;
extern fn tb_internal_now_ms() -> i64 = "tb_adapter_now_ms";

// ===========================================================================
// UTF-8 & UNICODE HELPERS
// ===========================================================================

// Return byte length of codepoint given first byte of UTF-8 sequence (1-6, 0 if invalid).
fn tb_utf8_char_length(c: i8) -> i32 {
    let uc = c as u8;
    if uc & 0x80 == 0 { return 1; }
    if uc & 0xe0 == 0xc0 { return 2; }
    if uc & 0xf0 == 0xe0 { return 3; }
    if uc & 0xf8 == 0xf0 { return 4; }
    if uc & 0xfc == 0xf8 { return 5; }
    if uc & 0xfe == 0xfc { return 6; }
    return 0;
}

// Decode one UTF-8 character from `c` into `out`.
// Returns byte length (1..4), 0 if `c` is empty, TB_ERR_NEED_MORE if truncated,
// or TB_ERR on invalid/overlong/surrogate/>U+10FFFF sequences.
fn tb_utf8_char_to_unicode(out: u32&, c: const u8[:]) -> i32 {
    if c.len == 0 { return 0; }
    let first = c[0];
    let len = tb_utf8_char_length(first as i8);
    if len <= 0 { return TB_ERR; }
    if len > c.len { return TB_ERR_NEED_MORE; }
    var i: i32 = 1;
    while i < len {
        if c[i] & 0xc0 != 0x80 { return TB_ERR; }
        i = i + 1;
    }
    let v0 = first as u32;
    let value: u32;
    if len == 1 {
        value = v0;
    } else if len == 2 {
        let b1 = c[1] as u32;
        value = ((v0 & 0x1f) << 6) | (b1 & 0x3f);
    } else if len == 3 {
        let b1 = c[1] as u32;
        let b2 = c[2] as u32;
        value = ((v0 & 0x0f) << 12) | ((b1 & 0x3f) << 6) | (b2 & 0x3f);
    } else if len == 4 {
        let b1 = c[1] as u32;
        let b2 = c[2] as u32;
        let b3 = c[3] as u32;
        value = ((v0 & 0x07) << 18) | ((b1 & 0x3f) << 12) | ((b2 & 0x3f) << 6) | (b3 & 0x3f);
    } else {
        return TB_ERR;
    }
    if (len == 2 && value < 0x80) || (len == 3 && value < 0x800) || (len == 4 && value < 0x10000) { return TB_ERR; }
    if value >= 0xd800 && value <= 0xdfff { return TB_ERR; }
    if value > 0x10ffff { return TB_ERR; }
    out = value;
    return len;
}

// Encode Unicode codepoint `c` as UTF-8 into NUL-terminated `out` (returns 1..4 bytes).
// Invalid codepoints (> U+10FFFF or UTF-16 surrogates) encode as U+FFFD.
fn tb_utf8_unicode_to_char(out: u8[7]&, c: u32) -> i32 {
    var len: i32;
    var b0: u8 = 0;
    var b1: u8 = 0;
    var b2: u8 = 0;
    var b3: u8 = 0;
    if c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff) {
        b0 = 0xef; b1 = 0xbf; b2 = 0xbd; len = 3;
    } else if c < 0x80 {
        b0 = c as u8; len = 1;
    } else if c < 0x800 {
        let sh = (c >> 6) as u8;
        b0 = (0xc0 | sh);
        let lo = (c as u8) & 0x3f;
        b1 = (0x80 | lo); len = 2;
    } else if c < 0x10000 {
        let sh12 = (c >> 12) as u8;
        b0 = (0xe0 | sh12);
        let m6 = ((c >> 6) as u8) & 0x3f;
        b1 = (0x80 | m6);
        let lo = (c as u8) & 0x3f;
        b2 = (0x80 | lo); len = 3;
    } else {
        let sh18 = (c >> 18) as u8;
        b0 = (0xf0 | sh18);
        let m12 = ((c >> 12) as u8) & 0x3f;
        b1 = (0x80 | m12);
        let m6 = ((c >> 6) as u8) & 0x3f;
        b2 = (0x80 | m6);
        let lo = (c as u8) & 0x3f;
        b3 = (0x80 | lo); len = 4;
    }
    out[0] = b0;
    if len >= 2 { out[1] = b1; }
    if len >= 3 { out[2] = b2; }
    if len >= 4 { out[3] = b3; }
    out[len] = 0;
    return len;
}

// Return 1 if `ch` is printable (excludes C0/C1 controls, DEL, surrogates, and nonchars).
fn tb_iswprint(ch: u32) -> i32 {
    if ch >= 0x20 && ch <= 0x7e { return 1; }
    if ch < 0x20 { return 0; }
    if ch >= 0x7f && ch <= 0x9f { return 0; }
    if (ch & 0xffff) == 0xfffe || (ch & 0xffff) == 0xffff { return 0; }
    if ch >= 0xa0 && ch <= 0xd7ff { return 1; }
    if ch >= 0xe000 && ch <= 0xfdcf { return 1; }
    if ch >= 0xfdf0 && ch <= 0xfffd { return 1; }
    if ch >= 0x10000 && ch <= 0x10fffd { return 1; }
    return 0;
}

// Return display column width of `ch`: 0 (NUL/combining/ZWJ), 1 (normal), 2 (wide CJK/emoji),
// or -1 (C0/C1 control).
fn tb_wcwidth(ch: u32) -> i32 {
    if ch >= 0x20 && ch <= 0x7e { return 1; }
    if ch >= 0x2500 && ch <= 0x25ff { return 1; }
    if ch == 0 { return 0; }
    if ch < 0x20 || (ch >= 0x7f && ch < 0xa0) { return -1; }

    // Combining marks, format controls (ZWJ/ZWNJ), Hangul Jamo V/T, variation selectors
    if (ch >= 0x0300 && ch <= 0x036f) ||
       (ch >= 0x0483 && ch <= 0x0489) ||
       (ch >= 0x0591 && ch <= 0x05bd) || ch == 0x05bf || ch == 0x05c1 || ch == 0x05c2 ||
       ch == 0x05c4 || ch == 0x05c5 || ch == 0x05c7 ||
       (ch >= 0x0610 && ch <= 0x061a) || (ch >= 0x064b && ch <= 0x065f) || ch == 0x0670 ||
       (ch >= 0x06d6 && ch <= 0x06dc) || (ch >= 0x06df && ch <= 0x06e4) ||
       (ch >= 0x06e7 && ch <= 0x06e8) || (ch >= 0x06ea && ch <= 0x06ed) ||
       (ch >= 0x0900 && ch <= 0x0902) || ch == 0x093c ||
       (ch >= 0x0941 && ch <= 0x0948) || ch == 0x094d ||
       ch == 0x0e31 || (ch >= 0x0e34 && ch <= 0x0e3a) || (ch >= 0x0e47 && ch <= 0x0e4e) ||
       (ch >= 0x1160 && ch <= 0x11ff) ||
       (ch >= 0x1ab0 && ch <= 0x1aff) ||
       (ch >= 0x1dc0 && ch <= 0x1dff) ||
       (ch >= 0x200b && ch <= 0x200f) ||
       (ch >= 0x202a && ch <= 0x202e) ||
       (ch >= 0x2060 && ch <= 0x206f) ||
       (ch >= 0x20d0 && ch <= 0x20ff) ||
       (ch >= 0xd7b0 && ch <= 0xd7ff) ||
       (ch >= 0xfe00 && ch <= 0xfe0f) ||
       (ch >= 0xfe20 && ch <= 0xfe2f) ||
       ch == 0xfeff ||
       (ch >= 0xe0100 && ch <= 0xe01ef) {
        return 0;
    }

    // Wide East Asian, Hangul, symbols & emoji blocks
    if ch >= 0x1100 && (
        ch <= 0x115f ||
        ch == 0x2329 || ch == 0x232a ||
        (ch >= 0x2e80 && ch <= 0xa4cf && ch != 0x303f) ||
        (ch >= 0xa960 && ch <= 0xa97f) ||
        (ch >= 0xac00 && ch <= 0xd7a3) ||
        (ch >= 0xf900 && ch <= 0xfaff) ||
        (ch >= 0xfe10 && ch <= 0xfe19) ||
        (ch >= 0xfe30 && ch <= 0xfe6f) ||
        (ch >= 0xff00 && ch <= 0xff60) ||
        (ch >= 0xffe0 && ch <= 0xffe6) ||
        ch == 0x1f004 || ch == 0x1f0cf || ch == 0x1f18e ||
        (ch >= 0x1f191 && ch <= 0x1f19a) ||
        (ch >= 0x1f1e6 && ch <= 0x1f1ff) ||
        (ch >= 0x1f200 && ch <= 0x1f2ff) ||
        (ch >= 0x1f300 && ch <= 0x1faff) ||
        (ch >= 0x20000 && ch <= 0x3fffd)
    ) {
        return 2;
    }
    return 1;
}

// ===========================================================================
// EGC POOL & CELL BUFFER OPERATIONS
// ===========================================================================

fn egc_free_chain(head: i32) {
    let g = gbl();
    var cur = head;
    while cur >= 0 {
        let nxt = g.egc_pool[cur].next;
        g.egc_pool[cur].ch = 0;
        g.egc_pool[cur].next = g.egc_free_head_p1 - 1;
        g.egc_free_head_p1 = cur + 1;
        cur = nxt;
    }
}

fn egc_alloc_node(ch: u32) -> i32 {
    let g = gbl();
    if g.egc_free_head_p1 > 0 {
        let idx = g.egc_free_head_p1 - 1;
        g.egc_free_head_p1 = g.egc_pool[idx].next + 1;
        g.egc_pool[idx].ch = ch;
        g.egc_pool[idx].next = -1;
        return idx;
    }
    let idx = g.egc_pool.len as i32;
    g.egc_pool.push(egc_node { ch: ch, next: -1 });
    return idx;
}

fn egc_append_back(cell_idx: i32, ch: u32) {
    let g = gbl();
    let new_idx = egc_alloc_node(ch);
    var cur = g.back_ech_head[cell_idx];
    if cur < 0 {
        g.back_ech_head[cell_idx] = new_idx;
        return;
    }
    while g.egc_pool[cur].next >= 0 {
        cur = g.egc_pool[cur].next;
    }
    g.egc_pool[cur].next = new_idx;
}

fn egc_append_front(cell_idx: i32, ch: u32) {
    let g = gbl();
    let new_idx = egc_alloc_node(ch);
    var cur = g.front_ech_head[cell_idx];
    if cur < 0 {
        g.front_ech_head[cell_idx] = new_idx;
        return;
    }
    while g.egc_pool[cur].next >= 0 {
        cur = g.egc_pool[cur].next;
    }
    g.egc_pool[cur].next = new_idx;
}

fn egc_cmp_chains(h1: i32, h2: i32) -> i32 {
    if h1 < 0 && h2 < 0 { return 0; }
    if h1 < 0 || h2 < 0 { return 1; }
    let g = gbl();
    var a = h1;
    var b = h2;
    while a >= 0 && b >= 0 {
        if g.egc_pool[a].ch != g.egc_pool[b].ch { return 1; }
        a = g.egc_pool[a].next;
        b = g.egc_pool[b].next;
    }
    if a >= 0 || b >= 0 { return 1; }
    return 0;
}

fn egc_copy_to_front(front_idx: i32, src_head: i32) {
    let g = gbl();
    if g.front_ech_head[front_idx] >= 0 {
        egc_free_chain(g.front_ech_head[front_idx]);
        g.front_ech_head[front_idx] = -1;
    }
    if src_head < 0 { return; }
    var cur = src_head;
    while cur >= 0 {
        let ch = g.egc_pool[cur].ch;
        egc_append_front(front_idx, ch);
        cur = g.egc_pool[cur].next;
    }
}

// Return current terminal width in columns (updated on init and resize events).
fn tb_width() -> i32 {
    return gbl().width;
}

// Return current terminal height in rows (updated on init and resize events).
fn tb_height() -> i32 {
    return gbl().height;
}

// Set default foreground/background attributes used by subsequent tb_clear() calls.
fn tb_set_clear_attrs(fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    g.fg = fg;
    g.bg = bg;
    return TB_OK;
}

// Fill the entire back buffer with spaces (0x20) using clear attributes and clear any EGC chains.
fn tb_clear() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    let fg = g.fg;
    let bg = g.bg;
    let tot = g.width * g.height;
    var idx = 0;
    while idx < tot {
        g.back.cells[idx].ch = 0x20;
        g.back.cells[idx].fg = fg;
        g.back.cells[idx].bg = bg;
        if g.back_ech_head[idx] >= 0 {
            egc_free_chain(g.back_ech_head[idx]);
            g.back_ech_head[idx] = -1;
        }
        idx = idx + 1;
    }
    return TB_OK;
}

// Write a single Unicode codepoint and attributes to the back buffer at (x, y).
// Returns TB_ERR_OUT_OF_BOUNDS if coordinates lie outside [0..width) x [0..height).
fn tb_set_cell(x: i32, y: i32, ch: u32, fg: uintattr_t, bg: uintattr_t) -> i32 {
    return tb_set_cell_ex(x, y, ch, 1, fg, bg);
}

// Extended cell setter (writes `ch` when `nch > 0`, or space if `nch <= 0`, clearing EGC chains).
// For multi-codepoint grapheme slices in Goose, use tb_set_cell_slice() or tb_extend_cell().
fn tb_set_cell_ex(x: i32, y: i32, ch: const u32&, nch: i64, fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    let idx = y * g.width + x;
    if g.back_ech_head[idx] >= 0 {
        egc_free_chain(g.back_ech_head[idx]);
        g.back_ech_head[idx] = -1;
    }
    // If overwriting the trailing cell of a wide character, clear the orphaned lead cell
    if x > 0 {
        let prev_ch = g.back.cells[idx - 1].ch;
        if prev_ch >= 0x1100 && (prev_ch < 0x2500 || prev_ch > 0x25ff) && tb_wcwidth(prev_ch) == 2 {
            g.back.cells[idx - 1].ch = 0x20;
            if g.back_ech_head[idx - 1] >= 0 {
                egc_free_chain(g.back_ech_head[idx - 1]);
                g.back_ech_head[idx - 1] = -1;
            }
        }
    }
    g.back.cells[idx].ch = if nch > 0 { ch } else { 0x20 };
    g.back.cells[idx].fg = fg;
    g.back.cells[idx].bg = bg;
    return TB_OK;
}

// Goose port helper: write a slice of Unicode codepoints (base + combining marks) at (x, y).
fn tb_set_cell_slice(x: i32, y: i32, chs: const u32[:], fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    if chs.len == 0 {
        return tb_set_cell(x, y, 0x20, fg, bg);
    }
    let rv = tb_set_cell_ex(x, y, chs[0], 1, fg, bg);
    if rv != TB_OK { return rv; }
    let idx = y * g.width + x;
    var i: i64 = 1;
    while i < chs.len {
        egc_append_back(idx, chs[i]);
        i = i + 1;
    }
    return TB_OK;
}

// Append a combining/additional Unicode codepoint to the cell at (x, y) (EGC support).
fn tb_extend_cell(x: i32, y: i32, ch: u32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    let idx = y * g.width + x;
    egc_append_back(idx, ch);
    return TB_OK;
}

// Goose port helper: copy cell at (x, y) from back buffer (`back != 0`) or front buffer.
fn tb_get_cell(x: i32, y: i32, back: i32, cell: tb_cell&) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    let idx = y * g.width + x;
    if back != 0 {
        cell = g.back.cells[idx];
    } else {
        cell = g.front.cells[idx];
    }
    return TB_OK;
}

fn grow_cells(buf: cellbuf&, width: i32, height: i32, is_back: i32) -> i32 {
    let g = gbl();
    let needed = width * height;
    let have = buf.cells.len;
    var ech_cur = if is_back != 0 { g.back_ech_head.len } else { g.front_ech_head.len };
    while ech_cur < needed {
        if is_back != 0 { g.back_ech_head.push(-1); }
        else { g.front_ech_head.push(-1); }
        ech_cur = ech_cur + 1;
    }
    if needed <= have {
        buf.width = width;
        buf.height = height;
        return TB_OK;
    }
    var cur = have;
    while cur < needed {
        buf.cells.push(tb_cell { ch: 0x20, fg: TB_DEFAULT, bg: TB_DEFAULT });
        cur = cur + 1;
    }
    buf.width = width;
    buf.height = height;
    return TB_OK;
}

fn resize_back_cellbuf(new_w: i32, new_h: i32, fg: uintattr_t, bg: uintattr_t) {
    let g = gbl();
    let old_w = g.back.width;
    let old_h = g.back.height;

    if new_h < old_h {
        var ry = new_h;
        while ry < old_h {
            var rx = 0;
            while rx < old_w {
                let ridx = ry * old_w + rx;
                if ridx < g.back_ech_head.len && g.back_ech_head[ridx] >= 0 {
                    egc_free_chain(g.back_ech_head[ridx]);
                    g.back_ech_head[ridx] = -1;
                }
                rx = rx + 1;
            }
            ry = ry + 1;
        }
    }
    let min_w = if old_w < new_w { old_w } else { new_w };
    let min_h = if old_h < new_h { old_h } else { new_h };
    if new_w < old_w {
        var ry = 0;
        for ry in min_h {
            var rx = new_w;
            while rx < old_w {
                let ridx = ry * old_w + rx;
                if ridx < g.back_ech_head.len && g.back_ech_head[ridx] >= 0 {
                    egc_free_chain(g.back_ech_head[ridx]);
                    g.back_ech_head[ridx] = -1;
                }
                rx = rx + 1;
            }
        }
    }

    let _ = grow_cells(g.back, new_w, new_h, 1);

    if new_w < old_w {
        var y = 0;
        for y in min_h {
            var x = 0;
            for x in min_w {
                g.back.cells[y * new_w + x] = g.back.cells[y * old_w + x];
                g.back_ech_head[y * new_w + x] = g.back_ech_head[y * old_w + x];
            }
        }
    } else if new_w > old_w {
        var y = min_h - 1;
        while y >= 0 {
            var x = min_w - 1;
            while x >= 0 {
                g.back.cells[y * new_w + x] = g.back.cells[y * old_w + x];
                g.back_ech_head[y * new_w + x] = g.back_ech_head[y * old_w + x];
                x = x - 1;
            }
            var cx = min_w;
            while cx < new_w {
                let idx = y * new_w + cx;
                g.back.cells[idx].ch = 0x20;
                g.back.cells[idx].fg = fg;
                g.back.cells[idx].bg = bg;
                g.back_ech_head[idx] = -1;
                cx = cx + 1;
            }
            y = y - 1;
        }
    }

    if new_h > old_h {
        var y = old_h;
        while y < new_h {
            var x = 0;
            while x < new_w {
                let idx = y * new_w + x;
                g.back.cells[idx].ch = 0x20;
                g.back.cells[idx].fg = fg;
                g.back.cells[idx].bg = bg;
                g.back_ech_head[idx] = -1;
                x = x + 1;
            }
            y = y + 1;
        }
    }
}

fn reset_cellbuf(buf: cellbuf&, ch: u32, fg: uintattr_t, bg: uintattr_t, is_back: i32) {
    let g = gbl();
    var y = 0;
    for y in buf.height {
        var x = 0;
        for x in buf.width {
            let idx = y * buf.width + x;
            buf.cells[idx].ch = ch;
            buf.cells[idx].fg = fg;
            buf.cells[idx].bg = bg;
            if is_back != 0 {
                if idx < g.back_ech_head.len && g.back_ech_head[idx] >= 0 {
                    egc_free_chain(g.back_ech_head[idx]);
                    g.back_ech_head[idx] = -1;
                }
            } else {
                if idx < g.front_ech_head.len && g.front_ech_head[idx] >= 0 {
                    egc_free_chain(g.front_ech_head[idx]);
                    g.front_ech_head[idx] = -1;
                }
            }
        }
    }
}

// ===========================================================================
// TERMINFO LOADER & BUILT-IN CAPABILITY TABLES
// ===========================================================================

const xterm_caps: const u8[:][TB_CAP__COUNT] = [
    "\x1bOP",      // kf1
    "\x1bOQ",      // kf2
    "\x1bOR",      // kf3
    "\x1bOS",      // kf4
    "\x1b[15~",    // kf5
    "\x1b[17~",    // kf6
    "\x1b[18~",    // kf7
    "\x1b[19~",    // kf8
    "\x1b[20~",    // kf9
    "\x1b[21~",    // kf10
    "\x1b[23~",    // kf11
    "\x1b[24~",    // kf12
    "\x1b[2~",     // kich1
    "\x1b[3~",     // kdch1
    "\x1bOH",      // khome
    "\x1bOF",      // kend
    "\x1b[5~",     // kpp
    "\x1b[6~",     // knp
    "\x1bOA",      // kcuu1
    "\x1bOB",      // kcud1
    "\x1bOD",      // kcub1
    "\x1bOC",      // kcuf1
    "\x1b[Z",      // kcbt
    "\x1b[?1049h\x1b[22;0;0t",  // smcup
    "\x1b[?1049l\x1b[23;0;0t",  // rmcup
    "\x1b[?12l\x1b[?25h",       // cnorm
    "\x1b[?25l",                // civis
    "\x1b[H\x1b[2J",            // clear
    "\x1b(B\x1b[m",             // sgr0
    "\x1b[4m",                  // smul
    "\x1b[1m",                  // bold
    "\x1b[5m",                  // blink
    "\x1b[3m",                  // sitm
    "\x1b[7m",                  // rev
    "\x1b[?1h\x1b=",            // smkx
    "\x1b[?1l\x1b>",            // rmkx
    "\x1b[2m",                  // dim
    "\x1b[8m",                  // invis
];

const screen_caps: const u8[:][TB_CAP__COUNT] = [
    "\x1bOP",      // kf1
    "\x1bOQ",      // kf2
    "\x1bOR",      // kf3
    "\x1bOS",      // kf4
    "\x1b[15~",    // kf5
    "\x1b[17~",    // kf6
    "\x1b[18~",    // kf7
    "\x1b[19~",    // kf8
    "\x1b[20~",    // kf9
    "\x1b[21~",    // kf10
    "\x1b[23~",    // kf11
    "\x1b[24~",    // kf12
    "\x1b[2~",     // kich1
    "\x1b[3~",     // kdch1
    "\x1b[1~",     // khome
    "\x1b[4~",     // kend
    "\x1b[5~",     // kpp
    "\x1b[6~",     // knp
    "\x1bOA",      // kcuu1
    "\x1bOB",      // kcud1
    "\x1bOD",      // kcub1
    "\x1bOC",      // kcuf1
    "\x1b[Z",      // kcbt
    "\x1b[?1049h", // smcup
    "\x1b[?1049l", // rmcup
    "\x1b[34h\x1b[?25h", // cnorm
    "\x1b[?25l",         // civis
    "\x1b[H\x1b[J",      // clear
    "\x1b[m\x0f",        // sgr0
    "\x1b[4m",           // smul
    "\x1b[1m",           // bold
    "\x1b[5m",           // blink
    "\x1b[3m",           // sitm
    "\x1b[7m",           // rev
    "\x1b[?1h\x1b=",     // smkx
    "\x1b[?1l\x1b>",     // rmkx
    "\x1b[2m",           // dim
    "\x1b[8m",           // invis
];

const rxvt_caps: const u8[:][TB_CAP__COUNT] = [
    "\x1b[11~",    // kf1
    "\x1b[12~",    // kf2
    "\x1b[13~",    // kf3
    "\x1b[14~",    // kf4
    "\x1b[15~",    // kf5
    "\x1b[17~",    // kf6
    "\x1b[18~",    // kf7
    "\x1b[19~",    // kf8
    "\x1b[20~",    // kf9
    "\x1b[21~",    // kf10
    "\x1b[23~",    // kf11
    "\x1b[24~",    // kf12
    "\x1b[2~",     // kich1
    "\x1b[3~",     // kdch1
    "\x1b[7~",     // khome
    "\x1b[8~",     // kend
    "\x1b[5~",     // kpp
    "\x1b[6~",     // knp
    "\x1b[A",      // kcuu1
    "\x1b[B",      // kcud1
    "\x1b[D",      // kcub1
    "\x1b[C",      // kcuf1
    "\x1b[Z",      // kcbt
    "\x1b7\x1b[?47h",       // smcup
    "\x1b[2J\x1b[?47l\x1b8",// rmcup
    "\x1b[?25h",            // cnorm
    "\x1b[?25l",            // civis
    "\x1b[H\x1b[2J",        // clear
    "\x1b[m\x0f",           // sgr0
    "\x1b[4m",              // smul
    "\x1b[1m",              // bold
    "\x1b[5m",              // blink
    "\x1b[3m",              // sitm
    "\x1b[7m",              // rev
    "\x1b=",                // smkx
    "\x1b>",                // rmkx
    "\x1b[2m",              // dim
    "\x1b[8m",              // invis
];

const linux_caps: const u8[:][TB_CAP__COUNT] = [
    "\x1b[[A",      // kf1
    "\x1b[[B",      // kf2
    "\x1b[[C",      // kf3
    "\x1b[[D",      // kf4
    "\x1b[[E",      // kf5
    "\x1b[17~",     // kf6
    "\x1b[18~",     // kf7
    "\x1b[19~",     // kf8
    "\x1b[20~",     // kf9
    "\x1b[21~",     // kf10
    "\x1b[23~",     // kf11
    "\x1b[24~",     // kf12
    "\x1b[2~",      // kich1
    "\x1b[3~",      // kdch1
    "\x1b[1~",      // khome
    "\x1b[4~",      // kend
    "\x1b[5~",      // kpp
    "\x1b[6~",      // knp
    "\x1b[A",       // kcuu1
    "\x1b[B",       // kcud1
    "\x1b[D",       // kcub1
    "\x1b[C",       // kcuf1
    "\x1b\x09",     // kcbt
    "",             // smcup
    "",             // rmcup
    "\x1b[?25h\x1b[?0c",  // cnorm
    "\x1b[?25l\x1b[?1c",  // civis
    "\x1b[H\x1b[J",       // clear
    "\x1b[m\x0f",         // sgr0
    "\x1b[4m",            // smul
    "\x1b[1m",            // bold
    "\x1b[5m",            // blink
    "",                   // sitm
    "\x1b[7m",            // rev
    "",                   // smkx
    "",                   // rmkx
    "\x1b[2m",            // dim
    "",                   // invis
];

// SVr4 / ncurses binary terminfo string capability table indices for TB_CAP_* 0..37
const ti_str_indices: i32[TB_CAP__COUNT] = [
    66,  // TB_CAP_F1 (kf1)
    68,  // TB_CAP_F2 (kf2)
    69,  // TB_CAP_F3 (kf3)
    70,  // TB_CAP_F4 (kf4)
    71,  // TB_CAP_F5 (kf5)
    72,  // TB_CAP_F6 (kf6)
    73,  // TB_CAP_F7 (kf7)
    74,  // TB_CAP_F8 (kf8)
    75,  // TB_CAP_F9 (kf9)
    67,  // TB_CAP_F10 (kf10)
    216, // TB_CAP_F11 (kf11)
    217, // TB_CAP_F12 (kf12)
    77,  // TB_CAP_INSERT (kich1)
    59,  // TB_CAP_DELETE (kdch1)
    76,  // TB_CAP_HOME (khome)
    164, // TB_CAP_END (kend)
    82,  // TB_CAP_PGUP (kpp)
    81,  // TB_CAP_PGDN (knp)
    87,  // TB_CAP_ARROW_UP (kcuu1)
    61,  // TB_CAP_ARROW_DOWN (kcud1)
    79,  // TB_CAP_ARROW_LEFT (kcub1)
    83,  // TB_CAP_ARROW_RIGHT (kcuf1)
    148, // TB_CAP_BACK_TAB (kcbt)
    28,  // TB_CAP_ENTER_CA (smcup)
    40,  // TB_CAP_EXIT_CA (rmcup)
    16,  // TB_CAP_SHOW_CURSOR (cnorm)
    13,  // TB_CAP_HIDE_CURSOR (civis)
    5,   // TB_CAP_CLEAR_SCREEN (clear)
    39,  // TB_CAP_SGR0 (sgr0)
    36,  // TB_CAP_UNDERLINE (smul)
    27,  // TB_CAP_BOLD (bold)
    26,  // TB_CAP_BLINK (blink)
    311, // TB_CAP_ITALIC (sitm)
    34,  // TB_CAP_REVERSE (rev)
    89,  // TB_CAP_ENTER_KEYPAD (smkx)
    88,  // TB_CAP_EXIT_KEYPAD (rmkx)
    30,  // TB_CAP_DIM (dim)
    32,  // TB_CAP_INVISIBLE (invis)
];

struct term_entry {
    name: const u8[:],
    caps: const u8[:][TB_CAP__COUNT],
    alias: const u8[:],
}

const builtin_terms: term_entry[10] = [
    term_entry { name: "xterm",         caps: xterm_caps,  alias: "alacritty" },
    term_entry { name: "foot",          caps: xterm_caps,  alias: "kitty" },
    term_entry { name: "wezterm",       caps: xterm_caps,  alias: "ghostty" },
    term_entry { name: "gnome",         caps: xterm_caps,  alias: "vte" },
    term_entry { name: "screen",        caps: screen_caps, alias: "tmux" },
    term_entry { name: "rxvt-256color", caps: rxvt_caps,   alias: "rxvt-unicode" },
    term_entry { name: "rxvt",          caps: rxvt_caps,   alias: "" },
    term_entry { name: "Eterm",         caps: rxvt_caps,   alias: "" },
    term_entry { name: "eterm",         caps: rxvt_caps,   alias: "" },
    term_entry { name: "linux",         caps: linux_caps,  alias: "" },
];

fn str_starts_with(haystack: const u8[:], prefix: const u8[:]) -> i32 {
    if prefix.len == 0 || haystack.len < prefix.len { return 0; }
    var i = 0;
    for i in prefix.len {
        if haystack[i] != prefix[i] { return 0; }
    }
    return 1;
}

fn str_equals(a: const u8[:], b: const u8[:]) -> i32 {
    if a.len != b.len { return 0; }
    var i = 0;
    for i in a.len {
        if a[i] != b[i] { return 0; }
    }
    return 1;
}

fn find_builtin_term(name: const u8[:]) -> i32 {
    var i = 0;
    for i in builtin_terms.len {
        if str_equals(builtin_terms[i].name, name) != 0 {
            return i as i32;
        }
        if builtin_terms[i].alias.len > 0 && str_equals(builtin_terms[i].alias, name) != 0 {
            return i as i32;
        }
    }
    return -1;
}

fn read_le_i16(buf: const u8[:], off: i64) -> i32 {
    let lo = buf[off] as i32;
    let hi = (buf[off + 1] as i8) as i32;
    return (hi << 8) | lo;
}

fn read_le_u16(buf: const u8[:], off: i64) -> i32 {
    let lo = buf[off] as i32;
    let hi = buf[off + 1] as i32;
    return (hi << 8) | lo;
}

fn hex_nibble(v: u8) -> u8 {
    if v < 10 { return 0x30 + v; }
    return 0x61 + (v - 10);
}

fn try_read_terminfo_path(dir: const u8[:], suffix: const u8[:], term: const u8[:], use_hex: i32) -> i64 {
    if dir.len == 0 || term.len == 0 { return -1; }
    var pathbuf: u8[TB_PATH_MAX] = [0; TB_PATH_MAX];
    var pos: i32 = 0;
    var i: i64 = 0;
    while i < dir.len && pos < TB_PATH_MAX - 16 {
        pathbuf[pos] = dir[i];
        pos = pos + 1;
        i = i + 1;
    }
    i = 0;
    while i < suffix.len && pos < TB_PATH_MAX - 16 {
        pathbuf[pos] = suffix[i];
        pos = pos + 1;
        i = i + 1;
    }
    if pos >= TB_PATH_MAX - 8 { return -1; }
    pathbuf[pos] = '/';
    pos = pos + 1;
    if use_hex != 0 {
        let ch = term[0];
        pathbuf[pos] = hex_nibble((ch >> 4) & 0x0f);
        pathbuf[pos + 1] = hex_nibble(ch & 0x0f);
        pos = pos + 2;
    } else {
        pathbuf[pos] = term[0];
        pos = pos + 1;
    }
    pathbuf[pos] = '/';
    pos = pos + 1;
    i = 0;
    while i < term.len && pos < TB_PATH_MAX - 1 {
        pathbuf[pos] = term[i];
        pos = pos + 1;
        i = i + 1;
    }
    pathbuf[pos] = 0;

    var fbuf: u8[32768] = [0; 32768];
    let n = tb_adapter_read_file(pathbuf[0], fbuf[0], 32768);
    if n < 12 { return -1; }

    let g = gbl();
    var j: i64 = 0;
    while j < n {
        if j < g.terminfo.len {
            g.terminfo[j as i32] = fbuf[j];
        } else {
            g.terminfo.push(fbuf[j]);
        }
        j = j + 1;
    }
    g.nterminfo = n;
    return n;
}

fn get_env_var(name: const u8[:], envbuf: u8[1024]&) -> i32 {
    var nbuf: u8[64] = [0; 64];
    var i: i64 = 0;
    while i < name.len && i < 63 {
        nbuf[i] = name[i];
        i = i + 1;
    }
    nbuf[i] = 0;
    return tb_adapter_getenv(nbuf[0], envbuf[0], 1024);
}

fn load_terminfo_file(term: const u8[:]) -> i64 {
    var envbuf: u8[1024] = [0; 1024];

    // 1) $TERMINFO
    let ti_len = get_env_var("TERMINFO", envbuf);
    if ti_len > 0 {
        let n = try_read_terminfo_path(envbuf[0..ti_len], "", term, 0);
        if n >= 12 { return n; }
        let n2 = try_read_terminfo_path(envbuf[0..ti_len], "", term, 1);
        if n2 >= 12 { return n2; }
    }

    // 2) $HOME/.terminfo
    let home_len = get_env_var("HOME", envbuf);
    if home_len > 0 {
        let n = try_read_terminfo_path(envbuf[0..home_len], "/.terminfo", term, 0);
        if n >= 12 { return n; }
        let n2 = try_read_terminfo_path(envbuf[0..home_len], "/.terminfo", term, 1);
        if n2 >= 12 { return n2; }
    }
    // 2b) %USERPROFILE%/.terminfo (Windows)
    let up_len = get_env_var("USERPROFILE", envbuf);
    if up_len > 0 {
        let n = try_read_terminfo_path(envbuf[0..up_len], "/.terminfo", term, 0);
        if n >= 12 { return n; }
        let n2 = try_read_terminfo_path(envbuf[0..up_len], "/.terminfo", term, 1);
        if n2 >= 12 { return n2; }
    }

    // 3) $PREFIX/share/terminfo (Termux)
    let pfx_len = get_env_var("PREFIX", envbuf);
    if pfx_len > 0 {
        let n = try_read_terminfo_path(envbuf[0..pfx_len], "/share/terminfo", term, 0);
        if n >= 12 { return n; }
    }

    // 4) Standard system terminfo directories
    let dirs: const u8[:][3] = ["/etc/terminfo", "/lib/terminfo", "/usr/share/terminfo"];
    var di = 0;
    for di in 3 {
        let n = try_read_terminfo_path(dirs[di], "", term, 0);
        if n >= 12 { return n; }
        let n2 = try_read_terminfo_path(dirs[di], "", term, 1);
        if n2 >= 12 { return n2; }
    }

    return -1;
}

fn parse_terminfo_caps() -> i32 {
    let g = gbl();
    if g.nterminfo < 12 { return TB_ERR; }
    let ti = g.terminfo[0..g.nterminfo];
    let magic = read_le_u16(ti, 0);
    if magic != 0x011a && magic != 0x021e {
        return TB_ERR;
    }
    let num_size: i64 = if magic == 0x021e { 4 } else { 2 };
    let sz_names = read_le_i16(ti, 2) as i64;
    let n_bools  = read_le_i16(ti, 4) as i64;
    let n_nums   = read_le_i16(ti, 6) as i64;
    let n_strs   = read_le_i16(ti, 8) as i64;
    let sz_str   = read_le_i16(ti, 10) as i64;

    if sz_names < 0 || n_bools < 0 || n_nums < 0 || n_strs < 0 || sz_str < 0 {
        return TB_ERR;
    }

    var str_off_pos: i64 = 12 + sz_names + n_bools;
    if (str_off_pos % 2) != 0 {
        str_off_pos = str_off_pos + 1;
    }
    str_off_pos = str_off_pos + n_nums * num_size;
    let strtab_pos = str_off_pos + n_strs * 2;
    if strtab_pos + sz_str > g.nterminfo {
        return TB_ERR;
    }

    var ci = 0;
    for ci in TB_CAP__COUNT {
        let ti_idx = ti_str_indices[ci] as i64;
        if ti_idx >= n_strs {
            g.caps[ci] = "";
            continue;
        }
        let str_off = read_le_i16(ti, str_off_pos + ti_idx * 2) as i64;
        if str_off < 0 || str_off >= sz_str {
            g.caps[ci] = "";
            continue;
        }
        let start = strtab_pos + str_off;
        var end = start;
        let max_end = strtab_pos + sz_str;
        while end < max_end && g.terminfo[end] != 0 {
            end = end + 1;
        }
        if end > start {
            // Do not mutate g.terminfo after taking slices into it.
            g.caps[ci] = g.terminfo[start..end];
        } else {
            g.caps[ci] = "";
        }
    }
    return TB_OK;
}

// ===========================================================================
// TTY INITIALIZATION & SHUTDOWN
// ===========================================================================

fn cleanup_partial_init() {
    let g = gbl();
    let _ = tb_adapter_clear_signwinch();
    if g.has_orig_tios != 0 {
        let _ = tb_adapter_restore_termios(g.rfd);
        g.has_orig_tios = 0;
    }
    if g.has_orig_rfd_flags != 0 {
        let _ = tb_adapter_restore_fd_flags(g.rfd, g.orig_rfd_flags);
        g.has_orig_rfd_flags = 0;
    }
    if g.has_resize_pipe != 0 {
        let _ = tb_adapter_close(g.resize_pipefd[0]);
        let _ = tb_adapter_close(g.resize_pipefd[1]);
        g.resize_pipefd[0] = -1;
        g.resize_pipefd[1] = -1;
        g.has_resize_pipe = 0;
    }
    if g.ttyfd_open != 0 && g.fd_owned != 0 {
        let _ = tb_adapter_close(g.ttyfd);
    }
    g.ttyfd_open = 0;
    g.fd_owned = 0;
    g.rfd_is_tty = 0;
    g.initialized = 0;
}

// Open `/dev/tty`, enter raw mode, detect TERM capabilities, install SIGWINCH,
// switch to alternate screen, enable keypad transmit mode, and hide cursor.
fn tb_init() -> i32 {
    return tb_init_file("/dev/tty");
}

// Initialize termbox2 on the given TTY device path (fails with TB_ERR_INIT_ALREADY if open).
fn tb_init_file(path: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized == 0 else { return TB_ERR_INIT_ALREADY; }

    var pathbuf: u8[>..] = [];
    var i = 0;
    for i in path.len { pathbuf.push(path[i]); }
    pathbuf.push(0);

    let fd = tb_adapter_open_tty_rw(pathbuf[0]);
    guard fd >= 0 else { return TB_ERR_INIT_OPEN; }

    g.fd_owned = 1;
    let rv = tb_init_fd(fd);
    if rv != TB_OK {
        g.fd_owned = 0;
    }
    return rv;
}

// Initialize termbox2 using an existing open TTY file descriptor (caller retains ownership).
fn tb_init_fd(ttyfd: i32) -> i32 {
    return tb_init_rwfd(ttyfd, ttyfd);
}

// Initialize termbox2 using separate read/write file descriptors.
// Returns TB_ERR_INIT_ALREADY if already initialized. Supports both TTY and non-TTY pipe fds.
fn tb_init_rwfd(rfd: i32, wfd: i32) -> i32 {
    let g = gbl();
    guard g.initialized == 0 else { return TB_ERR_INIT_ALREADY; }

    if rfd < 0 || wfd < 0 {
        return TB_ERR_INIT_OPEN;
    }

    g.ttyfd = rfd;
    g.rfd = rfd;
    g.wfd = wfd;
    g.ttyfd_open = 1;
    g.has_resize_pipe = 0;
    g.resize_pipefd[0] = -1;
    g.resize_pipefd[1] = -1;
    g.has_orig_tios = 0;
    g.has_orig_rfd_flags = 0;
    g.last_errno = 0;
    g.caps = xterm_caps;
    g.nterminfo = 0;
    g.rfd_is_tty = tb_adapter_isatty(rfd);

    if g.rfd_is_tty != 0 {
        if tb_adapter_save_termios(rfd) != 0 {
            g.last_errno = tb_adapter_errno();
            cleanup_partial_init();
            return TB_ERR_TCGETATTR;
        }
        g.has_orig_tios = 1;
    }

    var orig_fl: i32 = 0;
    if tb_adapter_save_and_set_nonblock(rfd, orig_fl) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_READ;
    }
    g.orig_rfd_flags = orig_fl;
    g.has_orig_rfd_flags = 1;

    if g.rfd_is_tty != 0 {
        if tb_adapter_set_raw_mode(rfd) != 0 {
            g.last_errno = tb_adapter_errno();
            cleanup_partial_init();
            return TB_ERR_TCSETATTR;
        }
    }

    var pipefd: i32[2] = [-1, -1];
    if tb_adapter_pipe(pipefd) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_RESIZE_PIPE;
    }
    g.resize_pipefd[0] = pipefd[0];
    g.resize_pipefd[1] = pipefd[1];
    g.has_resize_pipe = 1;

    var w: i32 = 0;
    var h: i32 = 0;
    if tb_adapter_get_winsize(wfd, w, h) != 0 {
        if tb_adapter_get_winsize(rfd, w, h) != 0 {
            if g.rfd_is_tty != 0 {
                g.last_errno = tb_adapter_errno();
                cleanup_partial_init();
                return TB_ERR_RESIZE_IOCTL;
            }
            // Non-TTY pipe fallback dimensions (matches upstream termbox2.h)
            w = 80;
            h = 24;
        }
    }
    if !(w > 0 && h > 0) {
        if g.rfd_is_tty == 0 {
            w = 80;
            h = 24;
        } else {
            cleanup_partial_init();
            return TB_ERR_RESIZE_IOCTL;
        }
    }
    g.width = w;
    g.height = h;

    // Terminal capability detection: require TERM, try binary terminfo first, then builtin_terms
    var term_name: u8[64] = [0; 64];
    let rv = tb_adapter_get_term(term_name[0], 64);
    if rv <= 0 {
        cleanup_partial_init();
        return TB_ERR_NO_TERM;
    }
    let tslice = term_name[0..rv];

    g.term_index = -1;
    var loaded_ti: i32 = 0;
    if load_terminfo_file(tslice) >= 12 {
        if parse_terminfo_caps() == TB_OK {
            loaded_ti = 1;
        }
    }

    if loaded_ti == 0 {
        let term_idx = find_builtin_term(tslice);
        if term_idx >= 0 {
            g.term_index = term_idx;
        } else {
            var i: i32 = 0;
            for i in builtin_terms.len {
                let entry = builtin_terms[i];
                if str_starts_with(tslice, entry.name) != 0 ||
                   str_starts_with(tslice, entry.alias) != 0 {
                    g.term_index = i as i32;
                    break;
                }
            }
        }
        if g.term_index < 0 {
            cleanup_partial_init();
            return TB_ERR_UNSUPPORTED_TERM;
        }
        g.caps = builtin_terms[g.term_index].caps;
    }

    let _ = cap_trie_build();

    let _ = grow_cells(g.back, g.width, g.height, 1);
    let _ = grow_cells(g.front, g.width, g.height, 0);
    reset_cellbuf(g.back, 0x20, TB_DEFAULT, TB_DEFAULT, 1);
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0);

    if tb_adapter_setup_signwinch(g.resize_pipefd[1]) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_RESIZE_SIGACTION;
    }

    g.input_mode = TB_INPUT_ESC;
    g.output_mode = TB_OUTPUT_NORMAL;
    g.fg = TB_DEFAULT;
    g.bg = TB_DEFAULT;
    g.last_fg = 0xffffffffffffffff;
    g.last_bg = 0xffffffffffffffff;
    g.inbuf_pos = 0;
    g.inbuf_len = 0;
    g.outbuf_len = 0;
    g.cursor_x = -1;
    g.cursor_y = -1;
    g.cursor_hidden = 1;
    g.last_x = -1;
    g.last_y = -1;
    g.initialized = 1;

    if g.caps[TB_CAP_ENTER_CA].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_ENTER_CA]); }
    if g.caps[TB_CAP_ENTER_KEYPAD].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_ENTER_KEYPAD]); }
    if g.caps[TB_CAP_HIDE_CURSOR].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_HIDE_CURSOR]); }
    if g.caps[TB_CAP_CLEAR_SCREEN].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_CLEAR_SCREEN]); }
    let _ = outbuf_flush(g.wfd);

    return TB_OK;
}

// Disable mouse tracking, show cursor, reset SGR/keypad/alt-screen, clear SIGWINCH,
// restore saved termios & fd flags, release buffers, and close owned file descriptors.
fn tb_shutdown() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    if (g.input_mode & TB_INPUT_MOUSE) != 0 {
        let _ = outbuf_puts(TB_HARDCAP_EXIT_MOUSE);
    }
    if g.caps[TB_CAP_SHOW_CURSOR].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_SHOW_CURSOR]); }
    if g.caps[TB_CAP_SGR0].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_SGR0]); }
    if g.caps[TB_CAP_EXIT_KEYPAD].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_EXIT_KEYPAD]); }
    if g.caps[TB_CAP_EXIT_CA].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_EXIT_CA]); }
    let _ = outbuf_flush(g.wfd);

    let _ = tb_adapter_clear_signwinch();

    if g.has_orig_tios != 0 {
        let _ = tb_adapter_restore_termios(g.rfd);
        g.has_orig_tios = 0;
    }

    if g.has_orig_rfd_flags != 0 {
        let _ = tb_adapter_restore_fd_flags(g.rfd, g.orig_rfd_flags);
        g.has_orig_rfd_flags = 0;
    }

    if g.ttyfd_open != 0 && g.fd_owned != 0 {
        let _ = tb_adapter_close(g.ttyfd);
    }
    if g.has_resize_pipe != 0 {
        let _ = tb_adapter_close(g.resize_pipefd[0]);
        let _ = tb_adapter_close(g.resize_pipefd[1]);
        g.resize_pipefd[0] = -1;
        g.resize_pipefd[1] = -1;
        g.has_resize_pipe = 0;
    }

    reset_cellbuf(g.back, 0x20, TB_DEFAULT, TB_DEFAULT, 1);
    reset_cellbuf(g.front, 0x20, TB_DEFAULT, TB_DEFAULT, 0);
    g.caps = xterm_caps;
    g.cap_trie_len = 0;
    g.cap_trie_root = 0;
    g.inbuf_pos = 0;
    g.inbuf_len = 0;
    g.outbuf_len = 0;
    g.nterminfo = 0;

    g.initialized = 0;
    g.ttyfd_open = 0;
    g.fd_owned = 0;
    g.rfd_is_tty = 0;
    return TB_OK;
}

// ===========================================================================
// INFO & ERROR HELPERS
// ===========================================================================

// Return 1 if 24-bit truecolor output is supported by this build (always 1).
fn tb_has_truecolor() -> i32 {
    return 1;
}

// Return 1 if Extended Grapheme Cluster support is enabled (1 in this port).
fn tb_has_egc() -> i32 {
    return TB_OPT_EGC;
}

// Return bit width of uintattr_t (64 in this port).
fn tb_attr_width() -> i32 {
    return TB_OPT_ATTR_W;
}

// Return the library version string.
fn tb_version() -> const u8[:] {
    return TB_VERSION_STR;
}

// Return the last POSIX errno recorded by adapter calls.
fn tb_last_errno() -> i32 {
    return gbl().last_errno;
}

// Return a human-readable description for a TB_ERR_* return code.
fn tb_strerror(err: i32) -> const u8[:] {
    if err == TB_OK { return "termbox2 ok"; }
    if err == TB_ERR { return "termbox2 error"; }
    if err == TB_ERR_NEED_MORE { return "termbox2 needs more data"; }
    if err == TB_ERR_INIT_ALREADY { return "termbox2 already initialized"; }
    if err == TB_ERR_INIT_OPEN { return "termbox2 cannot open terminal"; }
    if err == TB_ERR_MEM { return "termbox2 out of memory"; }
    if err == TB_ERR_NO_EVENT { return "termbox2 no event"; }
    if err == TB_ERR_NO_TERM { return "termbox2 no terminal"; }
    if err == TB_ERR_NOT_INIT { return "termbox2 not initialized"; }
    if err == TB_ERR_OUT_OF_BOUNDS { return "termbox2 out of bounds"; }
    if err == TB_ERR_READ { return "termbox2 read error"; }
    if err == TB_ERR_RESIZE_IOCTL { return "termbox2 resize ioctl error"; }
    if err == TB_ERR_RESIZE_PIPE { return "termbox2 resize pipe error"; }
    if err == TB_ERR_RESIZE_SIGACTION { return "termbox2 resize sigaction error"; }
    if err == TB_ERR_POLL { return "termbox2 poll error"; }
    if err == TB_ERR_TCGETATTR { return "termbox2 tcgetattr error"; }
    if err == TB_ERR_TCSETATTR { return "termbox2 tcsetattr error"; }
    if err == TB_ERR_UNSUPPORTED_TERM { return "termbox2 unsupported terminal"; }
    if err == TB_ERR_RESIZE_WRITE { return "termbox2 resize write error"; }
    if err == TB_ERR_RESIZE_POLL { return "termbox2 resize poll error"; }
    if err == TB_ERR_RESIZE_READ { return "termbox2 resize read error"; }
    if err == TB_ERR_RESIZE_SSCANF { return "termbox2 resize sscanf error"; }
    if err == TB_ERR_CAP_COLLISION { return "termbox2 capability collision"; }
    return "termbox2 unknown error";
}

// ===========================================================================
// ESCAPE SEQUENCE PARSER (CAP TRIE + CSI + KITTY + OSC + MOUSE) & POLLING
// ===========================================================================

fn cap_trie_add_node(c: u8) -> i32 {
    let g = gbl();
    let idx = g.cap_trie_len;
    if idx < g.cap_trie.len {
        g.cap_trie[idx].c = c;
        g.cap_trie[idx].first_child = -1;
        g.cap_trie[idx].next_sibling = -1;
        g.cap_trie[idx].is_leaf = 0;
        g.cap_trie[idx].key = 0;
        g.cap_trie[idx].mod = 0;
    } else {
        g.cap_trie.push(cap_trie_node {
            c: c,
            first_child: -1,
            next_sibling: -1,
            is_leaf: 0,
            key: 0,
            mod: 0,
        });
    }
    g.cap_trie_len = idx + 1;
    return idx;
}

fn cap_trie_find_child(node: i32, c: u8) -> i32 {
    let g = gbl();
    var cur = g.cap_trie[node].first_child;
    while cur >= 0 {
        if g.cap_trie[cur].c == c {
            return cur;
        }
        cur = g.cap_trie[cur].next_sibling;
    }
    return -1;
}

fn cap_trie_add_child(node: i32, c: u8) -> i32 {
    let existing = cap_trie_find_child(node, c);
    if existing >= 0 { return existing; }
    let new_idx = cap_trie_add_node(c);
    let g = gbl();
    let old_first = g.cap_trie[node].first_child;
    g.cap_trie[new_idx].next_sibling = old_first;
    g.cap_trie[node].first_child = new_idx;
    return new_idx;
}

fn cap_trie_insert_seq(seq: const u8[:], key_code: u16, mod_val: u8) {
    if seq.len == 0 { return; }
    let g = gbl();
    var node = g.cap_trie_root;
    var si = 0;
    for si in seq.len {
        node = cap_trie_add_child(node, seq[si]);
    }
    if g.cap_trie[node].is_leaf == 0 {
        g.cap_trie[node].is_leaf = 1;
        g.cap_trie[node].key = key_code;
        g.cap_trie[node].mod = mod_val;
    }
}

fn cap_trie_build() -> i32 {
    let g = gbl();
    g.cap_trie_len = 0;
    g.cap_trie_root = cap_trie_add_node(0);

    // 1) Active terminal's key capabilities take priority
    var ci = 0;
    for ci in TB_CAP__COUNT_KEYS {
        cap_trie_insert_seq(g.caps[ci], (0xffff - ci) as u16, 0);
    }

    // 2) Standard CSI/SS3/rxvt sequences
    cap_trie_insert_seq("\x1b[A", TB_KEY_ARROW_UP, 0);
    cap_trie_insert_seq("\x1b[B", TB_KEY_ARROW_DOWN, 0);
    cap_trie_insert_seq("\x1b[C", TB_KEY_ARROW_RIGHT, 0);
    cap_trie_insert_seq("\x1b[D", TB_KEY_ARROW_LEFT, 0);
    cap_trie_insert_seq("\x1b[H", TB_KEY_HOME, 0);
    cap_trie_insert_seq("\x1b[F", TB_KEY_END, 0);
    cap_trie_insert_seq("\x1b[Z", TB_KEY_BACK_TAB, 0);
    cap_trie_insert_seq("\x1b[a", TB_KEY_ARROW_UP, TB_MOD_SHIFT);
    cap_trie_insert_seq("\x1b[b", TB_KEY_ARROW_DOWN, TB_MOD_SHIFT);
    cap_trie_insert_seq("\x1b[c", TB_KEY_ARROW_RIGHT, TB_MOD_SHIFT);
    cap_trie_insert_seq("\x1b[d", TB_KEY_ARROW_LEFT, TB_MOD_SHIFT);
    cap_trie_insert_seq("\x1bOa", TB_KEY_ARROW_UP, TB_MOD_CTRL);
    cap_trie_insert_seq("\x1bOb", TB_KEY_ARROW_DOWN, TB_MOD_CTRL);
    cap_trie_insert_seq("\x1bOc", TB_KEY_ARROW_RIGHT, TB_MOD_CTRL);
    cap_trie_insert_seq("\x1bOd", TB_KEY_ARROW_LEFT, TB_MOD_CTRL);

    // 3) Fallback built-in terminal caps
    var ti = 0;
    for ti in builtin_terms.len {
        let entry = builtin_terms[ti];
        var ci2 = 0;
        for ci2 in TB_CAP__COUNT_KEYS {
            cap_trie_insert_seq(entry.caps[ci2], (0xffff - ci2) as u16, 0);
        }
    }

    return TB_OK;
}

fn xterm_mod_to_tb(m: i32) -> u8 {
    let bits = m - 1;
    var mod_out: u8 = 0;
    if (bits & 1) != 0 { mod_out = mod_out | TB_MOD_SHIFT; }
    if (bits & 2) != 0 { mod_out = mod_out | TB_MOD_ALT; }
    if (bits & 4) != 0 { mod_out = mod_out | TB_MOD_CTRL; }
    return mod_out;
}

fn apply_mouse_btn(event: tb_event&, cb: i32, is_release: i32) {
    event.mod = 0;
    if (cb & 4) != 0 { event.mod = event.mod | TB_MOD_SHIFT; }
    if (cb & 8) != 0 { event.mod = event.mod | TB_MOD_ALT; }
    if (cb & 16) != 0 { event.mod = event.mod | TB_MOD_CTRL; }
    if (cb & 32) != 0 { event.mod = event.mod | TB_MOD_MOTION; }
    event.ch = 0;

    if is_release != 0 {
        event.key = TB_KEY_MOUSE_RELEASE;
        return;
    }
    if (cb & 64) != 0 {
        if (cb & 1) != 0 {
            event.key = TB_KEY_MOUSE_WHEEL_DOWN;
        } else {
            event.key = TB_KEY_MOUSE_WHEEL_UP;
        }
        return;
    }
    let btn = cb & 3;
    if btn == 0 { event.key = TB_KEY_MOUSE_LEFT; }
    else if btn == 1 { event.key = TB_KEY_MOUSE_MIDDLE; }
    else if btn == 2 { event.key = TB_KEY_MOUSE_RIGHT; }
    else { event.key = TB_KEY_MOUSE_RELEASE; }
}

fn parse_sgr_mouse(buf: const u8[:], event: tb_event&) -> i32 {
    let g = gbl();
    // Format: \x1b[<b;x;yM  or  \x1b[<b;x;ym
    var i: i64 = 3;
    var vals: i32[3] = [0, 0, 0];
    var field: i32 = 0;
    var have_digit: i32 = 0;
    while i < buf.len {
        let ch = buf[i];
        if ch >= '0' && ch <= '9' {
            vals[field] = vals[field] * 10 + (ch - '0');
            have_digit = 1;
        } else if ch == ';' {
            if have_digit == 0 || field >= 2 { return 0; }
            field = field + 1;
            have_digit = 0;
        } else if ch == 'M' || ch == 'm' {
            if field != 2 || have_digit == 0 { return 0; }
            if (g.input_mode & TB_INPUT_MOUSE) != 0 {
                event.kind = TB_EVENT_MOUSE;
                event.x = vals[1] - 1;
                event.y = vals[2] - 1;
                apply_mouse_btn(event, vals[0], if ch == 'm' { 1 } else { 0 });
            } else {
                event.kind = 0;
            }
            return (i + 1) as i32;
        } else {
            return 0;
        }
        i = i + 1;
    }
    if buf.len < 32 { return TB_ERR_NEED_MORE; }
    return 0;
}

fn apply_kitty_or_other_code(code: i32, mod_val: u8, event: tb_event&) -> i32 {
    if code <= 0 || code > 0x10ffff { return 0; }
    event.kind = TB_EVENT_KEY;
    event.mod = mod_val;
    if code < 0x20 || code == 0x7f {
        event.key = code as u16;
        event.ch = 0;
    } else {
        event.key = 0;
        event.ch = code as u32;
    }
    return 1;
}

fn parse_csi_modified(buf: const u8[:], end: i64, event: tb_event&) -> i32 {
    // Parse \x1b[p1<fin>, \x1b[p1;p2<fin>, or \x1b[p1;p2;p3<fin> (also subparams ':' ignored)
    var p1: i32 = 0;
    var p2: i32 = 0;
    var p3: i32 = 0;
    var has_p1: i32 = 0;
    var has_p2: i32 = 0;
    var has_p3: i32 = 0;
    var p_idx: i32 = 0;
    var in_subparam: i32 = 0;
    var i: i64 = 2;
    while i < end {
        let ch = buf[i];
        if ch >= '0' && ch <= '9' {
            if in_subparam == 0 {
                if p_idx == 0 {
                    p1 = p1 * 10 + (ch - '0');
                    has_p1 = 1;
                } else if p_idx == 1 {
                    p2 = p2 * 10 + (ch - '0');
                    has_p2 = 1;
                } else {
                    p3 = p3 * 10 + (ch - '0');
                    has_p3 = 1;
                }
            }
        } else if ch == ':' {
            in_subparam = 1;
        } else if ch == ';' {
            if p_idx >= 2 { return 0; }
            p_idx = p_idx + 1;
            in_subparam = 0;
        } else {
            return 0;
        }
        i = i + 1;
    }

    let fin = buf[end];
    var key: u16 = 0;
    var mod_val: u8 = 0;

    if fin == '~' {
        if has_p1 == 0 { return 0; }
        // xterm modifyOtherKeys: \x1b[27;mod;code~
        if p1 == 27 && has_p2 != 0 && has_p3 != 0 {
            return apply_kitty_or_other_code(p3, xterm_mod_to_tb(p2), event);
        }
        if p1 == 2 { key = TB_KEY_INSERT; }
        else if p1 == 3 { key = TB_KEY_DELETE; }
        else if p1 == 1 || p1 == 7 { key = TB_KEY_HOME; }
        else if p1 == 4 || p1 == 8 { key = TB_KEY_END; }
        else if p1 == 5 { key = TB_KEY_PGUP; }
        else if p1 == 6 { key = TB_KEY_PGDN; }
        else if p1 == 11 { key = TB_KEY_F1; }
        else if p1 == 12 { key = TB_KEY_F2; }
        else if p1 == 13 { key = TB_KEY_F3; }
        else if p1 == 14 { key = TB_KEY_F4; }
        else if p1 == 15 { key = TB_KEY_F5; }
        else if p1 == 17 { key = TB_KEY_F6; }
        else if p1 == 18 { key = TB_KEY_F7; }
        else if p1 == 19 { key = TB_KEY_F8; }
        else if p1 == 20 { key = TB_KEY_F9; }
        else if p1 == 21 { key = TB_KEY_F10; }
        else if p1 == 23 { key = TB_KEY_F11; }
        else if p1 == 24 { key = TB_KEY_F12; }
        else { return 0; }
        if has_p2 != 0 { mod_val = xterm_mod_to_tb(p2); }
    } else if fin == 'u' {
        // Kitty keyboard protocol: \x1b[codepoint;modu or \x1b[codepointu
        if has_p1 == 0 { return 0; }
        if has_p2 != 0 { mod_val = xterm_mod_to_tb(p2); }
        return apply_kitty_or_other_code(p1, mod_val, event);
    } else if has_p1 != 0 && p1 == 1 && has_p2 != 0 {
        mod_val = xterm_mod_to_tb(p2);
        if fin == 'A' { key = TB_KEY_ARROW_UP; }
        else if fin == 'B' { key = TB_KEY_ARROW_DOWN; }
        else if fin == 'C' { key = TB_KEY_ARROW_RIGHT; }
        else if fin == 'D' { key = TB_KEY_ARROW_LEFT; }
        else if fin == 'H' { key = TB_KEY_HOME; }
        else if fin == 'F' { key = TB_KEY_END; }
        else if fin == 'P' { key = TB_KEY_F1; }
        else if fin == 'Q' { key = TB_KEY_F2; }
        else if fin == 'R' { key = TB_KEY_F3; }
        else if fin == 'S' { key = TB_KEY_F4; }
        else { return 0; }
    } else {
        return 0;
    }

    event.kind = TB_EVENT_KEY;
    event.mod = mod_val;
    event.key = key;
    event.ch = 0;
    return 1;
}

// Consume string-terminated escape sequences (OSC \x1b], DCS \x1bP, APC \x1b_, PM \x1b^, SOS \x1bX)
fn try_consume_string_esc(buf: const u8[:], event: tb_event&) -> i32 {
    var i: i64 = 2;
    while i < buf.len {
        let b = buf[i];
        if b == 0x07 {
            event.kind = 0;
            return (i + 1) as i32;
        }
        if b == 0x1b && (i + 1) < buf.len && buf[i + 1] == '\\' {
            event.kind = 0;
            return (i + 2) as i32;
        }
        i = i + 1;
    }
    if buf.len < TB_OPT_READ_BUF { return TB_ERR_NEED_MORE; }
    event.kind = 0;
    return buf.len as i32;
}

fn try_match_escape_buf(buf: const u8[:], event: tb_event&, alt_bracket_final: i32) -> i32 {
    let g = gbl();
    guard buf.len > 0 else { return 0; }
    guard buf[0] == 0x1b else { return 0; }

    event.kind = 0;
    event.mod = 0;
    event.key = 0;
    event.ch = 0;

    if buf.len == 1 {
        event.kind = TB_EVENT_KEY;
        event.key = TB_KEY_ESC;
        return 1;
    }

    // 1) Mouse sequences
    if buf.len >= 3 && buf[1] == '[' && buf[2] == '<' {
        let mrv = parse_sgr_mouse(buf, event);
        if mrv != 0 { return mrv; }
    }
    if buf.len >= 3 && buf[1] == '[' && buf[2] == 'M' {
        if buf.len < 6 { return TB_ERR_NEED_MORE; }
        if (g.input_mode & TB_INPUT_MOUSE) != 0 {
            event.kind = TB_EVENT_MOUSE;
            let cb = (buf[3] as i32) - 32;
            event.x = (buf[4] as i32) - 33;
            event.y = (buf[5] as i32) - 33;
            apply_mouse_btn(event, cb, if (cb & 3) == 3 { 1 } else { 0 });
        } else {
            event.kind = 0;
        }
        return 6;
    }

    // 2) Walk capability trie
    var node = g.cap_trie_root;
    var i: i64 = 0;
    while i < buf.len {
        let next = cap_trie_find_child(node, buf[i]);
        if next < 0 { break; }
        node = next;
        if g.cap_trie[node].is_leaf != 0 {
            event.kind = TB_EVENT_KEY;
            event.mod = g.cap_trie[node].mod;
            event.key = g.cap_trie[node].key;
            event.ch = 0;
            return (i + 1) as i32;
        }
        i = i + 1;
    }
    if i == buf.len && g.cap_trie[node].first_child >= 0 {
        if !(alt_bracket_final != 0 && buf.len == 2 && buf[1] == '[') {
            return TB_ERR_NEED_MORE;
        }
    }

    // 3) OSC / DCS / APC / PM / SOS string-terminated sequences
    if buf[1] == ']' || buf[1] == 'P' || buf[1] == '_' || buf[1] == '^' || buf[1] == 'X' {
        return try_consume_string_esc(buf, event);
    }

    // 4) CSI sequence (\x1b[ ... final)
    if buf[1] == '[' {
        if buf.len == 2 && (g.input_mode & TB_INPUT_ALT) != 0 && alt_bracket_final != 0 {
            event.kind = TB_EVENT_KEY;
            event.mod = TB_MOD_ALT;
            event.key = 0;
            event.ch = '[';
            return 2;
        }
        var end: i64 = 2;
        while end < buf.len {
            let b = buf[end];
            if b >= 0x40 && b <= 0x7e { break; }
            end = end + 1;
        }
        if end >= buf.len {
            if buf.len < 32 { return TB_ERR_NEED_MORE; }
            event.kind = TB_EVENT_KEY;
            event.key = TB_KEY_ESC;
            return 1;
        }
        let seq_len = (end + 1) as i32;
        if parse_csi_modified(buf, end, event) != 0 {
            return seq_len;
        }
        // Unrecognized complete CSI sequence (e.g. focus in/out): consume silently
        event.kind = 0;
        return seq_len;
    }

    // 5) SS3 sequence (\x1bO<ch>) not in trie
    if buf[1] == 'O' {
        if buf.len < 3 { return TB_ERR_NEED_MORE; }
        event.kind = 0;
        return 3;
    }

    // 6) TB_INPUT_ALT: ESC + char/control
    if (g.input_mode & TB_INPUT_ALT) != 0 {
        let b1 = buf[1];
        if b1 < 0x20 || b1 == 0x7f {
            event.kind = TB_EVENT_KEY;
            event.mod = TB_MOD_ALT;
            event.key = b1;
            event.ch = 0;
            return 2;
        }
        var uni: u32 = 0;
        let urv = tb_utf8_char_to_unicode(uni, buf[1..]);
        if urv == TB_ERR_NEED_MORE { return TB_ERR_NEED_MORE; }
        if urv > 0 {
            event.kind = TB_EVENT_KEY;
            event.mod = TB_MOD_ALT;
            event.key = 0;
            event.ch = uni;
            return 1 + urv;
        }
    }

    // 7) Fallback: bare ESC
    event.kind = TB_EVENT_KEY;
    event.mod = 0;
    event.key = TB_KEY_ESC;
    event.ch = 0;
    return 1;
}

fn inbuf_consume(n: i64) {
    let g = gbl();
    guard n > 0 && n <= g.inbuf_len else { return; }
    g.inbuf_pos = g.inbuf_pos + n;
    g.inbuf_len = g.inbuf_len - n;
    if g.inbuf_len == 0 {
        g.inbuf_pos = 0;
        return;
    }
    if g.inbuf_pos > 32 || (g.inbuf_pos + g.inbuf_len) > g.inbuf.len {
        var i: i64 = 0;
        while i < g.inbuf_len {
            let idx = i as i32;
            let src = (g.inbuf_pos + i) as i32;
            guard src < g.inbuf.len else { break; }
            g.inbuf[idx] = g.inbuf[src];
            i = i + 1;
        }
        g.inbuf_pos = 0;
    }
}

fn inbuf_copy_to(mbuf: u8[TB_OPT_READ_BUF]&) -> i64 {
    let g = gbl();
    var i: i64 = 0;
    while i < g.inbuf_len && i < TB_OPT_READ_BUF {
        let src = (g.inbuf_pos + i) as i32;
        guard src < g.inbuf.len else { break; }
        let idx = i as i32;
        mbuf[idx] = g.inbuf[src];
        i = i + 1;
    }
    return i;
}

fn inbuf_append(readbuf: const u8[TB_OPT_READ_BUF]&, nread: i64) {
    let g = gbl();
    var j: i64 = 0;
    while j < nread {
        let pos = (g.inbuf_pos + g.inbuf_len + j) as i32;
        if pos >= g.inbuf.len {
            g.inbuf.push(readbuf[j]);
        } else {
            g.inbuf[pos] = readbuf[j];
        }
        j = j + 1;
    }
    g.inbuf_len = g.inbuf_len + nread;
}

fn drain_resize_and_fill(event: tb_event&) -> i32 {
    let g = gbl();
    var got_byte: i32 = 0;
    var rb: u8[1] = [0; 1];
    loop {
        let r = tb_adapter_read(g.resize_pipefd[0], rb[0], 1);
        if r <= 0 { break; }
        got_byte = 1;
    }
    if got_byte == 0 { return 0; }

    var new_w: i32 = 0;
    var new_h: i32 = 0;
    if tb_adapter_get_winsize(g.wfd, new_w, new_h) == 0 ||
       tb_adapter_get_winsize(g.rfd, new_w, new_h) == 0 {
        if new_w > 0 && new_h > 0 && (new_w != g.width || new_h != g.height) {
            g.width = new_w;
            g.height = new_h;
            resize_back_cellbuf(g.width, g.height, g.fg, g.bg);
            let _ = grow_cells(g.front, g.width, g.height, 0);
        }
    }
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0);
    g.last_fg = 0xffffffffffffffff;
    g.last_bg = 0xffffffffffffffff;
    g.last_x = -1;
    g.last_y = -1;
    event.kind = TB_EVENT_RESIZE;
    event.mod = 0;
    event.key = 0;
    event.ch = 0;
    event.w = g.width;
    event.h = g.height;
    return 1;
}

fn decode_inbuf_event(event: tb_event&, allow_esc_coalesce: i32) -> i32 {
    let g = gbl();
    if g.inbuf_len <= 0 { return TB_ERR_NEED_MORE; }

    var alt_bracket_final: i32 = 0;

    // Briefly coalesce lone ESC or ESC+[ (in TB_INPUT_ALT mode) so split sequences don't stall
    if allow_esc_coalesce != 0 && g.inbuf[g.inbuf_pos as i32] == 0x1b &&
       (g.inbuf_len == 1 ||
        (g.inbuf_len == 2 && (g.input_mode & TB_INPUT_ALT) != 0 &&
         g.inbuf[(g.inbuf_pos + 1) as i32] == '[')) {
        let prev_len = g.inbuf_len;
        let prv = tb_adapter_poll(g.rfd, 10);
        if prv > 0 {
            var more: u8[TB_OPT_READ_BUF] = [0; TB_OPT_READ_BUF];
            let nr = tb_adapter_read(g.rfd, more[0], TB_OPT_READ_BUF);
            if nr > 0 {
                inbuf_append(more, nr);
            }
        }
        if prev_len == 2 && g.inbuf_len == 2 && (g.input_mode & TB_INPUT_ALT) != 0 {
            alt_bracket_final = 1;
        }
    }

    var mbuf: u8[TB_OPT_READ_BUF] = [0; TB_OPT_READ_BUF];
    let mlen = inbuf_copy_to(mbuf);
    let first = mbuf[0];

    if first == 0x1b {
        let consumed = try_match_escape_buf(mbuf[0..mlen], event, alt_bracket_final);
        if consumed == TB_ERR_NEED_MORE {
            return TB_ERR_NEED_MORE;
        }
        if consumed > 0 {
            inbuf_consume(consumed);
            if event.kind == 0 {
                return TB_ERR_NO_EVENT;
            }
            return TB_OK;
        }
    }

    // ASCII control characters (0x00..0x1f, 0x7f) go into event.key
    if first < 0x20 || first == 0x7f {
        event.kind = TB_EVENT_KEY;
        event.mod = 0;
        event.key = first;
        event.ch = 0;
        inbuf_consume(1);
        return TB_OK;
    }

    // UTF-8 character decoding
    var uni: u32 = 0;
    let urv = tb_utf8_char_to_unicode(uni, mbuf[0..mlen]);
    if urv == TB_ERR_NEED_MORE {
        return TB_ERR_NEED_MORE;
    }
    if urv > 0 {
        event.kind = TB_EVENT_KEY;
        event.mod = 0;
        event.key = 0;
        event.ch = uni;
        inbuf_consume(urv);
        return TB_OK;
    }

    // Invalid UTF-8 byte: consume 1 byte and emit replacement char
    event.kind = TB_EVENT_KEY;
    event.mod = 0;
    event.key = 0;
    event.ch = 0xfffd;
    inbuf_consume(1);
    return TB_OK;
}

// Wait up to `timeout_ms` milliseconds (-1 = block until ready, 0 = non-blocking)
// for a key, mouse, or resize event. Returns TB_OK, TB_ERR_NO_EVENT, or TB_ERR_*.
fn tb_peek_event(event: tb_event&, timeout_ms: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    // Phase 1: Try to parse bytes already in inbuf
    let coalesce_phase1: i32 = if timeout_ms != 0 { 1 } else { 0 };
    while g.inbuf_len > 0 {
        let drv = decode_inbuf_event(event, coalesce_phase1);
        if drv == TB_OK { return TB_OK; }
        if drv == TB_ERR_NEED_MORE { break; }
    }

    // Check pending resize pipe notification
    if drain_resize_and_fill(event) != 0 {
        return TB_OK;
    }

    // Phase 2: Poll TTY and resize pipe across remaining timeout
    let start_ms = tb_internal_now_ms();
    var remaining_ms = timeout_ms;
    loop {
        let poll_rv = tb_adapter_poll_multi(g.rfd, g.resize_pipefd[0], remaining_ms);
        if poll_rv == 0 {
            return TB_ERR_NO_EVENT;
        }
        if poll_rv < 0 {
            if tb_adapter_is_eintr() != 0 {
                if drain_resize_and_fill(event) != 0 {
                    return TB_OK;
                }
            } else {
                g.last_errno = tb_adapter_errno();
                return TB_ERR_POLL;
            }
        } else {
            // Check resize pipe first
            if tb_adapter_poll_is_in(1) != 0 {
                if drain_resize_and_fill(event) != 0 {
                    return TB_OK;
                }
            }

            // Check TTY input
            if tb_adapter_poll_is_in(0) != 0 {
                var readbuf: u8[TB_OPT_READ_BUF] = [0; TB_OPT_READ_BUF];
                let nread = tb_adapter_read(g.rfd, readbuf[0], TB_OPT_READ_BUF);
                if nread == 0 {
                    return TB_ERR_READ;
                }
                if nread < 0 {
                    if tb_adapter_is_again() == 0 && tb_adapter_is_eintr() == 0 {
                        g.last_errno = tb_adapter_errno();
                        return TB_ERR_READ;
                    }
                } else {
                    inbuf_append(readbuf, nread);
                    while g.inbuf_len > 0 {
                        let drv = decode_inbuf_event(event, if timeout_ms != 0 { 1 } else { 0 });
                        if drv == TB_OK { return TB_OK; }
                        if drv == TB_ERR_NEED_MORE { break; }
                    }
                }
            } else if tb_adapter_poll_is_err(0) != 0 {
                return TB_ERR_READ;
            }
        }

        if timeout_ms == 0 { return TB_ERR_NO_EVENT; }
        if timeout_ms > 0 {
            let elapsed = (tb_internal_now_ms() - start_ms) as i32;
            remaining_ms = timeout_ms - elapsed;
            if remaining_ms <= 0 { return TB_ERR_NO_EVENT; }
        }
    }
}

// Block until an event (key, mouse, or resize) is available or a fatal error occurs.
fn tb_poll_event(event: tb_event&) -> i32 {
    loop {
        let rv = tb_peek_event(event, -1);
        if rv != TB_ERR_NO_EVENT && rv != TB_ERR_NEED_MORE {
            return rv;
        }
    }
}

// Export the TTY read fd and SIGWINCH self-pipe read fd for external poll/select loops.
fn tb_get_fds(ttyfd: i32&, resizefd: i32&) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    ttyfd = g.rfd;
    resizefd = g.resize_pipefd[0];
    return TB_OK;
}

// Get or set the active input mode (`TB_INPUT_CURRENT` queries; accepts ESC or ALT, optionally | MOUSE).
fn tb_set_input_mode(mode: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if mode == TB_INPUT_CURRENT { return g.input_mode; }
    let valid = TB_INPUT_ESC | TB_INPUT_ALT | TB_INPUT_MOUSE;
    if (mode & ~valid) != 0 { return TB_ERR; }
    if (mode & TB_INPUT_ESC) != 0 && (mode & TB_INPUT_ALT) != 0 { return TB_ERR; }

    let was_mouse = g.input_mode & TB_INPUT_MOUSE;
    let now_mouse = mode & TB_INPUT_MOUSE;
    if was_mouse == 0 && now_mouse != 0 {
        let _ = outbuf_puts(TB_HARDCAP_ENTER_MOUSE);
        let _ = outbuf_flush(g.wfd);
    } else if was_mouse != 0 && now_mouse == 0 {
        let _ = outbuf_puts(TB_HARDCAP_EXIT_MOUSE);
        let _ = outbuf_flush(g.wfd);
    }

    g.input_mode = mode;
    return g.input_mode;
}

// Get or set the color output mode (`TB_OUTPUT_CURRENT`, NORMAL, 256, 216, GRAYSCALE, TRUECOLOR).
fn tb_set_output_mode(mode: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if mode == TB_OUTPUT_CURRENT { return g.output_mode; }
    if !(mode == TB_OUTPUT_NORMAL || mode == TB_OUTPUT_256 || mode == TB_OUTPUT_216 || mode == TB_OUTPUT_GRAYSCALE || mode == TB_OUTPUT_TRUECOLOR) {
        return TB_ERR;
    }
    g.output_mode = mode;
    g.last_fg = 0xffffffffffffffff;
    g.last_bg = 0xffffffffffffffff;
    return g.output_mode;
}

// Invalidate the front buffer so the next tb_present() redraws every cell.
fn tb_invalidate() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0);
    return TB_OK;
}

// Show and position the terminal cursor at (cx, cy), or hide it if either coordinate is < 0.
fn tb_set_cursor(cx: i32, cy: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if cx < 0 || cy < 0 {
        return tb_hide_cursor();
    }
    if g.cursor_hidden != 0 {
        if g.caps[TB_CAP_SHOW_CURSOR].len > 0 {
            let _ = outbuf_puts(g.caps[TB_CAP_SHOW_CURSOR]);
        } else {
            let _ = outbuf_puts("\x1b[?25h");
        }
        g.cursor_hidden = 0;
    }
    g.cursor_x = cx;
    g.cursor_y = cy;
    return TB_OK;
}

// Hide the terminal cursor (emits TB_CAP_HIDE_CURSOR or CSI ?25l).
fn tb_hide_cursor() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if g.cursor_hidden == 0 {
        if g.caps[TB_CAP_HIDE_CURSOR].len > 0 {
            let _ = outbuf_puts(g.caps[TB_CAP_HIDE_CURSOR]);
        } else {
            let _ = outbuf_puts("\x1b[?25l");
        }
        g.cursor_hidden = 1;
    }
    g.cursor_x = -1;
    g.cursor_y = -1;
    return TB_OK;
}

// ===========================================================================
// OUTPUT BUFFER
// ===========================================================================

fn outbuf_push_byte(g: tb_global&, b: u8) {
    let pos = g.outbuf_len;
    if pos < g.outbuf.len {
        g.outbuf[pos as i32] = b;
    } else {
        g.outbuf.push(b);
    }
    g.outbuf_len = pos + 1;
}

fn outbuf_puts(str: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    var i: i64 = 0;
    while i < str.len {
        outbuf_push_byte(g, str[i as i32]);
        i = i + 1;
    }
    return TB_OK;
}

fn outbuf_nputs(buf: const u8[:], n: i64) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    let limit = if n < buf.len { n } else { buf.len };
    var i: i64 = 0;
    while i < limit {
        let pos = g.outbuf_len;
        if pos < g.outbuf.len {
            g.outbuf[pos as i32] = buf[i as i32];
        } else {
            g.outbuf.push(buf[i as i32]);
        }
        g.outbuf_len = g.outbuf_len + 1;
        i = i + 1;
    }
    return TB_OK;
}

fn outbuf_shift(written: i64) {
    let g = gbl();
    if written <= 0 { return; }
    var i: i64 = 0;
    while i < (g.outbuf_len - written) {
        let src = (written + i) as i32;
        let dst = i as i32;
        g.outbuf[dst] = g.outbuf[src];
        i = i + 1;
    }
    g.outbuf_len = g.outbuf_len - written;
}

fn outbuf_flush(fd: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if g.outbuf_len <= 0 { return TB_OK; }

    var written: i64 = 0;
    while written < g.outbuf_len {
        let off = written as i32;
        let remaining = g.outbuf_len - written;
        let n = tb_adapter_write(fd, g.outbuf[off], remaining as u64);
        if n > 0 {
            written = written + n;
        } else {
            if tb_adapter_is_eintr() != 0 { continue; }
            if tb_adapter_is_again() != 0 {
                let prv = tb_adapter_poll_out(fd, 50);
                if prv > 0 || (prv < 0 && tb_adapter_is_eintr() != 0) {
                    continue;
                }
                outbuf_shift(written);
                g.last_errno = tb_adapter_errno();
                return TB_ERR_POLL;
            }
            outbuf_shift(written);
            g.last_errno = tb_adapter_errno();
            return TB_ERR_READ;
        }
    }

    outbuf_shift(written);
    return TB_OK;
}

fn convert_num(num: u64, buf: u8[32]&) -> i32 {
    var digits: u8[32];
    var n = 0;
    if num == 0 {
        digits[0] = 0x30;
        n = 1;
    } else {
        var v = num;
        while v > 0 {
            digits[n] = (0x30 + (v % 10)) as u8;
            v = v / 10;
            n = n + 1;
        }
    }
    var i = 0;
    for i in n / 2 {
        let tmp = digits[i];
        digits[i] = digits[n - 1 - i];
        digits[n - 1 - i] = tmp;
    }
    var j = 0;
    for j in n {
        buf[j] = digits[j];
    }
    return n as i32;
}

fn send_num(num: u64) {
    var nbuf: u8[32] = [0; 32];
    let len = convert_num(num, nbuf);
    let _ = outbuf_puts(nbuf[0..len]);
}

fn outbuf_push_u8_dec(g: tb_global&, v: u64) {
    if v >= 100 {
        outbuf_push_byte(g, (0x30 + (v / 100)) as u8);
        outbuf_push_byte(g, (0x30 + ((v / 10) % 10)) as u8);
        outbuf_push_byte(g, (0x30 + (v % 10)) as u8);
    } else if v >= 10 {
        outbuf_push_byte(g, (0x30 + (v / 10)) as u8);
        outbuf_push_byte(g, (0x30 + (v % 10)) as u8);
    } else {
        outbuf_push_byte(g, (0x30 + v) as u8);
    }
}

fn outbuf_push_pos_dec(g: tb_global&, v: i32) {
    if v >= 0 && v <= 255 {
        outbuf_push_u8_dec(g, v as u64);
    } else {
        send_num(v as u64);
    }
}

// ===========================================================================
// OUTPUT / PRESENT
// ===========================================================================

fn eff_color(c: uintattr_t, mode: i32) -> uintattr_t {
    if mode == TB_OUTPUT_TRUECOLOR {
        let rgb = c & 0xffffff;
        if rgb != 0 { return rgb; }
        if (c & TB_HI_BLACK) != 0 { return 0; }
        return 0x1000000;
    }
    if mode == TB_OUTPUT_256 {
        let idx = c & 0xff;
        if idx != 0 || (c & TB_HI_BLACK) != 0 { return idx; }
        return 0x1000000;
    }
    if mode == TB_OUTPUT_216 {
        let idx = c & 0xff;
        if idx >= 1 && idx <= 216 { return 15 + idx; }
        return 0x1000000;
    }
    if mode == TB_OUTPUT_GRAYSCALE {
        let idx = c & 0xff;
        if idx >= 1 && idx <= 24 { return 231 + idx; }
        return 0x1000000;
    }
    // TB_OUTPUT_NORMAL
    var idx = c & 0xff;
    var bright: i32 = if (c & TB_BRIGHT) != 0 { 1 } else { 0 };
    if (c & TB_HI_BLACK) != 0 && idx == 0 {
        idx = 1;
        bright = 1;
    }
    if idx >= 1 && idx <= 8 {
        let base: uintattr_t = if bright != 0 { 90 } else { 30 };
        return base + idx - 1;
    }
    return 0x1000000;
}

fn emit_sgr_sep(g: tb_global&, first_param: i32) {
    if first_param == 0 {
        outbuf_push_byte(g, ';');
    }
}

fn send_attr(fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    if fg == g.last_fg && bg == g.last_bg { return TB_OK; }

    let mode = g.output_mode;
    let force_reset: i32 = if g.last_fg == 0xffffffffffffffff || g.last_bg == 0xffffffffffffffff { 1 } else { 0 };
    let new_style = fg & TB_STYLE_MASK;
    let old_style = if force_reset != 0 { 0 } else { g.last_fg & TB_STYLE_MASK };

    let new_fg = eff_color(fg, mode);
    let old_fg = if force_reset != 0 { 0x1000000 } else { eff_color(g.last_fg, mode) };
    let new_bg = eff_color(bg, mode);
    let old_bg = if force_reset != 0 { 0x1000000 } else { eff_color(g.last_bg, mode) };

    if force_reset == 0 && new_style == old_style && new_fg == old_fg && new_bg == old_bg {
        g.last_fg = fg;
        g.last_bg = bg;
        return TB_OK;
    }

    let need_reset: i32 =
        if force_reset != 0 ||
           (old_style & ~new_style) != 0 ||
           (new_fg == 0x1000000 && old_fg != 0x1000000) ||
           (new_bg == 0x1000000 && old_bg != 0x1000000) { 1 } else { 0 };

    let emit_style: uintattr_t = if need_reset != 0 { new_style } else { new_style & ~old_style };
    let emit_fg: i32 = if new_fg != 0x1000000 && (need_reset != 0 || new_fg != old_fg) { 1 } else { 0 };
    let emit_bg: i32 = if new_bg != 0x1000000 && (need_reset != 0 || new_bg != old_bg) { 1 } else { 0 };

    if need_reset != 0 && emit_style == 0 && emit_fg == 0 && emit_bg == 0 {
        outbuf_push_byte(g, 0x1b);
        outbuf_push_byte(g, '[');
        outbuf_push_byte(g, 'm');
    } else {
        outbuf_push_byte(g, 0x1b);
        outbuf_push_byte(g, '[');
        var first_param: i32 = 1;
        if need_reset != 0 {
            outbuf_push_byte(g, '0');
            first_param = 0;
        }
        if emit_style != 0 {
            if (emit_style & TB_BOLD) != 0        { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '1'); first_param = 0; }
            if (emit_style & TB_DIM) != 0         { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '2'); first_param = 0; }
            if (emit_style & TB_ITALIC) != 0      { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '3'); first_param = 0; }
            if (emit_style & TB_UNDERLINE) != 0   { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '4'); first_param = 0; }
            if (emit_style & TB_BLINK) != 0       { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '5'); first_param = 0; }
            if (emit_style & TB_REVERSE) != 0     { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '7'); first_param = 0; }
            if (emit_style & TB_INVISIBLE) != 0   { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '8'); first_param = 0; }
            if (emit_style & TB_STRIKEOUT) != 0   { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '9'); first_param = 0; }
            if (emit_style & TB_UNDERLINE_2) != 0 { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '2'); outbuf_push_byte(g, '1'); first_param = 0; }
            if (emit_style & TB_OVERLINE) != 0    { emit_sgr_sep(g, first_param); outbuf_push_byte(g, '5'); outbuf_push_byte(g, '3'); first_param = 0; }
        }
        if emit_fg != 0 {
            emit_sgr_sep(g, first_param);
            first_param = 0;
            if mode == TB_OUTPUT_TRUECOLOR {
                outbuf_push_byte(g, '3');
                outbuf_push_byte(g, '8');
                outbuf_push_byte(g, ';');
                outbuf_push_byte(g, '2');
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, (new_fg >> 16) & 0xff);
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, (new_fg >> 8) & 0xff);
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, new_fg & 0xff);
            } else if mode == TB_OUTPUT_NORMAL {
                outbuf_push_u8_dec(g, new_fg);
            } else {
                outbuf_push_byte(g, '3');
                outbuf_push_byte(g, '8');
                outbuf_push_byte(g, ';');
                outbuf_push_byte(g, '5');
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, new_fg);
            }
        }
        if emit_bg != 0 {
            emit_sgr_sep(g, first_param);
            if mode == TB_OUTPUT_TRUECOLOR {
                outbuf_push_byte(g, '4');
                outbuf_push_byte(g, '8');
                outbuf_push_byte(g, ';');
                outbuf_push_byte(g, '2');
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, (new_bg >> 16) & 0xff);
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, (new_bg >> 8) & 0xff);
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, new_bg & 0xff);
            } else if mode == TB_OUTPUT_NORMAL {
                outbuf_push_u8_dec(g, new_bg + 10);
            } else {
                outbuf_push_byte(g, '4');
                outbuf_push_byte(g, '8');
                outbuf_push_byte(g, ';');
                outbuf_push_byte(g, '5');
                outbuf_push_byte(g, ';');
                outbuf_push_u8_dec(g, new_bg);
            }
        }
        outbuf_push_byte(g, 'm');
    }

    g.last_fg = fg;
    g.last_bg = bg;
    return TB_OK;
}

fn cell_cmp(a: tb_cell&, b: tb_cell&) -> i32 {
    if a.ch != b.ch || a.fg != b.fg || a.bg != b.bg { return 1; }
    return 0;
}

fn send_cursor_if(x: i32, y: i32) -> i32 {
    if x < 0 || y < 0 { return TB_OK; }
    let g = gbl();
    outbuf_push_byte(g, 0x1b);
    outbuf_push_byte(g, '[');
    outbuf_push_pos_dec(g, y + 1);
    outbuf_push_byte(g, ';');
    outbuf_push_pos_dec(g, x + 1);
    outbuf_push_byte(g, 'H');
    return TB_OK;
}

fn send_char(ch: u32) -> i32 {
    var buf: u8[7] = [0, 0, 0, 0, 0, 0, 0];
    let len = tb_utf8_unicode_to_char(buf, ch);
    return outbuf_puts(buf[0..len]);
}

fn send_char_fast(g: tb_global&, ch: u32) {
    if ch < 0x80 {
        outbuf_push_byte(g, ch as u8);
        return;
    }
    if ch == 0x2580 {
        outbuf_push_byte(g, 0xe2);
        outbuf_push_byte(g, 0x96);
        outbuf_push_byte(g, 0x80);
        return;
    }
    if ch == 0x2588 {
        outbuf_push_byte(g, 0xe2);
        outbuf_push_byte(g, 0x96);
        outbuf_push_byte(g, 0x88);
        return;
    }
    let _ = send_char(ch);
}

// Diff back buffer against front buffer, emit minimal ANSI cursor/SGR/UTF-8 sequences,
// emit EGC combining codepoints, clip wide characters at the right edge, position cursor,
// and flush to `wfd`.
fn tb_present() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    let fw = g.front.width;
    let fh = g.front.height;
    let bw = g.back.width;
    var any_dirty: i32 = 0;
    var y = 0;
    for y in fh {
        var x: i32 = 0;
        let back_row = y * bw;
        let front_row = y * fw;
        while x < fw {
            let back_idx = back_row + x;
            let front_idx = front_row + x;
            let back = g.back.cells[back_idx];
            let front = g.front.cells[front_idx];
            let back_ech = g.back_ech_head[back_idx];
            let front_ech = g.front_ech_head[front_idx];

            // Fast path for ASCII and block glyphs with no EGC chains
            if back_ech < 0 && front_ech < 0 &&
               ((back.ch >= 0x20 && back.ch <= 0x7e) || back.ch == 0x2580 || back.ch == 0x2588) {
                if back.ch != front.ch || back.fg != front.fg || back.bg != front.bg {
                    if any_dirty == 0 {
                        let _ = outbuf_puts("\x1b[?2026h\x1b[m");
                        g.last_fg = TB_DEFAULT;
                        g.last_bg = TB_DEFAULT;
                        g.last_x = -1;
                        g.last_y = -1;
                        any_dirty = 1;
                    }
                    g.front.cells[front_idx] = back;
                    if back.fg != g.last_fg || back.bg != g.last_bg {
                        let _ = send_attr(back.fg, back.bg);
                    }
                    if x != g.last_x + 1 || y != g.last_y {
                        let _ = send_cursor_if(x, y);
                    }
                    send_char_fast(g, back.ch);
                    g.last_x = x;
                    g.last_y = y;
                }
                x = x + 1;
                continue;
            }

            let safe_ch: u32 = if back.ch == 0 || tb_iswprint(back.ch) == 0 { 0x20 } else { back.ch };
            let w = tb_wcwidth(safe_ch);
            let w2: i32 = if w < 1 { 1 } else { w };

            if cell_cmp(back, front) != 0 || egc_cmp_chains(back_ech, front_ech) != 0 {
                if any_dirty == 0 {
                    let _ = outbuf_puts("\x1b[?2026h\x1b[m");
                    g.last_fg = TB_DEFAULT;
                    g.last_bg = TB_DEFAULT;
                    g.last_x = -1;
                    g.last_y = -1;
                    any_dirty = 1;
                }

                g.front.cells[front_idx] = back;
                egc_copy_to_front(front_idx, back_ech);

                let fg = back.fg;
                let bg = back.bg;
                if fg != g.last_fg || bg != g.last_bg {
                    let _ = send_attr(fg, bg);
                }

                if x != g.last_x + 1 || y != g.last_y {
                    let _ = send_cursor_if(x, y);
                }

                if w2 > 1 && x >= fw - (w2 - 1) {
                    var i = x;
                    while i < fw {
                        outbuf_push_byte(g, ' ');
                        i = i + 1;
                    }
                    g.last_x = fw - 1;
                } else {
                    send_char_fast(g, safe_ch);
                    var cur_ech = back_ech;
                    while cur_ech >= 0 {
                        let ech_ch = g.egc_pool[cur_ech].ch;
                        if tb_iswprint(ech_ch) != 0 {
                            send_char_fast(g, ech_ch);
                        }
                        cur_ech = g.egc_pool[cur_ech].next;
                    }
                    g.last_x = x + w2 - 1;
                }
                g.last_y = y;

                // Invalidate trailing columns of a wide character in front buffer
                var wi_off = 1;
                while wi_off < w2 {
                    let wi = x + wi_off;
                    if wi < fw {
                        let wide_idx = front_row + wi;
                        g.front.cells[wide_idx].ch = 0xffffffff;
                        g.front.cells[wide_idx].fg = 0xffffffffffffffff;
                        g.front.cells[wide_idx].bg = 0xffffffffffffffff;
                        if g.front_ech_head[wide_idx] >= 0 {
                            egc_free_chain(g.front_ech_head[wide_idx]);
                            g.front_ech_head[wide_idx] = -1;
                        }
                    }
                    wi_off = wi_off + 1;
                }
            }
            x = x + w2;
        }
    }

    if g.cursor_x >= 0 && g.cursor_x < fw &&
       g.cursor_y >= 0 && g.cursor_y < fh &&
       (g.cursor_x != g.last_x + 1 || g.cursor_y != g.last_y) {
        let _ = send_cursor_if(g.cursor_x, g.cursor_y);
        g.last_x = g.cursor_x;
        g.last_y = g.cursor_y;
    }

    if any_dirty != 0 {
        let _ = outbuf_puts("\x1b[?2026l");
    }

    return outbuf_flush(g.wfd);
}

// ===========================================================================
// PRINTING FUNCTIONS
// ===========================================================================

// Print UTF-8 string `str` starting at (x, y), handling `\n`, EGC combining marks, and clipping at right margin.
fn tb_print(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32 {
    var out_w: u64 = 0;
    return tb_print_ex(x, y, fg, bg, out_w, str);
}

// Print UTF-8 string `str` starting at (x, y) and write max rendered column width into `out_w`.
fn tb_print_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, str: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }

    var cx = x;
    var cy = y;
    var prev_cx: i32 = -1;
    var cur_w: u64 = 0;
    var max_w: u64 = 0;

    var si = 0;
    while si < str.len {
        var uni: u32 = 0;
        let rv = tb_utf8_char_to_unicode(uni, str[si..]);
        if rv <= 0 {
            si = si + 1;
            continue;
        }
        si = si + rv;

        if uni == 0x0a { // newline
            if cur_w > max_w { max_w = cur_w; }
            cur_w = 0;
            cx = x;
            prev_cx = -1;
            cy = cy + 1;
            if cy >= g.height { break; }
            continue;
        }

        if tb_iswprint(uni) == 0 {
            uni = 0xfffd;
        }

        let w = tb_wcwidth(uni);
        if w == 0 {
            // Attach combining mark / zero-width joiner to the previous cell on this line
            if prev_cx >= x && prev_cx < g.width && cy >= 0 && cy < g.height {
                let _ = tb_extend_cell(prev_cx, cy, uni);
            }
            continue;
        }

        // Skip characters past right margin until next newline
        if cx >= g.width {
            continue;
        }

        let w2: i32 = if w < 1 { 1 } else { w };
        if cx >= 0 && cx < g.width && cy >= 0 && cy < g.height {
            let _ = tb_set_cell(cx, cy, uni, fg, bg);
            prev_cx = cx;
            cur_w = cur_w + (w2 as u64);
        }

        cx = cx + w2;
    }

    if cur_w > max_w { max_w = cur_w; }
    out_w = max_w;
    return TB_OK;
}

// tb_send — append raw bytes to the output buffer.
fn tb_send(buf: const u8[:], nbuf: i64) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    return outbuf_nputs(buf, nbuf);
}

// tb_sendf — non-variadic stub in Goose: writes `fmt` literally without `%` formatting.
fn tb_sendf(fmt: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    return tb_send(fmt, fmt.len);
}

// tb_printf — non-variadic stub in Goose: prints `fmt` literally via tb_print_ex() without `%` formatting.
fn tb_printf(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, fmt: const u8[:]) -> i32 {
    var out_w: u64 = 0;
    return tb_print_ex(x, y, fg, bg, out_w, fmt);
}

// tb_printf_ex — non-variadic stub in Goose: prints `fmt` literally and writes rendered column width to `out_w`.
fn tb_printf_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, fmt: const u8[:]) -> i32 {
    return tb_print_ex(x, y, fg, bg, out_w, fmt);
}
