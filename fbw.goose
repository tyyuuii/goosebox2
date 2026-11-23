// fbw.goose — Faithful Terminal Frontend for Fractal Block World (Xar)
// Uses termbox2.goose + fbw_core.goose with 24-bit Truecolor half-block (▀)
// 3D DDA raycasting, Camera Roll (Q/E + True Up), 10 Weapons (Primary/Secondary),
// 6-face Grow + Fractal Shrink portals, Stations, Markers, and F1-F5 Xar overlays.
//
// Build:  goose build fbw.goose -o fbw
// Run:    ./fbw

import termbox2;
import fbw_core;

extern fn tb_adapter_now_ms() -> i64 = "tb_adapter_now_ms";

const CH_HALF_TOP: u32 = 0x2580; // ▀
const CH_BLOCK: u32 = 0x2588;    // █

const MAX_PW: i32 = 240;
const MAX_PH: i32 = 140;

// ---------------------------------------------------------------------------
// Color Helpers (Truecolor & 256-Color Fallback)
// ---------------------------------------------------------------------------
fn rgb_to_attr(rgb: u32) -> uintattr_t {
    let st = core();
    if st.truecolor != 0 {
        return (rgb as uintattr_t) | TB_HI_BLACK;
    }
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
fn ui_muted() -> uintattr_t { return rgb_to_attr(pack_rgb(156, 163, 184)); }
fn ui_yellow() -> uintattr_t { return rgb_to_attr(pack_rgb(250, 204, 21)); }
fn ui_green() -> uintattr_t { return rgb_to_attr(pack_rgb(74, 222, 128)); }
fn ui_cyan() -> uintattr_t { return rgb_to_attr(pack_rgb(56, 189, 248)); }
fn ui_red() -> uintattr_t { return rgb_to_attr(pack_rgb(248, 113, 113)); }
fn ui_magenta() -> uintattr_t { return rgb_to_attr(pack_rgb(232, 121, 249)); }
fn ui_orange() -> uintattr_t { return rgb_to_attr(pack_rgb(251, 146, 60)); }
fn ui_bg() -> uintattr_t { return rgb_to_attr(pack_rgb(10, 14, 24)); }
fn ui_panel_bg() -> uintattr_t { return rgb_to_attr(pack_rgb(16, 22, 36)); }
fn ui_blue_bg() -> uintattr_t { return rgb_to_attr(pack_rgb(37, 99, 235)); }

// ---------------------------------------------------------------------------
// Text Buffer & Box Drawing Helpers
// ---------------------------------------------------------------------------
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
    let st = core();
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
// Biome Skies & Signature FBW Fractal Block Shading
// ---------------------------------------------------------------------------
fn biome_sky_top(biome: i32) -> u32 {
    if biome == BIOME_SPACE { return pack_rgb(2, 4, 14); }
    if biome == BIOME_TUTORIAL { return pack_rgb(18, 56, 128); }
    if biome == BIOME_YING_FOREST { return pack_rgb(24, 92, 168); }
    if biome == BIOME_WHITE_FLOWER { return pack_rgb(142, 168, 212); }
    if biome == BIOME_YELLOW_FLOWER { return pack_rgb(84, 58, 12); }
    if biome == BIOME_MYLANTIS { return pack_rgb(10, 48, 64); }
    if biome == BIOME_BLACK_CUBE { return pack_rgb(10, 8, 22); }
    return pack_rgb(38, 6, 42);
}

fn biome_sky_bot(biome: i32) -> u32 {
    if biome == BIOME_SPACE { return pack_rgb(8, 10, 32); }
    if biome == BIOME_TUTORIAL { return pack_rgb(68, 138, 212); }
    if biome == BIOME_YING_FOREST { return pack_rgb(88, 184, 210); }
    if biome == BIOME_WHITE_FLOWER { return pack_rgb(218, 228, 248); }
    if biome == BIOME_YELLOW_FLOWER { return pack_rgb(176, 132, 28); }
    if biome == BIOME_MYLANTIS { return pack_rgb(24, 102, 118); }
    if biome == BIOME_BLACK_CUBE { return pack_rgb(38, 22, 68); }
    return pack_rgb(112, 18, 86);
}

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

    let edge = if u < 0.06 || u > 0.94 || v < 0.06 || v > 0.94 { 1 } else { 0 };
    var detail: f64 = 1.0;

    if edge != 0 {
        detail = if is_block_shrinkable(blk) != 0 || is_block_upgrade(blk) != 0 { 1.35 } else { 0.62 };
    } else if is_block_shrinkable(blk) != 0 {
        // Concentric fractal portal rings inside shrinkable blocks
        let du = fabs(u - 0.5);
        let dv = fabs(v - 0.5);
        let ring = if du > dv { du } else { dv };
        if ring < 0.14 { detail = 0.42; }
        else if ring < 0.24 { detail = 1.38; }
        else if ring < 0.34 { detail = 0.68; }
        else { detail = 1.10; }
    } else if blk == BLK_CRATE {
        let diag = fabs(u - v);
        if diag < 0.10 { detail = 1.30; }
    } else if blk == BLK_BUY_STATION || blk == BLK_SELL_STATION || blk == BLK_BLACK_MARKET {
        if u > 0.18 && u < 0.82 && v > 0.18 && v < 0.82 { detail = 1.32; }
        else { detail = 0.75; }
    } else if is_block_upgrade(blk) != 0 {
        if (fabs(u - 0.5) < 0.12 && v > 0.22 && v < 0.78) || (fabs(v - 0.5) < 0.12 && u > 0.22 && u < 0.78) {
            detail = 1.48;
        }
    }

    var shaded = scale_rgb(base, face_mul * detail);

    if blk == BLK_BLACK_CUBE {
        if edge != 0 { shaded = pack_rgb(148, 102, 255); }
        else {
            let du = fabs(u - 0.5);
            let dv = fabs(v - 0.5);
            let ring = if du > dv { du } else { dv };
            if ring > 0.22 && ring < 0.28 { shaded = pack_rgb(92, 62, 188); }
        }
    } else if blk == BLK_MYLANTIS_M {
        // Iconic 'M' glyph on Mylantis planet block
        let gx = ffloor(u * 7.0);
        let gy = ffloor((1.0 - v) * 7.0);
        let is_m =
            if (gx == 1 || gx == 5) && gy >= 1 && gy <= 5 { 1 }
            else if (gx == 2 || gx == 4) && gy == 2 { 1 }
            else if gx == 3 && gy == 3 { 1 }
            else { 0 };
        if is_m != 0 { shaded = pack_rgb(255, 245, 190); }
    } else if blk == BLK_CORE_GATE && edge != 0 {
        shaded = pack_rgb(255, 118, 224);
    } else if blk == BLK_SPAWNER && ((ffloor(u * 4.0) + ffloor(v * 4.0)) & 1) != 0 {
        shaded = pack_rgb(255, 84, 118);
    } else if blk == BLK_LOCKED_DOOR {
        let du = fabs(u - 0.5);
        let dv = fabs(v - 0.5);
        if du < 0.14 && dv < 0.22 { shaded = pack_rgb(36, 28, 18); }
    } else if blk == BLK_TOME && u > 0.25 && u < 0.75 && v > 0.2 && v < 0.8 {
        shaded = pack_rgb(255, 248, 210);
    }

    let fog = fclamp((dist - 5.0) / 22.0, 0.0, 0.78);
    return lerp_rgb(shaded, sky, fog);
}

