// fbw.goose — Faithful Terminal Recreation of Fractal Block World (Xar)
// Uses termbox2.goose with 24-bit Truecolor half-block (▀) 3D DDA raycasting,
// recursive 16x16x16 infinite-scale shrinking/growing rings, Xar biomes,
// 6 upgradeable weapons, destructible blocks, waypoints, and Core Boss rescue.
//
// Build:  goose build fbw.goose -o fbw
// Run:    ./fbw   (Windows: fbw.exe)
//
// Controls:
//   W/A/S/D          Move forward / strafe / back
//   Space / C        Fly Up / Fly Down
//   Arrows / IJKL    Look (Yaw & Pitch)
//   Mouse Drag       Look around
//   F / Enter / LMB  Fire active weapon
//   1..6 / Wheel     Select weapon (Plasma, Minigun, Laser, Cannon, Railgun, Dark Hole)
//   E                Interact / Activate Shrine or nearby Scale Ring
//   U                Open / Close Upgrade & Ammo Shop (spend Gold)
//   V / B            Drop Waypoint / Warp to Waypoint
//   Tab              Toggle Tactical Minimap & Scale Stack
//   M                Toggle 24-bit Truecolor / 256-color mode
//   P                Toggle Pause / Controls Help
//   Q / Esc          Quit (or close modal)

import termbox2;

extern fn tb_adapter_now_ms() -> i64 = "tb_adapter_now_ms";
extern fn tb_adapter_sleep_ms(ms: i32) = "tb_adapter_sleep_ms";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const PI: f64 = 3.14159265358979323846;
const TAU: f64 = 6.28318530717958647692;
const HALF_PI: f64 = 1.57079632679489661923;

const CHUNK_DIM: i32 = 16;
const CHUNK_VOL: i32 = 4096;

const MAX_PW: i32 = 240;
const MAX_PH: i32 = 140;
const MAX_PIXELS: i32 = 33600;

const MACRO_OFFSET: i32 = 4;
const MAX_STACK: i32 = 64;

const MAX_ENTITIES: i32 = 96;
const MAX_SHOTS: i32 = 64;
const MAX_PARTICLES: i32 = 64;
const MAX_DELTAS: i32 = 256;

// Screen modes
const SCREEN_TITLE: i32 = 0;
const SCREEN_PLAY: i32 = 1;
const SCREEN_UPGRADE: i32 = 2;
const SCREEN_HELP: i32 = 3;
const SCREEN_DEAD: i32 = 4;

// Biomes
const BIOME_MACRO: i32 = 0;
const BIOME_YING_FOREST: i32 = 1;
const BIOME_YELLOW_FLOWER: i32 = 2;
const BIOME_BLUE_FLOWER: i32 = 3;
const BIOME_MYLANTIS: i32 = 4;
const BIOME_BLACK_CUBE: i32 = 5;
const BIOME_INNER_CORE: i32 = 6;

// Block IDs
const BLK_AIR: u8 = 0;
const BLK_GRASS: u8 = 1;
const BLK_DIRT: u8 = 2;
const BLK_WOOD: u8 = 3;
const BLK_LEAVES: u8 = 4;
const BLK_FLOWER_Y: u8 = 5;
const BLK_POLLEN: u8 = 6;
const BLK_FLOWER_B: u8 = 7;
const BLK_MYLANTIS: u8 = 8;
const BLK_BLACK_CUBE: u8 = 9;
const BLK_CRATE: u8 = 10;
const BLK_SPAWNER: u8 = 11;
const BLK_SHRINE: u8 = 12;
const BLK_CORE: u8 = 13;
const BLK_WAYPOINT: u8 = 14;
const BLK_GLASS: u8 = 15;

// Entity kinds
const ENT_NONE: i32 = 0;
const ENT_RING_GREEN: i32 = 1;
const ENT_RING_RED: i32 = 2;
const ENT_RING_BLUE: i32 = 3;
const ENT_RING_PINK: i32 = 4;
const ENT_GOBLIN: i32 = 5;
const ENT_SLIME: i32 = 6;
const ENT_TURRET: i32 = 7;
const ENT_WARDEN: i32 = 8;
const ENT_BOSS: i32 = 9;
const ENT_GOLD: i32 = 10;
const ENT_HEALTH: i32 = 11;
const ENT_ARMOR: i32 = 12;
const ENT_AMMO: i32 = 13;
const ENT_K_BEACON: i32 = 14;

// Weapons
const WEP_PLASMA: i32 = 0;
const WEP_MINIGUN: i32 = 1;
const WEP_LASER: i32 = 2;
const WEP_CANNON: i32 = 3;
const WEP_RAILGUN: i32 = 4;
const WEP_DARKHOLE: i32 = 5;

const CH_HALF_TOP: u32 = 0x2580; // ▀
const CH_BLOCK: u32 = 0x2588;    // █

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------
struct ScaleFrame {
    bx: i32,
    by: i32,
    bz: i32,
    biome: i32,
    parent_block: u8,
    seed: u64,
}

struct Entity {
    kind: i32,
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    hp: i32,
    max_hp: i32,
    cooldown: i32,
    target_block: u8,
    active: i32,
}

struct Shot {
    active: i32,
    from_player: i32,
    wep: i32,
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    dmg: i32,
    ttl_ms: i32,
    rgb: u32,
}

struct Particle {
    active: i32,
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    ttl_ms: i32,
    rgb: u32,
}

struct BlockDelta {
    used: i32,
    seed: u64,
    bx: u8,
    by: u8,
    bz: u8,
    blk: u8,
}

root struct fbw_state {
    term_w: i32,
    term_h: i32,
    pw: i32,
    ph: i32,
    screen: i32,
    truecolor: i32,
    show_minimap: i32,

    // World chunk
    blocks: u8[CHUNK_VOL],
    stack: ScaleFrame[MAX_STACK],
    depth: i32, // 0 = Ying Forest, <0 = Macro, >0 = Inner Fractals
    max_depth_reached: i32,

    // Player
    px: f64,
    py: f64,
    pz: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    yaw: f64,
    pitch: f64,
    hp: i32,
    max_hp: i32,
    armor: i32,
    max_armor: i32,
    gold: i32,
    kills: i32,
    k_rescued: i32,

    // Weapons & Upgrades
    weapon: i32,
    ammo: i32[6],
    dmg_lvl: i32,
    rof_lvl: i32,
    spd_lvl: i32,
    fire_cd_ms: i32,
    ring_cd_ms: i32,
    beam_timer_ms: i32,
    beam_rgb: u32,
    beam_x1: f64,
    beam_y1: f64,
    beam_z1: f64,
    beam_x2: f64,
    beam_y2: f64,
    beam_z2: f64,

    // Waypoint
    has_wp: i32,
    wp_depth: i32,
    wp_px: f64,
    wp_py: f64,
    wp_pz: f64,
    wp_stack: ScaleFrame[MAX_STACK],

    // Mouse drag tracking
    mouse_last_x: i32,
    mouse_last_y: i32,
    mouse_dragging: i32,

    // Feedback / Flash
    flash_ms: i32,
    flash_rgb: u32,
    msg_ms: i32,
    msg_len: i32,
    msg_buf: u8[96],

    // Crosshair target readout
    target_name_len: i32,
    target_name: u8[32],
    target_hp: i32,
    target_max_hp: i32,
    near_ring_kind: i32,

    // Entities, Shots, Particles, Deltas
    entities: Entity[MAX_ENTITIES],
    shots: Shot[MAX_SHOTS],
    particles: Particle[MAX_PARTICLES],
    deltas: BlockDelta[MAX_DELTAS],
    delta_head: i32,

    // Framebuffer
    fb_rgb: u32[MAX_PIXELS],
    fb_z: f64[MAX_PIXELS],

    // PRNG & Timing
    rng: u64,
    tick_ms: i64,
    fps: i32,
    frame_cnt: i32,
    fps_last_ms: i64,
    anim_ms: i64,
}

var st: fbw_state;

// ---------------------------------------------------------------------------
// Pure Goose Math Helpers (no external libm dependency)
// ---------------------------------------------------------------------------
fn fabs(x: f64) -> f64 {
    if x < 0.0 { return -x; }
    return x;
}

fn fmin(a: f64, b: f64) -> f64 {
    if a < b { return a; }
    return b;
}

fn fmax(a: f64, b: f64) -> f64 {
    if a > b { return a; }
    return b;
}

fn fclamp(x: f64, lo: f64, hi: f64) -> f64 {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

fn ffloor(x: f64) -> i32 {
    let i = x as! i32;
    if i > x { return i - 1; }
    return i;
}

fn fsqrt(x: f64) -> f64 {
    if x <= 0.0 { return 0.0; }
    var g: f64 = if x > 1.0 { x * 0.5 } else { 1.0 };
    var k: i32 = 0;
    // Rough power-of-2 range reduction for very large/small inputs
    var v: f64 = x;
    var scale: f64 = 1.0;
    while v > 4.0 && k < 24 {
        v = v * 0.25;
        scale = scale * 2.0;
        k = k + 1;
    }
    while v < 0.25 && k < 24 {
        v = v * 4.0;
        scale = scale * 0.5;
        k = k + 1;
    }
    g = (0.5 + 0.5 * v) * scale;
    var i: i32 = 0;
    while i < 7 {
        g = 0.5 * (g + x / g);
        i = i + 1;
    }
    return g;
}

fn wrap_angle(a_in: f64) -> f64 {
    var a: f64 = a_in;
    while a > PI { a = a - TAU; }
    while a < -PI { a = a + TAU; }
    return a;
}

fn fsin(x_in: f64) -> f64 {
    var x: f64 = wrap_angle(x_in);
    if x > HALF_PI { x = PI - x; }
    if x < -HALF_PI { x = -PI - x; }
    let x2 = x * x;
    let x3 = x2 * x;
    let x5 = x3 * x2;
    let x7 = x5 * x2;
    let x9 = x7 * x2;
    return x - (x3 / 6.0) + (x5 / 120.0) - (x7 / 5040.0) + (x9 / 362880.0);
}

fn fcos(x_in: f64) -> f64 {
    return fsin(x_in + HALF_PI);
}

fn clamp_i(v: i32, lo: i32, hi: i32) -> i32 {
    if v < lo { return lo; }
    if v > hi { return hi; }
    return v;
}

// ---------------------------------------------------------------------------
// Hashing & PRNG
// ---------------------------------------------------------------------------
fn splitmix64(x_in: u64) -> u64 {
    var z: u64 = x_in + 0x9e3779b97f4a7c15;
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) * 0x94d049bb133111eb;
    return z ^ (z >> 31);
}

fn hash_block_seed(parent_seed: u64, bx: i32, by: i32, bz: i32, depth: i32) -> u64 {
    let h1 = splitmix64(parent_seed ^ ((bx as u64) * 0x517cc1b727220a95));
    let h2 = splitmix64(h1 ^ ((by as u64) * 0x94d049bb133111eb));
    let h3 = splitmix64(h2 ^ ((bz as u64) * 0xbf58476d1ce4e5b9));
    return splitmix64(h3 ^ ((depth + 128) as u64));
}

fn rng_u32() -> u32 {
    st.rng = splitmix64(st.rng);
    return (st.rng >> 16) as! u32;
}

fn rng_range(lo: i32, hi: i32) -> i32 {
    if hi <= lo { return lo; }
    let span = (hi - lo + 1) as u32;
    return lo + ((rng_u32() % span) as! i32);
}

fn rng_f01() -> f64 {
    return (rng_u32() & 0xffff) / 65536.0;
}

// ---------------------------------------------------------------------------
// Color Helpers (Truecolor & 256-Color Fallback)
// ---------------------------------------------------------------------------
fn pack_rgb(r_in: i32, g_in: i32, b_in: i32) -> u32 {
    let r = clamp_i(r_in, 0, 255) as! u32;
    let g = clamp_i(g_in, 0, 255) as! u32;
    let b = clamp_i(b_in, 0, 255) as! u32;
    return (r << 16) | (g << 8) | b;
}

fn scale_rgb(rgb: u32, mul: f64) -> u32 {
    let r = ((rgb >> 16) & 0xff) * mul;
    let g = ((rgb >> 8) & 0xff) * mul;
    let b = (rgb & 0xff) * mul;
    return pack_rgb(r as! i32, g as! i32, b as! i32);
}

fn lerp_rgb(c1: u32, c2: u32, t_in: f64) -> u32 {
    let t = fclamp(t_in, 0.0, 1.0);
    let it = 1.0 - t;
    let r1 = ((c1 >> 16) & 0xff) as f64;
    let g1 = ((c1 >> 8) & 0xff) as f64;
    let b1 = (c1 & 0xff) as f64;
    let r2 = ((c2 >> 16) & 0xff) as f64;
    let g2 = ((c2 >> 8) & 0xff) as f64;
    let b2 = (c2 & 0xff) as f64;
    return pack_rgb((r1 * it + r2 * t) as! i32, (g1 * it + g2 * t) as! i32, (b1 * it + b2 * t) as! i32);
}

fn rgb_to_attr(rgb: u32) -> uintattr_t {
    if st.truecolor != 0 {
        // TB_HI_BLACK ensures (0,0,0) still emits explicit black SGR
        return (rgb as uintattr_t) | TB_HI_BLACK;
    }
    // Map 24-bit RGB to xterm 6x6x6 color cube (indices 16..231)
    let r = ((rgb >> 16) & 0xff) as! i32;
    let g = ((rgb >> 8) & 0xff) as! i32;
    let b = (rgb & 0xff) as! i32;
    let ri = (r * 5 + 127) / 255;
    let gi = (g * 5 + 127) / 255;
    let bi = (b * 5 + 127) / 255;
    let idx = 16 + 36 * ri + 6 * gi + bi;
    return (idx as uintattr_t) | TB_HI_BLACK;
}


fn ui_white() -> uintattr_t { return rgb_to_attr(pack_rgb(245, 247, 250)); }
fn ui_yellow() -> uintattr_t { return rgb_to_attr(pack_rgb(250, 204, 21)); }
fn ui_green() -> uintattr_t { return rgb_to_attr(pack_rgb(74, 222, 128)); }
fn ui_cyan() -> uintattr_t { return rgb_to_attr(pack_rgb(56, 189, 248)); }
fn ui_red() -> uintattr_t { return rgb_to_attr(pack_rgb(248, 113, 113)); }
fn ui_magenta() -> uintattr_t { return rgb_to_attr(pack_rgb(232, 121, 249)); }
fn ui_bg() -> uintattr_t { return rgb_to_attr(pack_rgb(12, 15, 24)); }
fn ui_blue_bg() -> uintattr_t { return rgb_to_attr(pack_rgb(37, 99, 235)); }

