// termbox2.goose — termbox2 terminal I/O library, ported to Goose
// Port of https://github.com/termbox/termbox2 (MIT license)
// Original authors: Adam Saponara, nsf
//
// Build: goose build termbox2.goose   (links adapter.c via termbox2.build)

const TB_VERSION_STR = "3.0.0-goose";

// ---------------------------------------------------------------------------
// Compile-time options (mirrors termbox2.h TB_OPT_*)
// ---------------------------------------------------------------------------

const TB_OPT_ATTR_W = 64;
const TB_OPT_EGC = 0;
const TB_OPT_PRINTF_BUF = 4096;
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

// --- TTY/ioctl constants ---
const TIOCGWINSZ: u64 = 0x5413;
const TCGETS: u64 = 0x5401;
const TCSETS: u64 = 0x5402;
const F_GETFL: i32 = 3;
const F_SETFL: i32 = 4;
const O_NONBLOCK: i32 = 0x800;
const O_RDWR: i32 = 2;
const SIGWINCH: i32 = 28;

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

// --- Event types ---
const TB_EVENT_KEY   = 1;
const TB_EVENT_RESIZE = 2;
const TB_EVENT_MOUSE = 3;

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
    cap_trie_root: i32,
    term_index: i32,
    inbuf: u8[>..],
    inbuf_pos: i64,
    inbuf_len: i64,
    outbuf: u8[>..],
    outbuf_len: i64,
    back: cellbuf,
    front: cellbuf,
    has_orig_tios: i32,
    last_errno: i32,
    initialized: i32,
    errbuf: u8[1024],
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
extern fn tb_adapter_set_nonblock(fd: i32) -> i32;
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
extern fn tb_adapter_ttyname(fd: i32) -> u64;
extern fn tb_adapter_get_ttyname(buf: u8&, bufsz: u64, tty_name_ptr: u64) -> i32;
extern fn tb_adapter_setup_signwinch(pipe_fd: i32) -> i32;
extern fn tb_adapter_clear_signwinch() -> i32;
extern fn tb_adapter_resize_notify(fd: i32) -> i32;
extern fn tb_adapter_set_raw_mode(fd: i32) -> i32;
extern fn tb_adapter_get_term(buf: u8&, bufsz: u64) -> i32;
extern fn tb_internal_now_ms() -> i64 = "tb_adapter_now_ms";

// ===========================================================================
// UTF-8 HELPERS
// ===========================================================================

// Return byte length of codepoint given first byte of UTF-8 sequence (1-6).
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

fn tb_utf8_char_to_unicode(out: u32&, c: const u8[:]) -> i32 {
    if c.len == 0 { return 0; }
    let first = c[0];
    let len = tb_utf8_char_length(first as i8);
    if len <= 0 { return TB_ERR; }
    if len > c.len { return TB_ERR_NEED_MORE; }
    // Validate continuation bytes
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
    // Reject overlong, surrogates, > 0x10ffff
    if (len == 2 && value < 0x80) || (len == 3 && value < 0x800) || (len == 4 && value < 0x10000) { return TB_ERR; }
    if value >= 0xd800 && value <= 0xdfff { return TB_ERR; }
    if value > 0x10ffff { return TB_ERR; }
    out = value;
    return len;
}