// ---------------------------------------------------------------------------
// 3D Camera Basis (Yaw, Pitch, Roll) & DDA Raycaster
// ---------------------------------------------------------------------------
fn draw_pixel_safe(x: i32, y: i32, z: f64, rgb: u32) {
    let st = core();
    if x < 0 || x >= st.pw || y < 0 || y >= st.ph { return; }
    let idx = y * st.pw + x;
    if z < st.fb_z[idx] {
        st.fb_z[idx] = z;
        st.fb_rgb[idx] = rgb;
    }
}

fn render_3d_world() {
    let st = core();
    let pw = st.pw;
    let ph = st.ph;
    if pw <= 0 || ph <= 0 { return; }

    let sidx = st.depth + MACRO_OFFSET;
    let biome = st.stack[sidx].biome;
    let sky_top = biome_sky_top(biome);
    let sky_bot = biome_sky_bot(biome);

    // Camera orthonormal basis with Yaw, Pitch, and Q/E Roll!
    let cp = fcos(st.pitch);
    let sp = fsin(st.pitch);
    let cy = fcos(st.yaw);
    let sy = fsin(st.yaw);
    let cr = fcos(st.roll);
    let sr = fsin(st.roll);

    let fx = cp * cy;
    let fy = sp;
    let fz = cp * sy;

    let rx0 = -sy;
    let ry0 = 0.0;
    let rz0 = cy;

    let ux0 = -sp * cy;
    let uy0 = cp;
    let uz0 = -sp * sy;

    let rx = rx0 * cr + ux0 * sr;
    let ry = ry0 * cr + uy0 * sr;
    let rz = rz0 * cr + uz0 * sr;

    let ux = ux0 * cr - rx0 * sr;
    let uy = uy0 * cr - ry0 * sr;
    let uz = uz0 * cr - rz0 * sr;

    let aspect = (pw as f64) / ph;
    let fov_scale: f64 = 0.74;

    let start_bx = ffloor(st.px);
    let start_by = ffloor(st.py);
    let start_bz = ffloor(st.pz);
    let open_void = if biome == BIOME_SPACE || biome == BIOME_TUTORIAL { 1 } else { 0 };

    st.target_name_len = 0;

    // 1) Raycast 16x16x16 chunk
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
            while step_i < 30 {
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
                    if map_y < 0 && open_void == 0 {
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
                var sky_col = row_sky;
                if biome == BIOME_SPACE || biome == BIOME_BLACK_CUBE || biome == BIOME_INNER_CORE || biome == BIOME_TUTORIAL {
                    let sh = splitmix64(((px as u64) * 73856093) ^ ((py as u64) * 19349663));
                    if (sh % 113) == 0 && (biome == BIOME_SPACE || py < (ph * 2) / 3) {
                        sky_col = pack_rgb(235, 242, 255);
                    }
                }
                st.fb_rgb[pidx] = sky_col;
                st.fb_z[pidx] = 32.0;
            }
            px = px + 1;
        }
        py = py + 1;
    }

    // 2) Hitscan laser / railgun beam
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

    // 3) Billboard Entities (Rings, Xar Monster Manual Enemies, Pickups, Friend K)
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

        let cdx = fabs(sx_f - pw * 0.5);
        let cdy = fabs(sy_f - ph * 0.5);
        if cdx < 6.0 && cdy < 6.0 && depth_z < best_cross_d {
            best_cross_d = depth_z;
            if k == ENT_RING_GREEN { set_target_name("Green Shrink Ring (16x)", 0, 0); }
            else if k == ENT_RING_RED { set_target_name("Red Grow Ring (1/16x)", 0, 0); }
            else if k == ENT_RING_BLUE { set_target_name("Blue Mylantis Warp Ring", 0, 0); }
            else if k == ENT_RING_PINK { set_target_name("Pink Deep Dive Ring (256x)", 0, 0); }
            else if k == ENT_RAT { set_target_name("Rat", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_SPIDER { set_target_name("Spider", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_GOON { set_target_name("Goon", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_MARINE { set_target_name("Marine", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_PIRATE { set_target_name("Pirate", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_YINYANG { set_target_name("Yin Yang", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_MENACE { set_target_name("Menace", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_DEMON { set_target_name("Demon", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_GUARDIAN {
                set_target_name(
                    if st.entities[ei].freeze_ms > 0 { "Guardian [FROZEN]" } else { "Guardian (Pool Ball)" },
                    st.entities[ei].hp, st.entities[ei].max_hp);
            }
            else if k == ENT_SINGULARITY { set_target_name("THE SINGULARITY", st.entities[ei].hp, st.entities[ei].max_hp); }
            else if k == ENT_FRIEND_K { set_target_name("Friend 'K' [F to Rescue!]", 0, 0); }
        }

        let is_ring = if k >= ENT_RING_GREEN && k <= ENT_RING_PINK { 1 } else { 0 };
        let world_rad =
            if is_ring != 0 { 0.58 }
            else if k == ENT_SINGULARITY { 0.80 }
            else if k == ENT_GUARDIAN || k == ENT_DEMON { 0.54 }
            else if k >= ENT_GOLD { 0.24 }
            else { 0.38 };
        var pix_rad = ((world_rad / (depth_z * fov_scale)) * 0.5 * ph) as! i32;
        if pix_rad < 2 { pix_rad = 2; }
        if pix_rad > 28 { pix_rad = 28; }

        var col: u32 =
            if k == ENT_RING_GREEN { scale_rgb(pack_rgb(48, 255, 118), pulse) }
            else if k == ENT_RING_RED { scale_rgb(pack_rgb(255, 62, 62), pulse) }
            else if k == ENT_RING_BLUE { scale_rgb(pack_rgb(64, 168, 255), pulse) }
            else if k == ENT_RING_PINK { scale_rgb(pack_rgb(255, 92, 224), pulse) }
            else if k == ENT_RAT { pack_rgb(168, 132, 92) }
            else if k == ENT_SPIDER { pack_rgb(112, 42, 138) }
            else if k == ENT_GOON { pack_rgb(98, 220, 74) }
            else if k == ENT_MARINE { pack_rgb(64, 152, 240) }
            else if k == ENT_PIRATE { pack_rgb(234, 88, 62) }
            else if k == ENT_YINYANG { pack_rgb(235, 240, 250) }
            else if k == ENT_MENACE { pack_rgb(245, 158, 11) }
            else if k == ENT_DEMON { pack_rgb(210, 32, 68) }
            else if k == ENT_GUARDIAN { pack_rgb(250, 204, 21) }
            else if k == ENT_SINGULARITY { scale_rgb(pack_rgb(244, 63, 184), pulse) }
            else if k == ENT_GOLD { pack_rgb(255, 215, 42) }
            else if k == ENT_HEALTH { pack_rgb(248, 72, 92) }
            else if k == ENT_ARMOR { pack_rgb(72, 196, 255) }
            else if k == ENT_AMMO { pack_rgb(255, 168, 56) }
            else if k == ENT_KEY { pack_rgb(253, 224, 71) }
            else { scale_rgb(pack_rgb(255, 248, 128), pulse) };

        if st.entities[ei].freeze_ms > 0 && k >= ENT_RAT && k <= ENT_SINGULARITY {
            col = lerp_rgb(col, pack_rgb(96, 240, 255), 0.65);
        }

        var dy: i32 = -pix_rad;
        while dy <= pix_rad {
            var dx: i32 = -pix_rad;
            while dx <= pix_rad {
                let d2 = dx * dx + dy * dy;
                let r2 = pix_rad * pix_rad;
                if is_ring != 0 {
                    let inner = (pix_rad * 58) / 100;
                    if d2 <= r2 && d2 >= inner * inner {
                        draw_pixel_safe(scx + dx, scy + dy, depth_z, col);
                    }
                } else if d2 <= r2 {
                    var px_col = col;
                    if k == ENT_YINYANG && dx < 0 { px_col = pack_rgb(28, 30, 42); }
                    if k >= ENT_RAT && k <= ENT_SINGULARITY && dy == -(pix_rad / 4) && (dx == -(pix_rad / 3) || dx == (pix_rad / 3)) {
                        px_col = if st.entities[ei].freeze_ms > 0 { pack_rgb(186, 250, 255) } else { pack_rgb(255, 36, 48) };
                    }
                    draw_pixel_safe(scx + dx, scy + dy, depth_z, px_col);
                }
                dx = dx + 1;
            }
            dy = dy + 1;
        }
        ei = ei + 1;
    }

    // 4) Projectiles & Particles
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

    // 5) Flash / Telekinesis tint
    if st.flash_ms > 0 {
        let amt = fclamp(st.flash_ms / 460.0, 0.0, 0.42);
        var k: i32 = 0;
        let tot = pw * ph;
        while k < tot {
            st.fb_rgb[k] = lerp_rgb(st.fb_rgb[k], st.flash_rgb, amt);
            k = k + 1;
        }
    }

    // 6) Half-block (▀) blit
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
        let ch_col = if st.target_name_len > 0 { ui_yellow() | TB_BOLD } else { ui_white() | TB_BOLD };
        let _ = tb_set_cell(ch_x, ch_y, '+', ch_col, cur_c.bg);
    }
}

// ---------------------------------------------------------------------------
// Minimap & Authentic FBW Bottom HUD
// ---------------------------------------------------------------------------
fn draw_minimap_overlay() {
    let st = core();
    let view_rows = st.ph / 2;
    if st.term_w < 44 || view_rows < 20 { return; }
    let mx = st.term_w - 19;
    let my: i32 = 1;
    draw_rect(mx, my, 18, 18, ui_cyan() | TB_BOLD, ui_bg());
    let _ = tb_print(mx + 2, my, ui_cyan() | TB_BOLD, ui_bg(), " CHUNK & STACK ");

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
                col =
                    if is_block_shrinkable(b) != 0 { ui_magenta() }
                    else if is_block_upgrade(b) != 0 { ui_yellow() }
                    else if b == BLK_BUY_STATION || b == BLK_SELL_STATION || b == BLK_BLACK_MARKET { ui_cyan() }
                    else if b == BLK_SPAWNER { ui_red() }
                    else { ui_green() };
            }
            let _ = tb_set_cell(mx + 1 + x, my + 1 + z, ch, col, ui_bg());
            x = x + 1;
        }
        z = z + 1;
    }

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
            else if k == ENT_FRIEND_K { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, 'K', ui_yellow() | TB_BOLD, ui_bg()); }
            else if k >= ENT_RAT && k <= ENT_SINGULARITY { let _ = tb_set_cell(mx + 1 + ex, my + 1 + ez, '!', ui_red() | TB_BOLD, ui_bg()); }
        }
        i = i + 1;
    }

    let px_i = clamp_i(ffloor(st.px), 0, 15);
    let pz_i = clamp_i(ffloor(st.pz), 0, 15);
    let _ = tb_set_cell(mx + 1 + px_i, my + 1 + pz_i, '@', ui_white() | TB_BOLD, ui_blue_bg());

    var buf: u8[160] = [0; 160];
    var len: i32 = 0;
    buf_put_str(buf, len, " LVL:");
    buf_put_int(buf, len, st.depth);
    buf_put_str(buf, len, " [");
    buf_put_int(buf, len, st.min_depth_reached);
    buf_put_str(buf, len, "..");
    buf_put_int(buf, len, st.max_depth_reached);
    buf_put_str(buf, len, "] ");
    let _ = tb_print(mx + 1, my + 17, ui_white() | TB_BOLD, ui_bg(), buf[0..len]);
}

fn weapon_short_tag(w: i32) -> const u8[:] {
    let st = core();
    if w == WEP_PLASMA { return "1:Pls"; }
    if w == WEP_CANNON { return "2:Can"; }
    if w == WEP_LASER { return "3:Las"; }
    if w == WEP_ROCKET { return "4:Rkt"; }
    if w == WEP_HOMING { return "5:Hom"; }
    if w == WEP_MINIGUN { return "6:Min"; }
    if w == WEP_RAILGUN { return "7:Ral"; }
    if w == WEP_EMP { return "8:EMP"; }
    if w == WEP_NUKE { return "9:Nuk"; }
    if st.quasar_drive != 0 { return "0:Qsr"; }
    return "0:Drk";
}

fn draw_hud() {
    let st = core();
    let w = st.term_w;
    let h = st.term_h;
    if h < 4 || w < 20 { return; }

    let hud_y = h - 3;
    var y: i32 = hud_y;
    while y < h {
        var x: i32 = 0;
        while x < w {
            let _ = tb_set_cell(x, y, ' ', ui_white(), ui_bg());
            x = x + 1;
        }
        y = y + 1;
    }

    // Row 1: Context / Ring / Target / Marker / Help Hint
    if st.near_ring_kind != ENT_NONE {
        let rmsg =
            if st.near_ring_kind == ENT_RING_GREEN { "[F] Green Shrink Ring -> Dive 16x deeper" }
            else if st.near_ring_kind == ENT_RING_RED { "[F] Red Grow Ring -> Ascend 16x outward" }
            else if st.near_ring_kind == ENT_RING_BLUE { "[F] Blue Ring -> Mylantis Portal" }
            else { "[F] Pink Deep Ring -> Dive 256x deeper!" };
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
    } else if st.near_prompt_len > 0 {
        let _ = tb_print(1, hud_y, ui_green() | TB_BOLD, ui_bg(), st.near_prompt[0..st.near_prompt_len]);
    } else {
        let hint = if w >= 98 {
            "WASD/Space/C:Fly | Q/E:Roll U:TrueUp | Tab:Rocket X:Brake | F:Use T:TK | R/RMB:2ndFire | F1-F5:Info"
        } else {
            "WASD/Spc/C:Fly Q/E:Roll Tab:Rkt F:Use R:2ndFire G:Map F1-F5:Info"
        };
        let _ = tb_print(1, hud_y, ui_muted(), ui_bg(), hint);
    }

    // Row 2: HP (+Regen), Armor, Gold, Keys, Depth, Biome, Coords, Active Marker
    var sbuf: u8[160] = [0; 160];
    var slen: i32 = 0;
    buf_put_str(sbuf, slen, "HP:");
    buf_put_int(sbuf, slen, st.hp);
    buf_put_ch(sbuf, slen, '/');
    buf_put_int(sbuf, slen, st.max_hp);
    buf_put_str(sbuf, slen, "(+");
    buf_put_int(sbuf, slen, st.hp_regen);
    buf_put_str(sbuf, slen, ") ARM:");
    buf_put_int(sbuf, slen, st.armor);
    buf_put_ch(sbuf, slen, '/');
    buf_put_int(sbuf, slen, st.max_armor);
    buf_put_str(sbuf, slen, " GOLD:");
    buf_put_int(sbuf, slen, st.gold);
    buf_put_str(sbuf, slen, " KEY:");
    buf_put_int(sbuf, slen, st.keys);
    buf_put_str(sbuf, slen, " | LVL:");
    buf_put_int(sbuf, slen, st.depth);
    buf_put_str(sbuf, slen, " [");
    let sidx = st.depth + MACRO_OFFSET;
    buf_put_str(sbuf, slen, biome_name(st.stack[sidx].biome));
    buf_put_str(sbuf, slen, "] (");
    buf_put_int(sbuf, slen, ffloor(st.px));
    buf_put_ch(sbuf, slen, ',');
    buf_put_int(sbuf, slen, ffloor(st.py));
    buf_put_ch(sbuf, slen, ',');
    buf_put_int(sbuf, slen, ffloor(st.pz));
    buf_put_ch(sbuf, slen, ')');
    if st.rocket_mode != 0 { buf_put_str(sbuf, slen, " RKT"); }
    if st.true_up == 0 { buf_put_str(sbuf, slen, " FREE-ROLL"); }
    if st.k_rescued != 0 { buf_put_str(sbuf, slen, " K:OK"); }
    let hp_col = if st.hp <= 25 { ui_red() | TB_BOLD } else { ui_white() | TB_BOLD };
    let _ = tb_print(1, hud_y + 1, hp_col, ui_bg(), sbuf[0..slen]);

    // Row 3: 10-Weapon Strip + Active Ammo + Marker + FPS
    var cx: i32 = 1;
    var wi: i32 = 0;
    while wi < NUM_WEAPONS && cx + 8 < w {
        let tag = weapon_short_tag(wi);
        let is_cur = if wi == st.weapon { 1 } else { 0 };
        let has_ammo = if wi == WEP_PLASMA || st.ammo[wi] > 0 { 1 } else { 0 };
        let fg: uintattr_t =
            if is_cur != 0 { ui_bg() | TB_BOLD }
            else if has_ammo != 0 { ui_white() }
            else { ui_muted() };
        let bg: uintattr_t = if is_cur != 0 { ui_green() } else { ui_bg() };
        let _ = tb_print(cx, hud_y + 2, fg, bg, tag);
        cx = cx + (tag.len as! i32) + 1;
        wi = wi + 1;
    }

    var abuf: u8[160] = [0; 160];
    var alen: i32 = 0;
    buf_put_str(abuf, alen, "| Ammo:");
    if st.weapon == WEP_PLASMA { buf_put_str(abuf, alen, "INF"); }
    else {
        buf_put_int(abuf, alen, st.ammo[st.weapon]);
        buf_put_ch(abuf, alen, '/');
        buf_put_int(abuf, alen, st.max_ammo[st.weapon]);
    }
    if st.active_marker >= 0 && st.markers[st.active_marker].used != 0 {
        buf_put_str(abuf, alen, " M");
        buf_put_int(abuf, alen, st.active_marker);
        buf_put_str(abuf, alen, ":L");
        buf_put_int(abuf, alen, st.markers[st.active_marker].depth);
    }
    if st.fps > 0 {
        buf_put_str(abuf, alen, " FPS:");
        buf_put_int(abuf, alen, st.fps);
    }
    if cx + 4 < w {
        let _ = tb_print(cx, hud_y + 2, ui_yellow() | TB_BOLD, ui_bg(), abuf[0..alen]);
    }
}

// ---------------------------------------------------------------------------
// Authentic Xar Modals: Title, Buy/Sell/Black Market, Tome, F1-F5, Pause, Victory
// ---------------------------------------------------------------------------
fn draw_title_screen() {
    let st = core();
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

    let mw = if w >= 72 { 70 } else { w - 2 };
    let mh = if h >= 22 { 21 } else { h - 2 };
    let cx = (w - mw) / 2;
    let cy = (h - mh) / 2;
    draw_rect(cx, cy, mw, mh, ui_cyan() | TB_BOLD, ui_panel_bg());

    let _ = tb_print(cx + 3, cy + 2, ui_yellow() | TB_BOLD, ui_panel_bg(), "FRACTAL BLOCK WORLD (XAR) — TERMINAL EDITION");
    let _ = tb_print(cx + 3, cy + 3, ui_green(), ui_panel_bg(),           "16x16x16 Recursive Fractal World (termbox2.goose)");
    let _ = tb_print(cx + 3, cy + 5, ui_white(), ui_panel_bg(),           "Start in the Tutorial Room: fly into the Black Cube to");
    let _ = tb_print(cx + 3, cy + 6, ui_white(), ui_panel_bg(),           "shrink into Ying Forest, or exit any of the 6 chunk");
    let _ = tb_print(cx + 3, cy + 7, ui_white(), ui_panel_bg(),           "faces to grow 16x outward into Outer Space & Mylantis!");
    let _ = tb_print(cx + 3, cy + 8, ui_magenta(), ui_panel_bg(),         "Explore Small White/Yellow Flowers, I2 & Core to rescue K.");

    let _ = tb_print(cx + 3, cy + 10, ui_cyan() | TB_BOLD, ui_panel_bg(), "WASD / Space / C(Z): 6-DOF Flight | Q/E: Roll | U: TrueUp");
    let _ = tb_print(cx + 3, cy + 11, ui_white(), ui_panel_bg(),          "Arrows/IJKL/Mouse: Aim | LMB/Enter: Fire | R/RMB: 2nd Fire");
    let _ = tb_print(cx + 3, cy + 12, ui_white(), ui_panel_bg(),          "1-9,0: 10 Weapons (Recoil Boost!) | Tab: Rocket | X: Brake");
    let _ = tb_print(cx + 3, cy + 13, ui_white(), ui_panel_bg(),          "F: Use Station/Tome/Key | T: Telekinesis | M/N: Markers");
    let _ = tb_print(cx + 3, cy + 14, ui_white(), ui_panel_bg(),          "F1-F5: Controls/Stats/Weapons/Markers/Lore | P/Esc: Pause");

    let _ = tb_print(cx + 3, cy + 17, ui_green() | TB_BOLD, ui_panel_bg(), ">>> Press [ENTER] or [SPACE] to Enter Xar  ([Q] Quit) <<<");
    let _ = tb_present();
}

fn draw_buy_modal() {
    let st = core();
    let mw = if st.term_w >= 62 { 60 } else { st.term_w - 4 };
    let mh: i32 = 15;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_green() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_green() | TB_BOLD, ui_panel_bg(), "XAR BUY STATION — GOLD EXCHANGE");

    var gbuf: u8[160] = [0; 160];
    var glen: i32 = 0;
    buf_put_str(gbuf, glen, "Gold: ");
    buf_put_int(gbuf, glen, st.gold);
    buf_put_str(gbuf, glen, " / 1,000,000");
    let _ = tb_print(mx + 2, my + 2, ui_yellow() | TB_BOLD, ui_panel_bg(), gbuf[0..glen]);

    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "[1] +50 HP Restore              (15 Gold)");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "[2] +50 Armor Plating           (20 Gold)");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "[3] Standard Munitions Pack     (25 Gold)");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "[4] Heavy Ordnance (Rkt/Rail)   (40 Gold)");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_panel_bg(), "[5] +2 Nuke & +2 Dark Hole      (60 Gold)");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_panel_bg(), "[6] Vault Key                   (50 Gold)");
    let _ = tb_print(mx + 2, my + 12, ui_cyan() | TB_BOLD, ui_panel_bg(), "Press [1-6] to purchase, [F] or [ESC] to close");
}