// ---------------------------------------------------------------------------
// Text / Buffer Formatting Helpers
// ---------------------------------------------------------------------------
fn set_status_msg(msg: const u8[:], ms: i32) {
    var n: i32 = msg.len as! i32;
    if n > 95 { n = 95; }
    var i: i32 = 0;
    while i < n {
        st.msg_buf[i] = msg[i];
        i = i + 1;
    }
    st.msg_len = n;
    st.msg_ms = ms;
}

fn set_target_name(name: const u8[:], hp: i32, max_hp: i32) {
    var n: i32 = name.len as! i32;
    if n > 31 { n = 31; }
    var i: i32 = 0;
    while i < n {
        st.target_name[i] = name[i];
        i = i + 1;
    }
    st.target_name_len = n;
    st.target_hp = hp;
    st.target_max_hp = max_hp;
}

fn buf_put_str(buf: u8[160]&, len: i32&, s: const u8[:]) {
    var i: i32 = 0;
    let n = s.len as! i32;
    while i < n && len < 159 {
        buf[len] = s[i];
        len = len + 1;
        i = i + 1;
    }
}

fn buf_put_ch(buf: u8[160]&, len: i32&, ch: u8) {
    if len < 159 {
        buf[len] = ch;
        len = len + 1;
    }
}

fn buf_put_int(buf: u8[160]&, len: i32&, val_in: i32) {
    var v: i32 = val_in;
    if v < 0 {
        buf_put_ch(buf, len, '-');
        v = -v;
    }
    var tmp: u8[16] = [0; 16];
    var tl: i32 = 0;
    if v == 0 {
        tmp[0] = '0';
        tl = 1;
    } else {
        while v > 0 && tl < 16 {
            tmp[tl] = (0x30 + (v % 10)) as! u8;
            v = v / 10;
            tl = tl + 1;
        }
    }
    var i: i32 = tl - 1;
    while i >= 0 {
        buf_put_ch(buf, len, tmp[i]);
        i = i - 1;
    }
}

fn draw_rect(x: i32, y: i32, w: i32, h: i32, fg: uintattr_t, bg: uintattr_t) {
    var dy: i32 = 0;
    while dy < h {
        var dx: i32 = 0;
        while dx < w {
            let cx = x + dx;
            let cy = y + dy;
            if cx >= 0 && cx < st.term_w && cy >= 0 && cy < st.term_h {
                var ch: u32 = ' ';
                if dy == 0 && dx == 0 { ch = 0x250c; }
                else if dy == 0 && dx == w - 1 { ch = 0x2510; }
                else if dy == h - 1 && dx == 0 { ch = 0x2514; }
                else if dy == h - 1 && dx == w - 1 { ch = 0x2518; }
                else if dy == 0 || dy == h - 1 { ch = 0x2500; }
                else if dx == 0 || dx == w - 1 { ch = 0x2502; }
                let _ = tb_set_cell(cx, cy, ch, fg, bg);
            }
            dx = dx + 1;
        }
        dy = dy + 1;
    }
}

// ---------------------------------------------------------------------------
// Block & Biome Helpers
// ---------------------------------------------------------------------------
fn b_idx(x: i32, y: i32, z: i32) -> i32 {
    return (y << 8) | (z << 4) | x;
}

fn get_block(x: i32, y: i32, z: i32) -> u8 {
    if x < 0 || x >= CHUNK_DIM || y < 0 || y >= CHUNK_DIM || z < 0 || z >= CHUNK_DIM {
        return BLK_AIR;
    }
    return st.blocks[b_idx(x, y, z)];
}

fn set_block(x: i32, y: i32, z: i32, b: u8) {
    if x < 0 || x >= CHUNK_DIM || y < 0 || y >= CHUNK_DIM || z < 0 || z >= CHUNK_DIM {
        return;
    }
    st.blocks[b_idx(x, y, z)] = b;
}

fn record_block_delta(bx: i32, by: i32, bz: i32, b: u8) {
    let sidx = st.depth + MACRO_OFFSET;
    if sidx < 0 || sidx >= MAX_STACK { return; }
    let seed = st.stack[sidx].seed;
    // Update existing delta if matching
    var i: i32 = 0;
    while i < MAX_DELTAS {
        if st.deltas[i].used != 0 &&
           st.deltas[i].seed == seed &&
           st.deltas[i].bx == bx &&
           st.deltas[i].by == by &&
           st.deltas[i].bz == bz {
            st.deltas[i].blk = b;
            return;
        }
        i = i + 1;
    }
    let idx = st.delta_head;
    st.deltas[idx].used = 1;
    st.deltas[idx].seed = seed;
    st.deltas[idx].bx = bx as! u8;
    st.deltas[idx].by = by as! u8;
    st.deltas[idx].bz = bz as! u8;
    st.deltas[idx].blk = b;
    st.delta_head = (st.delta_head + 1) % MAX_DELTAS;
}

fn is_block_solid(b: u8) -> i32 {
    if b == BLK_AIR { return 0; }
    return 1;
}

fn is_block_destructible(b: u8) -> i32 {
    if b == BLK_CRATE || b == BLK_SPAWNER { return 1; }
    return 0;
}

fn biome_name(biome: i32) -> const u8[:] {
    if biome == BIOME_MACRO { return "Macro Garden"; }
    if biome == BIOME_YING_FOREST { return "Ying Forest"; }
    if biome == BIOME_YELLOW_FLOWER { return "Yellow Flower"; }
    if biome == BIOME_BLUE_FLOWER { return "Blue Flower"; }
    if biome == BIOME_MYLANTIS { return "Mylantis Crust"; }
    if biome == BIOME_BLACK_CUBE { return "Black Cube"; }
    return "Inner Core";
}

fn biome_sky_top(biome: i32) -> u32 {
    if biome == BIOME_MACRO { return pack_rgb(10, 12, 34); }
    if biome == BIOME_YING_FOREST { return pack_rgb(26, 98, 168); }
    if biome == BIOME_YELLOW_FLOWER { return pack_rgb(82, 58, 12); }
    if biome == BIOME_BLUE_FLOWER { return pack_rgb(12, 36, 92); }
    if biome == BIOME_MYLANTIS { return pack_rgb(16, 46, 58); }
    if biome == BIOME_BLACK_CUBE { return pack_rgb(8, 8, 14); }
    return pack_rgb(44, 10, 48);
}

fn biome_sky_bot(biome: i32) -> u32 {
    if biome == BIOME_MACRO { return pack_rgb(38, 22, 68); }
    if biome == BIOME_YING_FOREST { return pack_rgb(126, 198, 228); }
    if biome == BIOME_YELLOW_FLOWER { return pack_rgb(186, 134, 34); }
    if biome == BIOME_BLUE_FLOWER { return pack_rgb(38, 102, 188); }
    if biome == BIOME_MYLANTIS { return pack_rgb(38, 124, 132); }
    if biome == BIOME_BLACK_CUBE { return pack_rgb(28, 16, 44); }
    return pack_rgb(142, 34, 118);
}

fn block_base_rgb(b: u8) -> u32 {
    if b == BLK_GRASS { return pack_rgb(46, 168, 79); }
    if b == BLK_DIRT { return pack_rgb(112, 82, 56); }
    if b == BLK_WOOD { return pack_rgb(124, 77, 43); }
    if b == BLK_LEAVES { return pack_rgb(28, 132, 68); }
    if b == BLK_FLOWER_Y { return pack_rgb(245, 198, 38); }
    if b == BLK_POLLEN { return pack_rgb(255, 244, 130); }
    if b == BLK_FLOWER_B { return pack_rgb(44, 108, 238); }
    if b == BLK_MYLANTIS { return pack_rgb(28, 178, 170); }
    if b == BLK_BLACK_CUBE { return pack_rgb(24, 24, 36); }
    if b == BLK_CRATE { return pack_rgb(206, 140, 44); }
    if b == BLK_SPAWNER { return pack_rgb(188, 38, 62); }
    if b == BLK_SHRINE { return pack_rgb(56, 196, 248); }
    if b == BLK_CORE { return pack_rgb(244, 114, 182); }
    if b == BLK_WAYPOINT { return pack_rgb(74, 222, 128); }
    if b == BLK_GLASS { return pack_rgb(138, 212, 245); }
    return pack_rgb(128, 128, 128);
}

fn block_is_fractal(b: u8) -> i32 {
    if b == BLK_LEAVES || b == BLK_FLOWER_Y || b == BLK_FLOWER_B ||
       b == BLK_MYLANTIS || b == BLK_BLACK_CUBE || b == BLK_CORE ||
       b == BLK_SHRINE || b == BLK_SPAWNER {
        return 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Entities, Shots & Particles Management
// ---------------------------------------------------------------------------
fn clear_entities_and_shots() {
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        st.entities[i].active = 0;
        st.entities[i].kind = ENT_NONE;
        i = i + 1;
    }
    i = 0;
    while i < MAX_SHOTS {
        st.shots[i].active = 0;
        i = i + 1;
    }
    i = 0;
    while i < MAX_PARTICLES {
        st.particles[i].active = 0;
        i = i + 1;
    }
}

fn spawn_entity(kind: i32, x: f64, y: f64, z: f64, hp: i32, target_blk: u8) -> i32 {
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active == 0 {
            st.entities[i].active = 1;
            st.entities[i].kind = kind;
            st.entities[i].x = x;
            st.entities[i].y = y;
            st.entities[i].z = z;
            st.entities[i].vx = 0.0;
            st.entities[i].vy = 0.0;
            st.entities[i].vz = 0.0;
            st.entities[i].hp = hp;
            st.entities[i].max_hp = hp;
            st.entities[i].cooldown = rng_range(400, 1400);
            st.entities[i].target_block = target_blk;
            return i;
        }
        i = i + 1;
    }
    return -1;
}

fn spawn_shot(from_player: i32, wep: i32, x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, dmg: i32, ttl_ms: i32, rgb: u32) {
    var i: i32 = 0;
    while i < MAX_SHOTS {
        if st.shots[i].active == 0 {
            st.shots[i].active = 1;
            st.shots[i].from_player = from_player;
            st.shots[i].wep = wep;
            st.shots[i].x = x;
            st.shots[i].y = y;
            st.shots[i].z = z;
            st.shots[i].vx = vx;
            st.shots[i].vy = vy;
            st.shots[i].vz = vz;
            st.shots[i].dmg = dmg;
            st.shots[i].ttl_ms = ttl_ms;
            st.shots[i].rgb = rgb;
            return;
        }
        i = i + 1;
    }
}

