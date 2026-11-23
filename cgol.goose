// cgol.goose — Conway's Game of Life in Goose using termbox2
//
// Build:  goose build cgol.goose -o cgol
// Run:    ./cgol (requires real TTY; run in Termux)
//
// Controls:
//   HJKL / WASD / Arrow keys   move cursor
//   X / Space / Left click     toggle cell at cursor
//   ENTER / R                  force run
//   S / SPACE                  single step (when paused)
//   C                          clear grid
//   Z                          randomize (~50% alive)
//   G                          place Glider at cursor
//   B                          place Block at cursor
//   b                          place Blinker at cursor
//   T                          place Toad at cursor
//   O                          place R-pentomino at cursor
//   A                          place Acorn at cursor
//   D                          place Diehard at cursor
//   L                          place Lightweight Spaceship (LWSS) at cursor
//   P                          toggle pause/run
//   Q / ESC                    quit

import termbox2;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const CH_BLOCK: u32 = 0x2588;  // █
const CH_CURSOR: u32 = 0x2588; // █ (cursor over dead)
const CH_CURSOR_ALIVE: u32 = 0x2591; // ░ (cursor over alive)
const CH_EMPTY: u32 = ' ';

// ---------------------------------------------------------------------------
// World state (root struct so it can own multiple resizable arrays)
// ---------------------------------------------------------------------------

root struct cgol_world {
    width: i32,
    height: i32,
    cur: u8[>..],      // current generation
    nxt: u8[>..],      // next generation
    gen: i64,
    running: i32,      // auto-run on/off
    cx: i32,           // cursor x
    cy: i32,           // cursor y
    speed_ms: i32,     // animation speed (simulation interval)
    // Performance tracking
    frame_count: i64,
    last_fps_update: i64,
    current_fps: i32,
    frame_time_ms: i32,
    skip_frame: i32,
    last_frame_skipped: i32,
}

var world: cgol_world;

// ---------------------------------------------------------------------------
// Pattern definitions: each pattern is a list of Point offsets from origin
// ---------------------------------------------------------------------------

struct Point { x: i32, y: i32 }

fn pattern_glider(pts: Point[>..]&) {
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 2, y: 1 });
    pts.push(Point { x: 0, y: 2 });
    pts.push(Point { x: 1, y: 2 });
    pts.push(Point { x: 2, y: 2 });
}

fn pattern_block(pts: Point[>..]&) {
    pts.push(Point { x: 0, y: 0 });
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 0, y: 1 });
    pts.push(Point { x: 1, y: 1 });
}

fn pattern_blinker(pts: Point[>..]&) {
    pts.push(Point { x: 0, y: 0 });
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 2, y: 0 });
}

fn pattern_toad(pts: Point[>..]&) {
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 2, y: 0 });
    pts.push(Point { x: 3, y: 0 });
    pts.push(Point { x: 0, y: 1 });
    pts.push(Point { x: 1, y: 1 });
    pts.push(Point { x: 2, y: 1 });
}

fn pattern_rpentomino(pts: Point[>..]&) {
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 2, y: 0 });
    pts.push(Point { x: 0, y: 1 });
    pts.push(Point { x: 1, y: 1 });
    pts.push(Point { x: 1, y: 2 });
}

fn pattern_acorn(pts: Point[>..]&) {
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 3, y: 1 });
    pts.push(Point { x: 0, y: 2 });
    pts.push(Point { x: 1, y: 2 });
    pts.push(Point { x: 4, y: 2 });
    pts.push(Point { x: 5, y: 2 });
    pts.push(Point { x: 6, y: 2 });
}

fn pattern_diehard(pts: Point[>..]&) {
    pts.push(Point { x: 6, y: 0 });
    pts.push(Point { x: 0, y: 1 });
    pts.push(Point { x: 1, y: 1 });
    pts.push(Point { x: 1, y: 2 });
    pts.push(Point { x: 5, y: 2 });
    pts.push(Point { x: 6, y: 2 });
    pts.push(Point { x: 7, y: 2 });
}

