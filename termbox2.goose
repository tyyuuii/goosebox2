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
    child_offset: i32,
    child_count: i32,
    is_leaf: i32,
    key: u16,
    mod: u8,
}

root struct tb_global {
    ttyfd: i32,
    rfd: i32,
    wfd: i32,
    ttyfd_open: i32,
    resize_pipefd: i32[2],
    width: i32,
    height: i32,
    cursor_x: i32,
    cursor_y: i32,
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
    cap_trie_children: i32[>..],
    inbuf: u8[>..],
    outbuf: u8[>..],
    back: cellbuf,
    front: cellbuf,
    orig_tios: u8[64],
    winsize: u8[16],
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

extern fn tb_adapter_tcgetattr(fd: i32, tios: u8[64]&) -> i32;
extern fn tb_adapter_tcsetattr(fd: i32, optional_actions: i32, tios: const u8[64]&) -> i32;
extern fn tb_adapter_ioctl_winsize(fd: i32, request: u64, ws: u8[16]&) -> i32;
extern fn tb_adapter_fcntl_getfl(fd: i32) -> i32;
extern fn tb_adapter_fcntl_setfl(fd: i32, flags: i32) -> i32;
extern fn tb_adapter_open_tty(path: const u8&, flags: i32) -> i32;
extern fn tb_adapter_close(fd: i32) -> i32;
extern fn tb_adapter_write(fd: i32, buf: const u8&, n: u64) -> i64;
extern fn tb_adapter_read(fd: i32, buf: u8&, n: u64) -> i64;
extern fn tb_adapter_poll(fd: i32, timeout_ms: i32) -> i32;
extern fn tb_adapter_pipe(pipefd: i32[2]&) -> i32;
extern fn tb_adapter_isatty(fd: i32) -> i32;
extern fn tb_adapter_errno() -> i32;
extern fn tb_adapter_ttyname(fd: i32) -> u64;
extern fn tb_adapter_vsnprintf(buf: u8[TB_OPT_PRINTF_BUF]&, bufsz: u64, fmt: const u8&, ap: u64) -> i32;
extern fn tb_adapter_setup_signwinch(pipe_fd: i32) -> i32;
extern fn tb_adapter_resize_notify(fd: i32) -> i32;
extern fn tb_adapter_set_raw_mode(fd: i32) -> i32;

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
    if len <= 0 || len > c.len { return -1; }
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
        return -1;
    }
    out = value;
    return len;
}