fn spawn_burst(x: f64, y: f64, z: f64, rgb: u32, count: i32) {
    var spawned: i32 = 0;
    var i: i32 = 0;
    while i < MAX_PARTICLES && spawned < count {
        if st.particles[i].active == 0 {
            st.particles[i].active = 1;
            st.particles[i].x = x;
            st.particles[i].y = y;
            st.particles[i].z = z;
            st.particles[i].vx = (rng_f01() - 0.5) * 7.0;
            st.particles[i].vy = (rng_f01() - 0.3) * 7.0;
            st.particles[i].vz = (rng_f01() - 0.5) * 7.0;
            st.particles[i].ttl_ms = rng_range(180, 520);
            st.particles[i].rgb = rgb;
            spawned = spawned + 1;
        }
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// Procedural Fractal Chunk Generation (Xar Universe)
// ---------------------------------------------------------------------------
fn pick_biome(depth: i32, parent_blk: u8, seed: u64) -> i32 {
    if depth < 0 { return BIOME_MACRO; }
    if depth == 0 { return BIOME_YING_FOREST; }
    if parent_blk == BLK_FLOWER_Y || parent_blk == BLK_POLLEN { return BIOME_YELLOW_FLOWER; }
    if parent_blk == BLK_FLOWER_B { return BIOME_BLUE_FLOWER; }
    if parent_blk == BLK_MYLANTIS { return BIOME_MYLANTIS; }
    if parent_blk == BLK_BLACK_CUBE { return BIOME_BLACK_CUBE; }
    if parent_blk == BLK_CORE || depth >= 6 { return BIOME_INNER_CORE; }
    let r = (splitmix64(seed) % 5) as! i32;
    if depth == 1 { return BIOME_YELLOW_FLOWER; }
    if depth == 2 { return BIOME_BLUE_FLOWER; }
    if depth == 3 || depth == 4 { return BIOME_MYLANTIS; }
    if depth == 5 || r == 4 { return BIOME_BLACK_CUBE; }
    return BIOME_INNER_CORE;
}

fn build_tree(tx: i32, tz: i32, base_y: i32, h: i32, put_ring: i32) {
    var y: i32 = 0;
    while y < h {
        set_block(tx, base_y + y, tz, BLK_WOOD);
        y = y + 1;
    }
    let cy = base_y + h;
    var dy: i32 = -1;
    while dy <= 2 {
        var dz: i32 = -2;
        while dz <= 2 {
            var dx: i32 = -2;
            while dx <= 2 {
                let man = (if dx < 0 { -dx } else { dx }) + (if dz < 0 { -dz } else { dz });
                if dy == 2 && man > 1 {
                    dx = dx + 1;
                    continue;
                }
                if man == 2 && (dy == -1 || dy == 1) {
                    dx = dx + 1;
                    continue;
                }
                // Hollow center at dy == 0 / 1 for shrink entrance
                if put_ring != 0 && dx == 0 && (dz == 0 || dz == -1) && (dy == 0 || dy == 1) {
                    set_block(tx + dx, cy + dy, tz + dz, BLK_AIR);
                } else {
                    set_block(tx + dx, cy + dy, tz + dz, BLK_LEAVES);
                }
                dx = dx + 1;
            }
            dz = dz + 1;
        }
        dy = dy + 1;
    }
    if put_ring != 0 {
        let _ = spawn_entity(ENT_RING_GREEN, tx + 0.5, cy + 0.6, tz + 0.5, 1, BLK_LEAVES);
    }
}

fn generate_ying_forest() {
    // Grass & rolling hills
    var z: i32 = 0;
    while z < CHUNK_DIM {
        var x: i32 = 0;
        while x < CHUNK_DIM {
            let edge = if x == 0 || x == 15 || z == 0 || z == 15 { 1 } else { 0 };
            set_block(x, 0, z, BLK_DIRT);
            set_block(x, 1, z, BLK_GRASS);
            if edge != 0 && ((x + z) % 2 == 0) {
                set_block(x, 2, z, BLK_GRASS);
            }
            x = x + 1;
        }
        z = z + 1;
    }

    // Fractal Ying Trees around the clearing
    build_tree(3, 12, 2, 4, 1);
    build_tree(12, 12, 2, 4, 0);
    build_tree(13, 4, 2, 5, 1);
    build_tree(2, 3, 2, 3, 0);

    // Iconic Jumbo Yellow Flower at (8, 2, 12)
    set_block(8, 2, 12, BLK_WOOD);
    set_block(8, 3, 12, BLK_WOOD);
    set_block(8, 4, 12, BLK_FLOWER_Y);
    var fz: i32 = 10;
    while fz <= 14 {
        var fx: i32 = 6;
        while fx <= 10 {
            let dx = fx - 8;
            let dz = fz - 12;
            let r2 = dx * dx + dz * dz;
            if r2 <= 4 {
                if r2 <= 1 {
                    set_block(fx, 4, fz, BLK_POLLEN);
                } else {
                    set_block(fx, 5, fz, BLK_FLOWER_Y);
                }
            }
            fx = fx + 1;
        }
        fz = fz + 1;
    }
    // Green Shrink Ring inside the Jumbo Yellow Flower bulb!
    let _ = spawn_entity(ENT_RING_GREEN, 8.5, 5.6, 12.5, 1, BLK_FLOWER_Y);

    // Blue Flower at (3, 2, 5)
    set_block(3, 2, 5, BLK_WOOD);
    set_block(3, 3, 5, BLK_FLOWER_B);
    set_block(2, 4, 5, BLK_FLOWER_B);
    set_block(4, 4, 5, BLK_FLOWER_B);
    set_block(3, 4, 4, BLK_FLOWER_B);
    set_block(3, 4, 6, BLK_FLOWER_B);
    let _ = spawn_entity(ENT_RING_BLUE, 3.5, 4.6, 5.5, 1, BLK_FLOWER_B);

    // Mysterious Black Cube Monolith tucked in corner (13, 2, 9)
    set_block(13, 2, 9, BLK_BLACK_CUBE);
    set_block(13, 3, 9, BLK_BLACK_CUBE);
    set_block(14, 2, 9, BLK_BLACK_CUBE);
    set_block(14, 3, 9, BLK_BLACK_CUBE);
    let _ = spawn_entity(ENT_RING_PINK, 13.0, 4.3, 9.5, 1, BLK_BLACK_CUBE);

    // Upgrade Shrine & Crates
    set_block(11, 2, 6, BLK_SHRINE);
    set_block(5, 2, 8, BLK_CRATE);
    set_block(10, 2, 9, BLK_CRATE);

    // Floating Red Grow Ring above clearing -> Macro Garden (Level -1)
    let _ = spawn_entity(ENT_RING_RED, 8.5, 12.2, 8.5, 1, BLK_AIR);

    // Starting Goblins, Slime & Pickups
    let _ = spawn_entity(ENT_GOBLIN, 6.5, 2.5, 10.5, 35, 0);
    let _ = spawn_entity(ENT_GOBLIN, 10.5, 2.5, 10.5, 35, 0);
    let _ = spawn_entity(ENT_SLIME, 4.5, 2.5, 7.5, 25, 0);
    let _ = spawn_entity(ENT_GOLD, 8.5, 2.5, 7.0, 1, 0);
    let _ = spawn_entity(ENT_GOLD, 11.5, 3.5, 6.5, 1, 0);
    let _ = spawn_entity(ENT_AMMO, 5.5, 3.5, 8.5, 1, 0);
}

fn generate_macro_garden() {
    // Level < 0: Giant cosmic blossom containing the Ying Forest!
    var z: i32 = 2;
    while z <= 13 {
        var x: i32 = 2;
        while x <= 13 {
            let dx = x - 8;
            let dz = z - 8;
            let d2 = dx * dx + dz * dz;
            if d2 <= 28 {
                set_block(x, 2, z, BLK_MYLANTIS);
            }
            if d2 >= 18 && d2 <= 28 {
                set_block(x, 3, z, BLK_FLOWER_Y);
                if d2 >= 24 { set_block(x, 4, z, BLK_FLOWER_Y); }
            }
            x = x + 1;
        }
        z = z + 1;
    }
    // Central Giant Ying Flower Cup -> Green Ring shrinks back down to Level 0!
    set_block(8, 3, 8, BLK_POLLEN);
    let _ = spawn_entity(ENT_RING_GREEN, 8.5, 4.6, 8.5, 1, BLK_GRASS);
    let _ = spawn_entity(ENT_RING_RED, 8.5, 12.0, 8.5, 1, BLK_AIR);
    set_block(11, 3, 8, BLK_SHRINE);
    let _ = spawn_entity(ENT_TURRET, 5.5, 4.5, 5.5, 70, 0);
    let _ = spawn_entity(ENT_TURRET, 11.5, 4.5, 11.5, 70, 0);
    let _ = spawn_entity(ENT_GOLD, 6.5, 3.6, 8.5, 1, 0);
    let _ = spawn_entity(ENT_ARMOR, 8.5, 3.6, 5.5, 1, 0);
}

fn generate_interior_biome(biome: i32, depth: i32, seed: u64) {
    var ls: u64 = seed;
    let wall_blk: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_FLOWER_Y }
        else if biome == BIOME_BLUE_FLOWER { BLK_FLOWER_B }
        else if biome == BIOME_MYLANTIS { BLK_MYLANTIS }
        else if biome == BIOME_BLACK_CUBE { BLK_BLACK_CUBE }
        else { BLK_CORE };
    let trim_blk: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_POLLEN }
        else if biome == BIOME_BLUE_FLOWER { BLK_GLASS }
        else if biome == BIOME_MYLANTIS { BLK_FLOWER_B }
        else if biome == BIOME_BLACK_CUBE { BLK_CORE }
        else { BLK_POLLEN };

    // Enclosing fractal chamber with ceiling skylight shaft
    var y: i32 = 0;
    while y < CHUNK_DIM {
        var z: i32 = 0;
        while z < CHUNK_DIM {
            var x: i32 = 0;
            while x < CHUNK_DIM {
                let shell = if x == 0 || x == 15 || y == 0 || y == 15 || z == 0 || z == 15 { 1 } else { 0 };
                if shell != 0 {
                    // Leave a central skylight in the ceiling so players can fly out to grow!
                    if y == 15 && x >= 6 && x <= 9 && z >= 6 && z <= 9 {
                        set_block(x, y, z, BLK_AIR);
                    } else if (x + y + z) % 5 == 0 {
                        set_block(x, y, z, trim_blk);
                    } else {
                        set_block(x, y, z, wall_blk);
                    }
                }
                x = x + 1;
            }
            z = z + 1;
        }
        y = y + 1;
    }

    // Multi-level platforms, pillars & fractal arches
    var p: i32 = 0;
    while p < 4 {
        ls = splitmix64(ls);
        let px = 3 + ((ls % 10) as! i32);
        ls = splitmix64(ls);
        let pz = 3 + ((ls % 10) as! i32);
        ls = splitmix64(ls);
        let py = 3 + ((ls % 7) as! i32);
        var dz: i32 = -1;
        while dz <= 1 {
            var dx: i32 = -1;
            while dx <= 1 {
                set_block(px + dx, py, pz + dz, wall_blk);
                dx = dx + 1;
            }
            dz = dz + 1;
        }
        p = p + 1;
    }

    // 4 Corner Fractal Columns
    var cy: i32 = 1;
    while cy < 13 {
        if cy % 3 != 0 {
            set_block(3, cy, 3, trim_blk);
            set_block(12, cy, 3, trim_blk);
            set_block(3, cy, 12, trim_blk);
            set_block(12, cy, 12, trim_blk);
        }
        cy = cy + 1;
    }

    // Keep center spawn column clear (x=7..9, z=7..9, y=2..12)
    var sy: i32 = 2;
    while sy <= 12 {
        var sz: i32 = 7;
        while sz <= 9 {
            var sx: i32 = 7;
            while sx <= 9 {
                set_block(sx, sy, sz, BLK_AIR);
                sx = sx + 1;
            }
            sz = sz + 1;
        }
        sy = sy + 1;
    }

    // Upgrade Shrine & Destructible Crates / Spawners
    set_block(8, 1, 8, trim_blk);
    set_block(5, 1, 8, BLK_SHRINE);
    set_block(11, 1, 5, BLK_CRATE);
    set_block(4, 1, 11, BLK_CRATE);
    if depth >= 2 {
        set_block(11, 1, 11, BLK_SPAWNER);
    }

    // Red Grow Ring near upper shaft + Green/Blue/Pink Shrink Rings
    let _ = spawn_entity(ENT_RING_RED, 8.0, 11.8, 8.0, 1, BLK_AIR);
    let next_blk_a: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_FLOWER_B }
        else if biome == BIOME_BLUE_FLOWER { BLK_MYLANTIS }
        else if biome == BIOME_MYLANTIS { BLK_BLACK_CUBE }
        else { BLK_CORE };
    let _ = spawn_entity(ENT_RING_GREEN, 4.5, 3.0, 4.5, 1, next_blk_a);
    let _ = spawn_entity(ENT_RING_BLUE, 12.0, 5.5, 12.0, 1, BLK_MYLANTIS);
    if depth >= 2 {
        let _ = spawn_entity(ENT_RING_PINK, 12.0, 3.0, 4.5, 1, BLK_BLACK_CUBE);
    }

    // Scale-appropriate enemies + Core Boss at depth >= 6
    let scale_hp = 30 + depth * 22;
    let _ = spawn_entity(ENT_GOBLIN, 4.5, 2.5, 11.5, scale_hp, 0);
    let _ = spawn_entity(ENT_SLIME, 11.5, 2.5, 4.5, scale_hp - 5, 0);
    if depth >= 2 {
        let _ = spawn_entity(ENT_TURRET, 3.5, 8.0, 12.5, scale_hp + 20, 0);
        let _ = spawn_entity(ENT_WARDEN, 12.5, 3.0, 12.5, scale_hp + 45, 0);
    }
    if depth >= 6 {
        let _ = spawn_entity(ENT_BOSS, 8.0, 6.5, 12.0, 260 + depth * 40, 0);
        if st.k_rescued == 0 {
            let _ = spawn_entity(ENT_K_BEACON, 8.0, 2.6, 13.5, 1, 0);
        }
    }

    // Pickups
    let _ = spawn_entity(ENT_GOLD, 6.5, 2.2, 5.5, 1, 0);
    let _ = spawn_entity(ENT_GOLD, 10.5, 2.2, 10.5, 1, 0);
    let _ = spawn_entity(ENT_HEALTH, 8.0, 2.2, 4.0, 1, 0);
    let _ = spawn_entity(ENT_ARMOR, 12.0, 2.2, 8.0, 1, 0);
    let _ = spawn_entity(ENT_AMMO, 4.0, 2.2, 8.0, 1, 0);
}

fn load_current_chunk() {
    var i: i32 = 0;
    while i < CHUNK_VOL {
        st.blocks[i] = BLK_AIR;
        i = i + 1;
    }
    clear_entities_and_shots();

    let sidx = st.depth + MACRO_OFFSET;
    let biome = st.stack[sidx].biome;
    let seed = st.stack[sidx].seed;

    if biome == BIOME_YING_FOREST {
        generate_ying_forest();
    } else if biome == BIOME_MACRO {
        generate_macro_garden();
    } else {
        generate_interior_biome(biome, st.depth, seed);
    }

    // Reapply persistent block deltas (destroyed crates/spawners, waypoints)
    i = 0;
    while i < MAX_DELTAS {
        if st.deltas[i].used != 0 && st.deltas[i].seed == seed {
            set_block(st.deltas[i].bx, st.deltas[i].by, st.deltas[i].bz, st.deltas[i].blk);
        }
        i = i + 1;
    }
}

fn shrink_into(bx: i32, by: i32, bz: i32, target_blk: u8, steps: i32) {
    if st.ring_cd_ms > 0 { return; }
    var d: i32 = 0;
    var cur_bx: i32 = bx;
    var cur_by: i32 = by;
    var cur_bz: i32 = bz;
    var cur_blk: u8 = target_blk;
    while d < steps {
        let next_depth = st.depth + 1;
        let next_idx = next_depth + MACRO_OFFSET;
        if next_idx >= MAX_STACK {
            set_status_msg("Max fractal recursion depth reached!", 1600);
            break;
        }
        let cur_idx = st.depth + MACRO_OFFSET;
        let pseed = st.stack[cur_idx].seed;
        let nseed = hash_block_seed(pseed, cur_bx, cur_by, cur_bz, next_depth);
        st.depth = next_depth;
        if st.depth > st.max_depth_reached { st.max_depth_reached = st.depth; }
        st.stack[next_idx].bx = cur_bx;
        st.stack[next_idx].by = cur_by;
        st.stack[next_idx].bz = cur_bz;
        st.stack[next_idx].parent_block = cur_blk;
        st.stack[next_idx].seed = nseed;
        st.stack[next_idx].biome = pick_biome(next_depth, cur_blk, nseed);
        cur_bx = 8; cur_by = 8; cur_bz = 8;
        cur_blk = BLK_BLACK_CUBE;
        d = d + 1;
    }

    load_current_chunk();
    st.px = 8.0;
    st.py = 3.2;
    st.pz = 8.0;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.ring_cd_ms = 750;
    st.flash_ms = 260;
    st.flash_rgb = pack_rgb(40, 235, 130);
    set_status_msg("SHRANK 16x deeper into the fractal!", 1800);
}