fn pattern_lwss(pts: Point[>..]&) {
    pts.push(Point { x: 1, y: 0 });
    pts.push(Point { x: 4, y: 0 });
    pts.push(Point { x: 0, y: 1 });
    pts.push(Point { x: 0, y: 2 });
    pts.push(Point { x: 4, y: 2 });
    pts.push(Point { x: 0, y: 3 });
    pts.push(Point { x: 1, y: 3 });
    pts.push(Point { x: 2, y: 3 });
    pts.push(Point { x: 3, y: 3 });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn idx(x: i32, y: i32) -> i32 {
    return y * world.width + x;
}

fn in_bounds(x: i32, y: i32) -> bool {
    return x >= 0 && x < world.width && y >= 0 && y < world.height;
}

fn clamp_x(x: i32) -> i32 {
    if x < 0 { return 0; }
    if x >= world.width { return world.width - 1; }
    return x;
}

fn grid_height() -> i32 {
    // Reserve 2 rows for status bar
    if world.height >= 3 { return world.height - 2; }
    return 0;
}

fn clamp_y(y: i32) -> i32 {
    let gh = grid_height();
    if gh <= 0 { return 0; }
    if y < 0 { return 0; }
    if y >= gh { return gh - 1; }
    return y;
}

// ---------------------------------------------------------------------------
// Initialization / shutdown
// ---------------------------------------------------------------------------

fn cgol_init() -> i32 {
    let rv = tb_init();
    if rv != TB_OK { return rv; }

    world.width = tb_width();
    world.height = tb_height();

    // Allocate grids
    let total = world.width * world.height;
    var i = 0;
    while i < total {
        world.cur.push(0);
        world.nxt.push(0);
        i = i + 1;
    }

    // Randomize ~50% alive in visible grid only
    let gh = grid_height();
    var seed: u64 = 0x123456789ABCDEF ^ (tb_adapter_now_ms() as u64);
    if seed == 0 { seed = 0x123456789ABCDEF; }
    var ry: i32 = 0;
    while ry < gh {
        var rx: i32 = 0;
        while rx < world.width {
            // xorshift64*
            seed ^= seed >> 12;
            seed ^= seed << 25;
            seed ^= seed >> 27;
            let r = (seed * 0x2545F4914F6CDD1D) as u32;
            world.cur[idx(rx, ry)] = if (r & 1) != 0 { 1 } else { 0 };
            rx = rx + 1;
        }
        ry = ry + 1;
    }

    world.gen = 0;
    world.running = 1;
    world.cx = world.width / 2;
    world.cy = grid_height() / 2;
    world.speed_ms = 60;  // 60ms = ~16 FPS
    world.frame_count = 0;
    world.last_fps_update = tb_adapter_now_ms();
    world.current_fps = 0;
    world.frame_time_ms = 0;
    world.skip_frame = 0;

    let _ = tb_set_input_mode(TB_INPUT_ESC | TB_INPUT_MOUSE);
    let _ = tb_hide_cursor();
    return TB_OK;
}

fn cgol_shutdown() {
    let _ = tb_shutdown();
}

// ---------------------------------------------------------------------------
// Core simulation
// ---------------------------------------------------------------------------

fn count_neighbors(x: i32, y: i32) -> i32 {
    let w = world.width;
    let h = grid_height();
    if w <= 0 || h <= 0 { return 0; }
    var n: i32 = 0;

    // Toroidal wrapping over visible grid: (y + dy + h) % h, (x + dx + w) % w
    var dy: i32 = -1;
    while dy <= 1 {
        var dx: i32 = -1;
        while dx <= 1 {
            if dx != 0 || dy != 0 {
                let nx = (x + dx + w) % w;
                let ny = (y + dy + h) % h;
                n = n + world.cur[idx(nx, ny)];
            }
            dx = dx + 1;
        }
        dy = dy + 1;
    }
    return n;
}

fn cgol_step() {
    let w = world.width;
    let h = grid_height();
    if w <= 0 || h <= 0 { return; }
    var y: i32 = 0;
    while y < h {
        var x: i32 = 0;
        while x < w {
            let i = idx(x, y);
            let alive = world.cur[i];
            let n = count_neighbors(x, y);
            // B3/S23: birth at 3, survive at 2 or 3
            if alive != 0 {
                world.nxt[i] = if n == 2 || n == 3 { 1 } else { 0 };
            } else {
                world.nxt[i] = if n == 3 { 1 } else { 0 };
            }
            x = x + 1;
        }
        y = y + 1;
    }

    // Copy nxt into cur, zero nxt (visible grid)
    let total = w * h;
    var k: i32 = 0;
    while k < total {
        world.cur[k] = world.nxt[k];
        world.nxt[k] = 0;
        k = k + 1;
    }
    world.gen = world.gen + 1;
}

// ---------------------------------------------------------------------------
// Grid manipulation
// ---------------------------------------------------------------------------

fn cgol_toggle(x: i32, y: i32) {
    if !in_bounds(x, y) { return; }
    let i = idx(x, y);
    world.cur[i] = if world.cur[i] != 0 { 0 } else { 1 };
}

fn cgol_clear() {
    let total = world.width * world.height;
    var i: i32 = 0;
    while i < total {
        world.cur[i] = 0;
        world.nxt[i] = 0;
        i = i + 1;
    }
    world.gen = 0;
}

fn cgol_randomize() {
    cgol_clear();
    let gh = grid_height();
    if world.width <= 0 || gh <= 0 { return; }
    // Mix in current time for different boards on each call
    var seed: u64 = (world.gen as u64 + 0x9E3779B97F4A7C15) ^ (tb_adapter_now_ms() as u64);
    if seed == 0 { seed = 0x9E3779B97F4A7C15; }
    var ry: i32 = 0;
    while ry < gh {
        var rx: i32 = 0;
        while rx < world.width {
            seed ^= seed >> 12;
            seed ^= seed << 25;
            seed ^= seed >> 27;
            let r = (seed * 0x2545F4914F6CDD1D) as u32;
            world.cur[idx(rx, ry)] = if (r & 1) != 0 { 1 } else { 0 };
            rx = rx + 1;
        }
        ry = ry + 1;
    }
    world.gen = 0;
}

fn cgol_place_pattern(name: const u8[:], px: i32, py: i32) {
    // Build pattern points
    var pts: Point[>..] = [];

    // Match pattern name (need at least 2 chars for prefix)
    if name.len < 2 { return; }

    if name[0] == 'g' && name[1] == 'l' {        // glider
        pattern_glider(pts);
    } else if name[0] == 'b' && name[1] == 'k' { // blinker (check before block)
        pattern_blinker(pts);
    } else if name[0] == 'b' && name[1] == 'l' { // block
        pattern_block(pts);
    } else if name[0] == 't' && name[1] == 'o' { // toad
        pattern_toad(pts);
    } else if name[0] == 'r' {                   // r-pentomino
        pattern_rpentomino(pts);
    } else if name[0] == 'a' {                   // acorn
        pattern_acorn(pts);
    } else if name[0] == 'd' {                   // diehard
        pattern_diehard(pts);
    } else if name[0] == 'l' {                   // lwss
        pattern_lwss(pts);
    } else {
        return;
    }

    var j: i32 = 0;
    for j in pts.len {
        let dx = pts[j].x;
        let dy = pts[j].y;
        // Toroidal wrapping to match count_neighbors behavior
        let x = ((px + dx) % world.width + world.width) % world.width;
        let gh = grid_height();
        if gh <= 0 { continue; }
        let y = ((py + dy) % gh + gh) % gh;
        world.cur[idx(x, y)] = 1;
    }
}

// ---------------------------------------------------------------------------
// Resize handling
// ---------------------------------------------------------------------------

fn cgol_resize() {
    let old_w = world.width;
    let old_h = world.height;
    let new_w = tb_width();
    let new_h = tb_height();
    let new_total = new_w * new_h;

    // Allocate new grid
    var new_cur: u8[>..] = [];
    var i = 0;
    while i < new_total {
        new_cur.push(0);
        i = i + 1;
    }

    // Copy overlapping region from old to new (preserving pattern)
    let copy_w = if old_w < new_w { old_w } else { new_w };
    let copy_h = if old_h < new_h { old_h } else { new_h };
    var y: i32 = 0;
    while y < copy_h {
        var x: i32 = 0;
        while x < copy_w {
            new_cur[y * new_w + x] = world.cur[y * old_w + x];
            x = x + 1;
        }
        y = y + 1;
    }

    // Update dimensions
    world.width = new_w;
    world.height = new_h;

    // Clamp cursor
    world.cx = clamp_x(world.cx);
    world.cy = clamp_y(world.cy);

    // Replace grids
    while world.cur.len < new_total {
        world.cur.push(0);
        world.nxt.push(0);
    }
    i = 0;
    while i < new_total {
        world.cur[i] = new_cur[i];
        world.nxt[i] = 0;
        i = i + 1;
    }
    // If smaller, extra elements are left zeroed but logically unused
    // (borrow checker prevents pop on global resizable arrays)

    let _ = tb_invalidate();
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

fn cgol_draw() {
    let _ = tb_clear();

    let w = world.width;
    let h = world.height;
    let status_y = h - 1;
    let grid_h = if status_y >= 1 { status_y - 1 } else { h };

    // Draw alive cells (only in grid area, not status rows)
    var y: i32 = 0;
    while y < grid_h {
        var x: i32 = 0;
        while x < w {
            let i = idx(x, y);
            if world.cur[i] != 0 {
                let _ = tb_set_cell(x, y, CH_BLOCK, TB_GREEN | TB_BOLD, TB_DEFAULT);
            }
            x = x + 1;
        }
        y = y + 1;
    }

    // Draw cursor
    if in_bounds(world.cx, world.cy) && world.cy < grid_h {
        let i = idx(world.cx, world.cy);
        let ch = if world.cur[i] != 0 { CH_CURSOR_ALIVE } else { CH_CURSOR };
        let fg = if world.cur[i] != 0 { TB_BLACK } else { TB_WHITE };
        let bg = if world.cur[i] != 0 { TB_GREEN | TB_BOLD } else { TB_BLUE };
        let _ = tb_set_cell(world.cx, world.cy, ch, fg as u64, bg as u64);
    }

    // Status lines at bottom (2 rows: stats on status_y-1, help on status_y)
    if status_y >= 1 {
        // Line 1: stats - build sequentially to avoid overlap/wrap
        var col: i32 = 0;
        let w = world.width;
        
        // Gen
        let _ = tb_print(col, status_y - 1, TB_CYAN, TB_DEFAULT, "Gen: ");
        col = col + 5;
        var gen_str: u8[32] = [0; 32];
        var len: i32 = 0;
        var v = world.gen;
        if v == 0 {
            gen_str[0] = 0x30;
            len = 1;
        } else {
            while v > 0 {
                gen_str[len] = (0x30 + (v % 10)) as u8;
                v = v / 10;
                len = len + 1;
            }
            var i: i32 = 0;
            for i in len / 2 {
                let tmp = gen_str[i];
                gen_str[i] = gen_str[len - 1 - i];
                gen_str[len - 1 - i] = tmp;
            }
        }
        let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, gen_str[0..len]);
        col = col + len + 1;
        
        // Running
        let _ = tb_print(col, status_y - 1, TB_CYAN, TB_DEFAULT, "Running: ");
        col = col + 9;
        let _ = tb_print(col, status_y - 1,
            if world.running != 0 { TB_GREEN | TB_BOLD } else { TB_WHITE },
            TB_DEFAULT,
            if world.running != 0 { "ON " } else { "OFF" });
        col = col + 4;
        
        // Speed
        let _ = tb_print(col, status_y - 1, TB_CYAN, TB_DEFAULT, "Speed: ");
        col = col + 7;
        var spd_str: u8[16] = [0; 16];
        var spd_len: i32 = 0;
        var sv = world.speed_ms;
        if sv == 0 {
            spd_str[0] = 'M'; spd_str[1] = 'A'; spd_str[2] = 'X'; spd_len = 3;
        } else {
            while sv > 0 {
                spd_str[spd_len] = (0x30 + (sv % 10)) as u8;
                sv = sv / 10;
                spd_len = spd_len + 1;
            }
            var i: i32 = 0;
            for i in spd_len / 2 {
                let tmp = spd_str[i];
                spd_str[i] = spd_str[spd_len - 1 - i];
                spd_str[spd_len - 1 - i] = tmp;
            }
        }
        let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, spd_str[0..spd_len]);
        col = col + spd_len;
        if world.speed_ms > 0 {
            let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, "ms");
            col = col + 2;
        }
        
        // Pause indicator
        if world.running == 0 && col + 10 < w {
            let _ = tb_print(col, status_y - 1, TB_RED | TB_BOLD, TB_DEFAULT, " [PAUSED]");
            col = col + 9;
        }
        
        // FPS
        if world.current_fps > 0 && col + 10 < w {
            let _ = tb_print(col, status_y - 1, TB_CYAN, TB_DEFAULT, " FPS: ");
            col = col + 6;
            var fps_str: u8[16] = [0; 16];
            var fps_len: i32 = 0;
            var fv = world.current_fps;
            while fv > 0 {
                fps_str[fps_len] = (0x30 + (fv % 10)) as u8;
                fv = fv / 10;
                fps_len = fps_len + 1;
            }
            var i: i32 = 0;
            for i in fps_len / 2 {
                let tmp = fps_str[i];
                fps_str[i] = fps_str[fps_len - 1 - i];
                fps_str[fps_len - 1 - i] = tmp;
            }
            let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, fps_str[0..fps_len]);
            col = col + fps_len;
        }
        
        // Frame time
        if world.frame_time_ms > 0 && col + 8 < w {
            let _ = tb_print(col, status_y - 1, TB_CYAN, TB_DEFAULT, " FT: ");
            col = col + 5;
            var ft_str: u8[16] = [0; 16];
            var ft_len: i32 = 0;
            var ft = world.frame_time_ms;
            while ft > 0 {
                ft_str[ft_len] = (0x30 + (ft % 10)) as u8;
                ft = ft / 10;
                ft_len = ft_len + 1;
            }
            var i: i32 = 0;
            for i in ft_len / 2 {
                let tmp = ft_str[i];
                ft_str[i] = ft_str[ft_len - 1 - i];
                ft_str[ft_len - 1 - i] = tmp;
            }
            let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, ft_str[0..ft_len]);
            col = col + ft_len;
            let _ = tb_print(col, status_y - 1, TB_WHITE, TB_DEFAULT, "ms");
            col = col + 2;
        }
        
        // Skip indicator (show if last frame was skipped)
        if world.last_frame_skipped != 0 && col + 8 < w {
            let _ = tb_print(col, status_y - 1, TB_RED | TB_BOLD, TB_DEFAULT, " [SKIP]");
        }
        
        // Line 2: help text - shortened to fit 80 cols
        let _ = tb_print(0, status_y, TB_YELLOW, TB_DEFAULT,
            "HJKL/WASD/Arrows:move X/Space:toggle S:step C:clear Z:rand G:glider B:block b:blink T:toad O:rpent A:acorn D:diehard L:lwss P:pause R/Enter:run +/-/0:speed Q:quit");
    } else if status_y == 0 {
        let _ = tb_print(0, 0, TB_YELLOW, TB_DEFAULT, "Q:quit");
    }

    let _ = tb_present();
}