fn tb_utf8_unicode_to_char(out: u8[7]&, c: u32) -> i32 {
    var len: i32;
    var b0: u8 = 0;
    var b1: u8 = 0;
    var b2: u8 = 0;
    var b3: u8 = 0;
    if c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff) {
        // Replacement character U+FFFD
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

fn tb_iswprint(ch: u32) -> i32 {
    if ch < 0x20 { return 0; }
    if ch == 0x7f { return 0; }
    if ch >= 0x20 && ch <= 0x7e { return 1; }
    if ch >= 0xa0 && ch <= 0xd7ff { return 1; }
    if ch >= 0xe000 && ch <= 0xfdcf { return 1; }
    if ch >= 0xfdf0 && ch <= 0xfffd { return 1; }
    if ch >= 0x10000 && ch <= 0x10fffd { return 1; }
    return 0;
}

fn tb_wcwidth(ch: u32) -> i32 {
    if ch == 0 { return 0; }
    if ch < 0x20 || (ch >= 0x7f && ch < 0xa0) { return -1; }
    // Common combining marks
    if (ch >= 0x0300 && ch <= 0x036f) ||
       (ch >= 0x1ab0 && ch <= 0x1aff) ||
       (ch >= 0x1dc0 && ch <= 0x1dff) ||
       (ch >= 0x20d0 && ch <= 0x20ff) ||
       (ch >= 0xfe00 && ch <= 0xfe0f) ||
       (ch >= 0xfe20 && ch <= 0xfe2f) {
        return 0;
    }
    // Wide East Asian & emoji ranges
    if ch >= 0x1100 && (
        ch <= 0x115f ||
        ch == 0x2329 || ch == 0x232a ||
        (ch >= 0x2e80 && ch <= 0xa4cf && ch != 0x303f) ||
        (ch >= 0xac00 && ch <= 0xd7a3) ||
        (ch >= 0xf900 && ch <= 0xfaff) ||
        (ch >= 0xfe10 && ch <= 0xfe19) ||
        (ch >= 0xfe30 && ch <= 0xfe6f) ||
        (ch >= 0xff00 && ch <= 0xff60) ||
        (ch >= 0xffe0 && ch <= 0xffe6) ||
        (ch >= 0x1f300 && ch <= 0x1faff) ||
        (ch >= 0x20000 && ch <= 0x3fffd)
    ) {
        return 2;
    }
    return 1;
}

// ===========================================================================
// CELL BUFFER OPERATIONS
// ===========================================================================

fn tb_width() -> i32 {
    return gbl().width;
}

fn tb_height() -> i32 {
    return gbl().height;
}

fn tb_set_clear_attrs(fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    g.fg = fg;
    g.bg = bg;
    return TB_OK;
}

fn tb_clear() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    let fg = g.fg;
    let bg = g.bg;
    var y = 0;
    for y in g.height {
        var x = 0;
        for x in g.width {
            let idx = y * g.width + x;
            g.back.cells[idx].ch = 0x20;
            g.back.cells[idx].fg = fg;
            g.back.cells[idx].bg = bg;
        }
    }
    return TB_OK;
}

fn tb_set_cell(x: i32, y: i32, ch: u32, fg: uintattr_t, bg: uintattr_t) -> i32 {
    return tb_set_cell_ex(x, y, ch, 1, fg, bg);
}

fn tb_set_cell_ex(x: i32, y: i32, ch: const u32&, nch: i64, fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    let idx = y * g.width + x;
    g.back.cells[idx].ch = ch;
    g.back.cells[idx].fg = fg;
    g.back.cells[idx].bg = bg;
    return TB_OK;
}

fn tb_extend_cell(x: i32, y: i32, ch: u32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }
    if TB_OPT_EGC == 0 {
        return TB_ERR;
    }
    return TB_OK;
}

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

fn grow_cells(buf: cellbuf&, width: i32, height: i32) -> i32 {
    let needed = width * height;
    let have = buf.cells.len;
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

fn resize_back_cellbuf(buf: cellbuf&, new_w: i32, new_h: i32, fg: uintattr_t, bg: uintattr_t) {
    let old_w = buf.width;
    let old_h = buf.height;
    let _ = grow_cells(buf, new_w, new_h);
    let min_w = if old_w < new_w { old_w } else { new_w };
    let min_h = if old_h < new_h { old_h } else { new_h };

    if new_w < old_w {
        var y = 0;
        for y in min_h {
            var x = 0;
            for x in min_w {
                buf.cells[y * new_w + x] = buf.cells[y * old_w + x];
            }
        }
    } else if new_w > old_w {
        var y = min_h - 1;
        while y >= 0 {
            var x = min_w - 1;
            while x >= 0 {
                buf.cells[y * new_w + x] = buf.cells[y * old_w + x];
                x = x - 1;
            }
            var cx = min_w;
            while cx < new_w {
                let idx = y * new_w + cx;
                buf.cells[idx].ch = 0x20;
                buf.cells[idx].fg = fg;
                buf.cells[idx].bg = bg;
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
                buf.cells[idx].ch = 0x20;
                buf.cells[idx].fg = fg;
                buf.cells[idx].bg = bg;
                x = x + 1;
            }
            y = y + 1;
        }
    }
}

fn reset_cellbuf(buf: cellbuf&, ch: u32, fg: uintattr_t, bg: uintattr_t) {
    var y = 0;
    for y in buf.height {
        var x = 0;
        for x in buf.width {
            let idx = y * buf.width + x;
            buf.cells[idx].ch = ch;
            buf.cells[idx].fg = fg;
            buf.cells[idx].bg = bg;
        }
    }
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
    g.initialized = 0;
}

fn tb_init() -> i32 {
    return tb_init_file("/dev/tty");
}

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
        // tb_init_rwfd cleans up fd_owned on failure, ensure cleared
        g.fd_owned = 0;
    }
    return rv;
}