fn grow_out() {
    if st.ring_cd_ms > 0 { return; }
    let next_depth = st.depth - 1;
    let next_idx = next_depth + MACRO_OFFSET;
    if next_idx < 1 {
        set_status_msg("Outer Cosmic Boundary reached! Dive back down!", 1600);
        return;
    }
    let cur_idx = st.depth + MACRO_OFFSET;
    let ret_bx = st.stack[cur_idx].bx;
    let ret_by = st.stack[cur_idx].by;
    let ret_bz = st.stack[cur_idx].bz;

    // Ensure macro frame exists if growing above 0 for the first time
    if next_depth < 0 && st.stack[next_idx].seed == 0 {
        let mseed = hash_block_seed(0x4642575f584152, 8, 4, 8, next_depth);
        st.stack[next_idx].bx = 8;
        st.stack[next_idx].by = 4;
        st.stack[next_idx].bz = 8;
        st.stack[next_idx].parent_block = BLK_AIR;
        st.stack[next_idx].seed = mseed;
        st.stack[next_idx].biome = BIOME_MACRO;
    }

    st.depth = next_depth;
    load_current_chunk();
    // Emerge safely above or beside the parent block
    if st.depth < 0 {
        st.px = 8.5;
        st.py = 6.2;
        st.pz = 8.5;
    } else {
        st.px = ret_bx + 0.5;
        st.py = fclamp(ret_by + 1.4, 2.8, 13.5);
        st.pz = ret_bz + 0.5;
        // Clear landing spot if solid
        let lx = ffloor(st.px);
        let ly = ffloor(st.py);
        let lz = ffloor(st.pz);
        if is_block_solid(get_block(lx, ly, lz)) != 0 {
            st.py = 11.5;
        }
    }
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.ring_cd_ms = 750;
    st.flash_ms = 260;
    st.flash_rgb = pack_rgb(245, 70, 70);
    set_status_msg("GREW 16x outward to parent scale!", 1800);
}

// ---------------------------------------------------------------------------
// Game Init / Reset
// ---------------------------------------------------------------------------
fn init_new_game() {
    var i: i32 = 0;
    while i < MAX_STACK {
        st.stack[i].seed = 0;
        st.stack[i].biome = BIOME_MACRO;
        i = i + 1;
    }
    i = 0;
    while i < MAX_DELTAS {
        st.deltas[i].used = 0;
        i = i + 1;
    }
    st.delta_head = 0;

    st.depth = 0;
    st.max_depth_reached = 0;
    let zidx = MACRO_OFFSET;
    st.stack[zidx].bx = 8;
    st.stack[zidx].by = 4;
    st.stack[zidx].bz = 8;
    st.stack[zidx].parent_block = BLK_GRASS;
    st.stack[zidx].seed = 0x5841525f59494e47;
    st.stack[zidx].biome = BIOME_YING_FOREST;

    st.px = 8.5;
    st.py = 3.0;
    st.pz = 3.2;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.yaw = HALF_PI; // Facing +Z toward the Jumbo Yellow Flower!
    st.pitch = -0.05;

    st.hp = 100;
    st.max_hp = 100;
    st.armor = 50;
    st.max_armor = 100;
    st.gold = 25;
    st.kills = 0;
    st.k_rescued = 0;

    st.weapon = WEP_PLASMA;
    st.ammo[0] = 9999; // Plasma infinite
    st.ammo[1] = 160;  // Minigun
    st.ammo[2] = 45;   // Laser
    st.ammo[3] = 20;   // Cannon
    st.ammo[4] = 16;   // Railgun
    st.ammo[5] = 3;    // Dark Hole

    st.dmg_lvl = 1;
    st.rof_lvl = 1;
    st.spd_lvl = 1;
    st.fire_cd_ms = 0;
    st.ring_cd_ms = 400;
    st.beam_timer_ms = 0;
    st.has_wp = 0;
    st.flash_ms = 0;
    st.near_ring_kind = ENT_NONE;
    st.target_name_len = 0;

    load_current_chunk();
    set_status_msg("Welcome to Xar (Ying Forest). Enter the Yellow Flower Green Ring!", 3500);
}

// ---------------------------------------------------------------------------
// Physics, Combat & AI Simulation
// ---------------------------------------------------------------------------
fn point_collides(x: f64, y: f64, z: f64) -> i32 {
    let rad: f64 = 0.26;
    var dz: i32 = -1;
    while dz <= 1 {
        var dy: i32 = -1;
        while dy <= 1 {
            var dx: i32 = -1;
            while dx <= 1 {
                let cx = ffloor(x + dx * rad);
                let cy = ffloor(y + dy * rad);
                let cz = ffloor(z + dz * rad);
                if is_block_solid(get_block(cx, cy, cz)) != 0 {
                    return 1;
                }
                dx = dx + 1;
            }
            dy = dy + 1;
        }
        dz = dz + 1;
    }
    return 0;
}

fn move_player(dx: f64, dy: f64, dz: f64) {
    let nx = st.px + dx;
    if point_collides(nx, st.py, st.pz) == 0 { st.px = nx; }
    let ny = st.py + dy;
    if point_collides(st.px, ny, st.pz) == 0 { st.py = ny; }
    let nz = st.pz + dz;
    if point_collides(st.px, st.py, nz) == 0 { st.pz = nz; }

    // Clamp horizontally inside 16x16 chunk, but allow flying out sky at top
    st.px = fclamp(st.px, 0.35, 15.65);
    st.pz = fclamp(st.pz, 0.35, 15.65);
    if st.py < 1.35 { st.py = 1.35; }

    // Flying high out the top of a chunk triggers natural Scale Grow!
    if st.py > 15.6 {
        grow_out();
    }
}

fn damage_player(dmg_in: i32) {
    if st.screen != SCREEN_PLAY { return; }
    var dmg: i32 = dmg_in;
    if st.armor > 0 {
        let absorbed = if st.armor >= (dmg * 2) / 3 { (dmg * 2) / 3 } else { st.armor };
        st.armor = st.armor - absorbed;
        dmg = dmg - absorbed;
    }
    st.hp = st.hp - dmg;
    st.flash_ms = 180;
    st.flash_rgb = pack_rgb(220, 28, 38);
    if st.hp <= 0 {
        st.hp = 0;
        st.screen = SCREEN_DEAD;
    }
}

fn break_block_at(bx: i32, by: i32, bz: i32) {
    let b = get_block(bx, by, bz);
    if is_block_destructible(b) == 0 { return; }
    set_block(bx, by, bz, BLK_AIR);
    record_block_delta(bx, by, bz, BLK_AIR);
    let cx = (bx as f64) + 0.5;
    let cy = (by as f64) + 0.5;
    let cz = (bz as f64) + 0.5;
    spawn_burst(cx, cy, cz, block_base_rgb(b), 12);
    if b == BLK_CRATE {
        let _ = spawn_entity(ENT_GOLD, cx, cy, cz, 1, 0);
        let _ = spawn_entity(ENT_AMMO, cx + 0.25, cy, cz, 1, 0);
        set_status_msg("Treasure crate shattered! Gold + Ammo dropped.", 1400);
    } else if b == BLK_SPAWNER {
        let _ = spawn_entity(ENT_GOLD, cx, cy, cz, 1, 0);
        let _ = spawn_entity(ENT_ARMOR, cx, cy + 0.2, cz, 1, 0);
        st.kills = st.kills + 1;
        set_status_msg("Spawner Hive destroyed!", 1600);
    }
}

fn damage_entity(idx: i32, dmg: i32) {
    if st.entities[idx].active == 0 { return; }
    let k = st.entities[idx].kind;
    if k < ENT_GOBLIN || k > ENT_BOSS { return; }
    st.entities[idx].hp = st.entities[idx].hp - dmg;
    spawn_burst(st.entities[idx].x, st.entities[idx].y, st.entities[idx].z, pack_rgb(255, 110, 60), 6);
    if st.entities[idx].hp <= 0 {
        st.entities[idx].active = 0;
        st.kills = st.kills + 1;
        let ex = st.entities[idx].x;
        let ey = st.entities[idx].y;
        let ez = st.entities[idx].z;
        spawn_burst(ex, ey, ez, pack_rgb(255, 210, 70), 14);
        let _ = spawn_entity(ENT_GOLD, ex, ey, ez, 1, 0);
        if k == ENT_BOSS {
            let _ = spawn_entity(ENT_ARMOR, ex + 0.4, ey, ez, 1, 0);
            let _ = spawn_entity(ENT_HEALTH, ex - 0.4, ey, ez, 1, 0);
            set_status_msg("CORE GUARDIAN DEFEATED! Fly to K's Beacon [★]!", 3500);
        } else if (rng_u32() % 3) == 0 {
            let _ = spawn_entity(ENT_HEALTH, ex + 0.3, ey, ez, 1, 0);
        }
    }
}

fn explosion_at(x: f64, y: f64, z: f64, rad: f64, dmg: i32, rgb: u32) {
    spawn_burst(x, y, z, rgb, 18);
    // Damage enemies in radius
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 {
            let dx = st.entities[i].x - x;
            let dy = st.entities[i].y - y;
            let dz = st.entities[i].z - z;
            let d = fsqrt(dx * dx + dy * dy + dz * dz);
            if d <= rad {
                damage_entity(i, dmg);
            }
        }
        i = i + 1;
    }
    // Break destructible blocks in radius
    let ir = (rad + 0.6) as! i32;
    let cx = ffloor(x);
    let cy = ffloor(y);
    let cz = ffloor(z);
    var bz: i32 = cz - ir;
    while bz <= cz + ir {
        var by: i32 = cy - ir;
        while by <= cy + ir {
            var bx: i32 = cx - ir;
            while bx <= cx + ir {
                if is_block_destructible(get_block(bx, by, bz)) != 0 {
                    break_block_at(bx, by, bz);
                }
                bx = bx + 1;
            }
            by = by + 1;
        }
        bz = bz + 1;
    }
}

fn fire_active_weapon() {
    if st.fire_cd_ms > 0 { return; }
    let w = st.weapon;
    if w != WEP_PLASMA && st.ammo[w] <= 0 {
        st.weapon = WEP_PLASMA;
        set_status_msg("Out of ammo — switched to Plasma!", 1200);
        return;
    }
    if w != WEP_PLASMA { st.ammo[w] = st.ammo[w] - 1; }

    let cp = fcos(st.pitch);
    let dx = cp * fcos(st.yaw);
    let dy = fsin(st.pitch);
    let dz = cp * fsin(st.yaw);

    let base_rof_mul = 1.0 / (1.0 + 0.18 * ((st.rof_lvl - 1) as f64));
    let dmg_bonus = 1.0 + 0.25 * ((st.dmg_lvl - 1) as f64);

    if w == WEP_PLASMA {
        st.fire_cd_ms = (210.0 * base_rof_mul) as! i32;
        let dmg = (18.0 * dmg_bonus) as! i32;
        spawn_shot(1, w, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4, dx * 16.0, dy * 16.0, dz * 16.0, dmg, 1400, pack_rgb(56, 224, 255));
    } else if w == WEP_MINIGUN {
        st.fire_cd_ms = (85.0 * base_rof_mul) as! i32;
        let dmg = (11.0 * dmg_bonus) as! i32;
        let jx = dx + (rng_f01() - 0.5) * 0.05;
        let jy = dy + (rng_f01() - 0.5) * 0.05;
        let jz = dz + (rng_f01() - 0.5) * 0.05;
        spawn_shot(1, w, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4, jx * 22.0, jy * 22.0, jz * 22.0, dmg, 1000, pack_rgb(255, 210, 72));
    } else if w == WEP_LASER || w == WEP_RAILGUN {
        let is_rail = if w == WEP_RAILGUN { 1 } else { 0 };
        st.fire_cd_ms = if is_rail != 0 { (650.0 * base_rof_mul) as! i32 } else { (280.0 * base_rof_mul) as! i32 };
        let dmg = ((if is_rail != 0 { 72.0 } else { 32.0 }) * dmg_bonus) as! i32;
        let col = if is_rail != 0 { pack_rgb(196, 86, 255) } else { pack_rgb(255, 68, 86) };

        // Hitscan march
        var t: f64 = 0.4;
        var end_x: f64 = st.px + dx * 18.0;
        var end_y: f64 = st.py + dy * 18.0;
        var end_z: f64 = st.pz + dz * 18.0;
        while t < 20.0 {
            let hx = st.px + dx * t;
            let hy = st.py + dy * t;
            let hz = st.pz + dz * t;
            let bx = ffloor(hx);
            let by = ffloor(hy);
            let bz = ffloor(hz);
            if bx < 0 || bx >= 16 || by < 0 || by >= 16 || bz < 0 || bz >= 16 {
                end_x = hx; end_y = hy; end_z = hz;
                break;
            }
            let blk = get_block(bx, by, bz);
            if is_block_solid(blk) != 0 {
                end_x = hx; end_y = hy; end_z = hz;
                if is_block_destructible(blk) != 0 {
                    break_block_at(bx, by, bz);
                } else {
                    spawn_burst(hx, hy, hz, col, 6);
                }
                break;
            }
            // Check entities
            var ei: i32 = 0;
            while ei < MAX_ENTITIES {
                if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_GOBLIN && st.entities[ei].kind <= ENT_BOSS {
                    let ex = st.entities[ei].x - hx;
                    let ey = st.entities[ei].y - hy;
                    let ez = st.entities[ei].z - hz;
                    if (ex * ex + ey * ey + ez * ez) < 0.38 {
                        damage_entity(ei, dmg);
                        if is_rail == 0 {
                            end_x = hx; end_y = hy; end_z = hz;
                            t = 99.0;
                            break;
                        }
                    }
                }
                ei = ei + 1;
            }
            t = t + 0.25;
        }
        st.beam_timer_ms = 140;
        st.beam_rgb = col;
        st.beam_x1 = st.px + dx * 0.45;
        st.beam_y1 = st.py + dy * 0.45 - 0.12;
        st.beam_z1 = st.pz + dz * 0.45;
        st.beam_x2 = end_x;
        st.beam_y2 = end_y;
        st.beam_z2 = end_z;
    } else if w == WEP_CANNON {
        st.fire_cd_ms = (460.0 * base_rof_mul) as! i32;
        let dmg = (55.0 * dmg_bonus) as! i32;
        spawn_shot(1, w, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4, dx * 13.0, dy * 13.0, dz * 13.0, dmg, 1800, pack_rgb(255, 138, 36));
    } else if w == WEP_DARKHOLE {
        st.fire_cd_ms = (850.0 * base_rof_mul) as! i32;
        let dmg = (150.0 * dmg_bonus) as! i32;
        spawn_shot(1, w, st.px + dx * 0.5, st.py + dy * 0.5, st.pz + dz * 0.5, dx * 9.0, dy * 9.0, dz * 9.0, dmg, 2000, pack_rgb(218, 62, 255));
    }
}

