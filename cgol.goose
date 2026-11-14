// cgol.goose — Conway's Game of Life in Goose using termbox2
//
// Build:  goose build cgol.goose -o cgol
// Run:    ./cgol (requires real TTY; run in Termux)
//
// Controls:
//   HJKL / WASD / Arrow keys   move cursor
//   X / Space / Left click     toggle cell at cursor
//   ENTER / R                  toggle auto-run
//   S / SPACE                  single step (when paused)
//   C                          clear grid
//   Z                          randomize (~50% alive)
//   G                          place Glider at cursor
//   B                          place Block at cursor
//   b                          place Blinker at cursor
//   T                          place Toad at cursor
//   P                          place R-pentomino at cursor
//   A                          place Acorn at cursor
//   D                          place Diehard at cursor
//   L                          place Lightweight Spaceship (LWSS) at cursor
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
    speed_ms: i32,     // animation speed (peek timeout)
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

fn clamp_y(y: i32) -> i32 {
    if y < 0 { return 0; }
    if y >= world.height { return world.height - 1; }
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

    // Randomize ~50% alive
    var seed: u64 = 0x123456789ABCDEF;
    var j = 0;
    for j in total {
        // xorshift64*
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        let r = (seed * 0x2545F4914F6CDD1D) as u32;
        world.cur[j] = if (r & 1) != 0 { 1 } else { 0 };
    }

    world.gen = 0;
    world.running = 1;
    world.cx = world.width / 2;
    world.cy = world.height / 2;
    world.speed_ms = 0;  // 0 = max FPS (no throttle)

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
    let h = world.height;
    var n: i32 = 0;

    // Toroidal wrapping: (y + dy + h) % h, (x + dx + w) % w
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
    let h = world.height;
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

    // Copy nxt into cur, zero nxt
    var k: i32 = 0;
    let total = w * h;
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
    let total = world.width * world.height;
    var seed: u64 = world.gen as u64 + 0x9E3779B97F4A7C15;
    var i: i32 = 0;
    for i in total {
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        let r = (seed * 0x2545F4914F6CDD1D) as u32;
        world.cur[i] = if (r & 1) != 0 { 1 } else { 0 };
        world.nxt[i] = 0;
    }
    world.gen = 0;
}

fn cgol_place_pattern(name: const u8[:], px: i32, py: i32) {
    // Build pattern points
    var pts: Point[>..] = [];

    // Match pattern name
    if name[0] == 'g' && name[1] == 'l' {        // glider
        pattern_glider(pts);
    } else if name[0] == 'b' && name[1] == 'l' { // block
        pattern_block(pts);
    } else if name[0] == 'b' && name[1] == 'k' { // blinker
        pattern_blinker(pts);
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
        let x = px + dx;
        let y = py + dy;
        if in_bounds(x, y) {
            world.cur[idx(x, y)] = 1;
        }
    }
}

// ---------------------------------------------------------------------------
// Resize handling
// ---------------------------------------------------------------------------

