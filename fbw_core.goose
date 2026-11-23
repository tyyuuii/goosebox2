// fbw_core.goose — Pure Simulation & Fractal World Engine for Fractal Block World (Xar)
// Zero terminal/rendering dependency so core mechanics can be unit-tested directly.

const PI: f64 = 3.14159265358979323846;
const TAU: f64 = 6.28318530717958647692;
const HALF_PI: f64 = 1.57079632679489661923;

const CHUNK_DIM: i32 = 16;
const CHUNK_VOL: i32 = 4096;

const MACRO_OFFSET: i32 = 8;
const MAX_STACK: i32 = 64;

const MAX_ENTITIES: i32 = 96;
const MAX_SHOTS: i32 = 72;
const MAX_PARTICLES: i32 = 72;
const MAX_DELTAS: i32 = 512;
const MAX_MARKERS: i32 = 16;

const MAX_GOLD: i32 = 1000000;
const DEATH_GOLD_PENALTY: i32 = 30;

// Screen / Modal states
const SCREEN_TITLE: i32 = 0;
const SCREEN_PLAY: i32 = 1;
const SCREEN_BUY: i32 = 2;
const SCREEN_SELL: i32 = 3;
const SCREEN_BLACK_MARKET: i32 = 4;
const SCREEN_PAUSE: i32 = 5;
const SCREEN_INFO_F1: i32 = 6;
const SCREEN_INFO_F2: i32 = 7;
const SCREEN_INFO_F3: i32 = 8;
const SCREEN_INFO_F4: i32 = 9;
const SCREEN_INFO_F5: i32 = 10;
const SCREEN_TOME: i32 = 11;
const SCREEN_VICTORY: i32 = 12;

// Biomes (Authentic Xar Progression)
const BIOME_SPACE: i32 = 0;         // Outer Space Level 0 (depth < 0)
const BIOME_TUTORIAL: i32 = 1;      // Tutorial Room & Tutorial Island (depth == 0)
const BIOME_YING_FOREST: i32 = 2;   // Ying Forest (Ying Trees, Totems, Flowers)
const BIOME_WHITE_FLOWER: i32 = 3;  // Small White Flower / Alpha Cube
const BIOME_YELLOW_FLOWER: i32 = 4; // Small & Jumbo Yellow Flower Labyrinths
const BIOME_MYLANTIS: i32 = 5;      // Mylantis Crust & Caves
const BIOME_BLACK_CUBE: i32 = 6;    // Black Cube / I1 / I2 / I3 Menger Lattice
const BIOME_INNER_CORE: i32 = 7;    // The Core / Singularity & K

// Block IDs
const BLK_AIR: u8 = 0;
const BLK_WALL_TUT: u8 = 1;
const BLK_GRASS: u8 = 2;
const BLK_DIRT: u8 = 3;
const BLK_WOOD: u8 = 4;
const BLK_LEAVES: u8 = 5;
const BLK_PETAL_Y: u8 = 6;
const BLK_POLLEN: u8 = 7;
const BLK_PETAL_W: u8 = 8;
const BLK_MYLANTIS: u8 = 9;
const BLK_ICE: u8 = 10;
const BLK_SAND: u8 = 11;
const BLK_GLASS: u8 = 12;
const BLK_STONE: u8 = 13;
const BLK_GOLD_ORE: u8 = 14;
const BLK_CRATE: u8 = 15;
const BLK_SPAWNER: u8 = 16;
const BLK_LOCKED_DOOR: u8 = 17;

// Shrinkable Fractal Portal Blocks (fly into or press F to shrink 16x deeper!)
const BLK_BLACK_CUBE: u8 = 20;
const BLK_WHITE_FLOWER: u8 = 21;
const BLK_ALPHA_CUBE: u8 = 22;
const BLK_FLOWER_Y_CORE: u8 = 23;
const BLK_MYLANTIS_M: u8 = 24;
const BLK_YING_PLANET: u8 = 25;
const BLK_ICE_WORLD: u8 = 26;
const BLK_DESERT_WORLD: u8 = 27;
const BLK_CORE_GATE: u8 = 28;

// Interactive Station & Upgrade Blocks
const BLK_BUY_STATION: u8 = 32;
const BLK_SELL_STATION: u8 = 33;
const BLK_BLACK_MARKET: u8 = 34;
const BLK_TOME: u8 = 35;
const BLK_UPG_HP: u8 = 36;
const BLK_UPG_REGEN: u8 = 37;
const BLK_UPG_ARMOR: u8 = 38;
const BLK_UPG_DMG: u8 = 39;
const BLK_UPG_ROF: u8 = 40;
const BLK_UPG_AMMO: u8 = 41;
const BLK_UPG_SPEED: u8 = 42;
const BLK_KEY_BLOCK: u8 = 43;

// Entity kinds
const ENT_NONE: i32 = 0;
const ENT_RING_GREEN: i32 = 1;  // Shrink 16x (1 level)
const ENT_RING_RED: i32 = 2;    // Grow 16x outward
const ENT_RING_BLUE: i32 = 3;   // Mylantis / Biome Teleporter
const ENT_RING_PINK: i32 = 4;   // Deep Dive 256x (2 levels)

// Xar Monster Manual Enemies
const ENT_RAT: i32 = 5;
const ENT_SPIDER: i32 = 6;
const ENT_GOON: i32 = 7;
const ENT_MARINE: i32 = 8;
const ENT_PIRATE: i32 = 9;
const ENT_YINYANG: i32 = 10;
const ENT_MENACE: i32 = 11;
const ENT_DEMON: i32 = 12;
const ENT_GUARDIAN: i32 = 13;   // Pool Ball / Guardian (freezable by Laser 2nd / EMP!)
const ENT_SINGULARITY: i32 = 14; // Core Boss

// Pickups & NPC
const ENT_GOLD: i32 = 15;
const ENT_HEALTH: i32 = 16;
const ENT_ARMOR: i32 = 17;
const ENT_AMMO: i32 = 18;
const ENT_KEY: i32 = 19;
const ENT_FRIEND_K: i32 = 20;

// 10 Authentic Weapons (Keys 1..9, 0)
const WEP_PLASMA: i32 = 0;   // 1
const WEP_CANNON: i32 = 1;   // 2
const WEP_LASER: i32 = 2;    // 3
const WEP_ROCKET: i32 = 3;   // 4
const WEP_HOMING: i32 = 4;   // 5
const WEP_MINIGUN: i32 = 5;  // 6
const WEP_RAILGUN: i32 = 6;  // 7
const WEP_EMP: i32 = 7;      // 8
const WEP_NUKE: i32 = 8;     // 9
const WEP_DARKHOLE: i32 = 9; // 0
const NUM_WEAPONS: i32 = 10;

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
    freeze_ms: i32,
    target_biome: i32,
    target_block: u8,
    active: i32,
}