fn interact_nearest() {
    // Check nearby K Beacon, Scale Rings, or Upgrade Shrine
    var i: i32 = 0;
    var best_ring: i32 = -1;
    var best_d: f64 = 2.4;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 {
            let k = st.entities[i].kind;
            let dx = st.entities[i].x - st.px;
            let dy = st.entities[i].y - st.py;
            let dz = st.entities[i].z - st.pz;
            let d = fsqrt(dx * dx + dy * dy + dz * dz);
            if k == ENT_K_BEACON && d < 2.2 {
                st.k_rescued = 1;
                st.entities[i].active = 0;
                st.gold = st.gold + 250;
                st.flash_ms = 420;
                st.flash_rgb = pack_rgb(255, 224, 96);
                set_status_msg("FRIEND 'K' RESCUED AT INNER CORE! +250 Gold! Keep diving deeper!", 4500);
                return;
            }
            if (k >= ENT_RING_GREEN && k <= ENT_RING_PINK) && d < best_d {
                best_d = d;
                best_ring = i;
            }
        }
        i = i + 1;
    }

    if best_ring >= 0 {
        let k = st.entities[best_ring].kind;
        let rx = ffloor(st.entities[best_ring].x);
        let ry = ffloor(st.entities[best_ring].y);
        let rz = ffloor(st.entities[best_ring].z);
        let tb = st.entities[best_ring].target_block;
        if k == ENT_RING_RED {
            grow_out();
        } else if k == ENT_RING_PINK {
            shrink_into(rx, ry, rz, tb, 2);
        } else {
            shrink_into(rx, ry, rz, tb, 1);
        }
        return;
    }

    // Check nearby Upgrade Shrine block
    let pbx = ffloor(st.px);
    let pby = ffloor(st.py);
    let pbz = ffloor(st.pz);
    var dz2: i32 = -2;
    while dz2 <= 2 {
        var dy2: i32 = -2;
        while dy2 <= 2 {
            var dx2: i32 = -2;
            while dx2 <= 2 {
                if get_block(pbx + dx2, pby + dy2, pbz + dz2) == BLK_SHRINE {
                    st.screen = SCREEN_UPGRADE;
                    return;
                }
                dx2 = dx2 + 1;
            }
            dy2 = dy2 + 1;
        }
        dz2 = dz2 + 1;
    }
    set_status_msg("Press [U] for Field Upgrade Shop or fly into a Scale Ring!", 1600);
}