fn cgol_resize() {
    world.width = tb_width();
    world.height = tb_height();

    // Clamp cursor
    world.cx = clamp_x(world.cx);
    world.cy = clamp_y(world.cy);

    // Reallocate grids to new size
    let total = world.width * world.height;

    // Zero out existing elements up to the new size (or old size)
    let old_total = world.cur.len;
    let min_total = if total < old_total { total } else { old_total };
    var i: i32 = 0;
    while i < min_total {
        world.cur[i] = 0;
        world.nxt[i] = 0;
        i = i + 1;
    }

    // If new size is larger, extend
    if total > old_total {
        i = old_total as i32;
        while i < total {
            world.cur.push(0);
            world.nxt.push(0);
            i = i + 1;
        }
    }
    // If new size is smaller, we just leave the extra elements (they're zeroed)
    // but logically we only use up to 'total' elements

    world.gen = 0;

    let _ = tb_invalidate();
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

fn cgol_draw() {
    let _ = tb_clear();

    let w = world.width;
    let h = world.height;

    // Draw alive cells
    var y: i32 = 0;
    while y < h {
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
    if in_bounds(world.cx, world.cy) {
        let i = idx(world.cx, world.cy);
        let ch = if world.cur[i] != 0 { CH_CURSOR_ALIVE } else { CH_CURSOR };
        let fg = if world.cur[i] != 0 { TB_BLACK } else { TB_WHITE };
        let bg = if world.cur[i] != 0 { TB_GREEN | TB_BOLD } else { TB_BLUE };
        let _ = tb_set_cell(world.cx, world.cy, ch, fg as u64, bg as u64);
    }

    // Status line at bottom
    let status_y = h - 1;
    if status_y >= 0 {
        let _ = tb_print(0, status_y, TB_YELLOW, TB_DEFAULT,
            "HJKL:move X:toggle Space:step C:clear Z:rand G:glider B:block b:blink T:toad O:rpent A:acorn D:diehard L:lwss P:pause R:run +/-/0:speed Q:quit");
        let _ = tb_print(0, status_y - 1, TB_CYAN, TB_DEFAULT,
            "Gen: ");
        // Print gen number
        let gen_str: u8[32];
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
            // Reverse
            var i: i32 = 0;
            for i in len / 2 {
                let tmp = gen_str[i];
                gen_str[i] = gen_str[len - 1 - i];
                gen_str[len - 1 - i] = tmp;
            }
        }
        let _ = tb_print(5, status_y - 1, TB_WHITE, TB_DEFAULT, gen_str[0..len]);
        let _ = tb_print(20, status_y - 1, TB_CYAN, TB_DEFAULT,
            "  Running: ");
        let _ = tb_print(32, status_y - 1,
            if world.running != 0 { TB_GREEN | TB_BOLD } else { TB_WHITE },
            TB_DEFAULT,
            if world.running != 0 { "ON " } else { "OFF" });
        // Speed
        let _ = tb_print(40, status_y - 1, TB_CYAN, TB_DEFAULT, "  Speed: ");
        let spd_str: u8[16];
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
        let _ = tb_print(50, status_y - 1, TB_WHITE, TB_DEFAULT, spd_str[0..spd_len]);
        let _ = tb_print(50 + spd_len, status_y - 1, TB_WHITE, TB_DEFAULT, "ms");
        // Pause indicator
        if world.running == 0 {
            let _ = tb_print(60, status_y - 1, TB_RED | TB_BOLD, TB_DEFAULT, "  [PAUSED]");
        }
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

    // Toggle cell at cursor
    if ev.ch == 'x' || ev.ch == ' ' || ev.key == TB_KEY_MOUSE_LEFT {
        cgol_toggle(world.cx, world.cy);
        return 1;
    }

    // Toggle auto-run
    if ev.ch == 'r' || ev.ch == 'R' || ev.key == TB_KEY_ENTER {
        world.running = if world.running != 0 { 0 } else { 1 };
        return 1;
    }

    // Single step
    if ev.ch == 's' || ev.ch == 'S' || ev.key == TB_KEY_SPACE {
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

    // Patterns
    if ev.ch == 'g' { cgol_place_pattern("glider", world.cx, world.cy); return 1; }
    if ev.ch == 'b' { cgol_place_pattern("blinker", world.cx, world.cy); return 1; }
    if ev.ch == 'B' { cgol_place_pattern("block", world.cx, world.cy); return 1; }
    if ev.ch == 't' { cgol_place_pattern("toad", world.cx, world.cy); return 1; }
    if ev.ch == 'o' { cgol_place_pattern("rpent", world.cx, world.cy); return 1; }
    if ev.ch == 'a' { cgol_place_pattern("acorn", world.cx, world.cy); return 1; }
    if ev.ch == 'd' { cgol_place_pattern("diehard", world.cx, world.cy); return 1; }
    if ev.ch == 'l' { cgol_place_pattern("lwss", world.cx, world.cy); return 1; }
    // Pause/Run
    if ev.ch == 'p' { world.running = 0; return 1; }
    if ev.ch == 'r' || ev.key == TB_KEY_ENTER { world.running = 1; return 1; }
    // Speed control (33ms = ~30 FPS minimum)
    if ev.ch == '+' || ev.ch == '=' { if world.speed_ms > 33 { world.speed_ms = world.speed_ms - 10; } else if world.speed_ms > 0 { world.speed_ms = 33; } return 1; }
    if ev.ch == '-' { world.speed_ms = world.speed_ms + 10; return 1; }
    if ev.ch == '0' { world.speed_ms = 0; return 1; }

    // Cursor movement
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

    return 1;
}

// ---------------------------------------------------------------------------
// Main loop: non-blocking input poll + fixed timestep + frame pacing
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

    loop {
        var ev = tb_event { .. };
        // NON-BLOCKING input poll (0ms) - returns immediately
        let rv2 = tb_peek_event(ev, 0);
        if rv2 == TB_OK {
            if ev.kind == TB_EVENT_KEY {
                let should_continue = cgol_handle_key(ev);
                if should_continue == 0 { break; }
            } else if ev.kind == TB_EVENT_RESIZE {
                cgol_resize();
            } else if ev.kind == TB_EVENT_MOUSE {
                if ev.key == TB_KEY_MOUSE_LEFT {
                    world.cx = ev.x;
                    world.cy = ev.y;
                    world.cx = clamp_x(world.cx);
                    world.cy = clamp_y(world.cy);
                    cgol_toggle(world.cx, world.cy);
                } else if ev.mod & TB_MOD_MOTION != 0 {
                    world.cx = ev.x;
                    world.cy = ev.y;
                    world.cx = clamp_x(world.cx);
                    world.cy = clamp_y(world.cy);
                }
            }
        } else if rv2 != TB_ERR_NO_EVENT {
            print("peek_event error: ", rv2, "\n");
            break;
        }

        // Fixed-timestep simulation advance
        if world.running != 0 && world.speed_ms > 0 {
            let now = tb_adapter_now_ms();
            if now - last_sim_ms >= world.speed_ms {
                cgol_step();
                last_sim_ms = now;
            }
        } else if world.running != 0 && world.speed_ms == 0 {
            // Unlimited: step every frame
            cgol_step();
        }

        cgol_draw();

        // Frame pacing: sleep to ~60 FPS (16ms) to not burn CPU
        tb_adapter_sleep_ms(16);
    }

    cgol_shutdown();
    print("thanks for playing\n");
}