struct Shot {
    active: i32,
    from_player: i32,
    wep: i32,
    secondary: i32,
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

struct Marker {
    used: i32,
    is_long: i32,
    depth: i32,
    px: f64,
    py: f64,
    pz: f64,
    biome: i32,
    stack: ScaleFrame[MAX_STACK],
}

root struct fbw_state {
    // Viewport & rendering flags (used by frontend)
    term_w: i32,
    term_h: i32,
    pw: i32,
    ph: i32,
    screen: i32,
    truecolor: i32,
    show_minimap: i32,
    render_scale: i32,
    is_termux: i32,
    modal_bg_ready: i32,

    // Recursive 16x16x16 world stack
    blocks: u8[CHUNK_VOL],
    stack: ScaleFrame[MAX_STACK],
    depth: i32, // 0 = Tutorial Island, <0 = Outer Space, >0 = Deep Fractals
    max_depth_reached: i32,
    min_depth_reached: i32,

    // Player 6-DOF kinematics
    px: f64,
    py: f64,
    pz: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    yaw: f64,
    pitch: f64,
    roll: f64,
    true_up: i32,     // 1 = True Up locks horizon level; 0 = Q/E roll freely
    rocket_mode: i32, // 1 = Low-drag Rocket Mode (Tab)

    // Player stats & economy
    hp: i32,
    max_hp: i32,
    hp_regen: i32,    // HP restored per 2 seconds
    regen_accum_ms: i32,
    armor: i32,
    max_armor: i32,
    gold: i32,
    keys: i32,
    kills: i32,
    deaths: i32,
    quasar_drive: i32, // Unlocked by defeating The Singularity
    k_rescued: i32,
    telekinesis_ms: i32,

    // 10 Weapons & Upgrade levels
    weapon: i32,
    ammo: i32[NUM_WEAPONS],
    max_ammo: i32[NUM_WEAPONS],
    dmg_lvl: i32,
    rof_lvl: i32,
    spd_lvl: i32,
    ammo_cap_lvl: i32,
    fire_cd_ms: i32,
    ring_cd_ms: i32,

    // Hitscan beam visual
    beam_timer_ms: i32,
    beam_rgb: u32,
    beam_x1: f64,
    beam_y1: f64,
    beam_z1: f64,
    beam_x2: f64,
    beam_y2: f64,
    beam_z2: f64,

    // Markers (Short & Long)
    markers: Marker[MAX_MARKERS],
    active_marker: i32,

    // Mouse drag tracking
    mouse_last_x: i32,
    mouse_last_y: i32,
    mouse_dragging: i32,

    // Feedback / Flash / Lore Tome
    flash_ms: i32,
    flash_rgb: u32,
    msg_ms: i32,
    msg_len: i32,
    msg_buf: u8[128],
    tome_id: i32,

    // Crosshair target readout
    target_name_len: i32,
    target_name: u8[40],
    target_hp: i32,
    target_max_hp: i32,
    near_ring_kind: i32,
    near_prompt_len: i32,
    near_prompt: u8[64],

    // Simulation arrays
    entities: Entity[MAX_ENTITIES],
    shots: Shot[MAX_SHOTS],
    particles: Particle[MAX_PARTICLES],
    deltas: BlockDelta[MAX_DELTAS],
    delta_head: i32,

    // Framebuffer
    fb_rgb: u32[33600],
    fb_z: f64[33600],

    // PRNG & Timing
    rng: u64,
    tick_ms: i64,
    fps: i32,
    frame_cnt: i32,
    fps_last_ms: i64,
    anim_ms: i64,
}

var st: fbw_state;

fn core() -> fbw_state& {
    return st;
}

// ---------------------------------------------------------------------------
// Pure Goose Math Helpers
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

fn clamp_i(v: i32, lo: i32, hi: i32) -> i32 {
    if v < lo { return lo; }
    if v > hi { return hi; }
    return v;
}

fn fsqrt(x: f64) -> f64 {
    if x <= 0.0 { return 0.0; }
    var v: f64 = x;
    var scale: f64 = 1.0;
    var k: i32 = 0;
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
    var g: f64 = (0.5 + 0.5 * v) * scale;
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

// ---------------------------------------------------------------------------
// Hashing, PRNG & Color Helpers
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

// ---------------------------------------------------------------------------
// Messages & Names
// ---------------------------------------------------------------------------
fn set_status_msg(msg: const u8[:], ms: i32) {
    var n: i32 = msg.len as! i32;
    if n > 127 { n = 127; }
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
    if n > 39 { n = 39; }
    var i: i32 = 0;
    while i < n {
        st.target_name[i] = name[i];
        i = i + 1;
    }
    st.target_name_len = n;
    st.target_hp = hp;
    st.target_max_hp = max_hp;
}

fn set_near_prompt(msg: const u8[:]) {
    var n: i32 = msg.len as! i32;
    if n > 63 { n = 63; }
    var i: i32 = 0;
    while i < n {
        st.near_prompt[i] = msg[i];
        i = i + 1;
    }
    st.near_prompt_len = n;
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

fn is_block_shrinkable(b: u8) -> i32 {
    if b == BLK_BLACK_CUBE || b == BLK_WHITE_FLOWER || b == BLK_ALPHA_CUBE ||
       b == BLK_FLOWER_Y_CORE || b == BLK_MYLANTIS_M || b == BLK_YING_PLANET ||
       b == BLK_ICE_WORLD || b == BLK_DESERT_WORLD || b == BLK_CORE_GATE {
        return 1;
    }
    return 0;
}

fn is_block_upgrade(b: u8) -> i32 {
    if b >= BLK_UPG_HP && b <= BLK_KEY_BLOCK { return 1; }
    return 0;
}

fn is_block_destructible(b: u8) -> i32 {
    if b == BLK_CRATE || b == BLK_SPAWNER || b == BLK_GOLD_ORE { return 1; }
    return 0;
}

fn biome_name(biome: i32) -> const u8[:] {
    if biome == BIOME_SPACE { return "Outer Space"; }
    if biome == BIOME_TUTORIAL { return "Tutorial Island"; }
    if biome == BIOME_YING_FOREST { return "Ying Forest"; }
    if biome == BIOME_WHITE_FLOWER { return "Alpha Cube"; }
    if biome == BIOME_YELLOW_FLOWER { return "Yellow Flower"; }
    if biome == BIOME_MYLANTIS { return "Mylantis Caves"; }
    if biome == BIOME_BLACK_CUBE { return "I2 Menger Lattice"; }
    return "Inner Core";
}

fn weapon_name(w: i32) -> const u8[:] {
    if w == WEP_PLASMA { return "1:Plasma"; }
    if w == WEP_CANNON { return "2:Cannon"; }
    if w == WEP_LASER { return "3:Laser"; }
    if w == WEP_ROCKET { return "4:Rocket"; }
    if w == WEP_HOMING { return "5:Homing"; }
    if w == WEP_MINIGUN { return "6:Minigun"; }
    if w == WEP_RAILGUN { return "7:Railgun"; }
    if w == WEP_EMP { return "8:EMP"; }
    if w == WEP_NUKE { return "9:Nuke"; }
    if st.quasar_drive != 0 { return "0:Quasar"; }
    return "0:DarkHole";
}

fn block_label(b: u8) -> const u8[:] {
    if b == BLK_BLACK_CUBE { return "Black Cube (Shrink 16x)"; }
    if b == BLK_WHITE_FLOWER { return "Small White Flower (Shrink)"; }
    if b == BLK_ALPHA_CUBE { return "Alpha Cube (Shrink 16x)"; }
    if b == BLK_FLOWER_Y_CORE { return "Yellow Flower Core (Shrink)"; }
    if b == BLK_MYLANTIS_M { return "Mylantis 'M' Block (Shrink)"; }
    if b == BLK_YING_PLANET { return "Ying World Planet (Shrink)"; }
    if b == BLK_ICE_WORLD { return "Ice World Block (Shrink)"; }
    if b == BLK_DESERT_WORLD { return "Desert Pyramid (Shrink)"; }
    if b == BLK_CORE_GATE { return "Core Gate (Shrink to Singularity)"; }
    if b == BLK_BUY_STATION { return "Buy Station [F]"; }
    if b == BLK_SELL_STATION { return "Sell Station [F]"; }
    if b == BLK_BLACK_MARKET { return "Black Market [F]"; }
    if b == BLK_TOME { return "Xar Manual Tome [F]"; }
    if b == BLK_LOCKED_DOOR { return "Locked Vault Door [F: Key]"; }
    return "";
}

fn block_base_rgb(b: u8) -> u32 {
    if b == BLK_WALL_TUT { return pack_rgb(168, 176, 198); }
    if b == BLK_GRASS { return pack_rgb(44, 172, 82); }
    if b == BLK_DIRT { return pack_rgb(112, 78, 52); }
    if b == BLK_WOOD { return pack_rgb(128, 78, 42); }
    if b == BLK_LEAVES { return pack_rgb(26, 134, 68); }
    if b == BLK_PETAL_Y { return pack_rgb(245, 198, 38); }
    if b == BLK_POLLEN { return pack_rgb(255, 244, 128); }
    if b == BLK_PETAL_W { return pack_rgb(236, 242, 250); }
    if b == BLK_MYLANTIS { return pack_rgb(24, 172, 168); }
    if b == BLK_ICE { return pack_rgb(122, 212, 250); }
    if b == BLK_SAND { return pack_rgb(218, 182, 108); }
    if b == BLK_GLASS { return pack_rgb(148, 224, 248); }
    if b == BLK_STONE { return pack_rgb(86, 94, 114); }
    if b == BLK_GOLD_ORE { return pack_rgb(245, 196, 42); }
    if b == BLK_CRATE { return pack_rgb(202, 138, 46); }
    if b == BLK_SPAWNER { return pack_rgb(196, 40, 68); }
    if b == BLK_LOCKED_DOOR { return pack_rgb(210, 165, 38); }
    if b == BLK_BLACK_CUBE { return pack_rgb(18, 18, 28); }
    if b == BLK_WHITE_FLOWER { return pack_rgb(248, 250, 255); }
    if b == BLK_ALPHA_CUBE { return pack_rgb(236, 72, 153); }
    if b == BLK_FLOWER_Y_CORE { return pack_rgb(255, 214, 48); }
    if b == BLK_MYLANTIS_M { return pack_rgb(249, 115, 22); }
    if b == BLK_YING_PLANET { return pack_rgb(52, 211, 102); }
    if b == BLK_ICE_WORLD { return pack_rgb(96, 218, 255); }
    if b == BLK_DESERT_WORLD { return pack_rgb(234, 179, 82); }
    if b == BLK_CORE_GATE { return pack_rgb(244, 63, 184); }
    if b == BLK_BUY_STATION { return pack_rgb(34, 197, 94); }
    if b == BLK_SELL_STATION { return pack_rgb(56, 189, 248); }
    if b == BLK_BLACK_MARKET { return pack_rgb(147, 51, 234); }
    if b == BLK_TOME { return pack_rgb(250, 204, 21); }
    if b == BLK_UPG_HP { return pack_rgb(244, 63, 94); }
    if b == BLK_UPG_REGEN { return pack_rgb(251, 113, 133); }
    if b == BLK_UPG_ARMOR { return pack_rgb(59, 130, 246); }
    if b == BLK_UPG_DMG { return pack_rgb(249, 115, 22); }
    if b == BLK_UPG_ROF { return pack_rgb(234, 179, 8); }
    if b == BLK_UPG_AMMO { return pack_rgb(168, 85, 247); }
    if b == BLK_UPG_SPEED { return pack_rgb(34, 211, 238); }
    if b == BLK_KEY_BLOCK { return pack_rgb(253, 224, 71); }
    return pack_rgb(128, 128, 128);
}

// ---------------------------------------------------------------------------
// Entities, Shots & Particles
// ---------------------------------------------------------------------------
fn clear_entities_and_shots() {
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        st.entities[i].active = 0;
        st.entities[i].kind = ENT_NONE;
        st.entities[i].freeze_ms = 0;
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

fn spawn_entity(kind: i32, x: f64, y: f64, z: f64, hp: i32, target_biome: i32, target_blk: u8) -> i32 {
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
            st.entities[i].freeze_ms = 0;
            st.entities[i].target_biome = target_biome;
            st.entities[i].target_block = target_blk;
            return i;
        }
        i = i + 1;
    }
    return -1;
}

fn spawn_shot(from_player: i32, wep: i32, secondary: i32, x: f64, y: f64, z: f64, vx: f64, vy: f64, vz: f64, dmg: i32, ttl_ms: i32, rgb: u32) {
    var i: i32 = 0;
    while i < MAX_SHOTS {
        if st.shots[i].active == 0 {
            st.shots[i].active = 1;
            st.shots[i].from_player = from_player;
            st.shots[i].wep = wep;
            st.shots[i].secondary = secondary;
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
            st.particles[i].vx = (rng_f01() - 0.5) * 8.0;
            st.particles[i].vy = (rng_f01() - 0.3) * 8.0;
            st.particles[i].vz = (rng_f01() - 0.5) * 8.0;
            st.particles[i].ttl_ms = rng_range(180, 520);
            st.particles[i].rgb = rgb;
            spawned = spawned + 1;
        }
        i = i + 1;
    }
}

fn add_gold(amount: i32) {
    st.gold = clamp_i(st.gold + amount, 0, MAX_GOLD);
}

// ---------------------------------------------------------------------------
// Authentic Xar Procedural World Generators (16x16x16 Chunks)
// ---------------------------------------------------------------------------
fn pick_biome_for_entry(depth: i32, parent_blk: u8, forced_biome: i32, seed: u64) -> i32 {
    if forced_biome >= 0 { return forced_biome; }
    if depth < 0 { return BIOME_SPACE; }
    if depth == 0 { return BIOME_TUTORIAL; }
    if parent_blk == BLK_WHITE_FLOWER { return BIOME_WHITE_FLOWER; }
    if parent_blk == BLK_ALPHA_CUBE { return BIOME_YELLOW_FLOWER; }
    if parent_blk == BLK_FLOWER_Y_CORE { return BIOME_YELLOW_FLOWER; }
    if parent_blk == BLK_YING_PLANET { return BIOME_YING_FOREST; }
    if parent_blk == BLK_MYLANTIS_M { return BIOME_MYLANTIS; }
    if parent_blk == BLK_ICE_WORLD { return BIOME_MYLANTIS; }
    if parent_blk == BLK_DESERT_WORLD { return BIOME_YELLOW_FLOWER; }
    if parent_blk == BLK_CORE_GATE || depth >= 6 { return BIOME_INNER_CORE; }
    if parent_blk == BLK_BLACK_CUBE {
        // Famous FBW rule: Black Cube in Tutorial -> Ying Forest! Deeper Black Cubes -> I1/I2/I3 Menger Lattice!
        if depth == 1 { return BIOME_YING_FOREST; }
        return BIOME_BLACK_CUBE;
    }
    let r = (splitmix64(seed) % 4) as! i32;
    if depth == 1 { return BIOME_YING_FOREST; }
    if depth == 2 { return BIOME_YELLOW_FLOWER; }
    if depth == 3 { return BIOME_MYLANTIS; }
    if depth == 4 || depth == 5 || r == 3 { return BIOME_BLACK_CUBE; }
    return BIOME_INNER_CORE;
}

fn build_ying_tree(tx: i32, tz: i32, base_y: i32, h: i32, has_fruit: i32) {
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
                if (dy == 2 && man > 1) || (man == 2 && (dy == -1 || dy == 1)) {
                    dx = dx + 1;
                    continue;
                }
                if has_fruit != 0 && dx == 0 && dz == 0 && dy == 0 {
                    set_block(tx, cy, tz, BLK_FLOWER_Y_CORE);
                } else {
                    set_block(tx + dx, cy + dy, tz + dz, BLK_LEAVES);
                }
                dx = dx + 1;
            }
            dz = dz + 1;
        }
        dy = dy + 1;
    }
}

fn generate_space_chunk() {
    // Outer Space Level 0: Floating macro worlds (Ying World, Mylantis M, Ice World, Desert, Black Cube)
    // Ying World Planet (center-south)
    var dz: i32 = -1;
    while dz <= 1 {
        var dy: i32 = -1;
        while dy <= 1 {
            var dx: i32 = -1;
            while dx <= 1 {
                set_block(8 + dx, 6 + dy, 8 + dz, BLK_YING_PLANET);
                dx = dx + 1;
            }
            dy = dy + 1;
        }
        dz = dz + 1;
    }
    // Iconic Orange Mylantis 'M' Block!
    set_block(13, 8, 12, BLK_MYLANTIS_M);
    set_block(13, 9, 12, BLK_MYLANTIS_M);
    set_block(14, 8, 12, BLK_MYLANTIS_M);
    set_block(14, 9, 12, BLK_MYLANTIS_M);
    let _ = spawn_entity(ENT_RING_BLUE, 13.5, 10.2, 12.5, 1, BIOME_MYLANTIS, BLK_MYLANTIS_M);

    // Ice World & Desert World Planets
    set_block(3, 9, 12, BLK_ICE_WORLD);
    set_block(3, 9, 13, BLK_ICE_WORLD);
    set_block(3, 4, 4, BLK_DESERT_WORLD);
    set_block(4, 4, 4, BLK_DESERT_WORLD);

    // Giant Cosmic Black Cube
    set_block(12, 4, 4, BLK_BLACK_CUBE);
    set_block(12, 5, 4, BLK_BLACK_CUBE);

    let _ = spawn_entity(ENT_RING_GREEN, 8.5, 8.2, 8.5, 1, BIOME_TUTORIAL, BLK_YING_PLANET);
    let _ = spawn_entity(ENT_MENACE, 5.5, 8.0, 6.5, 65, -1, 0);
    let _ = spawn_entity(ENT_PIRATE, 11.5, 7.5, 8.0, 55, -1, 0);
    let _ = spawn_entity(ENT_GOLD, 8.5, 8.5, 11.5, 1, -1, 0);
}