fn draw_sell_modal() {
    let st = core();
    let mw = if st.term_w >= 60 { 58 } else { st.term_w - 4 };
    let mh: i32 = 13;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_cyan() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_cyan() | TB_BOLD, ui_panel_bg(), "XAR SELL STATION — LIQUIDATE SURPLUS");

    var gbuf: u8[160] = [0; 160];
    var glen: i32 = 0;
    buf_put_str(gbuf, glen, "Gold: ");
    buf_put_int(gbuf, glen, st.gold);
    buf_put_str(gbuf, glen, " | HP: ");
    buf_put_int(gbuf, glen, st.hp);
    buf_put_str(gbuf, glen, " | ARM: ");
    buf_put_int(gbuf, glen, st.armor);
    let _ = tb_print(mx + 2, my + 2, ui_yellow() | TB_BOLD, ui_panel_bg(), gbuf[0..glen]);

    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "[1] Sell 25 HP             -> +20 Gold");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "[2] Sell 25 Armor          -> +18 Gold");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "[3] Sell 50 Minigun Rounds -> +15 Gold");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "[4] Sell 1 Vault Key       -> +40 Gold");
    let _ = tb_print(mx + 2, my + 10, ui_cyan() | TB_BOLD, ui_panel_bg(), "Press [1-4] to sell, [F] or [ESC] to close");
}