fn tb_utf8_unicode_to_char(out: u8[7]&, c: u32) -> i32 {
    var len: i32;
    var b0: u8 = 0;
    var b1: u8 = 0;
    var b2: u8 = 0;
    var b3: u8 = 0;
    if c < 0x80 {
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
    return len;
}

fn tb_iswprint(ch: u32) -> i32 {
    if ch < 0x20 { return 0; }
    if ch == 0x7f { return 0; }
    if ch >= 0x20 && ch <= 0x7e { return 1; }
    if ch >= 0xa0 && ch <= 0xd7ff { return 1; }
    if ch >= 0xe000 && ch <= 0xfdcf { return 1; }
    if ch >= 0xfdf0 && ch <= 0xfffd { return 1; }
    return 0;
}

fn tb_wcwidth(ch: u32) -> i32 {
    if ch < 0x20 { return -1; }
    if ch == 0x7f { return -1; }
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
    g.last_fg = fg;
    g.last_bg = bg;
    return TB_OK;
}

fn tb_clear() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    let fg = g.last_fg;
    let bg = g.last_bg;
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
    return tb_set_cell(x, y, ch, TB_DEFAULT, TB_DEFAULT);
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

// ===========================================================================
// TTY INITIALIZATION
// ===========================================================================

fn tb_init() -> i32 {
    return tb_init_file("/dev/tty");
}

fn tb_init_file(path: const u8[:]) -> i32 {
    let g = gbl();
    guard g.initialized == 0 else { return TB_ERR_INIT_ALREADY; }

    let pathbuf: u8[>..] = [];
    var i = 0;
    for i in path.len { pathbuf.push(path[i]); }
    pathbuf.push(0);

    let fd = tb_adapter_open_tty(pathbuf[0], O_RDWR);
    guard fd >= 0 else { return TB_ERR_INIT_OPEN; }

    return tb_init_fd(fd);
}

fn tb_init_fd(ttyfd: i32) -> i32 {
    return tb_init_rwfd(ttyfd, ttyfd);
}

fn tb_init_rwfd(rfd: i32, wfd: i32) -> i32 {
    let g = gbl();
    guard g.initialized == 0 else { return TB_ERR_INIT_ALREADY; }

    guard tb_adapter_isatty(rfd) != 0 else { return TB_ERR_NOT_INIT; }

    g.ttyfd = rfd;
    g.wfd = wfd;
    g.rfd = rfd;
    g.ttyfd_open = 1;

    let rv = tb_adapter_tcgetattr(rfd, g.orig_tios);
    guard rv == 0 else { return TB_ERR_TCGETATTR; }
    g.has_orig_tios = 1;

    let flags = tb_adapter_fcntl_getfl(rfd);
    guard flags >= 0 else { return TB_ERR_READ; }
    let rv2 = tb_adapter_fcntl_setfl(rfd, flags | O_NONBLOCK);
    guard rv2 == 0 else { return TB_ERR_READ; }

    let rv_raw = tb_adapter_set_raw_mode(rfd);
    guard rv_raw == 0 else { return TB_ERR_TCSETATTR; }

    var pipefd: i32[2] = [0, 0];
    let rv3 = tb_adapter_pipe(pipefd);
    guard rv3 == 0 else { return TB_ERR_RESIZE_PIPE; }
    g.resize_pipefd[0] = pipefd[0];
    g.resize_pipefd[1] = pipefd[1];

    let rv4 = tb_adapter_ioctl_winsize(rfd, TIOCGWINSZ, g.winsize);
    guard rv4 == 0 else { return TB_ERR_RESIZE_IOCTL; }
    g.height = g.winsize[0] | (g.winsize[1] << 8);
    g.width = g.winsize[2] | (g.winsize[3] << 8);
    guard g.width > 0 && g.height > 0 else { return TB_ERR_RESIZE_IOCTL; }

    // Initialize back and front cell buffers
    let _ = grow_cells(g.back, g.width, g.height);
    let _ = grow_cells(g.front, g.width, g.height);

    let rv5 = tb_adapter_setup_signwinch(g.resize_pipefd[1]);
    guard rv5 == 0 else { return TB_ERR_RESIZE_SIGACTION; }

    g.input_mode = TB_INPUT_ESC;
    g.output_mode = TB_OUTPUT_NORMAL;
    g.initialized = 1;

    return TB_OK;
}

fn tb_shutdown() -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    if g.has_orig_tios != 0 {
        let _ = tb_adapter_tcsetattr(g.rfd, 0, g.orig_tios);
    }

    if g.ttyfd_open != 0 {
        let _ = tb_adapter_close(g.ttyfd);
    }
    let _ = tb_adapter_close(g.resize_pipefd[0]);
    let _ = tb_adapter_close(g.resize_pipefd[1]);

    g.initialized = 0;
    g.has_orig_tios = 0;
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
    "\x1b\x09",      // kcbt
    "",              // smcup
    "",              // rmcup
    "\x1b[?25h\x1b[?0c",  // cnorm
    "\x1b[?25l\x1b[?1c",  // civis
    "\x1b[H\x1b[J",       // clear
    "\x1b[m\x0f",         // sgr0
    "\x1b[4m",             // smul
    "\x1b[1m",             // bold
    "\x1b[5m",             // blink
    "",                     // sitm
    "\x1b[7m",             // rev
    "",                     // smkx
    "",                     // rmkx
    "\x1b[2m",             // dim
    "",                     // invis
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
        let a = builtin_terms[i].name;
        let b = name;
        if a.len == b.len {
            var j = 0;
            var matched = 1;
            for j in a.len {
                if a[j] != b[j] { matched = 0; }
            }
            if matched != 0 { return i as i32; }
        }
    }
    return -1;
}