fn generate_tutorial_island() {
    // Tutorial Island floor (y=1 grass, y=0 dirt)
    var z: i32 = 2;
    while z <= 13 {
        var x: i32 = 2;
        while x <= 13 {
            set_block(x, 0, z, BLK_DIRT);
            set_block(x, 1, z, BLK_GRASS);
            x = x + 1;
        }
        z = z + 1;
    }

    // Tutorial Room enclosure around (x=5..11, y=2..6, z=3..11) with open front-top skylight & east exit
    var ry: i32 = 2;
    while ry <= 6 {
        var rz: i32 = 3;
        while rz <= 11 {
            var rx: i32 = 5;
            while rx <= 11 {
                let wall = if rx == 5 || rx == 11 || rz == 3 || rz == 11 || ry == 6 { 1 } else { 0 };
                if wall != 0 {
                    // Leave east doorway (rx==11, rz=6..8, ry=2..4) and central ceiling skylight (rx=7..9, rz=6..8)
                    let is_door = if rx == 11 && rz >= 6 && rz <= 8 && ry >= 2 && ry <= 4 { 1 } else { 0 };
                    let is_sky = if ry == 6 && rx >= 7 && rx <= 9 && rz >= 6 && rz <= 8 { 1 } else { 0 };
                    if is_door == 0 && is_sky == 0 {
                        set_block(rx, ry, rz, BLK_WALL_TUT);
                    }
                }
                rx = rx + 1;
            }
            rz = rz + 1;
        }
        ry = ry + 1;
    }

    // Iconic Tutorial Black Cube straight ahead at (8, 2..3, 9) — shrinking into it leads directly to Ying Forest!
    set_block(8, 2, 9, BLK_BLACK_CUBE);
    set_block(8, 3, 9, BLK_BLACK_CUBE);
    set_block(6, 2, 7, BLK_TOME);       // Xar Tutorial Tome
    set_block(10, 2, 7, BLK_BUY_STATION); // Tutorial Buy Station
    set_block(6, 2, 9, BLK_CRATE);        // Destructible crate with starting Gold

    // Outside Tutorial Room on the Island: Small White Flower (leads to Alpha Cube!) + Ying Tree + Grow Ring
    set_block(13, 2, 8, BLK_WOOD);
    set_block(13, 3, 8, BLK_PETAL_W);
    set_block(12, 3, 8, BLK_PETAL_W);
    set_block(14, 3, 8, BLK_PETAL_W);
    set_block(13, 4, 8, BLK_WHITE_FLOWER);
    let _ = spawn_entity(ENT_RING_GREEN, 13.5, 4.9, 8.5, 1, BIOME_WHITE_FLOWER, BLK_WHITE_FLOWER);

    // Health Upgrade + Sell Station outside
    set_block(3, 2, 12, BLK_UPG_HP);
    set_block(13, 2, 3, BLK_SELL_STATION);

    // Floating Red Grow Ring above skylight -> Outer Space Level 0
    let _ = spawn_entity(ENT_RING_RED, 8.5, 11.5, 7.5, 1, BIOME_SPACE, BLK_AIR);

    // Friendly early Goon & Gold pickup
    let _ = spawn_entity(ENT_GOON, 13.0, 2.6, 12.0, 25, -1, 0);
    let _ = spawn_entity(ENT_GOLD, 8.5, 2.5, 6.5, 1, -1, 0);
}

fn generate_ying_forest(seed: u64) {
    var z: i32 = 0;
    while z < CHUNK_DIM {
        var x: i32 = 0;
        while x < CHUNK_DIM {
            set_block(x, 0, z, BLK_DIRT);
            set_block(x, 1, z, BLK_GRASS);
            if (x == 0 || x == 15 || z == 0 || z == 15) && ((x + z) % 3 == 0) {
                set_block(x, 2, z, BLK_GRASS);
            }
            x = x + 1;
        }
        z = z + 1;
    }

    // Ying Trees with fractal fruit
    build_ying_tree(3, 12, 2, 4, 1);
    build_ying_tree(12, 12, 2, 4, 0);
    build_ying_tree(13, 3, 2, 5, 1);

    // Totem Pole + Health House
    set_block(3, 2, 4, BLK_WOOD);
    set_block(3, 3, 4, BLK_STONE);
    set_block(3, 4, 4, BLK_WOOD);
    set_block(3, 5, 4, BLK_UPG_REGEN);

    // Jumbo Yellow Flower at (8, 2..5, 12)
    set_block(8, 2, 12, BLK_WOOD);
    set_block(8, 3, 12, BLK_WOOD);
    var fz: i32 = 10;
    while fz <= 14 {
        var fx: i32 = 6;
        while fx <= 10 {
            let dx = fx - 8;
            let dz = fz - 12;
            let r2 = dx * dx + dz * dz;
            if r2 <= 4 {
                if r2 <= 1 { set_block(fx, 4, fz, BLK_POLLEN); }
                else { set_block(fx, 5, fz, BLK_PETAL_Y); }
            }
            fx = fx + 1;
        }
        fz = fz + 1;
    }
    set_block(8, 5, 12, BLK_FLOWER_Y_CORE);
    let _ = spawn_entity(ENT_RING_GREEN, 8.5, 5.9, 12.5, 1, BIOME_YELLOW_FLOWER, BLK_FLOWER_Y_CORE);

    // Small White Flower -> Alpha Cube
    set_block(5, 2, 4, BLK_WHITE_FLOWER);
    let _ = spawn_entity(ENT_RING_GREEN, 5.5, 3.2, 4.5, 1, BIOME_WHITE_FLOWER, BLK_WHITE_FLOWER);

    // Deep Black Cube Monolith -> I2 Lattice / Pink 256x dive
    set_block(13, 2, 9, BLK_BLACK_CUBE);
    set_block(13, 3, 9, BLK_BLACK_CUBE);
    let _ = spawn_entity(ENT_RING_PINK, 13.5, 4.2, 9.5, 1, BIOME_BLACK_CUBE, BLK_BLACK_CUBE);

    // Buy/Sell & Crates
    set_block(10, 2, 6, BLK_BUY_STATION);
    set_block(6, 2, 8, BLK_CRATE);
    set_block(11, 2, 8, BLK_UPG_DMG);

    // Blue Ring shortcut to Mylantis
    let _ = spawn_entity(ENT_RING_BLUE, 3.5, 3.2, 8.5, 1, BIOME_MYLANTIS, BLK_MYLANTIS_M);
    let _ = spawn_entity(ENT_RING_RED, 8.5, 12.5, 8.5, 1, -1, BLK_AIR);

    // Xar Enemies: Yin Yang, Goon, Marine, Spider
    let _ = spawn_entity(ENT_YINYANG, 6.5, 3.2, 10.5, 45, -1, 0);
    let _ = spawn_entity(ENT_GOON, 10.5, 2.6, 10.5, 35, -1, 0);
    let _ = spawn_entity(ENT_SPIDER, 4.5, 2.5, 7.5, 28, -1, 0);
    if (seed & 1) == 0 {
        let _ = spawn_entity(ENT_MARINE, 11.5, 2.6, 5.5, 48, -1, 0);
    }
    let _ = spawn_entity(ENT_GOLD, 8.5, 2.6, 7.5, 1, -1, 0);
    let _ = spawn_entity(ENT_AMMO, 5.5, 2.6, 8.5, 1, -1, 0);
}

fn generate_white_flower_alpha(seed: u64) {
    // Small White Flower interior housing the randomized Alpha Cube!
    var ls = seed;
    var y: i32 = 0;
    while y < CHUNK_DIM {
        var z: i32 = 0;
        while z < CHUNK_DIM {
            var x: i32 = 0;
            while x < CHUNK_DIM {
                let shell = if x == 0 || x == 15 || y == 0 || y == 15 || z == 0 || z == 15 { 1 } else { 0 };
                if shell != 0 {
                    if y == 15 && x >= 6 && x <= 9 && z >= 6 && z <= 9 {
                        set_block(x, y, z, BLK_AIR);
                    } else if ((x + y + z) % 3) == 0 {
                        set_block(x, y, z, BLK_PETAL_W);
                    } else {
                        set_block(x, y, z, BLK_GLASS);
                    }
                }
                x = x + 1;
            }
            z = z + 1;
        }
        y = y + 1;
    }

    // Central Alpha Cube pedestal + random fractal pillars
    set_block(8, 2, 8, BLK_ALPHA_CUBE);
    set_block(8, 3, 8, BLK_ALPHA_CUBE);
    set_block(5, 1, 8, BLK_UPG_HP);
    set_block(11, 1, 8, BLK_UPG_ARMOR);
    set_block(8, 1, 11, BLK_SELL_STATION);
    set_block(8, 1, 4, BLK_TOME);

    var p: i32 = 0;
    while p < 4 {
        ls = splitmix64(ls);
        let px = 3 + ((ls % 10) as! i32);
        ls = splitmix64(ls);
        let pz = 3 + ((ls % 10) as! i32);
        if px != 8 || pz != 8 {
            set_block(px, 2, pz, BLK_ALPHA_CUBE);
            set_block(px, 3, pz, BLK_GOLD_ORE);
        }
        p = p + 1;
    }

    let _ = spawn_entity(ENT_RING_GREEN, 8.5, 4.2, 8.5, 1, BIOME_YELLOW_FLOWER, BLK_ALPHA_CUBE);
    let _ = spawn_entity(ENT_RING_RED, 8.0, 12.2, 8.0, 1, -1, BLK_AIR);
    let _ = spawn_entity(ENT_RAT, 4.5, 2.5, 5.5, 22, -1, 0);
    let _ = spawn_entity(ENT_GOON, 11.5, 2.5, 11.5, 36, -1, 0);
    let _ = spawn_entity(ENT_GOLD, 6.5, 2.5, 9.5, 1, -1, 0);
    let _ = spawn_entity(ENT_HEALTH, 9.5, 2.5, 6.5, 1, -1, 0);
}