fn tb_init_fd(ttyfd: i32) -> i32 {
    return tb_init_rwfd(ttyfd, ttyfd);
}

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

fn tb_init_rwfd(rfd: i32, wfd: i32) -> i32 {
    let g = gbl();
    if g.initialized != 0 {
        let _ = tb_shutdown();
    }

    if tb_adapter_isatty(rfd) == 0 {
        if g.fd_owned != 0 {
            let _ = tb_adapter_close(rfd);
            g.fd_owned = 0;
        }
        return TB_ERR_NOT_INIT;
    }

    g.ttyfd = rfd;
    g.rfd = rfd;
    g.wfd = wfd;
    g.ttyfd_open = 1;
    g.has_resize_pipe = 0;
    g.resize_pipefd[0] = -1;
    g.resize_pipefd[1] = -1;
    g.has_orig_tios = 0;
    g.last_errno = 0;

    if tb_adapter_save_termios(rfd) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_TCGETATTR;
    }
    g.has_orig_tios = 1;

    if tb_adapter_set_nonblock(rfd) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_READ;
    }

    if tb_adapter_set_raw_mode(rfd) != 0 {
        g.last_errno = tb_adapter_errno();
        cleanup_partial_init();
        return TB_ERR_TCSETATTR;
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
            g.last_errno = tb_adapter_errno();
            cleanup_partial_init();
            return TB_ERR_RESIZE_IOCTL;
        }
    }
    if !(w > 0 && h > 0) {
        cleanup_partial_init();
        return TB_ERR_RESIZE_IOCTL;
    }
    g.width = w;
    g.height = h;

    // Terminal capability detection - use TERM env var (exact, then alias, then prefix)
    g.term_index = -1;
    var term_name: u8[64] = [0; 64];
    let rv = tb_adapter_get_term(term_name[0], 64);
    if rv > 0 {
        let tslice = term_name[0..rv];
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
    }
    if g.term_index < 0 {
        g.term_index = 0;
    }
    g.caps = builtin_terms[g.term_index].caps;

    // Build capability trie (re-creates root cleanly on re-init)
    let _ = cap_trie_build();

    // Initialize back and front cell buffers
    let _ = grow_cells(g.back, g.width, g.height);
    let _ = grow_cells(g.front, g.width, g.height);
    reset_cellbuf(g.back, 0x20, TB_DEFAULT, TB_DEFAULT);
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff);

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

    // Enter alternate screen, keypad transmit mode, hide cursor, clear screen
    if g.caps[TB_CAP_ENTER_CA].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_ENTER_CA]); }
    if g.caps[TB_CAP_ENTER_KEYPAD].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_ENTER_KEYPAD]); }
    if g.caps[TB_CAP_HIDE_CURSOR].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_HIDE_CURSOR]); }
    if g.caps[TB_CAP_CLEAR_SCREEN].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_CLEAR_SCREEN]); }
    let _ = outbuf_flush(g.wfd);

    return TB_OK;
}

fn tb_shutdown() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    // Restore terminal modes before restoring termios and closing fds
    if (g.input_mode & TB_INPUT_MOUSE) != 0 {
        let _ = outbuf_puts(TB_HARDCAP_EXIT_MOUSE);
    }
    if g.caps[TB_CAP_SHOW_CURSOR].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_SHOW_CURSOR]); }
    if g.caps[TB_CAP_SGR0].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_SGR0]); }
    if g.caps[TB_CAP_EXIT_KEYPAD].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_EXIT_KEYPAD]); }
    if g.caps[TB_CAP_EXIT_CA].len > 0 { let _ = outbuf_puts(g.caps[TB_CAP_EXIT_CA]); }
    let _ = outbuf_flush(g.wfd);

    // Clear SIGWINCH handler before closing pipe fds
    let _ = tb_adapter_clear_signwinch();

    if g.has_orig_tios != 0 {
        let _ = tb_adapter_restore_termios(g.rfd);
        g.has_orig_tios = 0;
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

    g.initialized = 0;
    g.ttyfd_open = 0;
    g.fd_owned = 0;
    return TB_OK;
}