fn tb_has_truecolor() -> i32 {
    return 1;
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
    return "termbox2 error";
}

// ===========================================================================
// ESCAPE SEQUENCE PARSER & EVENT POLLING
// ===========================================================================

fn cap_trie_add_node(c: u8) -> i32 {
    let g = gbl();
    let idx = g.cap_trie.len;
    g.cap_trie.push(cap_trie_node {
        c: c,
        child_offset: 0,
        child_count: 0,
        is_leaf: 0,
        key: 0,
        mod: 0,
    });
    return idx as i32;
}

fn cap_trie_find_child(node: i32, c: u8) -> i32 {
    let g = gbl();
    let n = &g.cap_trie[node];
    var i = 0;
    for i in n.child_count {
        let child_idx = g.cap_trie_children[n.child_offset + i];
        if g.cap_trie[child_idx].c == c {
            return child_idx;
        }
    }
    return -1;
}

fn cap_trie_add_child(node: i32, c: u8) -> i32 {
    let existing = cap_trie_find_child(node, c);
    if existing >= 0 { return existing; }
    let new_idx = cap_trie_add_node(c);
    let g = gbl();
    let n = &g.cap_trie[node];
    let off = g.cap_trie_children.len;
    g.cap_trie_children.push(0);
    g.cap_trie_children[off] = new_idx;
    g.cap_trie[node].child_count = n.child_count + 1;
    if n.child_count == 0 {
        g.cap_trie[node].child_offset = off as i32;
    }
    return new_idx;
}

fn cap_trie_build() -> i32 {
    cap_trie_add_node(0);
    var ti = 0;
    for ti in builtin_terms.len {
        let entry = builtin_terms[ti];
        var ci = 0;
        for ci in TB_CAP__COUNT {
            let caps = entry.caps;
            let seq = caps[ci];
            if seq.len == 0 { continue; }
            var node: i32 = 0;
            var si = 0;
            for si in seq.len {
                node = cap_trie_add_child(node, seq[si]);
            }
            let g = gbl();
            g.cap_trie[node].is_leaf = 1;
            g.cap_trie[node].key = ci as u16;
            g.cap_trie[node].mod = 0;
        }
    }
    return TB_OK;
}

fn try_match_escape_buf(buf: const u8[:], event: tb_event&) -> i32 {
    guard buf.len > 0 else { return 0; }
    guard buf[0] == 0x1b else { return 0; }

    if buf.len == 1 {
        event.kind = TB_EVENT_KEY;
        event.mod = 0;
        event.key = TB_KEY_ESC;
        event.ch = 0;
        return 1;
    }

    // ESC followed by an introducer: '[' (CSI) or 'O' (SS3)
    let intro = buf[1];
    if intro != 0x5b && intro != 0x4f {
        // Not CSI or SS3: ESC by itself
        event.kind = TB_EVENT_KEY;
        event.mod = 0;
        event.key = TB_KEY_ESC;
        event.ch = 0;
        return 1;
    }

    // Find the final byte (0x40-0x7e) that terminates the sequence.
    // Start at index 2 to skip the introducer byte (0x5b '[' or 0x4f 'O')
    // which is itself in the 0x40-0x7e range.
    var end = 2;
    while end < buf.len {
        let b = buf[end];
        if b >= 0x40 && b <= 0x7e { break; }
        end = end + 1;
    }
    if end >= buf.len { return TB_ERR_NEED_MORE; }

    let seq_len = end + 1;

    // Match against every builtin capability sequence.
    var ti = 0;
    for ti in builtin_terms.len {
        let entry = builtin_terms[ti];
        var ci = 0;
        for ci in TB_CAP__COUNT {
            let caps = entry.caps;
            let seq = caps[ci];
            if seq.len == 0 { continue; }
            if seq.len != seq_len { continue; }
            var matched = 1;
            var k = 0;
            for k in seq.len {
                if seq[k] != buf[k] { matched = 0; }
            }
            if matched != 0 {
                // Key codes are 0xffff - cap_index (e.g. cap 18 = arrow up → key 0xffed)
                event.kind = TB_EVENT_KEY;
                event.mod = 0;
                event.key = (0xffff - ci) as u16;
                event.ch = 0;
                return seq_len as i32;
            }
        }
    }

    // No capability matched; treat as ESC.
    event.kind = TB_EVENT_KEY;
    event.mod = 0;
    event.key = TB_KEY_ESC;
    event.ch = 0;
    return 1;
}