// ---------------------------------------------------------------------------
// Input handling
// ---------------------------------------------------------------------------

fn cgol_handle_key(ev: tb_event&) -> i32 {
    // Quit
    if ev.ch == 'q' || ev.ch == 'Q' || ev.key == TB_KEY_ESC {
        return 0;  // signal quit
    }

    // Cursor movement (HJKL / WASD / Arrow keys) - FIRST to avoid collisions
    if ev.ch == 'h' || ev.ch == 'a' || ev.key == TB_KEY_ARROW_LEFT {
        world.cx = clamp_x(world.cx - 1);
        return 1;
    }
    if ev.ch == 'j' || ev.ch == 's' || ev.key == TB_KEY_ARROW_DOWN {
        world.cy = clamp_y(world.cy + 1);
        return 1;
    }
    if ev.ch == 'k' || ev.ch == 'w' || ev.key == TB_KEY_ARROW_UP {
        world.cy = clamp_y(world.cy - 1);
        return 1;
    }
    if ev.ch == 'l' || ev.ch == 'd' || ev.key == TB_KEY_ARROW_RIGHT {
        world.cx = clamp_x(world.cx + 1);
        return 1;
    }

    // Toggle cell at cursor
    if ev.ch == 'x' || ev.ch == 'X' || ev.ch == ' ' || ev.key == TB_KEY_MOUSE_LEFT {
        cgol_toggle(world.cx, world.cy);
        return 1;
    }

    // Single step (Shift+S; lowercase 's' moves cursor down in WASD)
    if ev.ch == 'S' {
        cgol_step();
        return 1;
    }

    // Clear
    if ev.ch == 'c' || ev.ch == 'C' {
        cgol_clear();
        return 1;
    }

    // Randomize
    if ev.ch == 'z' || ev.ch == 'Z' {
        cgol_randomize();
        return 1;
    }

    // Patterns (uppercase to avoid collision with WASD/HJKL)
    if ev.ch == 'g' || ev.ch == 'G' { cgol_place_pattern("glider", world.cx, world.cy); return 1; }
    if ev.ch == 'b' { cgol_place_pattern("blinker", world.cx, world.cy); return 1; }
    if ev.ch == 'B' { cgol_place_pattern("block", world.cx, world.cy); return 1; }
    if ev.ch == 't' || ev.ch == 'T' { cgol_place_pattern("toad", world.cx, world.cy); return 1; }
    if ev.ch == 'o' || ev.ch == 'O' { cgol_place_pattern("rpent", world.cx, world.cy); return 1; }
    if ev.ch == 'A' { cgol_place_pattern("acorn", world.cx, world.cy); return 1; }
    if ev.ch == 'D' { cgol_place_pattern("diehard", world.cx, world.cy); return 1; }
    if ev.ch == 'L' { cgol_place_pattern("lwss", world.cx, world.cy); return 1; }

    // Pause/Run
    if ev.ch == 'p' || ev.ch == 'P' {
        world.running = if world.running != 0 { 0 } else { 1 };
        return 1;
    }
    if ev.ch == 'r' || ev.ch == 'R' || ev.key == TB_KEY_ENTER || ev.ch == 0x0a {
        world.running = 1;
        return 1;
    }

    // Speed control (33ms = ~30 FPS minimum)
    if ev.ch == '+' || ev.ch == '=' {
        if world.speed_ms > 10 { world.speed_ms = world.speed_ms - 10; }
        else if world.speed_ms > 0 { world.speed_ms = 0; }
        return 1;
    }
    if ev.ch == '-' { world.speed_ms = world.speed_ms + 10; return 1; }
    if ev.ch == '0' { world.speed_ms = 0; return 1; }

    return 1;
}