// ===========================================================================
// TERMINFO & CAPABILITY TABLE
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
    "\x1b[?25l",               // civis
    "\x1b[H\x1b[2J",            // clear
    "\x1b(B\x1b[m",             // sgr0
    "\x1b[4m",                   // smul
    "\x1b[1m",                   // bold
    "\x1b[5m",                   // blink
    "\x1b[3m",                   // sitm
    "\x1b[7m",                   // rev
    "\x1b[?1h\x1b=",            // smkx
    "\x1b[?1l\x1b>",            // rmkx
    "\x1b[2m",                   // dim
    "\x1b[8m",                   // invis
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

struct term_entry {
    name: const u8[:],
    caps: const u8[:][TB_CAP__COUNT],
    alias: const u8[:],
}

const builtin_terms: term_entry[6] = [
    term_entry { name: "xterm", caps: xterm_caps, alias: "" },
    term_entry { name: "linux", caps: linux_caps, alias: "" },
    term_entry { name: "screen", caps: linux_caps, alias: "tmux" },
    term_entry { name: "rxvt-256color", caps: linux_caps, alias: "" },
    term_entry { name: "rxvt-unicode", caps: linux_caps, alias: "rxvt" },
    term_entry { name: "Eterm", caps: linux_caps, alias: "" },
];

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

fn tb_has_truecolor() -> i32 {
    return if gbl().output_mode == TB_OUTPUT_TRUECOLOR { 1 } else { 0 };
}

fn tb_has_egc() -> i32 {
    return TB_OPT_EGC;
}

fn tb_attr_width() -> i32 {
    return TB_OPT_ATTR_W;
}

fn tb_version() -> const u8[:] {
    return TB_VERSION_STR;
}

fn tb_last_errno() -> i32 {
    return gbl().last_errno;
}