fn tb_peek_event(event: tb_event&, timeout_ms: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }

    // First, try to parse any bytes already in inbuf
    if g.inbuf.len > 0 {
        let consumed = try_match_escape_buf(g.inbuf, event);
        if consumed > 0 {
            return TB_OK;
        }
        // Regular character from inbuf
        event.kind = TB_EVENT_KEY;
        event.mod = 0;
        event.key = 0;
        event.ch = g.inbuf[0];
        return TB_OK;
    }

    // Poll the TTY for available data
    let poll_rv = tb_adapter_poll(g.rfd, timeout_ms);
    if poll_rv <= 0 {
        return TB_ERR_NO_EVENT;
    }

    // Read available bytes from TTY into a local buffer
    let readbuf: u8[64];
    var i = 0;
    for i in 64 { readbuf[i] = 0; }
    let nread = tb_adapter_read(g.rfd, readbuf[0], 64);
    if nread <= 0 {
        return TB_ERR_NO_EVENT;
    }

    // Process the bytes we read
    let consumed = try_match_escape_buf(readbuf[0..nread], event);
    if consumed == TB_ERR_NEED_MORE {
        // Incomplete escape sequence: drop it (no buffering yet)
        return TB_ERR_NO_EVENT;
    }
    if consumed > 0 {
        return TB_OK;
    }
    // Regular character
    event.kind = TB_EVENT_KEY;
    event.mod = 0;
    event.key = 0;
    event.ch = readbuf[0];
    return TB_OK;
}

fn tb_poll_event(event: tb_event&) -> i32 {
    return tb_peek_event(event, -1);
}

fn tb_get_fds(ttyfd: i32&, resizefd: i32&) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    ttyfd = g.ttyfd;
    resizefd = g.resize_pipefd[0];
    return TB_OK;
}

fn tb_set_input_mode(mode: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if mode == TB_INPUT_CURRENT { return g.input_mode; }
    g.input_mode = mode;
    return TB_OK;
}

fn tb_set_output_mode(mode: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    if mode == TB_OUTPUT_CURRENT { return g.output_mode; }
    g.output_mode = mode;
    return TB_OK;
}

fn tb_invalidate() -> i32 {
    return TB_OK;
}

fn tb_set_cursor(cx: i32, cy: i32) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    g.cursor_x = cx;
    g.cursor_y = cy;
    return TB_OK;
}

fn tb_hide_cursor() -> i32 {
    return TB_OK;
}

// ===========================================================================
// OUTPUT BUFFER
// ===========================================================================

// outbuf_nputs — write n bytes directly to the TTY.
fn outbuf_nputs(buf: const u8[:], n: i64) -> i32 {
    let g = gbl();
    guard g.initialized != 0 else { return TB_ERR_NOT_INIT; }
    let _ = tb_adapter_write(g.wfd, buf[0], n as u64);
    return TB_OK;
}

// outbuf_puts — append bytes to the output buffer.
fn outbuf_puts(str: const u8[:]) -> i32 {
    return outbuf_nputs(str, str.len);
}

// outbuf_flush — clear the output buffer (actual write to TTY needs FFI wrapper).
fn outbuf_flush(fd: i32) -> i32 {
    // Writes happen directly in outbuf_nputs; flush is a no-op.
    return TB_OK;
}

// convert_num — write an unsigned integer as decimal digits into buf.
// Returns the number of digits written.
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

// ===========================================================================
// OUTPUT / PRESENT
// ===========================================================================