fn draw_black_market_modal() {
    let st = core();
    let mw = if st.term_w >= 62 { 60 } else { st.term_w - 4 };
    let mh: i32 = 13;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_magenta() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_magenta() | TB_BOLD, ui_panel_bg(), "MYLANTIS BLACK MARKET — DISCOUNT HIGH-TIER ORDNANCE");

    var gbuf: u8[160] = [0; 160];
    var glen: i32 = 0;
    buf_put_str(gbuf, glen, "Gold: ");
    buf_put_int(gbuf, glen, st.gold);
    let _ = tb_print(mx + 2, my + 2, ui_yellow() | TB_BOLD, ui_panel_bg(), gbuf[0..glen]);

    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "[1] +12 Railgun Slugs      (20 Gold)");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "[2] +8  EMP Freeze Charges (18 Gold)");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "[3] +3  Nuke Warheads      (30 Gold)");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "[4] +3  Dark Hole Cores    (35 Gold)");
    let _ = tb_print(mx + 2, my + 10, ui_cyan() | TB_BOLD, ui_panel_bg(), "Press [1-4] to buy, [F] or [ESC] to close");
}

fn draw_tome_modal() {
    let st = core();
    let mw = if st.term_w >= 66 { 64 } else { st.term_w - 4 };
    let mh: i32 = 14;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_yellow() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_yellow() | TB_BOLD, ui_panel_bg(), "XAR TOME — ARCHIVE INSCRIPTION");

    if st.tome_id == BIOME_TUTORIAL {
        let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "Every block in Xar holds a 16x16x16 universe inside it.");
        let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "Fly straight into the Tutorial Black Cube to enter the");
        let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "Ying Forest, or climb out of the skylight/doorway to");
        let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "leave Tutorial Island and enter Outer Space (LVL -1)!");
        let _ = tb_print(mx + 2, my + 8, ui_cyan(), ui_panel_bg(),  "Tip: Use Railgun/Nuke recoil in Rocket Mode [Tab] to soar!");
    } else if st.tome_id == BIOME_WHITE_FLOWER {
        let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "Welcome to the Small White Flower's Alpha Cube chamber.");
        let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "Alpha Cubes generate randomized fractal treasures and");
        let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "lead onward to Yellow Flower labyrinths & Mylantis.");
        let _ = tb_print(mx + 2, my + 7, ui_cyan(), ui_panel_bg(),  "Tip: Press [M] or [N] before diving so [F4] brings you home.");
    } else {
        let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "Deep inside the I2 Menger Lattice lies the Core Gate.");
        let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "Guardians hit hard — freeze them with Laser 2nd [R] or");
        let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "EMP [8], then shatter The Singularity for Quasar Drive!");
        let _ = tb_print(mx + 2, my + 7, ui_cyan(), ui_panel_bg(),  "Finally, approach Friend K and press [F] to rescue them.");
    }
    let _ = tb_print(mx + 2, my + 11, ui_green() | TB_BOLD, ui_panel_bg(), "Press [F] or [ESC] to close Tome");
}