// ---------------------------------------------------------------------------
// Main loop: non-blocking input poll + fixed timestep + adaptive frame pacing
// ---------------------------------------------------------------------------

extern fn tb_adapter_now_ms() -> i64 = "tb_adapter_now_ms";
extern fn tb_adapter_sleep_ms(ms: i32) = "tb_adapter_sleep_ms";

fn main() {
    let rv = cgol_init();
    if rv != TB_OK {
        print("cgol_init failed: ", rv, "\n");
        return;
    }

    // Clear any initial input
    let g = gbl();
    g.inbuf_len = 0;
    g.inbuf_pos = 0;

    cgol_draw();
    var last_sim_ms: i64 = tb_adapter_now_ms();
    const TARGET_FRAME_MS: i32 = 16;  // ~60 FPS
    const MAX_FRAME_MS: i32 = 33;    // ~30 FPS minimum
    var running: i32 = 1;

    while running != 0 {
        let frame_start = tb_adapter_now_ms();
        var needs_draw: i32 = world.last_frame_skipped;

        // Process events with adaptive timeout (frame pacing + instant input)
        loop {
            let now = tb_adapter_now_ms();
            let elapsed = (now - frame_start) as i32;
            let remaining = TARGET_FRAME_MS - elapsed;
            let timeout = if remaining > 0 { remaining } else { 0 };

            var ev = tb_event { .. };
            let rv2 = tb_peek_event(ev, timeout);
            if rv2 != TB_OK {
                if rv2 == TB_ERR_NO_EVENT {
                    // Frame budget exhausted - break to sim/draw
                    break;
                }
                // Error
                print("peek_event error: ", rv2, "\n");
                running = 0;
                break;
            }

            // Event received - process IMMEDIATELY
            if ev.kind == TB_EVENT_KEY {
                let should_continue = cgol_handle_key(ev);
                needs_draw = 1;
                if should_continue == 0 { running = 0; break; } // quit
            } else if ev.kind == TB_EVENT_RESIZE {
                cgol_resize();
                needs_draw = 1;
            } else if ev.kind == TB_EVENT_MOUSE {
                if ev.key == TB_KEY_MOUSE_LEFT {
                    world.cx = ev.x;
                    world.cy = ev.y;
                    world.cx = clamp_x(world.cx);
                    world.cy = clamp_y(world.cy);
                    cgol_toggle(world.cx, world.cy);
                    needs_draw = 1;
                } else if ev.mod & TB_MOD_MOTION != 0 {
                    world.cx = ev.x;
                    world.cy = ev.y;
                    world.cx = clamp_x(world.cx);
                    world.cy = clamp_y(world.cy);
                    needs_draw = 1;
                }
            }
            // Continue inner loop to check for more events with updated timeout
        }
        if running == 0 { break; }

        // Frame budget used up - do simulation step
        if world.running != 0 && world.speed_ms > 0 {
            let now = tb_adapter_now_ms();
            if now - last_sim_ms >= world.speed_ms {
                cgol_step();
                last_sim_ms = now;
                needs_draw = 1;
            }
        } else if world.running != 0 && world.speed_ms == 0 {
            // Unlimited: step every frame
            cgol_step();
            needs_draw = 1;
        }

        // Render only when needed (skip if frame already too slow)
        world.skip_frame = 0;
        if needs_draw != 0 {
            if world.frame_time_ms <= MAX_FRAME_MS {
                cgol_draw();
            } else {
                world.skip_frame = 1;
            }
        }
        // Track if last frame was skipped for [SKIP] indicator
        world.last_frame_skipped = world.skip_frame;

        // Frame pacing & FPS tracking
        let frame_end = tb_adapter_now_ms();
        let elapsed = (frame_end - frame_start) as i32;
        world.frame_time_ms = elapsed;
        world.frame_count = world.frame_count + 1;

        // Update FPS every 500ms
        let now = tb_adapter_now_ms();
        if now - world.last_fps_update >= 500 {
            let dt = now - world.last_fps_update;
            if dt > 0 {
                world.current_fps = ((world.frame_count * 1000) / dt) as i32;
            }
            world.frame_count = 0;
            world.last_fps_update = now;
        }
    }

    cgol_shutdown();
    print("thanks for playing\n");
}