fn step_simulation(dt_ms: i32) {
    if st.screen != SCREEN_PLAY { return; }
    let dt = (dt_ms as f64) / 1000.0;

    if st.fire_cd_ms > 0 { st.fire_cd_ms = st.fire_cd_ms - dt_ms; if st.fire_cd_ms < 0 { st.fire_cd_ms = 0; } }
    if st.ring_cd_ms > 0 { st.ring_cd_ms = st.ring_cd_ms - dt_ms; if st.ring_cd_ms < 0 { st.ring_cd_ms = 0; } }
    if st.beam_timer_ms > 0 { st.beam_timer_ms = st.beam_timer_ms - dt_ms; if st.beam_timer_ms < 0 { st.beam_timer_ms = 0; } }
    if st.flash_ms > 0 { st.flash_ms = st.flash_ms - dt_ms; if st.flash_ms < 0 { st.flash_ms = 0; } }
    if st.msg_ms > 0 { st.msg_ms = st.msg_ms - dt_ms; if st.msg_ms < 0 { st.msg_ms = 0; } }

    // Update entities
    st.near_ring_kind = ENT_NONE;
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active == 0 {
            i = i + 1;
            continue;
        }
        let k = st.entities[i].kind;
        let dx = st.px - st.entities[i].x;
        let dy = st.py - st.entities[i].y;
        let dz = st.pz - st.entities[i].z;
        let dist = fsqrt(dx * dx + dy * dy + dz * dz);

        // Ring proximity & auto-traverse
        if k >= ENT_RING_GREEN && k <= ENT_RING_PINK {
            if dist < 2.2 { st.near_ring_kind = k; }
            if dist < 0.78 && st.ring_cd_ms <= 0 {
                let rx = ffloor(st.entities[i].x);
                let ry = ffloor(st.entities[i].y);
                let rz = ffloor(st.entities[i].z);
                let tb = st.entities[i].target_block;
                if k == ENT_RING_RED { grow_out(); }
                else if k == ENT_RING_PINK { shrink_into(rx, ry, rz, tb, 2); }
                else { shrink_into(rx, ry, rz, tb, 1); }
                return;
            }
        } else if k == ENT_K_BEACON {
            if dist < 0.95 {
                st.k_rescued = 1;
                st.entities[i].active = 0;
                st.gold = st.gold + 250;
                st.flash_ms = 420;
                st.flash_rgb = pack_rgb(255, 224, 96);
                set_status_msg("FRIEND 'K' RESCUED AT INNER CORE! +250 Gold! Keep diving deeper!", 4500);
            }
        } else if k >= ENT_GOLD && k <= ENT_AMMO {
            if dist < 1.05 {
                st.entities[i].active = 0;
                if k == ENT_GOLD {
                    let gain = 15 + st.depth * 5;
                    st.gold = st.gold + (if gain > 5 { gain } else { 10 });
                    set_status_msg("+Gold collected!", 900);
                } else if k == ENT_HEALTH {
                    st.hp = clamp_i(st.hp + 25, 0, st.max_hp);
                    set_status_msg("+25 Health restored!", 900);
                } else if k == ENT_ARMOR {
                    st.armor = clamp_i(st.armor + 25, 0, st.max_armor);
                    set_status_msg("+25 Armor!", 900);
                } else if k == ENT_AMMO {
                    st.ammo[WEP_MINIGUN] = st.ammo[WEP_MINIGUN] + 40;
                    st.ammo[WEP_LASER] = st.ammo[WEP_LASER] + 12;
                    st.ammo[WEP_CANNON] = st.ammo[WEP_CANNON] + 5;
                    st.ammo[WEP_RAILGUN] = st.ammo[WEP_RAILGUN] + 4;
                    st.ammo[WEP_DARKHOLE] = st.ammo[WEP_DARKHOLE] + 1;
                    set_status_msg("+Weapon Ammo Pack!", 1000);
                }
            }
        } else if k >= ENT_GOBLIN && k <= ENT_BOSS {
            // Enemy AI
            if dist > 0.2 && dist < 12.5 {
                let spd =
                    if k == ENT_GOBLIN { 2.0 }
                    else if k == ENT_SLIME { 1.4 }
                    else if k == ENT_TURRET { 0.0 }
                    else if k == ENT_WARDEN { 1.25 }
                    else { 1.5 };
                if spd > 0.0 && dist > 1.3 {
                    let step_x = (dx / dist) * spd * dt;
                    let step_y = (dy / dist) * spd * 0.7 * dt;
                    let step_z = (dz / dist) * spd * dt;
                    let nx = st.entities[i].x + step_x;
                    let ny = st.entities[i].y + step_y;
                    let nz = st.entities[i].z + step_z;
                    if is_block_solid(get_block(ffloor(nx), ffloor(st.entities[i].y), ffloor(st.entities[i].z))) == 0 {
                        st.entities[i].x = nx;
                    }
                    if is_block_solid(get_block(ffloor(st.entities[i].x), ffloor(ny), ffloor(st.entities[i].z))) == 0 {
                        st.entities[i].y = ny;
                    }
                    if is_block_solid(get_block(ffloor(st.entities[i].x), ffloor(st.entities[i].y), ffloor(nz))) == 0 {
                        st.entities[i].z = nz;
                    }
                }

                // Ranged attack or melee
                st.entities[i].cooldown = st.entities[i].cooldown - dt_ms;
                if st.entities[i].cooldown <= 0 {
                    if dist < 1.35 {
                        damage_player(8 + st.depth * 2);
                        st.entities[i].cooldown = 850;
                    } else if dist < 11.0 {
                        let sspd = 7.5;
                        let edmg = 6 + st.depth * 2 + (if k == ENT_BOSS { 8 } else { 0 });
                        let ergb = if k == ENT_BOSS { pack_rgb(255, 64, 210) } else { pack_rgb(255, 92, 64) };
                        spawn_shot(0, 0, st.entities[i].x, st.entities[i].y, st.entities[i].z,
                            (dx / dist) * sspd, (dy / dist) * sspd, (dz / dist) * sspd, edmg, 1700, ergb);
                        st.entities[i].cooldown = if k == ENT_BOSS { 700 } else if k == ENT_TURRET { 1250 } else { 1650 };
                    }
                }
            }
        }
        i = i + 1;
    }

    // Update projectiles
    i = 0;
    while i < MAX_SHOTS {
        if st.shots[i].active == 0 {
            i = i + 1;
            continue;
        }
        st.shots[i].ttl_ms = st.shots[i].ttl_ms - dt_ms;
        if st.shots[i].ttl_ms <= 0 {
            if st.shots[i].from_player != 0 && (st.shots[i].wep == WEP_CANNON || st.shots[i].wep == WEP_DARKHOLE) {
                let rad = if st.shots[i].wep == WEP_DARKHOLE { 4.2 } else { 2.4 };
                explosion_at(st.shots[i].x, st.shots[i].y, st.shots[i].z, rad, st.shots[i].dmg, st.shots[i].rgb);
            }
            st.shots[i].active = 0;
            i = i + 1;
            continue;
        }
        let nx = st.shots[i].x + st.shots[i].vx * dt;
        let ny = st.shots[i].y + st.shots[i].vy * dt;
        let nz = st.shots[i].z + st.shots[i].vz * dt;
        let bx = ffloor(nx);
        let by = ffloor(ny);
        let bz = ffloor(nz);
        if bx < 0 || bx >= 16 || by < 0 || by >= 16 || bz < 0 || bz >= 16 {
            st.shots[i].active = 0;
            i = i + 1;
            continue;
        }
        let blk = get_block(bx, by, bz);
        if is_block_solid(blk) != 0 {
            if st.shots[i].from_player != 0 {
                if st.shots[i].wep == WEP_CANNON || st.shots[i].wep == WEP_DARKHOLE {
                    let rad = if st.shots[i].wep == WEP_DARKHOLE { 4.2 } else { 2.4 };
                    explosion_at(nx, ny, nz, rad, st.shots[i].dmg, st.shots[i].rgb);
                } else {
                    spawn_burst(nx, ny, nz, st.shots[i].rgb, 5);
                    if is_block_destructible(blk) != 0 {
                        break_block_at(bx, by, bz);
                    }
                }
            }
            st.shots[i].active = 0;
            i = i + 1;
            continue;
        }
        st.shots[i].x = nx;
        st.shots[i].y = ny;
        st.shots[i].z = nz;

        if st.shots[i].from_player != 0 {
            var ei: i32 = 0;
            while ei < MAX_ENTITIES {
                if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_GOBLIN && st.entities[ei].kind <= ENT_BOSS {
                    let ex = st.entities[ei].x - nx;
                    let ey = st.entities[ei].y - ny;
                    let ez = st.entities[ei].z - nz;
                    if (ex * ex + ey * ey + ez * ez) < 0.42 {
                        if st.shots[i].wep == WEP_CANNON || st.shots[i].wep == WEP_DARKHOLE {
                            let rad = if st.shots[i].wep == WEP_DARKHOLE { 4.2 } else { 2.4 };
                            explosion_at(nx, ny, nz, rad, st.shots[i].dmg, st.shots[i].rgb);
                        } else {
                            damage_entity(ei, st.shots[i].dmg);
                        }
                        st.shots[i].active = 0;
                        break;
                    }
                }
                ei = ei + 1;
            }
        } else {
            let ex = st.px - nx;
            let ey = st.py - ny;
            let ez = st.pz - nz;
            if (ex * ex + ey * ey + ez * ez) < 0.36 {
                damage_player(st.shots[i].dmg);
                st.shots[i].active = 0;
            }
        }
        i = i + 1;
    }

    // Update particles
    i = 0;
    while i < MAX_PARTICLES {
        if st.particles[i].active != 0 {
            st.particles[i].ttl_ms = st.particles[i].ttl_ms - dt_ms;
            if st.particles[i].ttl_ms <= 0 {
                st.particles[i].active = 0;
            } else {
                st.particles[i].x = st.particles[i].x + st.particles[i].vx * dt;
                st.particles[i].y = st.particles[i].y + st.particles[i].vy * dt;
                st.particles[i].z = st.particles[i].z + st.particles[i].vz * dt;
            }
        }
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// 3D Voxel DDA Raycaster & Half-Block Truecolor Framebuffer Renderer
// ---------------------------------------------------------------------------
fn shade_hit_block(blk: u8, axis: i32, dist: f64, hx: f64, hy: f64, hz: f64, sky: u32) -> u32 {
    let base = block_base_rgb(blk);
    var u: f64 = 0.0;
    var v: f64 = 0.0;
    var face_mul: f64 = 1.0;

    if axis == 0 {
        u = hz - ffloor(hz);
        v = hy - ffloor(hy);
        face_mul = 0.78;
    } else if axis == 1 {
        u = hx - ffloor(hx);
        v = hz - ffloor(hz);
        face_mul = 1.04;
    } else {
        u = hx - ffloor(hx);
        v = hy - ffloor(hy);
        face_mul = 0.88;
    }

    // Block grid seam border (signature FBW crisp block edges)
    var detail: f64 = 1.0;
    if u < 0.06 || u > 0.94 || v < 0.06 || v > 0.94 {
        detail = if blk == BLK_BLACK_CUBE || blk == BLK_SHRINE || blk == BLK_CORE { 1.45 } else { 0.65 };
    } else if block_is_fractal(blk) != 0 {
        // Recursive 4x4 sub-fractal micro-grid texture on special blocks!
        let su = ffloor(u * 4.0);
        let sv = ffloor(v * 4.0);
        if ((su + sv) & 1) == 0 { detail = 1.12; } else { detail = 0.88; }
        if su >= 1 && su <= 2 && sv >= 1 && sv <= 2 {
            if blk == BLK_BLACK_CUBE { detail = 0.55; }
            else if blk == BLK_SHRINE { detail = 1.35; }
        }
    } else if blk == BLK_CRATE {
        // Diagonal crate brace
        let du = fabs(u - v);
        if du < 0.10 { detail = 1.28; }
    }

    var shaded = scale_rgb(base, face_mul * detail);
    if blk == BLK_BLACK_CUBE && (u < 0.06 || u > 0.94 || v < 0.06 || v > 0.94) {
        shaded = pack_rgb(138, 92, 246);
    } else if blk == BLK_SPAWNER && ((ffloor(u * 4.0) + ffloor(v * 4.0)) & 1) != 0 {
        shaded = pack_rgb(255, 86, 112);
    }

    // Distance fog into biome sky
    let fog = fclamp((dist - 4.0) / 20.0, 0.0, 0.82);
    return lerp_rgb(shaded, sky, fog);
}

fn draw_pixel_safe(x: i32, y: i32, z: f64, rgb: u32) {
    if x < 0 || x >= st.pw || y < 0 || y >= st.ph { return; }
    let idx = y * st.pw + x;
    if z < st.fb_z[idx] {
        st.fb_z[idx] = z;
        st.fb_rgb[idx] = rgb;
    }
}

fn render_3d_world() {
    let pw = st.pw;
    let ph = st.ph;
    if pw <= 0 || ph <= 0 { return; }

    let sidx = st.depth + MACRO_OFFSET;
    let biome = st.stack[sidx].biome;
    let sky_top = biome_sky_top(biome);
    let sky_bot = biome_sky_bot(biome);

    // Orthonormal camera basis
    let cp = fcos(st.pitch);
    let sp = fsin(st.pitch);
    let cy = fcos(st.yaw);
    let sy = fsin(st.yaw);

    let fx = cp * cy;
    let fy = sp;
    let fz = cp * sy;

    let rx = -sy;
    let ry = 0.0;
    let rz = cy;

    let ux = -sp * cy;
    let uy = cp;
    let uz = -sp * sy;

    let aspect = (pw as f64) / ph;
    let fov_scale: f64 = 0.72;

    let start_bx = ffloor(st.px);
    let start_by = ffloor(st.py);
    let start_bz = ffloor(st.pz);

    // Clear target tracking
    st.target_name_len = 0;

    // 1) Raycast 3D DDA per pixel
    var py: i32 = 0;
    while py < ph {
        let ny = (1.0 - (2.0 * (py + 0.5) / ph)) * fov_scale;
        let sky_t = (py as f64) / ph;
        let row_sky = lerp_rgb(sky_top, sky_bot, sky_t);

        var px: i32 = 0;
        while px < pw {
            let nx = ((2.0 * (px + 0.5) / pw) - 1.0) * fov_scale * aspect;

            let rdx = fx + rx * nx + ux * ny;
            let rdy = fy + ry * nx + uy * ny;
            let rdz = fz + rz * nx + uz * ny;

            var map_x: i32 = start_bx;
            var map_y: i32 = start_by;
            var map_z: i32 = start_bz;

            let step_x: i32 = if rdx < 0.0 { -1 } else { 1 };
            let step_y: i32 = if rdy < 0.0 { -1 } else { 1 };
            let step_z: i32 = if rdz < 0.0 { -1 } else { 1 };

            let tdx: f64 = if fabs(rdx) < 1e-8 { 1e12 } else { fabs(1.0 / rdx) };
            let tdy: f64 = if fabs(rdy) < 1e-8 { 1e12 } else { fabs(1.0 / rdy) };
            let tdz: f64 = if fabs(rdz) < 1e-8 { 1e12 } else { fabs(1.0 / rdz) };

            var tmax_x: f64 = if rdx < 0.0 { (st.px - map_x) * tdx } else { ((map_x + 1) - st.px) * tdx };
            var tmax_y: f64 = if rdy < 0.0 { (st.py - map_y) * tdy } else { ((map_y + 1) - st.py) * tdy };
            var tmax_z: f64 = if rdz < 0.0 { (st.pz - map_z) * tdz } else { ((map_z + 1) - st.pz) * tdz };

            var hit: i32 = 0;
            var hit_blk: u8 = BLK_AIR;
            var hit_axis: i32 = 0;
            var hit_t: f64 = 32.0;

            var step_i: i32 = 0;
            while step_i < 28 {
                if tmax_x < tmax_y {
                    if tmax_x < tmax_z {
                        hit_t = tmax_x;
                        map_x = map_x + step_x;
                        tmax_x = tmax_x + tdx;
                        hit_axis = 0;
                    } else {
                        hit_t = tmax_z;
                        map_z = map_z + step_z;
                        tmax_z = tmax_z + tdz;
                        hit_axis = 2;
                    }
                } else {
                    if tmax_y < tmax_z {
                        hit_t = tmax_y;
                        map_y = map_y + step_y;
                        tmax_y = tmax_y + tdy;
                        hit_axis = 1;
                    } else {
                        hit_t = tmax_z;
                        map_z = map_z + step_z;
                        tmax_z = tmax_z + tdz;
                        hit_axis = 2;
                    }
                }

                if map_x < 0 || map_x >= CHUNK_DIM || map_y < 0 || map_y >= CHUNK_DIM || map_z < 0 || map_z >= CHUNK_DIM {
                    if map_y < 0 {
                        // Solid bedrock below chunk
                        hit = 1;
                        hit_blk = BLK_DIRT;
                    }
                    break;
                }

                let blk = st.blocks[b_idx(map_x, map_y, map_z)];
                if blk != BLK_AIR {
                    hit = 1;
                    hit_blk = blk;
                    break;
                }
                step_i = step_i + 1;
            }

            let pidx = py * pw + px;
            if hit != 0 {
                let hx = st.px + rdx * hit_t;
                let hy = st.py + rdy * hit_t;
                let hz = st.pz + rdz * hit_t;
                st.fb_rgb[pidx] = shade_hit_block(hit_blk, hit_axis, hit_t, hx, hy, hz, row_sky);
                st.fb_z[pidx] = hit_t;
            } else {
                // Procedural stars in dark/macro/black-cube sky
                var sky_col = row_sky;
                if biome == BIOME_MACRO || biome == BIOME_BLACK_CUBE || biome == BIOME_INNER_CORE {
                    let sh = splitmix64(((px as u64) * 73856093) ^ ((py as u64) * 19349663));
                    if (sh % 137) == 0 && py < (ph * 2) / 3 {
                        sky_col = pack_rgb(235, 240, 255);
                    }
                }
                st.fb_rgb[pidx] = sky_col;
                st.fb_z[pidx] = 32.0;
            }
            px = px + 1;
        }
        py = py + 1;
    }

    // 2) Draw active laser/railgun beam in 3D space
    if st.beam_timer_ms > 0 {
        var bstep: i32 = 0;
        while bstep < 48 {
            let t = (bstep as f64) / 48.0;
            let bx = st.beam_x1 + (st.beam_x2 - st.beam_x1) * t;
            let by = st.beam_y1 + (st.beam_y2 - st.beam_y1) * t;
            let bz = st.beam_z1 + (st.beam_z2 - st.beam_z1) * t;
            let vx = bx - st.px;
            let vy = by - st.py;
            let vz = bz - st.pz;
            let depth_z = vx * fx + vy * fy + vz * fz;
            if depth_z > 0.25 {
                let cx = vx * rx + vy * ry + vz * rz;
                let cy = vx * ux + vy * uy + vz * uz;
                let sx = (((cx / (depth_z * fov_scale * aspect)) + 1.0) * 0.5 * pw) as! i32;
                let sy = ((1.0 - (cy / (depth_z * fov_scale))) * 0.5 * ph) as! i32;
                draw_pixel_safe(sx, sy, depth_z, st.beam_rgb);
                draw_pixel_safe(sx + 1, sy, depth_z, st.beam_rgb);
            }
            bstep = bstep + 1;
        }
    }

    // 3) Render 3D Billboard Entities (Hollow Scale Rings, Enemies, Pickups)
    let pulse = 0.85 + 0.15 * fsin(st.anim_ms * 0.006);
    var ei: i32 = 0;
    var best_cross_d: f64 = 99.0;
    while ei < MAX_ENTITIES {
        if st.entities[ei].active == 0 {
            ei = ei + 1;
            continue;
        }
        let k = st.entities[ei].kind;
        let vx = st.entities[ei].x - st.px;
        let vy = st.entities[ei].y - st.py;
        let vz = st.entities[ei].z - st.pz;
        let depth_z = vx * fx + vy * fy + vz * fz;
        if depth_z <= 0.25 {
            ei = ei + 1;
            continue;
        }

        let cx = vx * rx + vy * ry + vz * rz;
        let cy = vx * ux + vy * uy + vz * uz;
        let sx_f = ((cx / (depth_z * fov_scale * aspect)) + 1.0) * 0.5 * pw;
        let sy_f = (1.0 - (cy / (depth_z * fov_scale))) * 0.5 * ph;
        let scx = sx_f as! i32;
        let scy = sy_f as! i32;

        // Check crosshair target lock
        let cdx = fabs(sx_f - pw * 0.5);
        let cdy = fabs(sy_f - ph * 0.5);
        if cdx < 6.0 && cdy < 6.0 && depth_z < best_cross_d {
            best_cross_d = depth_z;
            if k == ENT_RING_GREEN { set_target_name("Green Shrink Ring (16x)", 0, 0); }
            else if k == ENT_RING_RED { set_target_name("Red Grow Ring (1/16x)", 0, 0); }
            else if k == ENT_RING_BLUE { set_target_name("Blue Mylantis Ring", 0, 0); }
            else if k == ENT_RING_PINK { set_target_name("Pink Deep Dive (256x)", 0, 0); }
            else if k == ENT_GOBLIN { set_target_name("Fractal Goblin", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_SLIME { set_target_name("Voxel Slime", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_TURRET { set_target_name("Sentry Turret", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_WARDEN { set_target_name("Cube Warden", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_BOSS { set_target_name("CORE GUARDIAN", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_K_BEACON { set_target_name("K's Core Beacon!", 0, 0); }
        }

        // Compute billboard radius in pixels
        let is_ring = if k >= ENT_RING_GREEN && k <= ENT_RING_PINK { 1 } else { 0 };
        let world_rad =
            if is_ring != 0 { 0.58 }
            else if k == ENT_BOSS { 0.75 }
            else if k == ENT_WARDEN { 0.52 }
            else if k >= ENT_GOLD { 0.24 }
            else { 0.40 };
        var pix_rad = ((world_rad / (depth_z * fov_scale)) * 0.5 * ph) as! i32;
        if pix_rad < 2 { pix_rad = 2; }
        if pix_rad > 28 { pix_rad = 28; }

        let col =
            if k == ENT_RING_GREEN { scale_rgb(pack_rgb(48, 255, 118), pulse) }
            else if k == ENT_RING_RED { scale_rgb(pack_rgb(255, 62, 62), pulse) }
            else if k == ENT_RING_BLUE { scale_rgb(pack_rgb(64, 168, 255), pulse) }
            else if k == ENT_RING_PINK { scale_rgb(pack_rgb(255, 92, 224), pulse) }
            else if k == ENT_GOBLIN { pack_rgb(106, 220, 74) }
            else if k == ENT_SLIME { pack_rgb(62, 232, 188) }
            else if k == ENT_TURRET { pack_rgb(245, 132, 52) }
            else if k == ENT_WARDEN { pack_rgb(168, 85, 247) }
            else if k == ENT_BOSS { scale_rgb(pack_rgb(255, 58, 168), pulse) }
            else if k == ENT_GOLD { pack_rgb(255, 215, 42) }
            else if k == ENT_HEALTH { pack_rgb(248, 72, 92) }
            else if k == ENT_ARMOR { pack_rgb(72, 196, 255) }
            else if k == ENT_AMMO { pack_rgb(255, 168, 56) }
            else { scale_rgb(pack_rgb(255, 248, 128), pulse) };

        var dy: i32 = -pix_rad;
        while dy <= pix_rad {
            var dx: i32 = -pix_rad;
            while dx <= pix_rad {
                let d2 = dx * dx + dy * dy;
                let r2 = pix_rad * pix_rad;
                if is_ring != 0 {
                    // Hollow glowing ring!
                    let inner = ((pix_rad * 58) / 100);
                    if d2 <= r2 && d2 >= inner * inner {
                        draw_pixel_safe(scx + dx, scy + dy, depth_z, col);
                    }
                } else if d2 <= r2 {
                    var px_col = col;
                    // Glowing eyes on enemies!
                    if k >= ENT_GOBLIN && k <= ENT_BOSS && dy == -(pix_rad / 4) && (dx == -(pix_rad / 3) || dx == (pix_rad / 3)) {
                        px_col = pack_rgb(255, 42, 42);
                    }
                    draw_pixel_safe(scx + dx, scy + dy, depth_z, px_col);
                }
                dx = dx + 1;
            }
            dy = dy + 1;
        }
        ei = ei + 1;
    }

    // 4) Shots & Particles
    var si: i32 = 0;
    while si < MAX_SHOTS {
        if st.shots[si].active != 0 {
            let vx = st.shots[si].x - st.px;
            let vy = st.shots[si].y - st.py;
            let vz = st.shots[si].z - st.pz;
            let depth_z = vx * fx + vy * fy + vz * fz;
            if depth_z > 0.25 {
                let cx = vx * rx + vy * ry + vz * rz;
                let cy = vx * ux + vy * uy + vz * uz;
                let sx = (((cx / (depth_z * fov_scale * aspect)) + 1.0) * 0.5 * pw) as! i32;
                let sy = ((1.0 - (cy / (depth_z * fov_scale))) * 0.5 * ph) as! i32;
                draw_pixel_safe(sx, sy, depth_z, st.shots[si].rgb);
                draw_pixel_safe(sx + 1, sy, depth_z, st.shots[si].rgb);
                draw_pixel_safe(sx, sy + 1, depth_z, st.shots[si].rgb);
            }
        }
        si = si + 1;
    }

    var pi: i32 = 0;
    while pi < MAX_PARTICLES {
        if st.particles[pi].active != 0 {
            let vx = st.particles[pi].x - st.px;
            let vy = st.particles[pi].y - st.py;
            let vz = st.particles[pi].z - st.pz;
            let depth_z = vx * fx + vy * fy + vz * fz;
            if depth_z > 0.25 {
                let cx = vx * rx + vy * ry + vz * rz;
                let cy = vx * ux + vy * uy + vz * uz;
                let sx = (((cx / (depth_z * fov_scale * aspect)) + 1.0) * 0.5 * pw) as! i32;
                let sy = ((1.0 - (cy / (depth_z * fov_scale))) * 0.5 * ph) as! i32;
                draw_pixel_safe(sx, sy, depth_z, st.particles[pi].rgb);
            }
        }
        pi = pi + 1;
    }

    // 5) Screen damage / warp tint flash
    if st.flash_ms > 0 {
        let amt = fclamp(st.flash_ms / 450.0, 0.0, 0.45);
        var k: i32 = 0;
        let tot = pw * ph;
        while k < tot {
            st.fb_rgb[k] = lerp_rgb(st.fb_rgb[k], st.flash_rgb, amt);
            k = k + 1;
        }
    }

    // 6) Blit half-block pixels (▀) onto termbox2 cell buffer
    let view_rows = ph / 2;
    var r: i32 = 0;
    while r < view_rows {
        let top_row = (r * 2) * pw;
        let bot_row = (r * 2 + 1) * pw;
        var c: i32 = 0;
        while c < pw {
            let fg = rgb_to_attr(st.fb_rgb[top_row + c]);
            let bg = rgb_to_attr(st.fb_rgb[bot_row + c]);
            let _ = tb_set_cell(c, r, CH_HALF_TOP, fg, bg);
            c = c + 1;
        }
        r = r + 1;
    }

    // Center crosshair
    let ch_x = pw / 2;
    let ch_y = view_rows / 2;
    if ch_x > 1 && ch_x < pw - 1 && ch_y > 1 && ch_y < view_rows - 1 {
        var cur_c = tb_cell { .. };
        let _ = tb_get_cell(ch_x, ch_y, 1, cur_c);
        let _ = tb_set_cell(ch_x, ch_y, '+', ui_white() | TB_BOLD, cur_c.bg);
    }
}

// ---------------------------------------------------------------------------
// Overlays: Tactical Minimap, HUD, Title, Upgrade Shop, Help
// ---------------------------------------------------------------------------
fn draw_minimap_overlay() {
    let view_rows = st.ph / 2;
    if st.term_w < 44 || view_rows < 18 { return; }
    let mx = st.term_w - 20;
    let my: i32 = 1;
    draw_rect(mx, my, 19, 19, ui_cyan() | TB_BOLD, ui_bg());
    let _ = tb_print(mx + 2, my, ui_cyan() | TB_BOLD, ui_bg(), " MAP & STACK ");

    let py_i = clamp_i(ffloor(st.py), 1, 14);
    var z: i32 = 0;
    while z < 16 {
        var x: i32 = 0;
        while x < 16 {
            let b = get_block(x, py_i, z);
            var ch: u32 = ' ';
            var col: uintattr_t = ui_bg();
            if b != BLK_AIR {
                ch = CH_BLOCK;
                col = if b == BLK_FLOWER_Y || b == BLK_POLLEN { ui_yellow() }
                    else if b == BLK_FLOWER_B || b == BLK_SHRINE { ui_cyan() }
                    else if b == BLK_BLACK_CUBE || b == BLK_CORE { ui_magenta() }
                    else if b == BLK_SPAWNER { ui_red() }
                    else { ui_green() };
            }
            let _ = tb_set_cell(mx + 1 + x, my + 1 + z, ch, col, ui_bg());
            x = x + 1;
        }
        z = z + 1;
    }

    // Entities on minimap
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 {
            let ex = clamp_i(ffloor(st.entities[i].x), 0, 15);
            let ez = clamp_i(ffloor(st.entities[i].z), 0, 15);
            let k = st.entities[i].kind;
            if k == ENT_RING_GREEN { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, 'G', ui_green() | TB_BOLD, ui_bg()); }
            else if k == ENT_RING_RED { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, 'R', ui_red() | TB_BOLD, ui_bg()); }
            else if k == ENT_RING_BLUE { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, 'B', ui_cyan() | TB_BOLD, ui_bg()); }
            else if k == ENT_RING_PINK { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, 'P', ui_magenta() | TB_BOLD, ui_bg()); }
            else if k >= ENT_GOBLIN && k <= ENT_BOSS { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, '!', ui_red() | TB_BOLD, ui_bg()); }
        }
        i = i + 1;
    }

    // Player marker
    let px_i = clamp_i(ffloor(st.px), 0, 15);
    let pz_i = clamp_i(ffloor(st.pz), 0, 15);
    let _ = tb_set_cell(mx + 1 + px_i, my + 1 + pz_i, '@', ui_white() | TB_BOLD, ui_blue_bg());

    // Scale Stack Summary below minimap
    if my + 21 < view_rows {
        var buf: u8[160] = [0; 160];
        var len: i32 = 0;
        buf_put_str(buf, len, "L");
        buf_put_int(buf, len, st.depth);
        buf_put_str(buf, len, " max:");
        buf_put_int(buf, len, st.max_depth_reached);
        let _ = tb_print(mx + 1, my + 19, ui_white() | TB_BOLD, ui_bg(), buf[0..len]);
    }
}

fn weapon_name(w: i32) -> const u8[:] {
    if w == WEP_PLASMA { return "1:Plasma"; }
    if w == WEP_MINIGUN { return "2:Minigun"; }
    if w == WEP_LASER { return "3:Laser"; }
    if w == WEP_CANNON { return "4:Cannon"; }
    if w == WEP_RAILGUN { return "5:Railgun"; }
    return "6:DarkHole";
}

fn draw_hud() {
    let w = st.term_w;
    let h = st.term_h;
    if h < 4 || w < 20 { return; }

    let hud_y = h - 3;
    // Clear HUD rows
    var y: i32 = hud_y;
    while y < h {
        var x: i32 = 0;
        while x < w {
            let _ = tb_set_cell(x, y, ' ', ui_white(), ui_bg());
            x = x + 1;
        }
        y = y + 1;
    }

    // Row 1: Target / Status Notification / Proximity Ring hint
    if st.near_ring_kind != ENT_NONE {
        let rmsg =
            if st.near_ring_kind == ENT_RING_GREEN { "[E] Green Shrink Ring -> Dive 16x deeper" }
            else if st.near_ring_kind == ENT_RING_RED { "[E] Red Grow Ring -> Ascend 16x outward" }
            else if st.near_ring_kind == ENT_RING_BLUE { "[E] Blue Ring -> Mylantis Sub-Scale" }
            else { "[E] Pink Deep Ring -> Dive 256x deeper!" };
        let _ = tb_print(1, hud_y, ui_green() | TB_BOLD, ui_bg(), rmsg);
    } else if st.msg_ms > 0 && st.msg_len > 0 {
        let _ = tb_print(1, hud_y, ui_yellow() | TB_BOLD, ui_bg(), st.msg_buf[0..st.msg_len]);
    } else if st.target_name_len > 0 {
        var tbuf: u8[160] = [0; 160];
        var tlen: i32 = 0;
        buf_put_str(tbuf, tlen, "Target: ");
        var ti: i32 = 0;
        while ti < st.target_name_len {
            buf_put_ch(tbuf, tlen, st.target_name[ti]);
            ti = ti + 1;
        }
        if st.target_max_hp > 0 {
            buf_put_str(tbuf, tlen, " [");
            buf_put_int(tbuf, tlen, st.target_hp);
            buf_put_ch(tbuf, tlen, '/');
            buf_put_int(tbuf, tlen, st.target_max_hp);
            buf_put_ch(tbuf, tlen, ']');
        }
        let _ = tb_print(1, hud_y, ui_cyan() | TB_BOLD, ui_bg(), tbuf[0..tlen]);
    } else {
        let _ = tb_print(1, hud_y, ui_white(), ui_bg(), "WASD Move | Space/C Fly | Arrows Look | F/Click Shoot | 1-6 Weapons | E Ring | U Shop | Tab Map");
    }

    // Row 2: Core Stats (HP, Armor, Gold, Biome, Depth)
    var sbuf: u8[160] = [0; 160];
    var slen: i32 = 0;
    buf_put_str(sbuf, slen, "HP:");
    buf_put_int(sbuf, slen, st.hp);
    buf_put_ch(sbuf, slen, '/');
    buf_put_int(sbuf, slen, st.max_hp);
    buf_put_str(sbuf, slen, " ARM:");
    buf_put_int(sbuf, slen, st.armor);
    buf_put_str(sbuf, slen, " GOLD:");
    buf_put_int(sbuf, slen, st.gold);
    buf_put_str(sbuf, slen, " LVL:");
    buf_put_int(sbuf, slen, st.depth);
    buf_put_str(sbuf, slen, " [");
    let sidx = st.depth + MACRO_OFFSET;
    buf_put_str(sbuf, slen, biome_name(st.stack[sidx].biome));
    buf_put_ch(sbuf, slen, ']');
    if st.k_rescued != 0 { buf_put_str(sbuf, slen, " K:SAVED"); }
    let hp_col = if st.hp <= 25 { ui_red() | TB_BOLD } else { ui_white() | TB_BOLD };
    let _ = tb_print(1, hud_y + 1, hp_col, ui_bg(), sbuf[0..slen]);

    // Row 3: Active Weapon + Ammo + Controls
    var wbuf: u8[160] = [0; 160];
    var wlen: i32 = 0;
    buf_put_str(wbuf, wlen, "WEP ");
    buf_put_str(wbuf, wlen, weapon_name(st.weapon));
    buf_put_str(wbuf, wlen, " [");
    if st.weapon == WEP_PLASMA {
        buf_put_str(wbuf, wlen, "INF");
    } else {
        buf_put_int(wbuf, wlen, st.ammo[st.weapon]);
    }
    buf_put_str(wbuf, wlen, "] DMG:T");
    buf_put_int(wbuf, wlen, st.dmg_lvl);
    buf_put_str(wbuf, wlen, " | Kills:");
    buf_put_int(wbuf, wlen, st.kills);
    if st.has_wp != 0 { buf_put_str(wbuf, wlen, " | WP:SET"); }
    buf_put_str(wbuf, wlen, if st.truecolor != 0 { " | 24bit" } else { " | 256c" });
    if st.fps > 0 {
        buf_put_str(wbuf, wlen, " FPS:");
        buf_put_int(wbuf, wlen, st.fps);
    }
    let _ = tb_print(1, hud_y + 2, ui_green() | TB_BOLD, ui_bg(), wbuf[0..wlen]);
}

fn draw_title_screen() {
    let _ = tb_clear();
    let w = st.term_w;
    let h = st.term_h;
    var y: i32 = 0;
    while y < h {
        var x: i32 = 0;
        while x < w {
            let _ = tb_set_cell(x, y, ' ', ui_white(), ui_bg());
            x = x + 1;
        }
        y = y + 1;
    }

    let cx = if w > 54 { (w - 54) / 2 } else { 1 };
    let cy = if h > 20 { (h - 20) / 2 } else { 1 };
    draw_rect(cx, cy, if w >= 56 { 54 } else { w - 2 }, 19, ui_cyan() | TB_BOLD, ui_bg());

    let _ = tb_print(cx + 3, cy + 2, ui_yellow() | TB_BOLD, ui_bg(), "FRACTAL BLOCK WORLD — TERMINAL EDITION");
    let _ = tb_print(cx + 3, cy + 3, ui_green(), ui_bg(),           "Recursive 16x16x16 Xar Engine (termbox2.goose)");
    let _ = tb_print(cx + 3, cy + 5, ui_white(), ui_bg(),           "Dive infinitely down through Green/Blue/Pink Rings");
    let _ = tb_print(cx + 3, cy + 6, ui_white(), ui_bg(),           "into Yellow Flowers, Mylantis & the Black Cube to");
    let _ = tb_print(cx + 3, cy + 7, ui_white(), ui_bg(),           "reach the Inner Core (LVL 6+) and rescue K!");
    let _ = tb_print(cx + 3, cy + 8, ui_cyan(), ui_bg(),            "Or fly through the Red Ring above Ying Forest to");
    let _ = tb_print(cx + 3, cy + 9, ui_cyan(), ui_bg(),            "grow 16x larger into the Macro Garden (LVL -1)!");

    let _ = tb_print(cx + 3, cy + 11, ui_white() | TB_BOLD, ui_bg(), "WASD / Space / C : 6-DOF Flight");
    let _ = tb_print(cx + 3, cy + 12, ui_white() | TB_BOLD, ui_bg(), "Arrows / IJKL / Mouse : Look  | F / LMB : Fire");
    let _ = tb_print(cx + 3, cy + 13, ui_white() | TB_BOLD, ui_bg(), "1-6 : Weapons | E : Ring/Shrine | U : Upgrade Shop");
    let _ = tb_print(cx + 3, cy + 14, ui_white() | TB_BOLD, ui_bg(), "V/B : Waypoint | Tab : Map | M : 24bit/256c | Q : Quit");

    let _ = tb_print(cx + 3, cy + 16, ui_green() | TB_BOLD, ui_bg(), ">>> Press [ENTER] or [SPACE] to Enter Xar <<<");
    let _ = tb_present();
}

fn draw_upgrade_modal() {
    let w = st.term_w;
    let h = st.term_h;
    let mw = if w >= 54 { 52 } else { w - 4 };
    let mh: i32 = 15;
    let mx = (w - mw) / 2;
    let my = (h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_yellow() | TB_BOLD, ui_bg());
    let _ = tb_print(mx + 2, my + 1, ui_yellow() | TB_BOLD, ui_bg(), "XAR FIELD UPGRADE & AMMO TERMINAL");

    var gbuf: u8[160] = [0; 160];
    var glen: i32 = 0;
    buf_put_str(gbuf, glen, "Available Gold: ");
    buf_put_int(gbuf, glen, st.gold);
    let _ = tb_print(mx + 2, my + 2, ui_green() | TB_BOLD, ui_bg(), gbuf[0..glen]);

    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_bg(), "[1] Weapon Power +25% (30 Gold)");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_bg(), "[2] Fire Rate +18%    (30 Gold)");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_bg(), "[3] Max HP +25 & Heal (25 Gold)");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_bg(), "[4] Armor +50         (20 Gold)");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_bg(), "[5] Flight Speed +15% (25 Gold)");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_bg(), "[6] Full Ammo Crate   (35 Gold)");
    let _ = tb_print(mx + 2, my + 12, ui_cyan() | TB_BOLD, ui_bg(), "Press [1-6] to buy, or [U]/[ESC] to resume");
}