fn draw_info_f1() {
    let st = core();
    let mw = if st.term_w >= 68 { 66 } else { st.term_w - 4 };
    let mh: i32 = 17;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_cyan() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_cyan() | TB_BOLD, ui_panel_bg(), "[F1] CONTROLS & FLIGHT MANUAL");
    let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "W/A/S/D           : 6-DOF Thrust (Forward/Strafe/Back)");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "Space / C or Z    : Ascend / Descend (PgUp / PgDn also work)");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "Q / E  &  U       : Camera Roll Left/Right & Toggle True Up");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "Tab / X           : Toggle Rocket Mode (Low Drag) / Brake");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "Arrows/IJKL/Mouse : Look Yaw & Pitch");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_panel_bg(), "LMB / Enter       : Primary Fire  | RMB / R : Secondary Fire");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_panel_bg(), "1..9, 0 / Wheel   : Select 10 Weapons");
    let _ = tb_print(mx + 2, my + 10, ui_white(), ui_panel_bg(), "F / T             : Use (Stations/Doors/K) / Telekinesis");
    let _ = tb_print(mx + 2, my + 11, ui_white(), ui_panel_bg(), "M / N             : Drop Short Marker / Long Marker");
    let _ = tb_print(mx + 2, my + 12, ui_white(), ui_panel_bg(), "G / V / P         : Minimap / 24-bit Color / Pause Menu");
    let _ = tb_print(mx + 2, my + 14, ui_green() | TB_BOLD, ui_panel_bg(), "Press [F1] or [ESC] to close");
}