fn tb_strerror(err: i32) -> const u8[:] {
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
// ESCAPE SEQUENCE PARSER (CAP TRIE + CSI + MOUSE) & EVENT POLLING
// ===========================================================================

fn cap_trie_add_node(c: u8) -> i32 {
    let g = gbl();
    let idx = g.cap_trie.len;
    g.cap_trie.push(cap_trie_node {
        c: c,
        first_child: -1,
        next_sibling: -1,
        is_leaf: 0,
        key: 0,
        mod: 0,
    });
    return idx as i32;
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
    g.cap_trie_root = cap_trie_add_node(0);

    // 1) Insert active terminal's key capabilities first so they take priority
    var ci = 0;
    for ci in TB_CAP__COUNT_KEYS {
        cap_trie_insert_seq(g.caps[ci], (0xffff - ci) as u16, 0);
    }

    // 2) Insert standard CSI/SS3 fallbacks common across modern terminals
    cap_trie_insert_seq("\x1b[A", TB_KEY_ARROW_UP, 0);
    cap_trie_insert_seq("\x1b[B", TB_KEY_ARROW_DOWN, 0);
    cap_trie_insert_seq("\x1b[C", TB_KEY_ARROW_RIGHT, 0);
    cap_trie_insert_seq("\x1b[D", TB_KEY_ARROW_LEFT, 0);
    cap_trie_insert_seq("\x1b[H", TB_KEY_HOME, 0);
    cap_trie_insert_seq("\x1b[F", TB_KEY_END, 0);
    cap_trie_insert_seq("\x1b[Z", TB_KEY_BACK_TAB, 0);

    // 3) Insert remaining built-in terminal key capabilities without overriding
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

fn parse_csi_modified(buf: const u8[:], end: i64, event: tb_event&) -> i32 {
    // Parse \x1b[p1;p2<final> or \x1b[p1<final>
    var p1: i32 = 0;
    var p2: i32 = 0;
    var has_p1: i32 = 0;
    var has_p2: i32 = 0;
    var in_p2: i32 = 0;
    var i: i64 = 2;
    while i < end {
        let ch = buf[i];
        if ch >= '0' && ch <= '9' {
            if in_p2 == 0 {
                p1 = p1 * 10 + (ch - '0');
                has_p1 = 1;
            } else {
                p2 = p2 * 10 + (ch - '0');
                has_p2 = 1;
            }
        } else if ch == ';' {
            if in_p2 != 0 { return 0; }
            in_p2 = 1;
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
        if p1 == 2 { key = TB_KEY_INSERT; }
        else if p1 == 3 { key = TB_KEY_DELETE; }
        else if p1 == 1 || p1 == 7 { key = TB_KEY_HOME; }
        else if p1 == 4 || p1 == 8 { key = TB_KEY_END; }
        else if p1 == 5 { key = TB_KEY_PGUP; }
        else if p1 == 6 { key = TB_KEY_PGDN; }
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

fn try_match_escape_buf(buf: const u8[:], event: tb_event&) -> i32 {
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
        return TB_ERR_NEED_MORE;
    }

    // 3) CSI sequence (\x1b[ ... final)
    if buf[1] == '[' {
        var end: i64 = 2;
        while end < buf.len {
            let b = buf[end];
            if b >= 0x40 && b <= 0x7e { break; }
            end = end + 1;
        }
        if end >= buf.len {
            if buf.len < 32 { return TB_ERR_NEED_MORE; }
            // Overlong malformed CSI: discard ESC
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

    // 4) SS3 sequence (\x1bO<ch>) not in trie
    if buf[1] == 'O' {
        if buf.len < 3 { return TB_ERR_NEED_MORE; }
        event.kind = 0;
        return 3;
    }

    // 5) TB_INPUT_ALT: ESC + char/control
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

    // 6) Fallback: bare ESC
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
    // Compact when position gets too large or logical end exceeds physical array
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

fn inbuf_copy_to(mbuf: u8[64]&) -> i64 {
    let g = gbl();
    var i: i64 = 0;
    while i < g.inbuf_len && i < 64 {
        let src = (g.inbuf_pos + i) as i32;
        guard src < g.inbuf.len else { break; }
        let idx = i as i32;
        mbuf[idx] = g.inbuf[src];
        i = i + 1;
    }
    return i;
}

fn inbuf_append(readbuf: const u8[64]&, nread: i64) {
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
            resize_back_cellbuf(g.back, g.width, g.height, g.fg, g.bg);
            let _ = grow_cells(g.front, g.width, g.height);
        }
    }
    // Invalidate front buffer and cached output state so next tb_present()
    // repaints every visible cell cleanly after terminal reflow/zoom.
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff);
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

    // If a lone ESC arrived, briefly wait (10ms) to coalesce split escape sequences
    if allow_esc_coalesce != 0 && g.inbuf_len == 1 && g.inbuf[g.inbuf_pos as i32] == 0x1b {
        let prv = tb_adapter_poll(g.rfd, 10);
        if prv > 0 {
            var more: u8[64] = [0; 64];
            let nr = tb_adapter_read(g.rfd, more[0], 64);
            if nr > 0 {
                inbuf_append(more, nr);
            }
        }
    }

    var mbuf: u8[64] = [0; 64];
    let mlen = inbuf_copy_to(mbuf);
    let first = mbuf[0];

    if first == 0x1b {
        let consumed = try_match_escape_buf(mbuf[0..mlen], event);
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

fn tb_peek_event(event: tb_event&, timeout_ms: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    // Phase 1: Try to parse bytes already in inbuf
    while g.inbuf_len > 0 {
        let drv = decode_inbuf_event(event, 0);
        if drv == TB_OK { return TB_OK; }
        if drv == TB_ERR_NEED_MORE { break; }
        // TB_ERR_NO_EVENT means a sequence was consumed & ignored; try remaining bytes
    }

    // Check if resize pipe already has a pending notification
    if drain_resize_and_fill(event) != 0 {
        return TB_OK;
    }

    // Phase 2: Poll for data on both TTY and resize pipe (handle EINTR cleanly)
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
                if timeout_ms >= 0 {
                    let elapsed = (tb_internal_now_ms() - start_ms) as i32;
                    remaining_ms = timeout_ms - elapsed;
                    if remaining_ms <= 0 { return TB_ERR_NO_EVENT; }
                }
                continue;
            }
            g.last_errno = tb_adapter_errno();
            return TB_ERR_POLL;
        }
        break;
    }

    // Check resize pipe first
    if tb_adapter_poll_is_in(1) != 0 {
        if drain_resize_and_fill(event) != 0 {
            return TB_OK;
        }
    }

    // Check TTY input
    if tb_adapter_poll_is_in(0) != 0 {
        var readbuf: u8[64] = [0; 64];
        let nread = tb_adapter_read(g.rfd, readbuf[0], 64);
        if nread == 0 {
            return TB_ERR_READ;
        }
        if nread < 0 {
            if tb_adapter_is_again() != 0 || tb_adapter_is_eintr() != 0 {
                return TB_ERR_NO_EVENT;
            }
            g.last_errno = tb_adapter_errno();
            return TB_ERR_READ;
        }

        inbuf_append(readbuf, nread);

        while g.inbuf_len > 0 {
            let drv = decode_inbuf_event(event, 1);
            if drv == TB_OK { return TB_OK; }
            if drv == TB_ERR_NEED_MORE { return TB_ERR_NO_EVENT; }
        }
        return TB_ERR_NO_EVENT;
    }

    if tb_adapter_poll_is_err(0) != 0 {
        return TB_ERR_READ;
    }

    return TB_ERR_NO_EVENT;
}

fn tb_poll_event(event: tb_event&) -> i32 {
    loop {
        let rv = tb_peek_event(event, -1);
        if rv != TB_ERR_NO_EVENT && rv != TB_ERR_NEED_MORE {
            return rv;
        }
    }
}

fn tb_get_fds(ttyfd: i32&, resizefd: i32&) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    ttyfd = g.rfd;
    resizefd = g.resize_pipefd[0];
    return TB_OK;
}

fn tb_set_input_mode(mode: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if mode == TB_INPUT_CURRENT { return g.input_mode; }
    // Accept bitmasks: ESC, ALT, MOUSE (but not ESC|ALT together)
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

fn tb_invalidate() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    reset_cellbuf(g.front, 0xffffffff, 0xffffffffffffffff, 0xffffffffffffffff);
    return TB_OK;
}

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

fn outbuf_puts(str: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    var i: i64 = 0;
    while i < str.len {
        let pos = g.outbuf_len;
        if pos < g.outbuf.len {
            g.outbuf[pos as i32] = str[i as i32];
        } else {
            g.outbuf.push(str[i as i32]);
        }
        g.outbuf_len = g.outbuf_len + 1;
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

// ===========================================================================
// OUTPUT / PRESENT
// ===========================================================================

fn send_sgr_color_fg(fg: uintattr_t, mode: i32) {
    if mode == TB_OUTPUT_NORMAL {
        var idx = fg & 0xff;
        var bright: i32 = if (fg & TB_BRIGHT) != 0 { 1 } else { 0 };
        if (fg & TB_HI_BLACK) != 0 && idx == 0 {
            idx = 1;
            bright = 1;
        }
        if idx >= 1 && idx <= 8 {
            let base: u64 = if bright != 0 { 90 } else { 30 };
            let _ = outbuf_puts("\x1b[");
            send_num(base + idx - 1);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_256 {
        let idx = fg & 0xff;
        if idx != 0 || (fg & TB_HI_BLACK) != 0 {
            let _ = outbuf_puts("\x1b[38;5;");
            send_num(idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_216 {
        let idx = fg & 0xff;
        if idx >= 1 && idx <= 216 {
            let _ = outbuf_puts("\x1b[38;5;");
            send_num(15 + idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_GRAYSCALE {
        let idx = fg & 0xff;
        if idx >= 1 && idx <= 24 {
            let _ = outbuf_puts("\x1b[38;5;");
            send_num(231 + idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_TRUECOLOR {
        let rgb = fg & 0xffffff;
        if rgb != 0 || (fg & TB_HI_BLACK) != 0 {
            let r = (rgb >> 16) & 0xff;
            let gch = (rgb >> 8) & 0xff;
            let b = rgb & 0xff;
            let _ = outbuf_puts("\x1b[38;2;");
            send_num(r);
            let _ = outbuf_puts(";");
            send_num(gch);
            let _ = outbuf_puts(";");
            send_num(b);
            let _ = outbuf_puts("m");
        }
    }
}

fn send_sgr_color_bg(bg: uintattr_t, mode: i32) {
    if mode == TB_OUTPUT_NORMAL {
        var idx = bg & 0xff;
        var bright: i32 = if (bg & TB_BRIGHT) != 0 { 1 } else { 0 };
        if (bg & TB_HI_BLACK) != 0 && idx == 0 {
            idx = 1;
            bright = 1;
        }
        if idx >= 1 && idx <= 8 {
            let base: u64 = if bright != 0 { 100 } else { 40 };
            let _ = outbuf_puts("\x1b[");
            send_num(base + idx - 1);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_256 {
        let idx = bg & 0xff;
        if idx != 0 || (bg & TB_HI_BLACK) != 0 {
            let _ = outbuf_puts("\x1b[48;5;");
            send_num(idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_216 {
        let idx = bg & 0xff;
        if idx >= 1 && idx <= 216 {
            let _ = outbuf_puts("\x1b[48;5;");
            send_num(15 + idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_GRAYSCALE {
        let idx = bg & 0xff;
        if idx >= 1 && idx <= 24 {
            let _ = outbuf_puts("\x1b[48;5;");
            send_num(231 + idx);
            let _ = outbuf_puts("m");
        }
    } else if mode == TB_OUTPUT_TRUECOLOR {
        let rgb = bg & 0xffffff;
        if rgb != 0 || (bg & TB_HI_BLACK) != 0 {
            let r = (rgb >> 16) & 0xff;
            let gch = (rgb >> 8) & 0xff;
            let b = rgb & 0xff;
            let _ = outbuf_puts("\x1b[48;2;");
            send_num(r);
            let _ = outbuf_puts(";");
            send_num(gch);
            let _ = outbuf_puts(";");
            send_num(b);
            let _ = outbuf_puts("m");
        }
    }
}

fn send_attr(fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    if fg == g.last_fg && bg == g.last_bg { return TB_OK; }

    // 1) Reset all SGR attributes and colors to a known state.
    let _ = outbuf_puts("\x1b[m");

    // 2) Attribute flags live in the high bits of `fg` (termbox convention).
    if fg & TB_BOLD        != 0 { let _ = outbuf_puts("\x1b[1m");  }
    if fg & TB_DIM         != 0 { let _ = outbuf_puts("\x1b[2m");  }
    if fg & TB_ITALIC      != 0 { let _ = outbuf_puts("\x1b[3m");  }
    if fg & TB_UNDERLINE   != 0 { let _ = outbuf_puts("\x1b[4m");  }
    if fg & TB_BLINK       != 0 { let _ = outbuf_puts("\x1b[5m");  }
    if fg & TB_REVERSE     != 0 { let _ = outbuf_puts("\x1b[7m");  }
    if fg & TB_INVISIBLE   != 0 { let _ = outbuf_puts("\x1b[8m");  }
    if fg & TB_STRIKEOUT   != 0 { let _ = outbuf_puts("\x1b[9m");  }
    if fg & TB_UNDERLINE_2 != 0 { let _ = outbuf_puts("\x1b[21m"); }
    if fg & TB_OVERLINE    != 0 { let _ = outbuf_puts("\x1b[53m"); }

    // 3) Foreground and background colors according to output_mode
    send_sgr_color_fg(fg, g.output_mode);
    send_sgr_color_bg(bg, g.output_mode);

    g.last_fg = fg;
    g.last_bg = bg;
    return TB_OK;
}

fn cell_cmp(a: tb_cell&, b: tb_cell&) -> i32 {
    if a.ch != b.ch || a.fg != b.fg || a.bg != b.bg { return 1; }
    return 0;
}

fn cell_copy(dst: tb_cell&, src: tb_cell&) -> i32 {
    dst.ch = src.ch;
    dst.fg = src.fg;
    dst.bg = src.bg;
    return TB_OK;
}

fn send_cursor_if(x: i32, y: i32) -> i32 {
    if x < 0 || y < 0 { return TB_OK; }
    let _ = outbuf_puts("\x1b[");
    send_num((y + 1) as u64);
    let _ = outbuf_puts(";");
    send_num((x + 1) as u64);
    let _ = outbuf_puts("H");
    return TB_OK;
}

fn send_char(ch: u32) -> i32 {
    var buf: u8[7] = [0, 0, 0, 0, 0, 0, 0];
    let len = tb_utf8_unicode_to_char(buf, ch);
    return outbuf_puts(buf[0..len]);
}

fn tb_present() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    var any_dirty: i32 = 0;
    var y = 0;
    for y in g.front.height {
        var x: i32 = 0;
        while x < g.front.width {
            let back_idx = y * g.back.width + x;
            let front_idx = y * g.front.width + x;
            let back = g.back.cells[back_idx];
            let front = g.front.cells[front_idx];

            let w = tb_wcwidth(back.ch);
            let w2: i32 = if w < 1 { 1 } else { w };

            if cell_cmp(back, front) != 0 {
                if any_dirty == 0 {
                    let _ = outbuf_puts("\x1b[m");
                    g.last_fg = TB_DEFAULT;
                    g.last_bg = TB_DEFAULT;
                    g.last_x = -1;
                    g.last_y = -1;
                    any_dirty = 1;
                }

                g.front.cells[front_idx] = back;

                let fg = back.fg;
                let bg = back.bg;
                if fg != g.last_fg || bg != g.last_bg {
                    let _ = send_attr(fg, bg);
                }

                if x != g.last_x + 1 || y != g.last_y {
                    let _ = send_cursor_if(x, y);
                }

                if w2 > 1 && x >= g.front.width - (w2 - 1) {
                    var i = x;
                    while i < g.front.width {
                        let _ = send_char(0x20);
                        i = i + 1;
                    }
                    g.last_x = g.front.width - 1;
                } else {
                    let _ = send_char(back.ch);
                    g.last_x = x + w2 - 1;
                }
                g.last_y = y;

                // Mark trailing cells of wide chars as invalid (start at i=1, NOT 0)
                var wi_off = 1;
                while wi_off < w2 {
                    let wi = x + wi_off;
                    if wi < g.front.width {
                        let wide_idx = y * g.front.width + wi;
                        g.front.cells[wide_idx].ch = 0xffffffff;
                        g.front.cells[wide_idx].fg = 0xffffffffffffffff;
                        g.front.cells[wide_idx].bg = 0xffffffffffffffff;
                    }
                    wi_off = wi_off + 1;
                }
            }
            x = x + w2;
        }
    }

    if g.cursor_x >= 0 && g.cursor_x < g.front.width &&
       g.cursor_y >= 0 && g.cursor_y < g.front.height &&
       (g.cursor_x != g.last_x + 1 || g.cursor_y != g.last_y) {
        let _ = send_cursor_if(g.cursor_x, g.cursor_y);
        g.last_x = g.cursor_x;
        g.last_y = g.cursor_y;
    }

    return outbuf_flush(g.wfd);
}

// ===========================================================================
// PRINTING FUNCTIONS
// ===========================================================================

fn tb_print(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32 {
    return tb_print_ex(x, y, fg, bg, str);
}

fn tb_print_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, str: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    guard x >= 0 && x < g.width && y >= 0 && y < g.height else {
        return TB_ERR_OUT_OF_BOUNDS;
    }

    var cx = x;
    var cy = y;

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
            cx = x;
            cy = cy + 1;
            if cy >= g.height { break; }
            continue;
        }

        // Skip characters past right margin until next newline
        if cx >= g.width {
            continue;
        }

        if tb_iswprint(uni) == 0 {
            uni = 0xfffd;
        }

        let w = tb_wcwidth(uni);
        let w2: i32 = if w < 1 { 1 } else { w };

        if cx >= 0 && cx < g.width && cy >= 0 && cy < g.height {
            let _ = tb_set_cell(cx, cy, uni, fg, bg);
        }

        cx = cx + w2;
    }

    return TB_OK;
}

// tb_send — append raw bytes to the output buffer.
fn tb_send(buf: const u8[:], nbuf: i64) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    return outbuf_nputs(buf, nbuf);
}

// tb_sendf — append a format string to the output buffer.
fn tb_sendf(fmt: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    return tb_send(fmt, fmt.len);
}

// tb_printf — print string at position.
fn tb_printf(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, fmt: const u8[:]) -> i32 {
    return tb_print_ex(x, y, fg, bg, fmt);
}

// tb_printf_ex — print string at position with width output.
fn tb_printf_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, fmt: const u8[:]) -> i32 {
    let rv = tb_print_ex(x, y, fg, bg, fmt);
    if rv != TB_OK { return rv; }
    out_w = 0;
    return TB_OK;
}