fn draw_help_modal() {
    let w = st.term_w;
    let h = st.term_h;
    let mw = if w >= 54 { 52 } else { w - 4 };
    let mh: i32 = 14;
    let mx = (w - mw) / 2;
    let my = (h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_cyan() | TB_BOLD, ui_bg());
    let _ = tb_print(mx + 2, my + 1, ui_cyan() | TB_BOLD, ui_bg(), "PAUSED — CONTROLS & FRACTAL GUIDE");
    let _ = tb_print(mx + 2, my + 3, ui_white(), ui_bg(), "WASD: Move/Strafe | Space: Up | C: Down");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_bg(), "Arrows / IJKL / Mouse Drag: Aim Yaw & Pitch");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_bg(), "F / Enter / Left Click: Fire Active Weapon");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_bg(), "1-6 / Scroll Wheel: Switch 6 FBW Weapons");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_bg(), "Green/Blue/Pink Rings: Shrink Deeper (16x/256x)");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_bg(), "Red Ring or Top Sky Shaft: Grow Outward");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_bg(), "V/B: Drop/Warp Waypoint | Tab: Map | M: Color");
    let _ = tb_print(mx + 2, my + 11, ui_green() | TB_BOLD, ui_bg(), "Press [P] or [ESC] to resume, [Q] to quit");
}