fn draw_info_f2() {
    let st = core();
    let mw = if st.term_w >= 64 { 62 } else { st.term_w - 4 };
    let mh: i32 = 16;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_yellow() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_yellow() | TB_BOLD, ui_panel_bg(), "[F2] PLAYER STATS & UPGRADE TIERS");

    var b1: u8[160] = [0; 160];
    var l1: i32 = 0;
    buf_put_str(b1, l1, "HP: "); buf_put_int(b1, l1, st.hp); buf_put_ch(b1, l1, '/'); buf_put_int(b1, l1, st.max_hp);
    buf_put_str(b1, l1, "  Regen: +"); buf_put_int(b1, l1, st.hp_regen); buf_put_str(b1, l1, " HP/2s");
    let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), b1[0..l1]);

    var b2: u8[160] = [0; 160];
    var l2: i32 = 0;
    buf_put_str(b2, l2, "Armor: "); buf_put_int(b2, l2, st.armor); buf_put_ch(b2, l2, '/'); buf_put_int(b2, l2, st.max_armor);
    buf_put_str(b2, l2, "  Gold: "); buf_put_int(b2, l2, st.gold);
    buf_put_str(b2, l2, "  Keys: "); buf_put_int(b2, l2, st.keys);
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), b2[0..l2]);

    var b3: u8[160] = [0; 160];
    var l3: i32 = 0;
    buf_put_str(b3, l3, "Damage Lvl: "); buf_put_int(b3, l3, st.dmg_lvl);
    buf_put_str(b3, l3, " | Fire Rate Lvl: "); buf_put_int(b3, l3, st.rof_lvl);
    let _ = tb_print(mx + 2, my + 6, ui_cyan(), ui_panel_bg(), b3[0..l3]);

    var b4: u8[160] = [0; 160];
    var l4: i32 = 0;
    buf_put_str(b4, l4, "Ammo Cap Lvl: "); buf_put_int(b4, l4, st.ammo_cap_lvl);
    buf_put_str(b4, l4, " | Thrust Speed Lvl: "); buf_put_int(b4, l4, st.spd_lvl);
    let _ = tb_print(mx + 2, my + 7, ui_cyan(), ui_panel_bg(), b4[0..l4]);

    var b5: u8[160] = [0; 160];
    var l5: i32 = 0;
    buf_put_str(b5, l5, "Depth: LVL "); buf_put_int(b5, l5, st.depth);
    buf_put_str(b5, l5, " (Range "); buf_put_int(b5, l5, st.min_depth_reached);
    buf_put_str(b5, l5, ".."); buf_put_int(b5, l5, st.max_depth_reached); buf_put_ch(b5, l5, ')');
    let _ = tb_print(mx + 2, my + 9, ui_green(), ui_panel_bg(), b5[0..l5]);

    var b6: u8[160] = [0; 160];
    var l6: i32 = 0;
    buf_put_str(b6, l6, "Kills: "); buf_put_int(b6, l6, st.kills);
    buf_put_str(b6, l6, "  Deaths: "); buf_put_int(b6, l6, st.deaths);
    buf_put_str(b6, l6, if st.quasar_drive != 0 { "  Quasar Drive: UNLOCKED" } else { "  Quasar Drive: Locked" });
    let _ = tb_print(mx + 2, my + 10, ui_white(), ui_panel_bg(), b6[0..l6]);

    let _ = tb_print(mx + 2, my + 13, ui_green() | TB_BOLD, ui_panel_bg(), "Press [F2] or [ESC] to close");
}

fn draw_info_f3() {
    let st = core();
    let mw = if st.term_w >= 72 { 70 } else { st.term_w - 4 };
    let mh: i32 = 17;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_magenta() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_magenta() | TB_BOLD, ui_panel_bg(), "[F3] 10-WEAPON ARSENAL & SECONDARY MODES");

    let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "1:Plasma   [INF]  | 1st: Bolt      | 2nd: 3-Way Spread");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "2:Cannon          | 1st: Heavy Orb | 2nd: Rapid Autocannon");
    let _ = tb_print(mx + 2, my + 5, ui_white(), ui_panel_bg(), "3:Laser           | 1st: Beam      | 2nd: Cryo Freeze +8 Armor");
    let _ = tb_print(mx + 2, my + 6, ui_white(), ui_panel_bg(), "4:Rocket          | 1st: Explosive | 2nd: Heavy Cluster");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "5:Homing          | 1st: Seeker    | 2nd: Dual Seekers");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_panel_bg(), "6:Minigun         | 1st: Shredder  | 2nd: Turbo Barrage");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_panel_bg(), "7:Railgun         | 1st: Piercing Rail + Recoil Boost!");
    let _ = tb_print(mx + 2, my + 10, ui_white(), ui_panel_bg(), "8:EMP             | 1st: Stun Bolt | 2nd: Radial EMP Shockwave");
    let _ = tb_print(mx + 2, my + 11, ui_white(), ui_panel_bg(), "9:Nuke            | High-Yield Blast + Strong Recoil Boost!");
    let _ = tb_print(mx + 2, my + 12, ui_yellow(), ui_panel_bg(), "0:DarkHole/Quasar | Gravity Pull Blast + Recoil (2x w/ Quasar)");
    let _ = tb_print(mx + 2, my + 14, ui_green() | TB_BOLD, ui_panel_bg(), "Press [F3] or [ESC] to close");
}

fn draw_info_f4() {
    let st = core();
    let mw = if st.term_w >= 68 { 66 } else { st.term_w - 4 };
    let mh: i32 = 17;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_green() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_green() | TB_BOLD, ui_panel_bg(), "[F4] SHORT & LONG MARKERS (TELEPORT MANAGER)");

    var row: i32 = 0;
    var i: i32 = 0;
    while i < 10 && row < 10 {
        var mbuf: u8[160] = [0; 160];
        var mlen: i32 = 0;
        buf_put_ch(mbuf, mlen, '[');
        buf_put_int(mbuf, mlen, i);
        buf_put_str(mbuf, mlen, "] ");
        if st.markers[i].used != 0 {
            buf_put_str(mbuf, mlen, if st.markers[i].is_long != 0 { "LONG  " } else { "SHORT " });
            buf_put_str(mbuf, mlen, "LVL:");
            buf_put_int(mbuf, mlen, st.markers[i].depth);
            buf_put_str(mbuf, mlen, " ");
            buf_put_str(mbuf, mlen, biome_name(st.markers[i].biome));
            buf_put_str(mbuf, mlen, " (");
            buf_put_int(mbuf, mlen, ffloor(st.markers[i].px));
            buf_put_ch(mbuf, mlen, ',');
            buf_put_int(mbuf, mlen, ffloor(st.markers[i].py));
            buf_put_ch(mbuf, mlen, ',');
            buf_put_int(mbuf, mlen, ffloor(st.markers[i].pz));
            buf_put_ch(mbuf, mlen, ')');
            let col = if i == st.active_marker { ui_yellow() | TB_BOLD } else { ui_white() };
            let _ = tb_print(mx + 2, my + 3 + row, col, ui_panel_bg(), mbuf[0..mlen]);
        } else {
            buf_put_str(mbuf, mlen, "(Empty — drop with [M] Short or [N] Long)");
            let _ = tb_print(mx + 2, my + 3 + row, ui_muted(), ui_panel_bg(), mbuf[0..mlen]);
        }
        row = row + 1;
        i = i + 1;
    }
    let _ = tb_print(mx + 2, my + 14, ui_cyan() | TB_BOLD, ui_panel_bg(), "Press [0-9] to warp to Marker, or [F4]/[ESC] to close");
}

fn draw_info_f5() {
    let st = core();
    let mw = if st.term_w >= 70 { 68 } else { st.term_w - 4 };
    let mh: i32 = 17;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_orange() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_orange() | TB_BOLD, ui_panel_bg(), "[F5] XAR BIOME PROGRESSION & MONSTER MANUAL");

    let _ = tb_print(mx + 2, my + 3, ui_cyan(), ui_panel_bg(),  "Space (LVL -1): Mylantis 'M', Ying Planet, Ice/Desert Worlds");
    let _ = tb_print(mx + 2, my + 4, ui_cyan(), ui_panel_bg(),  "Tutorial (0)  : Black Cube -> Ying Forest | White Flower -> Alpha");
    let _ = tb_print(mx + 2, my + 5, ui_cyan(), ui_panel_bg(),  "Deep Fractals : Yellow Flower -> Mylantis -> I2 Menger -> Core");
    let _ = tb_print(mx + 2, my + 7, ui_white(), ui_panel_bg(), "Rats & Spiders : Fast close-range cave swarmers");
    let _ = tb_print(mx + 2, my + 8, ui_white(), ui_panel_bg(), "Goons/Marines  : Ranged soldiers dropping Gold & Ammo");
    let _ = tb_print(mx + 2, my + 9, ui_white(), ui_panel_bg(), "Pirates/Menaces: Heavy space & flower patrols");
    let _ = tb_print(mx + 2, my + 10, ui_white(), ui_panel_bg(), "YinYangs/Demons: Ying Forest & Mylantis/I2 elites");
    let _ = tb_print(mx + 2, my + 11, ui_white(), ui_panel_bg(), "Guardians      : Pool-ball tanks (freeze w/ Laser 2nd or EMP!)");
    let _ = tb_print(mx + 2, my + 12, ui_magenta() | TB_BOLD, ui_panel_bg(), "The Singularity: Inner Core boss protecting Friend K");
    let _ = tb_print(mx + 2, my + 14, ui_green() | TB_BOLD, ui_panel_bg(), "Press [F5] or [ESC] to close");
}