fn generate_interior_biome(biome: i32, depth: i32, seed: u64) {
    var ls = seed;
    let wall_blk: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_PETAL_Y }
        else if biome == BIOME_MYLANTIS { BLK_MYLANTIS }
        else if biome == BIOME_BLACK_CUBE { BLK_BLACK_CUBE }
        else { BLK_CORE_GATE };
    let trim_blk: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_POLLEN }
        else if biome == BIOME_MYLANTIS { BLK_ICE }
        else if biome == BIOME_BLACK_CUBE { BLK_GLASS }
        else { BLK_GOLD_ORE };

    // Chamber with open exits on ceiling + two side windows so player can grow out via ANY face!
    var y: i32 = 0;
    while y < CHUNK_DIM {
        var z: i32 = 0;
        while z < CHUNK_DIM {
            var x: i32 = 0;
            while x < CHUNK_DIM {
                let shell = if x == 0 || x == 15 || y == 0 || y == 15 || z == 0 || z == 15 { 1 } else { 0 };
                if shell != 0 {
                    let sky_open = if y == 15 && x >= 6 && x <= 9 && z >= 6 && z <= 9 { 1 } else { 0 };
                    let side_open = if (x == 0 || x == 15) && y >= 6 && y <= 8 && z >= 7 && z <= 8 { 1 } else { 0 };
                    if sky_open == 0 && side_open == 0 {
                        if ((x + y + z) % 5) == 0 { set_block(x, y, z, trim_blk); }
                        else { set_block(x, y, z, wall_blk); }
                    }
                }
                x = x + 1;
            }
            z = z + 1;
        }
        y = y + 1;
    }

    // Menger-sponge style platforms / bridges
    var p: i32 = 0;
    while p < 4 {
        ls = splitmix64(ls);
        let px = 3 + ((ls % 9) as! i32);
        ls = splitmix64(ls);
        let pz = 3 + ((ls % 9) as! i32);
        ls = splitmix64(ls);
        let py = 3 + ((ls % 7) as! i32);
        var dz: i32 = -1;
        while dz <= 1 {
            var dx: i32 = -1;
            while dx <= 1 {
                if dx != 0 || dz != 0 {
                    set_block(px + dx, py, pz + dz, wall_blk);
                }
                dx = dx + 1;
            }
            dz = dz + 1;
        }
        p = p + 1;
    }

    // Clear center spawn shaft (7..9, 2..12, 6..9)
    var sy: i32 = 2;
    while sy <= 12 {
        var sz: i32 = 6;
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

    // Biome-specific stations, upgrades, destructibles & portals
    set_block(5, 1, 8, BLK_BUY_STATION);
    set_block(11, 1, 8, BLK_SELL_STATION);
    set_block(4, 1, 4, BLK_CRATE);
    set_block(11, 1, 4, BLK_GOLD_ORE);
    if depth >= 2 { set_block(11, 1, 11, BLK_SPAWNER); }
    if biome == BIOME_MYLANTIS || biome == BIOME_BLACK_CUBE {
        set_block(4, 1, 12, BLK_BLACK_MARKET);
        set_block(12, 2, 12, BLK_LOCKED_DOOR);
        set_block(12, 2, 13, BLK_UPG_AMMO);
    }

    if biome == BIOME_YELLOW_FLOWER {
        set_block(8, 1, 4, BLK_UPG_HP);
        set_block(8, 1, 12, BLK_KEY_BLOCK);
        set_block(4, 2, 8, BLK_MYLANTIS_M);
    } else if biome == BIOME_MYLANTIS {
        set_block(8, 1, 4, BLK_UPG_ROF);
        set_block(8, 1, 12, BLK_UPG_SPEED);
        set_block(4, 2, 8, BLK_BLACK_CUBE);
    } else if biome == BIOME_BLACK_CUBE {
        set_block(8, 1, 4, BLK_UPG_DMG);
        set_block(8, 1, 12, BLK_TOME);
        set_block(4, 2, 8, BLK_CORE_GATE);
    } else if biome == BIOME_INNER_CORE {
        set_block(8, 1, 4, BLK_UPG_ARMOR);
        set_block(8, 1, 12, BLK_UPG_HP);
    }

    // Rings
    let _ = spawn_entity(ENT_RING_RED, 8.0, 12.2, 8.0, 1, -1, BLK_AIR);
    let next_biome: i32 =
        if biome == BIOME_YELLOW_FLOWER { BIOME_MYLANTIS }
        else if biome == BIOME_MYLANTIS { BIOME_BLACK_CUBE }
        else { BIOME_INNER_CORE };
    let next_blk: u8 =
        if biome == BIOME_YELLOW_FLOWER { BLK_MYLANTIS_M }
        else if biome == BIOME_MYLANTIS { BLK_BLACK_CUBE }
        else { BLK_CORE_GATE };
    if biome != BIOME_INNER_CORE {
        let _ = spawn_entity(ENT_RING_GREEN, 4.5, 3.2, 8.0, 1, next_biome, next_blk);
        let _ = spawn_entity(ENT_RING_PINK, 12.0, 3.2, 4.5, 1, BIOME_BLACK_CUBE, BLK_BLACK_CUBE);
    }

    // Xar Monster Manual Enemies scaled by depth
    let scale_hp = 35 + depth * 28;
    if biome == BIOME_YELLOW_FLOWER {
        let _ = spawn_entity(ENT_PIRATE, 4.5, 2.6, 11.5, scale_hp, -1, 0);
        let _ = spawn_entity(ENT_MARINE, 11.5, 2.6, 4.5, scale_hp + 10, -1, 0);
        let _ = spawn_entity(ENT_MENACE, 8.0, 7.5, 12.0, scale_hp + 15, -1, 0);
    } else if biome == BIOME_MYLANTIS {
        let _ = spawn_entity(ENT_SPIDER, 4.5, 2.5, 11.5, scale_hp, -1, 0);
        let _ = spawn_entity(ENT_DEMON, 11.5, 3.5, 11.5, scale_hp + 30, -1, 0);
        let _ = spawn_entity(ENT_MARINE, 5.5, 5.5, 5.5, scale_hp + 15, -1, 0);
    } else if biome == BIOME_BLACK_CUBE {
        let _ = spawn_entity(ENT_GUARDIAN, 4.5, 5.0, 11.5, scale_hp + 85, -1, 0);
        let _ = spawn_entity(ENT_DEMON, 11.5, 3.5, 5.5, scale_hp + 45, -1, 0);
        let _ = spawn_entity(ENT_MENACE, 12.0, 8.5, 12.0, scale_hp + 30, -1, 0);
    } else {
        // Inner Core: The Singularity + Guardians + Friend K!
        let _ = spawn_entity(ENT_SINGULARITY, 8.0, 6.8, 11.8, 320 + depth * 45, -1, 0);
        let _ = spawn_entity(ENT_GUARDIAN, 4.2, 3.2, 11.5, scale_hp + 70, -1, 0);
        if st.k_rescued == 0 {
            let _ = spawn_entity(ENT_FRIEND_K, 8.0, 2.6, 13.6, 1, -1, 0);
        }
    }

    let _ = spawn_entity(ENT_GOLD, 6.5, 2.4, 5.5, 1, -1, 0);
    let _ = spawn_entity(ENT_AMMO, 4.0, 2.4, 8.0, 1, -1, 0);
    let _ = spawn_entity(ENT_HEALTH, 8.0, 2.4, 3.5, 1, -1, 0);
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

    if biome == BIOME_SPACE {
        generate_space_chunk();
    } else if biome == BIOME_TUTORIAL {
        generate_tutorial_island();
    } else if biome == BIOME_YING_FOREST {
        generate_ying_forest(seed);
    } else if biome == BIOME_WHITE_FLOWER {
        generate_white_flower_alpha(seed);
    } else {
        generate_interior_biome(biome, st.depth, seed);
    }

    // Reapply persistent block deltas (broken crates, opened doors, collected upgrades)
    i = 0;
    while i < MAX_DELTAS {
        if st.deltas[i].used != 0 && st.deltas[i].seed == seed {
            set_block(st.deltas[i].bx, st.deltas[i].by, st.deltas[i].bz, st.deltas[i].blk);
        }
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// Recursive 16x Shrink & 6-Face Chunk-Boundary Grow (Exact FBW Scaling)
// ---------------------------------------------------------------------------
fn shrink_into(bx: i32, by: i32, bz: i32, target_blk: u8, forced_biome: i32, steps: i32) {
    if st.ring_cd_ms > 0 { return; }
    var d: i32 = 0;
    var cur_bx: i32 = clamp_i(bx, 0, 15);
    var cur_by: i32 = clamp_i(by, 0, 15);
    var cur_bz: i32 = clamp_i(bz, 0, 15);
    var cur_blk: u8 = target_blk;
    var cur_forced: i32 = forced_biome;

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
        st.stack[next_idx].biome = pick_biome_for_entry(next_depth, cur_blk, cur_forced, nseed);
        cur_bx = 8; cur_by = 8; cur_bz = 8;
        cur_blk = BLK_BLACK_CUBE;
        cur_forced = -1;
        d = d + 1;
    }

    load_current_chunk();
    st.px = 8.0;
    st.py = 3.2;
    st.pz = 6.5;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.ring_cd_ms = 650;
    st.flash_ms = 220;
    st.flash_rgb = pack_rgb(40, 235, 130);
    set_status_msg("Shrank 16x deeper into fractal block!", 1800);
}

fn grow_out_axis(exit_x: f64, exit_y: f64, exit_z: f64) {
    if st.ring_cd_ms > 0 { return; }
    let next_depth = st.depth - 1;
    let next_idx = next_depth + MACRO_OFFSET;
    if next_idx < 1 {
        // Outer Cosmic Boundary — wrap gently inside Outer Space
        st.px = fclamp(exit_x, 0.5, 15.5);
        st.py = fclamp(exit_y, 0.5, 15.5);
        st.pz = fclamp(exit_z, 0.5, 15.5);
        set_status_msg("Outer Cosmic Boundary of Xar reached!", 1500);
        return;
    }

    let cur_idx = st.depth + MACRO_OFFSET;
    let ret_bx = st.stack[cur_idx].bx;
    let ret_by = st.stack[cur_idx].by;
    let ret_bz = st.stack[cur_idx].bz;

    if next_depth < 0 && st.stack[next_idx].seed == 0 {
        let mseed = hash_block_seed(0x4642575f584152, 8, 6, 8, next_depth);
        st.stack[next_idx].bx = 8;
        st.stack[next_idx].by = 6;
        st.stack[next_idx].bz = 8;
        st.stack[next_idx].parent_block = BLK_YING_PLANET;
        st.stack[next_idx].seed = mseed;
        st.stack[next_idx].biome = BIOME_SPACE;
    }

    st.depth = next_depth;
    if st.depth < st.min_depth_reached { st.min_depth_reached = st.depth; }
    load_current_chunk();

    // Place player on the exact face of the parent block they exited from!
    var nx: f64 = ret_bx + fclamp(exit_x / 16.0, 0.1, 0.9);
    var ny: f64 = ret_by + fclamp(exit_y / 16.0, 0.1, 0.9);
    var nz: f64 = ret_bz + fclamp(exit_z / 16.0, 0.1, 0.9);
    if exit_x < 0.0 { nx = ret_bx - 0.65; }
    else if exit_x >= 16.0 { nx = ret_bx + 1.65; }
    if exit_y < 0.0 { ny = ret_by - 0.65; }
    else if exit_y >= 16.0 { ny = ret_by + 1.65; }
    if exit_z < 0.0 { nz = ret_bz - 0.65; }
    else if exit_z >= 16.0 { nz = ret_bz + 1.65; }

    st.px = fclamp(nx, 0.6, 15.4);
    st.py = fclamp(ny, 1.5, 14.5);
    st.pz = fclamp(nz, 0.6, 15.4);

    // Push cleanly outside multi-block structures (e.g. 3x3x3 Ying Planet) if colliding
    var push: i32 = 0;
    while point_collides(st.px, st.py, st.pz) != 0 && push < 5 {
        if exit_x < 0.0 { st.px = st.px - 1.0; }
        else if exit_x >= 16.0 { st.px = st.px + 1.0; }
        else if exit_y < 0.0 { st.py = st.py - 1.0; }
        else if exit_y >= 16.0 { st.py = st.py + 1.0; }
        else if exit_z < 0.0 { st.pz = st.pz - 1.0; }
        else if exit_z >= 16.0 { st.pz = st.pz + 1.0; }
        else { st.py = st.py + 1.0; }
        st.px = fclamp(st.px, 0.6, 15.4);
        st.py = fclamp(st.py, 1.5, 14.5);
        st.pz = fclamp(st.pz, 0.6, 15.4);
        push = push + 1;
    }
    if point_collides(st.px, st.py, st.pz) != 0 {
        st.px = 8.5;
        st.py = 11.5;
        st.pz = 8.5;
    }

    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.ring_cd_ms = 650;
    st.flash_ms = 220;
    st.flash_rgb = pack_rgb(245, 70, 70);
    set_status_msg("Grew 16x outward to parent chunk!", 1800);
}

// ---------------------------------------------------------------------------
// Init, Respawn & Reset
// ---------------------------------------------------------------------------
fn set_default_ammo_caps() {
    let mul = 1.0 + 0.35 * ((st.ammo_cap_lvl - 1) as f64);
    st.max_ammo[WEP_PLASMA] = 9999;
    st.max_ammo[WEP_CANNON] = (80.0 * mul) as! i32;
    st.max_ammo[WEP_LASER] = (120.0 * mul) as! i32;
    st.max_ammo[WEP_ROCKET] = (40.0 * mul) as! i32;
    st.max_ammo[WEP_HOMING] = (32.0 * mul) as! i32;
    st.max_ammo[WEP_MINIGUN] = (400.0 * mul) as! i32;
    st.max_ammo[WEP_RAILGUN] = (30.0 * mul) as! i32;
    st.max_ammo[WEP_EMP] = (20.0 * mul) as! i32;
    st.max_ammo[WEP_NUKE] = (8.0 * mul) as! i32;
    st.max_ammo[WEP_DARKHOLE] = (6.0 * mul) as! i32;
}

fn init_new_game() {
    var i: i32 = 0;
    while i < MAX_STACK {
        st.stack[i].seed = 0;
        st.stack[i].biome = BIOME_SPACE;
        i = i + 1;
    }
    i = 0;
    while i < MAX_DELTAS {
        st.deltas[i].used = 0;
        i = i + 1;
    }
    i = 0;
    while i < MAX_MARKERS {
        st.markers[i].used = 0;
        i = i + 1;
    }
    st.delta_head = 0;
    st.active_marker = -1;

    st.depth = 0;
    st.max_depth_reached = 0;
    st.min_depth_reached = 0;
    let zidx = MACRO_OFFSET;
    st.stack[zidx].bx = 8;
    st.stack[zidx].by = 6;
    st.stack[zidx].bz = 8;
    st.stack[zidx].parent_block = BLK_YING_PLANET;
    st.stack[zidx].seed = 0x5841525f54555430;
    st.stack[zidx].biome = BIOME_TUTORIAL;

    // Spawn inside the Tutorial Room facing the Black Cube (+Z)
    st.px = 8.5;
    st.py = 3.2;
    st.pz = 5.2;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.yaw = HALF_PI;
    st.pitch = -0.04;
    st.roll = 0.0;
    st.true_up = 1;
    st.rocket_mode = 0;

    st.hp = 100;
    st.max_hp = 100;
    st.hp_regen = 1;
    st.regen_accum_ms = 0;
    st.armor = 50;
    st.max_armor = 100;
    st.gold = 40;
    st.keys = 0;
    st.kills = 0;
    st.deaths = 0;
    st.quasar_drive = 0;
    st.k_rescued = 0;
    st.telekinesis_ms = 0;

    st.dmg_lvl = 1;
    st.rof_lvl = 1;
    st.spd_lvl = 1;
    st.ammo_cap_lvl = 1;
    set_default_ammo_caps();

    st.weapon = WEP_PLASMA;
    st.ammo[WEP_PLASMA] = 9999;
    st.ammo[WEP_CANNON] = 24;
    st.ammo[WEP_LASER] = 45;
    st.ammo[WEP_ROCKET] = 12;
    st.ammo[WEP_HOMING] = 10;
    st.ammo[WEP_MINIGUN] = 140;
    st.ammo[WEP_RAILGUN] = 12;
    st.ammo[WEP_EMP] = 8;
    st.ammo[WEP_NUKE] = 2;
    st.ammo[WEP_DARKHOLE] = 2;

    st.fire_cd_ms = 0;
    st.ring_cd_ms = 400;
    st.beam_timer_ms = 0;
    st.flash_ms = 0;
    st.near_ring_kind = ENT_NONE;
    st.near_prompt_len = 0;
    st.target_name_len = 0;
    st.tome_id = 0;

    load_current_chunk();
    set_status_msg("Tutorial: Fly into Black Cube -> Ying Forest, or exit to Space!", 4200);
}

fn respawn_at_tutorial_preserving_progress() {
    // Authentic FBW death rule: lose 30 gold, keep weapons/upgrades/markers/deltas, respawn at Tutorial!
    st.deaths = st.deaths + 1;
    st.gold = if st.gold >= DEATH_GOLD_PENALTY { st.gold - DEATH_GOLD_PENALTY } else { 0 };
    st.hp = st.max_hp;
    st.armor = clamp_i(st.armor, st.max_armor / 2, st.max_armor);
    st.depth = 0;
    let zidx = MACRO_OFFSET;
    st.stack[zidx].bx = 8;
    st.stack[zidx].by = 6;
    st.stack[zidx].bz = 8;
    st.stack[zidx].parent_block = BLK_YING_PLANET;
    st.stack[zidx].seed = 0x5841525f54555430;
    st.stack[zidx].biome = BIOME_TUTORIAL;
    load_current_chunk();
    st.px = 8.5;
    st.py = 3.2;
    st.pz = 5.2;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.yaw = HALF_PI;
    st.pitch = -0.04;
    st.roll = 0.0;
    st.ring_cd_ms = 600;
    st.flash_ms = 320;
    st.flash_rgb = pack_rgb(220, 40, 60);
    set_status_msg("Hull destroyed! Respawned at Tutorial (-30 Gold, upgrades preserved).", 3600);
}

// ---------------------------------------------------------------------------
// Physics, Upgrades, Stations, Markers & Combat
// ---------------------------------------------------------------------------
fn point_collides(x: f64, y: f64, z: f64) -> i32 {
    let rad: f64 = 0.24;
    var dz: i32 = -1;
    while dz <= 1 {
        var dy: i32 = -1;
        while dy <= 1 {
            var dx: i32 = -1;
            while dx <= 1 {
                let bx = ffloor(x + dx * rad);
                let by = ffloor(y + dy * rad);
                let bz = ffloor(z + dz * rad);
                let blk = get_block(bx, by, bz);
                if is_block_solid(blk) != 0 {
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

fn collect_upgrade_block(bx: i32, by: i32, bz: i32, blk: u8) {
    set_block(bx, by, bz, BLK_AIR);
    record_block_delta(bx, by, bz, BLK_AIR);
    spawn_burst(bx + 0.5, by + 0.5, bz + 0.5, block_base_rgb(blk), 12);
    st.flash_ms = 180;
    st.flash_rgb = block_base_rgb(blk);

    if blk == BLK_UPG_HP {
        st.max_hp = st.max_hp + 20;
        st.hp = st.max_hp;
        set_status_msg("UPGRADE: +20 Max Health & Full Heal!", 2200);
    } else if blk == BLK_UPG_REGEN {
        st.hp_regen = st.hp_regen + 1;
        set_status_msg("UPGRADE: +1 Health Regen!", 2200);
    } else if blk == BLK_UPG_ARMOR {
        st.max_armor = st.max_armor + 25;
        st.armor = st.max_armor;
        set_status_msg("UPGRADE: +25 Max Armor & Refill!", 2200);
    } else if blk == BLK_UPG_DMG {
        st.dmg_lvl = st.dmg_lvl + 1;
        set_status_msg("UPGRADE: +20% Weapon Damage!", 2200);
    } else if blk == BLK_UPG_ROF {
        st.rof_lvl = st.rof_lvl + 1;
        set_status_msg("UPGRADE: +15% Fire Rate!", 2200);
    } else if blk == BLK_UPG_AMMO {
        st.ammo_cap_lvl = st.ammo_cap_lvl + 1;
        set_default_ammo_caps();
        set_status_msg("UPGRADE: +35% Max Ammo Capacity!", 2200);
    } else if blk == BLK_UPG_SPEED {
        st.spd_lvl = st.spd_lvl + 1;
        set_status_msg("UPGRADE: +12% Flight Thrust!", 2200);
    } else if blk == BLK_KEY_BLOCK {
        st.keys = st.keys + 1;
        set_status_msg("Picked up Vault Key!", 2000);
    }
}

fn check_touch_special_block(tx: f64, ty: f64, tz: f64) -> i32 {
    let bx = ffloor(tx);
    let by = ffloor(ty);
    let bz = ffloor(tz);
    let blk = get_block(bx, by, bz);
    if is_block_upgrade(blk) != 0 {
        collect_upgrade_block(bx, by, bz, blk);
        return 1;
    }
    if is_block_shrinkable(blk) != 0 && st.ring_cd_ms <= 0 {
        shrink_into(bx, by, bz, blk, -1, 1);
        return 2;
    }
    return 0;
}

fn apply_thrust(ax: f64, ay: f64, az: f64) {
    let mul = 1.0 + 0.12 * ((st.spd_lvl - 1) as f64);
    let boost = if st.rocket_mode != 0 { 1.35 } else { 1.0 };
    st.vx = st.vx + ax * mul * boost;
    st.vy = st.vy + ay * mul * boost;
    st.vz = st.vz + az * mul * boost;
}

fn apply_brake() {
    st.vx = st.vx * 0.18;
    st.vy = st.vy * 0.18;
    st.vz = st.vz * 0.18;
}

fn move_player_vec(dx: f64, dy: f64, dz: f64) {
    let nx = st.px + dx;
    if point_collides(nx, st.py, st.pz) == 0 {
        st.px = nx;
    } else {
        if check_touch_special_block(nx + (if dx > 0.0 { 0.25 } else { -0.25 }), st.py, st.pz) == 2 { return; }
        st.vx = 0.0;
    }

    let ny = st.py + dy;
    if point_collides(st.px, ny, st.pz) == 0 {
        st.py = ny;
    } else {
        if check_touch_special_block(st.px, ny + (if dy > 0.0 { 0.25 } else { -0.25 }), st.pz) == 2 { return; }
        st.vy = 0.0;
    }

    let nz = st.pz + dz;
    if point_collides(st.px, st.py, nz) == 0 {
        st.pz = nz;
    } else {
        if check_touch_special_block(st.px, st.py, nz + (if dz > 0.0 { 0.25 } else { -0.25 })) == 2 { return; }
        st.vz = 0.0;
    }

    // Authentic FBW: Leaving ANY of the 6 chunk faces grows 16x outward!
    if st.px < 0.0 || st.px >= 16.0 || st.py < 0.0 || st.py >= 16.0 || st.pz < 0.0 || st.pz >= 16.0 {
        grow_out_axis(st.px, st.py, st.pz);
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
        respawn_at_tutorial_preserving_progress();
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
        let _ = spawn_entity(ENT_GOLD, cx, cy, cz, 1, -1, 0);
        let _ = spawn_entity(ENT_AMMO, cx + 0.25, cy, cz, 1, -1, 0);
        set_status_msg("Crate smashed! Gold & Ammo dropped.", 1400);
    } else if b == BLK_GOLD_ORE {
        let _ = spawn_entity(ENT_GOLD, cx, cy, cz, 1, -1, 0);
        add_gold(15);
        set_status_msg("Gold Ore mined! +15 Gold!", 1400);
    } else if b == BLK_SPAWNER {
        let _ = spawn_entity(ENT_GOLD, cx, cy, cz, 1, -1, 0);
        let _ = spawn_entity(ENT_ARMOR, cx, cy + 0.2, cz, 1, -1, 0);
        st.kills = st.kills + 1;
        set_status_msg("Spawner destroyed!", 1500);
    }
}

fn damage_entity(idx: i32, dmg: i32, stun_ms: i32) {
    if st.entities[idx].active == 0 { return; }
    let k = st.entities[idx].kind;
    if k < ENT_RAT || k > ENT_SINGULARITY { return; }
    if stun_ms > st.entities[idx].freeze_ms {
        st.entities[idx].freeze_ms = stun_ms;
    }
    st.entities[idx].hp = st.entities[idx].hp - dmg;
    spawn_burst(st.entities[idx].x, st.entities[idx].y, st.entities[idx].z, pack_rgb(255, 110, 60), 6);
    if st.entities[idx].hp <= 0 {
        st.entities[idx].active = 0;
        st.kills = st.kills + 1;
        let ex = st.entities[idx].x;
        let ey = st.entities[idx].y;
        let ez = st.entities[idx].z;
        spawn_burst(ex, ey, ez, pack_rgb(255, 210, 70), 14);
        let _ = spawn_entity(ENT_GOLD, ex, ey, ez, 1, -1, 0);
        if k == ENT_GOON || k == ENT_MARINE || k == ENT_PIRATE {
            let _ = spawn_entity(ENT_AMMO, ex + 0.25, ey, ez, 1, -1, 0);
        }
        if k == ENT_SINGULARITY {
            st.quasar_drive = 1;
            add_gold(500);
            let _ = spawn_entity(ENT_ARMOR, ex + 0.4, ey, ez, 1, -1, 0);
            let _ = spawn_entity(ENT_HEALTH, ex - 0.4, ey, ez, 1, -1, 0);
            set_status_msg("THE SINGULARITY DEFEATED! Quasar Drive unlocked for Weapon 0! Approach K [F]!", 4800);
        } else if (rng_u32() % 3) == 0 {
            let _ = spawn_entity(ENT_HEALTH, ex + 0.3, ey, ez, 1, -1, 0);
        }
    }
}

fn explosion_at(x: f64, y: f64, z: f64, rad: f64, dmg: i32, stun_ms: i32, pull_in: i32, rgb: u32) {
    spawn_burst(x, y, z, rgb, 18);
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 && st.entities[i].kind >= ENT_RAT && st.entities[i].kind <= ENT_SINGULARITY {
            let dx = st.entities[i].x - x;
            let dy = st.entities[i].y - y;
            let dz = st.entities[i].z - z;
            let d = fsqrt(dx * dx + dy * dy + dz * dz);
            if d <= rad {
                if pull_in != 0 && d > 0.35 {
                    st.entities[i].x = st.entities[i].x - dx * 0.55;
                    st.entities[i].y = st.entities[i].y - dy * 0.55;
                    st.entities[i].z = st.entities[i].z - dz * 0.55;
                }
                damage_entity(i, dmg, stun_ms);
            }
        }
        i = i + 1;
    }
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

fn camera_forward(fx: f64&, fy: f64&, fz: f64&) {
    let cp = fcos(st.pitch);
    fx = cp * fcos(st.yaw);
    fy = fsin(st.pitch);
    fz = cp * fsin(st.yaw);
}

fn fire_weapon(secondary: i32) {
    if st.fire_cd_ms > 0 { return; }
    let w = st.weapon;
    let cost: i32 = if w == WEP_PLASMA { 0 } else if secondary != 0 && (w == WEP_HOMING || w == WEP_NUKE) { 2 } else { 1 };
    if w != WEP_PLASMA && st.ammo[w] < cost {
        st.weapon = WEP_PLASMA;
        set_status_msg("Out of ammo — switched to 1:Plasma!", 1200);
        return;
    }
    if w != WEP_PLASMA { st.ammo[w] = st.ammo[w] - cost; }

    var dx: f64 = 0.0;
    var dy: f64 = 0.0;
    var dz: f64 = 0.0;
    camera_forward(dx, dy, dz);

    let rof_mul = 1.0 / (1.0 + 0.15 * ((st.rof_lvl - 1) as f64));
    let dmg_mul = 1.0 + 0.20 * ((st.dmg_lvl - 1) as f64);

    if w == WEP_PLASMA {
        if secondary != 0 {
            st.fire_cd_ms = (320.0 * rof_mul) as! i32;
            let dmg = (14.0 * dmg_mul) as! i32;
            var s: i32 = -1;
            while s <= 1 {
                let syaw = st.yaw + s * 0.12;
                let cp = fcos(st.pitch);
                let sx = cp * fcos(syaw);
                let sz = cp * fsin(syaw);
                spawn_shot(1, w, 1, st.px + sx * 0.4, st.py + dy * 0.4, st.pz + sz * 0.4,
                    sx * 16.0, dy * 16.0, sz * 16.0, dmg, 1300, pack_rgb(64, 232, 255));
                s = s + 1;
            }
        } else {
            st.fire_cd_ms = (190.0 * rof_mul) as! i32;
            let dmg = (20.0 * dmg_mul) as! i32;
            spawn_shot(1, w, 0, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
                dx * 17.0, dy * 17.0, dz * 17.0, dmg, 1400, pack_rgb(56, 224, 255));
        }
    } else if w == WEP_CANNON {
        st.fire_cd_ms = ((if secondary != 0 { 190.0 } else { 380.0 }) * rof_mul) as! i32;
        let dmg = ((if secondary != 0 { 32.0 } else { 48.0 }) * dmg_mul) as! i32;
        let spd = if secondary != 0 { 19.0 } else { 15.0 };
        spawn_shot(1, w, secondary, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
            dx * spd, dy * spd, dz * spd, dmg, 1600, pack_rgb(255, 160, 48));
    } else if w == WEP_LASER {
        if secondary != 0 {
            // Laser Secondary: Cryo-Freeze burst + Shield Recharge (+8 Armor)!
            st.fire_cd_ms = (480.0 * rof_mul) as! i32;
            st.armor = clamp_i(st.armor + 8, 0, st.max_armor);
            explosion_at(st.px + dx * 3.0, st.py + dy * 3.0, st.pz + dz * 3.0, 4.5, (20.0 * dmg_mul) as! i32, 3500, 0, pack_rgb(80, 220, 255));
            set_status_msg("Laser Pulse: Enemies frozen +8 Armor!", 1200);
        } else {
            st.fire_cd_ms = (250.0 * rof_mul) as! i32;
            let dmg = (34.0 * dmg_mul) as! i32;
            let col = pack_rgb(255, 68, 86);
            var t: f64 = 0.4;
            var end_x = st.px + dx * 18.0;
            var end_y = st.py + dy * 18.0;
            var end_z = st.pz + dz * 18.0;
            while t < 20.0 {
                let hx = st.px + dx * t;
                let hy = st.py + dy * t;
                let hz = st.pz + dz * t;
                let bx = ffloor(hx);
                let by = ffloor(hy);
                let bz = ffloor(hz);
                if bx < 0 || bx >= 16 || by < 0 || by >= 16 || bz < 0 || bz >= 16 {
                    end_x = hx; end_y = hy; end_z = hz; break;
                }
                let blk = get_block(bx, by, bz);
                if is_block_solid(blk) != 0 {
                    end_x = hx; end_y = hy; end_z = hz;
                    if is_block_destructible(blk) != 0 { break_block_at(bx, by, bz); }
                    else { spawn_burst(hx, hy, hz, col, 6); }
                    break;
                }
                var ei: i32 = 0;
                while ei < MAX_ENTITIES {
                    if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_RAT && st.entities[ei].kind <= ENT_SINGULARITY {
                        let ex = st.entities[ei].x - hx;
                        let ey = st.entities[ei].y - hy;
                        let ez = st.entities[ei].z - hz;
                        if (ex * ex + ey * ey + ez * ez) < 0.42 {
                            damage_entity(ei, dmg, 0);
                            end_x = hx; end_y = hy; end_z = hz;
                            t = 99.0;
                            break;
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
            st.beam_x2 = end_x; st.beam_y2 = end_y; st.beam_z2 = end_z;
        }
    } else if w == WEP_ROCKET {
        st.fire_cd_ms = (460.0 * rof_mul) as! i32;
        let dmg = ((if secondary != 0 { 72.0 } else { 58.0 }) * dmg_mul) as! i32;
        let spd = if secondary != 0 { 16.0 } else { 12.5 };
        spawn_shot(1, w, secondary, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
            dx * spd, dy * spd, dz * spd, dmg, 1900, pack_rgb(255, 118, 36));
    } else if w == WEP_HOMING {
        st.fire_cd_ms = (420.0 * rof_mul) as! i32;
        let dmg = (44.0 * dmg_mul) as! i32;
        spawn_shot(1, w, secondary, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
            dx * 11.0, dy * 11.0, dz * 11.0, dmg, 2600, pack_rgb(244, 114, 248));
        if secondary != 0 {
            spawn_shot(1, w, secondary, st.px + dx * 0.4 + 0.2, st.py + dy * 0.4 + 0.15, st.pz + dz * 0.4,
                dx * 10.5, dy * 10.5, dz * 10.5, dmg, 2600, pack_rgb(244, 114, 248));
        }
    } else if w == WEP_MINIGUN {
        st.fire_cd_ms = ((if secondary != 0 { 55.0 } else { 80.0 }) * rof_mul) as! i32;
        let dmg = (12.0 * dmg_mul) as! i32;
        let spread = if secondary != 0 { 0.11 } else { 0.045 };
        let jx = dx + (rng_f01() - 0.5) * spread;
        let jy = dy + (rng_f01() - 0.5) * spread;
        let jz = dz + (rng_f01() - 0.5) * spread;
        spawn_shot(1, w, secondary, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
            jx * 22.0, jy * 22.0, jz * 22.0, dmg, 1000, pack_rgb(255, 215, 72));
    } else if w == WEP_RAILGUN {
        // Piercing hitscan + Recoil Boost!
        st.fire_cd_ms = (640.0 * rof_mul) as! i32;
        let dmg = ((if secondary != 0 { 110.0 } else { 78.0 }) * dmg_mul) as! i32;
        let recoil = if secondary != 0 { 9.5 } else { 5.2 };
        st.vx = st.vx - dx * recoil;
        st.vy = st.vy - dy * recoil;
        st.vz = st.vz - dz * recoil;

        let col = pack_rgb(196, 86, 255);
        var t: f64 = 0.4;
        var end_x = st.px + dx * 20.0;
        var end_y = st.py + dy * 20.0;
        var end_z = st.pz + dz * 20.0;
        while t < 22.0 {
            let hx = st.px + dx * t;
            let hy = st.py + dy * t;
            let hz = st.pz + dz * t;
            let bx = ffloor(hx);
            let by = ffloor(hy);
            let bz = ffloor(hz);
            if bx < 0 || bx >= 16 || by < 0 || by >= 16 || bz < 0 || bz >= 16 {
                end_x = hx; end_y = hy; end_z = hz; break;
            }
            let blk = get_block(bx, by, bz);
            if is_block_solid(blk) != 0 {
                end_x = hx; end_y = hy; end_z = hz;
                if is_block_destructible(blk) != 0 { break_block_at(bx, by, bz); }
                else { spawn_burst(hx, hy, hz, col, 7); }
                break;
            }
            var ei: i32 = 0;
            while ei < MAX_ENTITIES {
                if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_RAT && st.entities[ei].kind <= ENT_SINGULARITY {
                    let ex = st.entities[ei].x - hx;
                    let ey = st.entities[ei].y - hy;
                    let ez = st.entities[ei].z - hz;
                    if (ex * ex + ey * ey + ez * ez) < 0.48 {
                        damage_entity(ei, dmg, 0);
                    }
                }
                ei = ei + 1;
            }
            t = t + 0.30;
        }
        st.beam_timer_ms = 175;
        st.beam_rgb = col;
        st.beam_x1 = st.px + dx * 0.45;
        st.beam_y1 = st.py + dy * 0.45 - 0.12;
        st.beam_z1 = st.pz + dz * 0.45;
        st.beam_x2 = end_x; st.beam_y2 = end_y; st.beam_z2 = end_z;
    } else if w == WEP_EMP {
        if secondary != 0 {
            st.fire_cd_ms = (650.0 * rof_mul) as! i32;
            explosion_at(st.px, st.py, st.pz, 6.5, (28.0 * dmg_mul) as! i32, 4800, 0, pack_rgb(96, 165, 250));
            set_status_msg("EMP Shockwave released! Nearby enemies stunned.", 1400);
        } else {
            st.fire_cd_ms = (480.0 * rof_mul) as! i32;
            let dmg = (24.0 * dmg_mul) as! i32;
            spawn_shot(1, w, 0, st.px + dx * 0.4, st.py + dy * 0.4, st.pz + dz * 0.4,
                dx * 15.0, dy * 15.0, dz * 15.0, dmg, 1500, pack_rgb(59, 130, 246));
        }
    } else if w == WEP_NUKE {
        // Nuclear Pulse Propulsion Recoil Boost!
        st.fire_cd_ms = (950.0 * rof_mul) as! i32;
        let dmg = ((if secondary != 0 { 220.0 } else { 150.0 }) * dmg_mul) as! i32;
        st.vx = st.vx - dx * 8.2;
        st.vy = st.vy - dy * 8.2;
        st.vz = st.vz - dz * 8.2;
        spawn_shot(1, w, secondary, st.px + dx * 0.5, st.py + dy * 0.5, st.pz + dz * 0.5,
            dx * 9.5, dy * 9.5, dz * 9.5, dmg, 1900, pack_rgb(163, 230, 53));
    } else if w == WEP_DARKHOLE {
        // Dark Hole / Quasar Drive + Recoil Boost!
        st.fire_cd_ms = (880.0 * rof_mul) as! i32;
        let qmul = if st.quasar_drive != 0 { 2.0 } else { 1.0 };
        let dmg = (170.0 * dmg_mul * qmul) as! i32;
        st.vx = st.vx - dx * 7.5;
        st.vy = st.vy - dy * 7.5;
        st.vz = st.vz - dz * 7.5;
        let col = if st.quasar_drive != 0 { pack_rgb(255, 224, 112) } else { pack_rgb(218, 62, 255) };
        spawn_shot(1, w, secondary, st.px + dx * 0.5, st.py + dy * 0.5, st.pz + dz * 0.5,
            dx * 8.5, dy * 8.5, dz * 8.5, dmg, 2100, col);
    }
}

fn trigger_telekinesis() {
    st.telekinesis_ms = 420;
    var pulled: i32 = 0;
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 && st.entities[i].kind >= ENT_GOLD && st.entities[i].kind <= ENT_KEY {
            let dx = st.px - st.entities[i].x;
            let dy = st.py - st.entities[i].y;
            let dz = st.pz - st.entities[i].z;
            let d = fsqrt(dx * dx + dy * dy + dz * dz);
            if d > 0.2 && d < 14.0 {
                st.entities[i].x = st.px - (dx / d) * 0.4;
                st.entities[i].y = st.py - (dy / d) * 0.4;
                st.entities[i].z = st.pz - (dz / d) * 0.4;
                pulled = pulled + 1;
            }
        }
        i = i + 1;
    }
    if pulled > 0 {
        set_status_msg("Telekinesis pulled nearby pickups!", 1200);
    } else {
        set_status_msg("Telekinesis pulse — no loose pickups in range.", 1000);
    }
}

fn drop_marker(is_long: i32) {
    var slot: i32 = 0;
    if is_long == 0 {
        // Short marker uses slot 0 so pressing M replaces your quick breadcrumb
        slot = 0;
    } else {
        slot = 1;
        while slot < MAX_MARKERS && st.markers[slot].used != 0 {
            slot = slot + 1;
        }
        if slot >= MAX_MARKERS { slot = 1; }
    }
    st.markers[slot].used = 1;
    st.markers[slot].is_long = is_long;
    st.markers[slot].depth = st.depth;
    st.markers[slot].px = st.px;
    st.markers[slot].py = st.py;
    st.markers[slot].pz = st.pz;
    let sidx = st.depth + MACRO_OFFSET;
    st.markers[slot].biome = st.stack[sidx].biome;
    var wi: i32 = 0;
    while wi < MAX_STACK {
        st.markers[slot].stack[wi] = st.stack[wi];
        wi = wi + 1;
    }
    st.active_marker = slot;
    if is_long != 0 {
        set_status_msg("Long Tracking Marker placed! View & warp via [F4].", 1800);
    } else {
        set_status_msg("Short Marker dropped! Press [F4] to track or warp back.", 1600);
    }
}

fn warp_to_marker(slot: i32) -> i32 {
    if slot < 0 || slot >= MAX_MARKERS || st.markers[slot].used == 0 { return 0; }
    var wi: i32 = 0;
    while wi < MAX_STACK {
        st.stack[wi] = st.markers[slot].stack[wi];
        wi = wi + 1;
    }
    st.depth = st.markers[slot].depth;
    load_current_chunk();
    st.px = st.markers[slot].px;
    st.py = st.markers[slot].py;
    st.pz = st.markers[slot].pz;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.flash_ms = 240;
    st.flash_rgb = pack_rgb(74, 222, 128);
    set_status_msg("Warped to Marker!", 1600);
    return 1;
}

fn use_nearest() {
    // 1) Check Friend K, Rings
    var i: i32 = 0;
    var best_ring: i32 = -1;
    var best_d: f64 = 2.6;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 {
            let k = st.entities[i].kind;
            let dx = st.entities[i].x - st.px;
            let dy = st.entities[i].y - st.py;
            let dz = st.entities[i].z - st.pz;
            let d = fsqrt(dx * dx + dy * dy + dz * dz);
            if k == ENT_FRIEND_K && d < 2.6 {
                st.k_rescued = 1;
                st.entities[i].active = 0;
                add_gold(500);
                st.screen = SCREEN_VICTORY;
                return;
            }
            if k >= ENT_RING_GREEN && k <= ENT_RING_PINK && d < best_d {
                best_d = d;
                best_ring = i;
            }
        }
        i = i + 1;
    }

    // 2) Ray-probe ahead up to 2.5 units for Station / Tome / Locked Door / Shrinkable Block
    var fx: f64 = 0.0;
    var fy: f64 = 0.0;
    var fz: f64 = 0.0;
    camera_forward(fx, fy, fz);
    var t: f64 = 0.4;
    while t <= 2.6 {
        let bx = ffloor(st.px + fx * t);
        let by = ffloor(st.py + fy * t);
        let bz = ffloor(st.pz + fz * t);
        let b = get_block(bx, by, bz);
        if b == BLK_BUY_STATION { st.screen = SCREEN_BUY; return; }
        if b == BLK_SELL_STATION { st.screen = SCREEN_SELL; return; }
        if b == BLK_BLACK_MARKET { st.screen = SCREEN_BLACK_MARKET; return; }
        if b == BLK_TOME {
            let sidx = st.depth + MACRO_OFFSET;
            st.tome_id = st.stack[sidx].biome;
            st.screen = SCREEN_TOME;
            return;
        }
        if b == BLK_LOCKED_DOOR {
            if st.keys > 0 {
                st.keys = st.keys - 1;
                set_block(bx, by, bz, BLK_AIR);
                record_block_delta(bx, by, bz, BLK_AIR);
                set_status_msg("Unlocked Vault Door using 1 Key!", 1800);
            } else {
                set_status_msg("Locked Vault Door — requires a Key!", 1600);
            }
            return;
        }
        if is_block_shrinkable(b) != 0 {
            shrink_into(bx, by, bz, b, -1, 1);
            return;
        }
        t = t + 0.35;
    }

    // 3) Check nearby interactive block in 3x3x3 neighborhood
    let pbx = ffloor(st.px);
    let pby = ffloor(st.py);
    let pbz = ffloor(st.pz);
    var dz2: i32 = -2;
    while dz2 <= 2 {
        var dy2: i32 = -2;
        while dy2 <= 2 {
            var dx2: i32 = -2;
            while dx2 <= 2 {
                let nb = get_block(pbx + dx2, pby + dy2, pbz + dz2);
                if nb == BLK_BUY_STATION { st.screen = SCREEN_BUY; return; }
                if nb == BLK_SELL_STATION { st.screen = SCREEN_SELL; return; }
                if nb == BLK_BLACK_MARKET { st.screen = SCREEN_BLACK_MARKET; return; }
                if nb == BLK_TOME {
                    let sidx = st.depth + MACRO_OFFSET;
                    st.tome_id = st.stack[sidx].biome;
                    st.screen = SCREEN_TOME;
                    return;
                }
                dx2 = dx2 + 1;
            }
            dy2 = dy2 + 1;
        }
        dz2 = dz2 + 1;
    }

    if best_ring >= 0 {
        let k = st.entities[best_ring].kind;
        let rx = ffloor(st.entities[best_ring].x);
        let ry = ffloor(st.entities[best_ring].y);
        let rz = ffloor(st.entities[best_ring].z);
        let tb = st.entities[best_ring].target_block;
        let tbio = st.entities[best_ring].target_biome;
        if k == ENT_RING_RED { grow_out_axis(st.px, 16.5, st.pz); }
        else if k == ENT_RING_PINK { shrink_into(rx, ry, rz, tb, tbio, 2); }
        else { shrink_into(rx, ry, rz, tb, tbio, 1); }
        return;
    }

    set_status_msg("Nothing interactive right ahead. Aim at a Station, Tome, or Fractal Block and press [F]!", 1600);
}

fn handle_buy_action(choice: i32) {
    // Buy Station items (authentic FBW Gold economy)
    if choice == 1 && st.gold >= 15 {
        st.gold = st.gold - 15;
        st.hp = clamp_i(st.hp + 50, 0, st.max_hp);
        set_status_msg("Bought +50 HP!", 1400);
    } else if choice == 2 && st.gold >= 20 {
        st.gold = st.gold - 20;
        st.armor = clamp_i(st.armor + 50, 0, st.max_armor);
        set_status_msg("Bought +50 Armor!", 1400);
    } else if choice == 3 && st.gold >= 25 {
        st.gold = st.gold - 25;
        st.ammo[WEP_CANNON] = clamp_i(st.ammo[WEP_CANNON] + 20, 0, st.max_ammo[WEP_CANNON]);
        st.ammo[WEP_LASER] = clamp_i(st.ammo[WEP_LASER] + 30, 0, st.max_ammo[WEP_LASER]);
        st.ammo[WEP_MINIGUN] = clamp_i(st.ammo[WEP_MINIGUN] + 80, 0, st.max_ammo[WEP_MINIGUN]);
        set_status_msg("Bought Standard Munitions Pack!", 1400);
    } else if choice == 4 && st.gold >= 40 {
        st.gold = st.gold - 40;
        st.ammo[WEP_ROCKET] = clamp_i(st.ammo[WEP_ROCKET] + 10, 0, st.max_ammo[WEP_ROCKET]);
        st.ammo[WEP_HOMING] = clamp_i(st.ammo[WEP_HOMING] + 8, 0, st.max_ammo[WEP_HOMING]);
        st.ammo[WEP_RAILGUN] = clamp_i(st.ammo[WEP_RAILGUN] + 8, 0, st.max_ammo[WEP_RAILGUN]);
        st.ammo[WEP_EMP] = clamp_i(st.ammo[WEP_EMP] + 5, 0, st.max_ammo[WEP_EMP]);
        set_status_msg("Bought Heavy Ordnance Pack!", 1400);
    } else if choice == 5 && st.gold >= 60 {
        st.gold = st.gold - 60;
        st.ammo[WEP_NUKE] = clamp_i(st.ammo[WEP_NUKE] + 2, 0, st.max_ammo[WEP_NUKE]);
        st.ammo[WEP_DARKHOLE] = clamp_i(st.ammo[WEP_DARKHOLE] + 2, 0, st.max_ammo[WEP_DARKHOLE]);
        set_status_msg("Bought Nuke & Dark Hole Warheads!", 1400);
    } else if choice == 6 && st.gold >= 50 {
        st.gold = st.gold - 50;
        st.keys = st.keys + 1;
        set_status_msg("Bought 1 Vault Key!", 1400);
    }
}

fn handle_sell_action(choice: i32) {
    // Sell Station: convert excess HP / Armor / Key into Gold!
    if choice == 1 && st.hp > 25 {
        st.hp = st.hp - 25;
        add_gold(20);
        set_status_msg("Sold 25 HP for +20 Gold!", 1400);
    } else if choice == 2 && st.armor >= 25 {
        st.armor = st.armor - 25;
        add_gold(18);
        set_status_msg("Sold 25 Armor for +18 Gold!", 1400);
    } else if choice == 3 && st.ammo[WEP_MINIGUN] >= 50 {
        st.ammo[WEP_MINIGUN] = st.ammo[WEP_MINIGUN] - 50;
        add_gold(15);
        set_status_msg("Sold 50 Minigun rounds for +15 Gold!", 1400);
    } else if choice == 4 && st.keys >= 1 {
        st.keys = st.keys - 1;
        add_gold(40);
        set_status_msg("Sold 1 Vault Key for +40 Gold!", 1400);
    }
}

fn handle_black_market_action(choice: i32) {
    // Black Market: discounted high-tier Railgun, EMP, Nuke, Dark Hole!
    if choice == 1 && st.gold >= 20 {
        st.gold = st.gold - 20;
        st.ammo[WEP_RAILGUN] = clamp_i(st.ammo[WEP_RAILGUN] + 12, 0, st.max_ammo[WEP_RAILGUN]);
        set_status_msg("Black Market: +12 Railgun Slugs!", 1400);
    } else if choice == 2 && st.gold >= 18 {
        st.gold = st.gold - 18;
        st.ammo[WEP_EMP] = clamp_i(st.ammo[WEP_EMP] + 8, 0, st.max_ammo[WEP_EMP]);
        set_status_msg("Black Market: +8 EMP Charges!", 1400);
    } else if choice == 3 && st.gold >= 30 {
        st.gold = st.gold - 30;
        st.ammo[WEP_NUKE] = clamp_i(st.ammo[WEP_NUKE] + 3, 0, st.max_ammo[WEP_NUKE]);
        set_status_msg("Black Market: +3 Nukes!", 1400);
    } else if choice == 4 && st.gold >= 35 {
        st.gold = st.gold - 35;
        st.ammo[WEP_DARKHOLE] = clamp_i(st.ammo[WEP_DARKHOLE] + 3, 0, st.max_ammo[WEP_DARKHOLE]);
        set_status_msg("Black Market: +3 Dark Holes!", 1400);
    }
}

fn step_simulation(dt_ms: i32) {
    if st.screen != SCREEN_PLAY { return; }
    let dt = (dt_ms as f64) / 1000.0;

    if st.fire_cd_ms > 0 { st.fire_cd_ms = st.fire_cd_ms - dt_ms; if st.fire_cd_ms < 0 { st.fire_cd_ms = 0; } }
    if st.ring_cd_ms > 0 { st.ring_cd_ms = st.ring_cd_ms - dt_ms; if st.ring_cd_ms < 0 { st.ring_cd_ms = 0; } }
    if st.beam_timer_ms > 0 { st.beam_timer_ms = st.beam_timer_ms - dt_ms; if st.beam_timer_ms < 0 { st.beam_timer_ms = 0; } }
    if st.flash_ms > 0 { st.flash_ms = st.flash_ms - dt_ms; if st.flash_ms < 0 { st.flash_ms = 0; } }
    if st.msg_ms > 0 { st.msg_ms = st.msg_ms - dt_ms; if st.msg_ms < 0 { st.msg_ms = 0; } }
    if st.telekinesis_ms > 0 { st.telekinesis_ms = st.telekinesis_ms - dt_ms; if st.telekinesis_ms < 0 { st.telekinesis_ms = 0; } }

    // True Up smoothly levels camera roll
    if st.true_up != 0 && fabs(st.roll) > 0.001 {
        st.roll = st.roll * 0.72;
        if fabs(st.roll) < 0.01 { st.roll = 0.0; }
    }

    // Passive Health Regeneration
    if st.hp_regen > 0 && st.hp < st.max_hp {
        st.regen_accum_ms = st.regen_accum_ms + dt_ms;
        if st.regen_accum_ms >= 2000 {
            st.regen_accum_ms = st.regen_accum_ms - 2000;
            st.hp = clamp_i(st.hp + st.hp_regen, 0, st.max_hp);
        }
    }

    // 6-DOF Velocity integration & air drag (Rocket Mode vs Standard)
    let speed_sq = st.vx * st.vx + st.vy * st.vy + st.vz * st.vz;
    if speed_sq > 0.0001 {
        move_player_vec(st.vx * dt, st.vy * dt, st.vz * dt);
        let drag_rate = if st.rocket_mode != 0 { 0.85 } else { 7.2 };
        let decay = fclamp(1.0 - drag_rate * dt, 0.05, 0.99);
        st.vx = st.vx * decay;
        st.vy = st.vy * decay;
        st.vz = st.vz * decay;
    }

    // Probe block directly in front for HUD context prompt
    st.near_prompt_len = 0;
    var fx: f64 = 0.0;
    var fy: f64 = 0.0;
    var fz: f64 = 0.0;
    camera_forward(fx, fy, fz);
    var pt: f64 = 0.5;
    while pt <= 2.4 {
        let blk = get_block(ffloor(st.px + fx * pt), ffloor(st.py + fy * pt), ffloor(st.pz + fz * pt));
        if blk != BLK_AIR {
            let lbl = block_label(blk);
            if lbl.len > 0 { set_near_prompt(lbl); }
            break;
        }
        pt = pt + 0.4;
    }

    // Update entities
    st.near_ring_kind = ENT_NONE;
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active == 0 {
            i = i + 1;
            continue;
        }
        let k = st.entities[i].kind;
        if st.entities[i].freeze_ms > 0 {
            st.entities[i].freeze_ms = st.entities[i].freeze_ms - dt_ms;
            if st.entities[i].freeze_ms < 0 { st.entities[i].freeze_ms = 0; }
        }
        let dx = st.px - st.entities[i].x;
        let dy = st.py - st.entities[i].y;
        let dz = st.pz - st.entities[i].z;
        let dist = fsqrt(dx * dx + dy * dy + dz * dz);

        if k >= ENT_RING_GREEN && k <= ENT_RING_PINK {
            if dist < 2.4 { st.near_ring_kind = k; }
            if dist < 0.78 && st.ring_cd_ms <= 0 {
                let rx = ffloor(st.entities[i].x);
                let ry = ffloor(st.entities[i].y);
                let rz = ffloor(st.entities[i].z);
                let tb = st.entities[i].target_block;
                let tbio = st.entities[i].target_biome;
                if k == ENT_RING_RED { grow_out_axis(st.px, 16.5, st.pz); }
                else if k == ENT_RING_PINK { shrink_into(rx, ry, rz, tb, tbio, 2); }
                else { shrink_into(rx, ry, rz, tb, tbio, 1); }
                return;
            }
        } else if k == ENT_FRIEND_K {
            if dist < 1.15 {
                st.k_rescued = 1;
                st.entities[i].active = 0;
                add_gold(500);
                st.screen = SCREEN_VICTORY;
                return;
            }
        } else if k >= ENT_GOLD && k <= ENT_KEY {
            if dist < 1.15 {
                st.entities[i].active = 0;
                if k == ENT_GOLD {
                    let gain = 15 + (if st.depth > 0 { st.depth * 8 } else { 0 });
                    add_gold(gain);
                    set_status_msg("+Gold collected!", 900);
                } else if k == ENT_HEALTH {
                    st.hp = clamp_i(st.hp + 25, 0, st.max_hp);
                    set_status_msg("+25 Health restored!", 900);
                } else if k == ENT_ARMOR {
                    st.armor = clamp_i(st.armor + 25, 0, st.max_armor);
                    set_status_msg("+25 Armor!", 900);
                } else if k == ENT_KEY {
                    st.keys = st.keys + 1;
                    set_status_msg("+1 Vault Key collected!", 1100);
                } else if k == ENT_AMMO {
                    st.ammo[WEP_CANNON] = clamp_i(st.ammo[WEP_CANNON] + 10, 0, st.max_ammo[WEP_CANNON]);
                    st.ammo[WEP_LASER] = clamp_i(st.ammo[WEP_LASER] + 15, 0, st.max_ammo[WEP_LASER]);
                    st.ammo[WEP_ROCKET] = clamp_i(st.ammo[WEP_ROCKET] + 5, 0, st.max_ammo[WEP_ROCKET]);
                    st.ammo[WEP_HOMING] = clamp_i(st.ammo[WEP_HOMING] + 4, 0, st.max_ammo[WEP_HOMING]);
                    st.ammo[WEP_MINIGUN] = clamp_i(st.ammo[WEP_MINIGUN] + 45, 0, st.max_ammo[WEP_MINIGUN]);
                    st.ammo[WEP_RAILGUN] = clamp_i(st.ammo[WEP_RAILGUN] + 4, 0, st.max_ammo[WEP_RAILGUN]);
                    st.ammo[WEP_EMP] = clamp_i(st.ammo[WEP_EMP] + 2, 0, st.max_ammo[WEP_EMP]);
                    st.ammo[WEP_NUKE] = clamp_i(st.ammo[WEP_NUKE] + 1, 0, st.max_ammo[WEP_NUKE]);
                    st.ammo[WEP_DARKHOLE] = clamp_i(st.ammo[WEP_DARKHOLE] + 1, 0, st.max_ammo[WEP_DARKHOLE]);
                    set_status_msg("+Ammo Pack collected!", 1000);
                }
            }
        } else if k >= ENT_RAT && k <= ENT_SINGULARITY {
            if st.entities[i].freeze_ms > 0 {
                // Frozen by EMP or Laser Secondary!
                i = i + 1;
                continue;
            }
            if dist > 0.2 && dist < 13.0 {
                let spd =
                    if k == ENT_RAT { 2.8 }
                    else if k == ENT_SPIDER { 2.4 }
                    else if k == ENT_GOON { 1.8 }
                    else if k == ENT_MARINE { 1.5 }
                    else if k == ENT_PIRATE { 2.1 }
                    else if k == ENT_YINYANG { 1.6 }
                    else if k == ENT_MENACE { 0.8 }
                    else if k == ENT_DEMON { 1.9 }
                    else if k == ENT_GUARDIAN { 1.2 }
                    else { 1.45 };
                if dist > 1.35 {
                    let nx = st.entities[i].x + (dx / dist) * spd * dt;
                    let ny = st.entities[i].y + (dy / dist) * spd * 0.75 * dt;
                    let nz = st.entities[i].z + (dz / dist) * spd * dt;
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

                st.entities[i].cooldown = st.entities[i].cooldown - dt_ms;
                if st.entities[i].cooldown <= 0 {
                    if dist < 1.4 {
                        damage_player(6 + (if st.depth > 0 { st.depth * 2 } else { 0 }));
                        st.entities[i].cooldown = 850;
                    } else if dist < 11.5 && k != ENT_RAT {
                        let sspd = if k == ENT_SINGULARITY { 9.5 } else { 7.5 };
                        let edmg = 6 + (if st.depth > 0 { st.depth * 2 } else { 0 }) + (if k == ENT_SINGULARITY { 10 } else { 0 });
                        let ergb = if k == ENT_SINGULARITY { pack_rgb(255, 64, 210) } else { pack_rgb(255, 92, 64) };
                        spawn_shot(0, 0, 0, st.entities[i].x, st.entities[i].y, st.entities[i].z,
                            (dx / dist) * sspd, (dy / dist) * sspd, (dz / dist) * sspd, edmg, 1750, ergb);
                        st.entities[i].cooldown = if k == ENT_SINGULARITY { 650 } else if k == ENT_MENACE { 1100 } else { 1550 };
                    }
                }
            }
        }
        i = i + 1;
    }

    // Update projectiles (including Homing steering & Dark Hole gravity pull!)
    i = 0;
    while i < MAX_SHOTS {
        if st.shots[i].active == 0 {
            i = i + 1;
            continue;
        }
        st.shots[i].ttl_ms = st.shots[i].ttl_ms - dt_ms;

        // Homing guidance for WEP_HOMING
        if st.shots[i].from_player != 0 && st.shots[i].wep == WEP_HOMING {
            var best_e: i32 = -1;
            var best_ed: f64 = 12.0;
            var ei: i32 = 0;
            while ei < MAX_ENTITIES {
                if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_RAT && st.entities[ei].kind <= ENT_SINGULARITY {
                    let hx = st.entities[ei].x - st.shots[i].x;
                    let hy = st.entities[ei].y - st.shots[i].y;
                    let hz = st.entities[ei].z - st.shots[i].z;
                    let hd = fsqrt(hx * hx + hy * hy + hz * hz);
                    if hd < best_ed { best_ed = hd; best_e = ei; }
                }
                ei = ei + 1;
            }
            if best_e >= 0 && best_ed > 0.1 {
                let tx = ((st.entities[best_e].x - st.shots[i].x) / best_ed) * 12.0;
                let ty = ((st.entities[best_e].y - st.shots[i].y) / best_ed) * 12.0;
                let tz = ((st.entities[best_e].z - st.shots[i].z) / best_ed) * 12.0;
                st.shots[i].vx = st.shots[i].vx * 0.82 + tx * 0.18;
                st.shots[i].vy = st.shots[i].vy * 0.82 + ty * 0.18;
                st.shots[i].vz = st.shots[i].vz * 0.82 + tz * 0.18;
            }
        }

        if st.shots[i].ttl_ms <= 0 {
            if st.shots[i].from_player != 0 {
                let sw = st.shots[i].wep;
                if sw == WEP_ROCKET || sw == WEP_HOMING || sw == WEP_EMP || sw == WEP_NUKE || sw == WEP_DARKHOLE {
                    let rad = if sw == WEP_NUKE { 5.2 } else if sw == WEP_DARKHOLE { if st.quasar_drive != 0 { 6.2 } else { 4.5 } } else if sw == WEP_EMP { 4.2 } else { 2.6 };
                    let stun: i32 = if sw == WEP_EMP { 4500 } else { 0 };
                    let pull: i32 = if sw == WEP_DARKHOLE { 1 } else { 0 };
                    explosion_at(st.shots[i].x, st.shots[i].y, st.shots[i].z, rad, st.shots[i].dmg, stun, pull, st.shots[i].rgb);
                }
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
                let sw = st.shots[i].wep;
                if sw == WEP_ROCKET || sw == WEP_HOMING || sw == WEP_EMP || sw == WEP_NUKE || sw == WEP_DARKHOLE {
                    let rad = if sw == WEP_NUKE { 5.2 } else if sw == WEP_DARKHOLE { if st.quasar_drive != 0 { 6.2 } else { 4.5 } } else if sw == WEP_EMP { 4.2 } else { 2.6 };
                    let stun: i32 = if sw == WEP_EMP { 4500 } else { 0 };
                    let pull: i32 = if sw == WEP_DARKHOLE { 1 } else { 0 };
                    explosion_at(nx, ny, nz, rad, st.shots[i].dmg, stun, pull, st.shots[i].rgb);
                } else {
                    spawn_burst(nx, ny, nz, st.shots[i].rgb, 5);
                    if is_block_destructible(blk) != 0 { break_block_at(bx, by, bz); }
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
                if st.entities[ei].active != 0 && st.entities[ei].kind >= ENT_RAT && st.entities[ei].kind <= ENT_SINGULARITY {
                    let ex = st.entities[ei].x - nx;
                    let ey = st.entities[ei].y - ny;
                    let ez = st.entities[ei].z - nz;
                    if (ex * ex + ey * ey + ez * ez) < 0.45 {
                        let sw = st.shots[i].wep;
                        if sw == WEP_ROCKET || sw == WEP_HOMING || sw == WEP_EMP || sw == WEP_NUKE || sw == WEP_DARKHOLE {
                            let rad = if sw == WEP_NUKE { 5.2 } else if sw == WEP_DARKHOLE { if st.quasar_drive != 0 { 6.2 } else { 4.5 } } else if sw == WEP_EMP { 4.2 } else { 2.6 };
                            let stun: i32 = if sw == WEP_EMP { 4500 } else { 0 };
                            let pull: i32 = if sw == WEP_DARKHOLE { 1 } else { 0 };
                            explosion_at(nx, ny, nz, rad, st.shots[i].dmg, stun, pull, st.shots[i].rgb);
                        } else {
                            damage_entity(ei, st.shots[i].dmg, 0);
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
            if (ex * ex + ey * ey + ez * ez) < 0.38 {
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