fn draw_dead_modal() {
    let w = st.term_w;
    let h = st.term_h;
    let mw = if w >= 46 { 44 } else { w - 4 };
    let mh: i32 = 10;
    let mx = (w - mw) / 2;
    let my = (h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_red() | TB_BOLD, ui_bg());
    let _ = tb_print(mx + 2, my + 2, ui_red() | TB_BOLD, ui_bg(), "HULL SHATTERED IN THE FRACTAL!");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_bg(), "Your scale coordinates were lost.");
    let _ = tb_print(mx + 2, my + 6, ui_green() | TB_BOLD, ui_bg(), "Press [R] or [ENTER] to Respawn, [Q] Quit");
}

fn draw_frame() {
    if st.screen == SCREEN_TITLE {
        draw_title_screen();
        return;
    }
    let _ = tb_clear();
    render_3d_world();
    if st.show_minimap != 0 {
        draw_minimap_overlay();
    }
    draw_hud();
    if st.screen == SCREEN_UPGRADE { draw_upgrade_modal(); }
    else if st.screen == SCREEN_HELP { draw_help_modal(); }
    else if st.screen == SCREEN_DEAD { draw_dead_modal(); }
    let _ = tb_present();
}

// ---------------------------------------------------------------------------
// Input Handling & Resize
// ---------------------------------------------------------------------------
fn sync_viewport() {
    st.term_w = tb_width();
    st.term_h = tb_height();
    st.pw = if st.term_w > MAX_PW { MAX_PW } else if st.term_w < 16 { 16 } else { st.term_w };
    let vrows = if st.term_h > 4 { st.term_h - 3 } else { 1 };
    var ph = vrows * 2;
    if ph > MAX_PH { ph = MAX_PH; }
    if ph < 2 { ph = 2; }
    st.ph = ph;
}

fn handle_upgrade_key(ch: u32) {
    if ch == '1' && st.gold >= 30 {
        st.gold = st.gold - 30;
        st.dmg_lvl = st.dmg_lvl + 1;
        set_status_msg("Weapon Power upgraded!", 1400);
    } else if ch == '2' && st.gold >= 30 {
        st.gold = st.gold - 30;
        st.rof_lvl = st.rof_lvl + 1;
        set_status_msg("Fire Rate upgraded!", 1400);
    } else if ch == '3' && st.gold >= 25 {
        st.gold = st.gold - 25;
        st.max_hp = st.max_hp + 25;
        st.hp = st.max_hp;
        set_status_msg("Max HP increased & restored!", 1400);
    } else if ch == '4' && st.gold >= 20 {
        st.gold = st.gold - 20;
        st.armor = clamp_i(st.armor + 50, 0, st.max_armor);
        set_status_msg("Armor reinforced!", 1400);
    } else if ch == '5' && st.gold >= 25 {
        st.gold = st.gold - 25;
        st.spd_lvl = st.spd_lvl + 1;
        set_status_msg("Flux Thrusters upgraded!", 1400);
    } else if ch == '6' && st.gold >= 35 {
        st.gold = st.gold - 35;
        st.ammo[WEP_MINIGUN] = st.ammo[WEP_MINIGUN] + 100;
        st.ammo[WEP_LASER] = st.ammo[WEP_LASER] + 30;
        st.ammo[WEP_CANNON] = st.ammo[WEP_CANNON] + 15;
        st.ammo[WEP_RAILGUN] = st.ammo[WEP_RAILGUN] + 10;
        st.ammo[WEP_DARKHOLE] = st.ammo[WEP_DARKHOLE] + 2;
        set_status_msg("Full Ammo Crate acquired!", 1400);
    }
}

fn handle_key(ev: tb_event&) -> i32 {
    let ch = ev.ch;
    let key = ev.key;

    if st.screen == SCREEN_TITLE {
        if key == TB_KEY_ESC || ch == 'q' || ch == 'Q' { return 0; }
        if key == TB_KEY_ENTER || key == TB_KEY_SPACE || ch == ' ' {
            st.screen = SCREEN_PLAY;
        }
        return 1;
    }

    if st.screen == SCREEN_DEAD {
        if key == TB_KEY_ESC || ch == 'q' || ch == 'Q' { return 0; }
        if ch == 'r' || ch == 'R' || key == TB_KEY_ENTER {
            init_new_game();
            st.screen = SCREEN_PLAY;
        }
        return 1;
    }

    if st.screen == SCREEN_UPGRADE {
        if key == TB_KEY_ESC || ch == 'u' || ch == 'U' {
            st.screen = SCREEN_PLAY;
            return 1;
        }
        if ch == 'q' || ch == 'Q' { return 0; }
        handle_upgrade_key(ch);
        return 1;
    }

    if st.screen == SCREEN_HELP {
        if key == TB_KEY_ESC || ch == 'p' || ch == 'P' {
            st.screen = SCREEN_PLAY;
            return 1;
        }
        if ch == 'q' || ch == 'Q' { return 0; }
        return 1;
    }

    // Playing state
    if key == TB_KEY_ESC || ch == 'q' || ch == 'Q' { return 0; }
    if ch == 'u' || ch == 'U' { st.screen = SCREEN_UPGRADE; return 1; }
    if ch == 'p' || ch == 'P' { st.screen = SCREEN_HELP; return 1; }
    if key == TB_KEY_TAB { st.show_minimap = if st.show_minimap != 0 { 0 } else { 1 }; return 1; }
    if ch == 'm' || ch == 'M' {
        st.truecolor = if st.truecolor != 0 { 0 } else { 1 };
        let _ = tb_set_output_mode(if st.truecolor != 0 { TB_OUTPUT_TRUECOLOR } else { TB_OUTPUT_256 });
        let _ = tb_invalidate();
        return 1;
    }

    // Weapon slots 1-6
    if ch >= '1' && ch <= '6' {
        st.weapon = (ch - '1') as! i32;
        return 1;
    }

    // Waypoint drop / warp
    if ch == 'v' || ch == 'V' {
        st.has_wp = 1;
        st.wp_depth = st.depth;
        st.wp_px = st.px;
        st.wp_py = st.py;
        st.wp_pz = st.pz;
        var wi: i32 = 0;
        while wi < MAX_STACK {
            st.wp_stack[wi] = st.stack[wi];
            wi = wi + 1;
        }
        let bx = ffloor(st.px);
        let by = ffloor(st.py) - 1;
        let bz = ffloor(st.pz);
        if by >= 1 && get_block(bx, by, bz) == BLK_AIR {
            set_block(bx, by, bz, BLK_WAYPOINT);
            record_block_delta(bx, by, bz, BLK_WAYPOINT);
        }
        set_status_msg("Waypoint dropped! Press [B] anytime to warp back.", 1800);
        return 1;
    }
    if ch == 'b' || ch == 'B' {
        if st.has_wp == 0 {
            set_status_msg("No waypoint set yet — press [V] to drop one!", 1400);
            return 1;
        }
        var wi: i32 = 0;
        while wi < MAX_STACK {
            st.stack[wi] = st.wp_stack[wi];
            wi = wi + 1;
        }
        st.depth = st.wp_depth;
        load_current_chunk();
        st.px = st.wp_px;
        st.py = st.wp_py;
        st.pz = st.wp_pz;
        st.flash_ms = 240;
        st.flash_rgb = pack_rgb(74, 222, 128);
        set_status_msg("Warped to saved Waypoint!", 1600);
        return 1;
    }

    if ch == 'e' || ch == 'E' {
        interact_nearest();
        return 1;
    }

    if ch == 'f' || ch == 'F' || key == TB_KEY_ENTER {
        fire_active_weapon();
        return 1;
    }

    // Movement & Camera Look
    let spd = 0.42 * (1.0 + 0.15 * ((st.spd_lvl - 1) as f64));
    let fy_x = fcos(st.yaw);
    let fy_z = fsin(st.yaw);
    let rx = -fy_z;
    let rz = fy_x;

    if ch == 'w' || ch == 'W' { move_player(fy_x * spd, 0.0, fy_z * spd); }
    else if ch == 's' || ch == 'S' { move_player(-fy_x * spd, 0.0, -fy_z * spd); }
    else if ch == 'd' || ch == 'D' { move_player(rx * spd, 0.0, rz * spd); }
    else if ch == 'a' || ch == 'A' { move_player(-rx * spd, 0.0, -rz * spd); }
    else if key == TB_KEY_SPACE || ch == ' ' { move_player(0.0, spd * 0.85, 0.0); }
    else if ch == 'c' || ch == 'C' || ch == 'z' || ch == 'Z' { move_player(0.0, -spd * 0.85, 0.0); }
    else if key == TB_KEY_ARROW_LEFT || ch == 'j' || ch == 'J' { st.yaw = wrap_angle(st.yaw - 0.11); }
    else if key == TB_KEY_ARROW_RIGHT || ch == 'l' || ch == 'L' { st.yaw = wrap_angle(st.yaw + 0.11); }
    else if key == TB_KEY_ARROW_UP || ch == 'i' || ch == 'I' { st.pitch = fclamp(st.pitch + 0.08, -1.15, 1.15); }
    else if key == TB_KEY_ARROW_DOWN || ch == 'k' || ch == 'K' { st.pitch = fclamp(st.pitch - 0.08, -1.15, 1.15); }

    return 1;
}

fn handle_mouse(ev: tb_event&) {
    if st.screen != SCREEN_PLAY { return; }
    if ev.key == TB_KEY_MOUSE_LEFT {
        if (ev.mod & TB_MOD_MOTION) != 0 {
            if st.mouse_dragging != 0 {
                let dx = ev.x - st.mouse_last_x;
                let dy = ev.y - st.mouse_last_y;
                st.yaw = wrap_angle(st.yaw + dx * 0.025);
                st.pitch = fclamp(st.pitch - dy * 0.035, -1.15, 1.15);
            }
            st.mouse_dragging = 1;
            st.mouse_last_x = ev.x;
            st.mouse_last_y = ev.y;
        } else {
            fire_active_weapon();
            st.mouse_dragging = 1;
            st.mouse_last_x = ev.x;
            st.mouse_last_y = ev.y;
        }
    } else if ev.key == TB_KEY_MOUSE_RIGHT {
        interact_nearest();
    } else if ev.key == TB_KEY_MOUSE_RELEASE {
        st.mouse_dragging = 0;
    } else if ev.key == TB_KEY_MOUSE_WHEEL_UP {
        st.weapon = (st.weapon + 5) % 6;
    } else if ev.key == TB_KEY_MOUSE_WHEEL_DOWN {
        st.weapon = (st.weapon + 1) % 6;
    }
}

// ---------------------------------------------------------------------------
// Main Entrypoint
// ---------------------------------------------------------------------------
fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("fbw: tb_init failed: ", rv, "\n");
        return;
    }

    st.truecolor = 1;
    let _ = tb_set_output_mode(TB_OUTPUT_TRUECOLOR);
    let _ = tb_set_input_mode(TB_INPUT_ESC | TB_INPUT_MOUSE);
    let _ = tb_hide_cursor();

    st.rng = 0x4642575f32303236 ^ (tb_adapter_now_ms() as u64);
    st.screen = SCREEN_TITLE;
    st.show_minimap = 1;

    sync_viewport();
    init_new_game();

    // Flush any queued startup bytes
    let g = gbl();
    g.inbuf_len = 0;
    g.inbuf_pos = 0;

    draw_frame();

    const TARGET_FRAME_MS: i32 = 33; // ~30 FPS responsive raycast budget
    var last_tick: i64 = tb_adapter_now_ms();
    st.fps_last_ms = last_tick;
    var running: i32 = 1;

    while running != 0 {
        let frame_start = tb_adapter_now_ms();

        loop {
            let now = tb_adapter_now_ms();
            let elapsed = (now - frame_start) as! i32;
            let rem = TARGET_FRAME_MS - elapsed;
            let timeout = if rem > 0 { rem } else { 0 };
            var ev = tb_event { .. };
            let erv = tb_peek_event(ev, timeout);
            if erv != TB_OK {
                if erv == TB_ERR_NO_EVENT { break; }
                running = 0;
                break;
            }
            if ev.kind == TB_EVENT_KEY {
                if handle_key(ev) == 0 {
                    running = 0;
                    break;
                }
            } else if ev.kind == TB_EVENT_MOUSE {
                handle_mouse(ev);
            } else if ev.kind == TB_EVENT_RESIZE {
                sync_viewport();
                let _ = tb_invalidate();
            }
        }

        if running == 0 { break; }

        let now = tb_adapter_now_ms();
        var dt_ms = (now - last_tick) as! i32;
        if dt_ms < 1 { dt_ms = 1; }
        if dt_ms > 120 { dt_ms = 120; }
        last_tick = now;
        st.anim_ms = st.anim_ms + dt_ms;

        step_simulation(dt_ms);
        draw_frame();

        st.frame_cnt = st.frame_cnt + 1;
        if now - st.fps_last_ms >= 500 {
            let fdt = now - st.fps_last_ms;
            if fdt > 0 {
                st.fps = ((st.frame_cnt * 1000) / (fdt as! i32));
            }
            st.frame_cnt = 0;
            st.fps_last_ms = now;
        }
    }

    let _ = tb_shutdown();
}