fn draw_pause_modal() {
    let st = core();
    let mw = if st.term_w >= 54 { 52 } else { st.term_w - 4 };
    let mh: i32 = 12;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_cyan() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 1, ui_cyan() | TB_BOLD, ui_panel_bg(), "PAUSED — FRACTAL BLOCK WORLD");
    let _ = tb_print(mx + 2, my + 3, ui_white(), ui_panel_bg(), "Death respawns at Tutorial (-30 Gold, keeps gear).");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "Use [F1]..[F5] anytime for guides & marker warps.");
    let _ = tb_print(mx + 2, my + 6, ui_green() | TB_BOLD, ui_panel_bg(), "[P] / [ESC] : Resume Game");
    let _ = tb_print(mx + 2, my + 7, ui_yellow(), ui_panel_bg(),         "[N]         : Restart New Run");
    let _ = tb_print(mx + 2, my + 8, ui_red() | TB_BOLD, ui_panel_bg(),   "[Q]         : Quit to Terminal");
}

fn draw_victory_modal() {
    let st = core();
    let mw = if st.term_w >= 58 { 56 } else { st.term_w - 4 };
    let mh: i32 = 12;
    let mx = (st.term_w - mw) / 2;
    let my = (st.term_h - mh) / 2;
    draw_rect(mx, my, mw, mh, ui_yellow() | TB_BOLD, ui_panel_bg());
    let _ = tb_print(mx + 2, my + 2, ui_yellow() | TB_BOLD, ui_panel_bg(), "VICTORY! FRIEND 'K' RESCUED FROM THE CORE!");
    let _ = tb_print(mx + 2, my + 4, ui_white(), ui_panel_bg(), "You conquered The Singularity and saved K! (+500 Gold)");
    let _ = tb_print(mx + 2, my + 5, ui_cyan(), ui_panel_bg(),  "Quasar Drive (Weapon 0) powers your continued voyage.");
    let _ = tb_print(mx + 2, my + 7, ui_green() | TB_BOLD, ui_panel_bg(), "[ENTER] Keep Exploring Xar  |  [N] New Run  |  [Q] Quit");
}

fn draw_frame() {
    let st = core();
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
    if st.screen == SCREEN_BUY { draw_buy_modal(); }
    else if st.screen == SCREEN_SELL { draw_sell_modal(); }
    else if st.screen == SCREEN_BLACK_MARKET { draw_black_market_modal(); }
    else if st.screen == SCREEN_TOME { draw_tome_modal(); }
    else if st.screen == SCREEN_PAUSE { draw_pause_modal(); }
    else if st.screen == SCREEN_INFO_F1 { draw_info_f1(); }
    else if st.screen == SCREEN_INFO_F2 { draw_info_f2(); }
    else if st.screen == SCREEN_INFO_F3 { draw_info_f3(); }
    else if st.screen == SCREEN_INFO_F4 { draw_info_f4(); }
    else if st.screen == SCREEN_INFO_F5 { draw_info_f5(); }
    else if st.screen == SCREEN_VICTORY { draw_victory_modal(); }
    let _ = tb_present();
}

// ---------------------------------------------------------------------------
// Input Handling & Viewport Sync
// ---------------------------------------------------------------------------
fn sync_viewport() {
    let st = core();
    st.term_w = tb_width();
    st.term_h = tb_height();
    st.pw = if st.term_w > MAX_PW { MAX_PW } else if st.term_w < 16 { 16 } else { st.term_w };
    let vrows = if st.term_h > 4 { st.term_h - 3 } else { 1 };
    var ph = vrows * 2;
    if ph > MAX_PH { ph = MAX_PH; }
    if ph < 2 { ph = 2; }
    st.ph = ph;
}

fn toggle_info_screen(target: i32) {
    let st = core();
    if st.screen == target { st.screen = SCREEN_PLAY; }
    else { st.screen = target; }
}