fn send_attr(fg: uintattr_t, bg: uintattr_t) -> i32 {
    let g = gbl();
    if fg == g.last_fg && bg == g.last_bg { return TB_OK; }
    let _ = outbuf_puts("\x1b[m");
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
    let g = gbl();
    if x < 0 || y < 0 { return TB_OK; }
    let nbuf: u8[32] = [0; 32];
    let _ = outbuf_puts("\x1b[");
    let len_y = convert_num((y + 1) as u64, nbuf);
    let _ = outbuf_puts(nbuf[0..len_y]);
    let _ = outbuf_puts(";");
    let len_x = convert_num((x + 1) as u64, nbuf);
    let _ = outbuf_puts(nbuf[0..len_x]);
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

    g.last_x = -1;
    g.last_y = -1;

    var y = 0;
    for y in g.front.height {
        var x = 0;
        while x < g.front.width {
            let back_idx = y * g.back.width + x;
            let front_idx = y * g.front.width + x;
            let back = g.back.cells[back_idx];
            let front = g.front.cells[front_idx];

            let w = tb_wcwidth(back.ch);
            let w2: i32;
            if w < 1 { w2 = 1; } else { w2 = w; }

            if cell_cmp(back, front) != 0 {
                // copy back to front
                g.front.cells[front_idx] = back;

                // send attributes
                // send_attr equivalent
                let fg = back.fg;
                let bg = back.bg;
                let fg_changed = fg != g.last_fg;
                let bg_changed = bg != g.last_bg;
                if fg_changed || bg_changed {
                    let _ = send_attr(fg, bg);
                }

                // send cursor position
                // send_cursor_if(x, y)
                let _ = send_cursor_if(x as i32, y);
                g.last_x = x as i32;
                g.last_y = y;

                // send character
                if w2 > 1 && x >= g.front.width - (w2 - 1) {
                    // not enough room, send spaces
                    var i = x;
                    for i in g.front.width {
                        // send space
                    }
                } else {
                    let _ = send_char(back.ch);
                }

                // mark wide-char cells as invalid
                var i = 1;
                for i in w2 {
                    if i >= w2 { break; }
                    let wi = x + i;
                    if wi < g.front.width {
                        let wide_idx = y * g.front.width + wi;
                        g.front.cells[wide_idx].ch = 0xffffffff;
                        g.front.cells[wide_idx].fg = 0xffffffffffffffff;
                        g.front.cells[wide_idx].bg = 0xffffffffffffffff;
                    }
                }
            }
            x = x + w2;
        }
    }

    let _ = send_cursor_if(g.cursor_x, g.cursor_y);
    g.last_x = g.cursor_x;
    g.last_y = g.cursor_y;

    let _ = outbuf_flush(g.wfd);

    return TB_OK;
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
            // invalid UTF-8, skip
            si = si + 1;
            continue;
        }
        si = si + rv;

        if uni == 0x0a { // newline
            cx = x;
            cy = cy + 1;
            continue;
        }

        if tb_iswprint(uni) == 0 {
            uni = 0xfffd;
        }

        let w = tb_wcwidth(uni);
        let w2: i32;
        if w < 1 { w2 = 1; } else { w2 = w; }

        if cx >= 0 && cx < g.width && cy >= 0 && cy < g.height {
            let _ = tb_set_cell(cx, cy, uni, fg, bg);
        }

        cx = cx + w2;
        if cx >= g.width {
            cx = x;
            cy = cy + 1;
        }
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

// tb_printf — print formatted string at position.
fn tb_printf(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, fmt: const u8[:]) -> i32 {
    return tb_print_ex(x, y, fg, bg, fmt);
}

// tb_printf_ex — print formatted string at position with width output.
fn tb_printf_ex(x: i32, y: i32, fg: uintattr_t, bg: uintattr_t, out_w: u64&, fmt: const u8[:]) -> i32 {
    let rv = tb_print_ex(x, y, fg, bg, fmt);
    if rv != TB_OK { return rv; }
    return TB_OK;
}