fn handle_key(ev: tb_event&) -> i32 {
    let st = core();
    let ch = ev.ch;
    let key = ev.key;

    if key == TB_KEY_CTRL_Q || key == TB_KEY_CTRL_C { return 0; }

    if st.screen == SCREEN_TITLE {
        if key == TB_KEY_ESC || ch == 'q' || ch == 'Q' { return 0; }
        if key == TB_KEY_ENTER || key == TB_KEY_SPACE || ch == ' ' {
            st.screen = SCREEN_PLAY;
        }
        return 1;
    }

    if st.screen == SCREEN_VICTORY {
        if ch == 'q' || ch == 'Q' { return 0; }
        if key == TB_KEY_ENTER || key == TB_KEY_ESC {
            st.screen = SCREEN_PLAY;
            return 1;
        }
        if ch == 'n' || ch == 'N' {
            init_new_game();
            st.screen = SCREEN_PLAY;
            return 1;
        }
        return 1;
    }

    if st.screen == SCREEN_PAUSE {
        if ch == 'q' || ch == 'Q' { return 0; }
        if ch == 'n' || ch == 'N' {
            init_new_game();
            st.screen = SCREEN_PLAY;
            return 1;
        }
        if key == TB_KEY_ESC || ch == 'p' || ch == 'P' {
            st.screen = SCREEN_PLAY;
            return 1;
        }
        return 1;
    }

    if st.screen == SCREEN_BUY {
        if key == TB_KEY_ESC || ch == 'f' || ch == 'F' { st.screen = SCREEN_PLAY; return 1; }
        if ch >= '1' && ch <= '6' { handle_buy_action((ch - '0') as! i32); }
        return 1;
    }
    if st.screen == SCREEN_SELL {
        if key == TB_KEY_ESC || ch == 'f' || ch == 'F' { st.screen = SCREEN_PLAY; return 1; }
        if ch >= '1' && ch <= '4' { handle_sell_action((ch - '0') as! i32); }
        return 1;
    }
    if st.screen == SCREEN_BLACK_MARKET {
        if key == TB_KEY_ESC || ch == 'f' || ch == 'F' { st.screen = SCREEN_PLAY; return 1; }
        if ch >= '1' && ch <= '4' { handle_black_market_action((ch - '0') as! i32); }
        return 1;
    }
    if st.screen == SCREEN_TOME {
        if key == TB_KEY_ESC || ch == 'f' || ch == 'F' || key == TB_KEY_ENTER || key == TB_KEY_SPACE || ch == ' ' {
            st.screen = SCREEN_PLAY;
        }
        return 1;
    }

    // F1-F5 Info Overlays
    if key == TB_KEY_F1 { toggle_info_screen(SCREEN_INFO_F1); return 1; }
    if key == TB_KEY_F2 { toggle_info_screen(SCREEN_INFO_F2); return 1; }
    if key == TB_KEY_F3 { toggle_info_screen(SCREEN_INFO_F3); return 1; }
    if key == TB_KEY_F4 { toggle_info_screen(SCREEN_INFO_F4); return 1; }
    if key == TB_KEY_F5 { toggle_info_screen(SCREEN_INFO_F5); return 1; }

    if st.screen >= SCREEN_INFO_F1 && st.screen <= SCREEN_INFO_F5 {
        if st.screen == SCREEN_INFO_F4 && ch >= '0' && ch <= '9' {
            let slot = (ch - '0') as! i32;
            if warp_to_marker(slot) != 0 {
                st.screen = SCREEN_PLAY;
            }
            return 1;
        }
        if key == TB_KEY_ESC || key == TB_KEY_ENTER || key == TB_KEY_SPACE || ch == ' ' {
            st.screen = SCREEN_PLAY;
        }
        return 1;
    }

    // Active Gameplay (SCREEN_PLAY)
    if key == TB_KEY_ESC || ch == 'p' || ch == 'P' { st.screen = SCREEN_PAUSE; return 1; }
    if key == TB_KEY_TAB {
        st.rocket_mode = if st.rocket_mode != 0 { 0 } else { 1 };
        set_status_msg(if st.rocket_mode != 0 { "Rocket Mode ON (Low Drag Thrust)" } else { "Rocket Mode OFF (Standard Dampening)" }, 1300);
        return 1;
    }
    if ch == 'g' || ch == 'G' { st.show_minimap = if st.show_minimap != 0 { 0 } else { 1 }; return 1; }
    if ch == 'v' || ch == 'V' {
        st.truecolor = if st.truecolor != 0 { 0 } else { 1 };
        let _ = tb_set_output_mode(if st.truecolor != 0 { TB_OUTPUT_TRUECOLOR } else { TB_OUTPUT_256 });
        let _ = tb_invalidate();
        return 1;
    }

    // 10 Weapons: 1..9 -> slots 0..8, 0 -> slot 9 (Dark Hole / Quasar)
    if ch >= '1' && ch <= '9' { st.weapon = (ch - '1') as! i32; return 1; }
    if ch == '0' { st.weapon = WEP_DARKHOLE; return 1; }

    // Camera Roll (Q/E) & True Up (U)
    if ch == 'q' || ch == 'Q' { st.roll = wrap_angle(st.roll - 0.14); return 1; }
    if ch == 'e' || ch == 'E' { st.roll = wrap_angle(st.roll + 0.14); return 1; }
    if ch == 'u' || ch == 'U' {
        st.true_up = if st.true_up != 0 { 0 } else { 1 };
        set_status_msg(if st.true_up != 0 { "True Up ON (Horizon Auto-Levels)" } else { "True Up OFF (Free 3D Roll)" }, 1300);
        return 1;
    }

    // Use / Telekinesis / Brake / Markers / Fire
    if ch == 'f' || ch == 'F' { use_nearest(); return 1; }
    if ch == 't' || ch == 'T' { trigger_telekinesis(); return 1; }
    if ch == 'x' || ch == 'X' { apply_brake(); return 1; }
    if ch == 'm' || ch == 'M' { drop_marker(0); return 1; }
    if ch == 'n' || ch == 'N' { drop_marker(1); return 1; }
    if key == TB_KEY_ENTER { fire_weapon(0); return 1; }
    if ch == 'r' || ch == 'R' { fire_weapon(1); return 1; }

    // 6-DOF Flight Thrust & Look
    let thrust: f64 = 2.6;
    var fx: f64 = 0.0;
    var fy: f64 = 0.0;
    var fz: f64 = 0.0;
    camera_forward(fx, fy, fz);
    let sy = fsin(st.yaw);
    let cy = fcos(st.yaw);
    let rx = -sy;
    let rz = cy;

    if ch == 'w' || ch == 'W' { apply_thrust(fx * thrust, fy * thrust, fz * thrust); }
    else if ch == 's' || ch == 'S' { apply_thrust(-fx * thrust, -fy * thrust, -fz * thrust); }
    else if ch == 'd' || ch == 'D' { apply_thrust(rx * thrust, 0.0, rz * thrust); }
    else if ch == 'a' || ch == 'A' { apply_thrust(-rx * thrust, 0.0, -rz * thrust); }
    else if key == TB_KEY_SPACE || ch == ' ' || key == TB_KEY_PGUP { apply_thrust(0.0, thrust * 0.9, 0.0); }
    else if ch == 'c' || ch == 'C' || ch == 'z' || ch == 'Z' || key == TB_KEY_PGDN { apply_thrust(0.0, -thrust * 0.9, 0.0); }
    else if key == TB_KEY_ARROW_LEFT || ch == 'j' || ch == 'J' { st.yaw = wrap_angle(st.yaw - 0.11); }
    else if key == TB_KEY_ARROW_RIGHT || ch == 'l' || ch == 'L' { st.yaw = wrap_angle(st.yaw + 0.11); }
    else if key == TB_KEY_ARROW_UP || ch == 'i' || ch == 'I' { st.pitch = fclamp(st.pitch + 0.08, -1.25, 1.25); }
    else if key == TB_KEY_ARROW_DOWN || ch == 'k' || ch == 'K' { st.pitch = fclamp(st.pitch - 0.08, -1.25, 1.25); }

    return 1;
}

fn handle_mouse(ev: tb_event&) {
    let st = core();
    if st.screen != SCREEN_PLAY { return; }
    if ev.key == TB_KEY_MOUSE_LEFT {
        if (ev.mod & TB_MOD_MOTION) != 0 {
            if st.mouse_dragging != 0 {
                let dx = ev.x - st.mouse_last_x;
                let dy = ev.y - st.mouse_last_y;
                st.yaw = wrap_angle(st.yaw + dx * 0.025);
                st.pitch = fclamp(st.pitch - dy * 0.035, -1.25, 1.25);
            }
            st.mouse_dragging = 1;
            st.mouse_last_x = ev.x;
            st.mouse_last_y = ev.y;
        } else {
            fire_weapon(0);
            st.mouse_dragging = 1;
            st.mouse_last_x = ev.x;
            st.mouse_last_y = ev.y;
        }
    } else if ev.key == TB_KEY_MOUSE_RIGHT {
        fire_weapon(1);
    } else if ev.key == TB_KEY_MOUSE_RELEASE {
        st.mouse_dragging = 0;
    } else if ev.key == TB_KEY_MOUSE_WHEEL_UP {
        st.weapon = (st.weapon + NUM_WEAPONS - 1) % NUM_WEAPONS;
    } else if ev.key == TB_KEY_MOUSE_WHEEL_DOWN {
        st.weapon = (st.weapon + 1) % NUM_WEAPONS;
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

    let st = core();
    st.truecolor = 1;
    let _ = tb_set_output_mode(TB_OUTPUT_TRUECOLOR);
    let _ = tb_set_input_mode(TB_INPUT_ESC | TB_INPUT_MOUSE);
    let _ = tb_hide_cursor();

    st.rng = 0x4642575f32303236 ^ (tb_adapter_now_ms() as u64);
    st.screen = SCREEN_TITLE;
    st.show_minimap = 1;

    sync_viewport();
    init_new_game();

    let g = gbl();
    g.inbuf_len = 0;
    g.inbuf_pos = 0;

    draw_frame();

    const TARGET_FRAME_MS: i32 = 33;
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
                st.fps = (st.frame_cnt * 1000) / (fdt as! i32);
            }
            st.frame_cnt = 0;
            st.fps_last_ms = now;
        }
    }

    let _ = tb_shutdown();
}
