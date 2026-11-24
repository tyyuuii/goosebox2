// test_fbw.goose — Deterministic unit & simulation tests for fbw_core.goose

import fbw_core;

var g_pass: i32 = 0;
var g_fail: i32 = 0;

fn expect(cond: i32, name: const u8[:]) {
    if cond != 0 {
        g_pass = g_pass + 1;
    } else {
        g_fail = g_fail + 1;
        print("FAIL: ");
        print(name);
        print("\n");
    }
}

fn count_hostiles() -> i32 {
    let st = core();
    var cnt: i32 = 0;
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 && st.entities[i].kind >= ENT_RAT && st.entities[i].kind <= ENT_SINGULARITY {
            cnt = cnt + 1;
        }
        i = i + 1;
    }
    return cnt;
}

fn count_shrink_rings() -> i32 {
    let st = core();
    var cnt: i32 = 0;
    var i: i32 = 0;
    while i < MAX_ENTITIES {
        if st.entities[i].active != 0 && (st.entities[i].kind == ENT_RING_GREEN || st.entities[i].kind == ENT_RING_PINK) {
            cnt = cnt + 1;
        }
        i = i + 1;
    }
    return cnt;
}

fn test_tutorial_and_fractal_scaling() {
    let st = core();
    st.genesis_mode = 0;
    init_new_game();
    st.screen = SCREEN_PLAY;
    expect(if st.depth == 0 { 1 } else { 0 }, "starts at depth 0");
    expect(if get_frame(0).biome == BIOME_TUTORIAL { 1 } else { 0 }, "starts in BIOME_TUTORIAL");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "spawn is collision-free");
    expect(if get_block(8, 2, 9) == BLK_BLACK_CUBE { 1 } else { 0 }, "Tutorial Black Cube ahead");

    // 1) Fly forward (+Z) into the Tutorial Black Cube at depth 0 -> SOLID block stops player cleanly (no touch-teleport!)
    st.ring_cd_ms = 0;
    var step: i32 = 0;
    while step < 30 {
        apply_thrust(0.0, 0.0, 3.0);
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 0 && st.vz == 0.0 { 1 } else { 0 }, "Tutorial Black Cube blocks player solidly at depth 0 until shrunk");

    // Shrink in-place [B] and physically fly forward (+Z) through the open 4x8 3D archway into Ying Forest!
    shrink_targeted_block();
    expect(if st.depth == 1 && cur_parent_block() == BLK_AIR { 1 } else { 0 }, "[B] shrinks 16x in air before Black Cube");
    step = 0;
    while step < 35 && cur_parent_block() == BLK_AIR {
        st.vx = 0.0; st.vy = 0.0; st.vz = 10.0;
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 1 && cur_parent_block() == BLK_BLACK_CUBE && get_frame(1).biome == BIOME_YING_FOREST { 1 } else { 0 }, "Flying shrunken through 3D tunnel enters Ying Forest physically");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "Ying Forest physical entry is collision-free");

    // 2) Test all 6 chunk-boundary exits grow back to depth 0 at the right face!
    let faces_x = [ -0.5, 16.5, 8.0, 8.0, 8.0, 8.0 ];
    let faces_y = [ 8.0, 8.0, -0.5, 16.5, 8.0, 8.0 ];
    let faces_z = [ 8.0, 8.0, 8.0, 8.0, -0.5, 16.5 ];
    var f: i32 = 0;
    while f < 6 {
        init_new_game();
        st.screen = SCREEN_PLAY;
        st.ring_cd_ms = 0;
        shrink_into(8, 3, 9, BLK_BLACK_CUBE, -1, 1);
        expect(if st.depth == 1 { 1 } else { 0 }, "re-entered depth 1 for boundary grow test");
        st.ring_cd_ms = 0;
        grow_out_axis(faces_x[f], faces_y[f], faces_z[f]);
        expect(if st.depth == 0 { 1 } else { 0 }, "chunk boundary exit grows to depth 0");
        expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "grown player position is collision-free");
        f = f + 1;
    }

    // 3) Growing out of Tutorial Island (depth 0 -> -1) reaches Outer Space (BIOME_SPACE)
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    grow_out_axis(8.5, 16.5, 8.5);
    expect(if st.depth == -1 { 1 } else { 0 }, "exiting depth 0 reaches Outer Space depth -1");
    expect(if get_frame(-1).biome == BIOME_SPACE { 1 } else { 0 }, "depth -1 biome is BIOME_SPACE");
    expect(if get_block(13, 8, 12) == BLK_MYLANTIS_M { 1 } else { 0 }, "Mylantis M block exists in Outer Space");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "Outer Space exit is collision-free outside Ying Planet");

    // 4) Pink Ring 256x dive skips 2 levels at once
    st.ring_cd_ms = 0;
    shrink_into(13, 8, 12, BLK_MYLANTIS_M, BIOME_MYLANTIS, 2);
    expect(if st.depth == 1 { 1 } else { 0 }, "2-step 256x shrink from -1 lands at depth 1");
}

fn test_infinite_depth_and_early_peacefulness() {
    let st = core();
    st.genesis_mode = 0;
    init_new_game();
    st.screen = SCREEN_PLAY;

    // 1) Authentic early-game peacefulness (0 enemies in Tutorial, Space -1, Ying Forest 1, Alpha Cube 2)
    expect(if count_hostiles() == 0 { 1 } else { 0 }, "Tutorial (depth 0) is peaceful (0 enemies)");

    st.ring_cd_ms = 0;
    grow_out_axis(8.5, 16.5, 8.5);
    expect(if st.depth == -1 && count_hostiles() == 0 { 1 } else { 0 }, "Space (depth -1) is peaceful (0 enemies)");

    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into(8, 2, 9, BLK_BLACK_CUBE, -1, 1);
    expect(if cur_biome() == BIOME_YING_FOREST && count_hostiles() == 0 { 1 } else { 0 }, "Early Ying Forest (depth 1) is peaceful");

    st.ring_cd_ms = 0;
    shrink_into(5, 2, 4, BLK_WHITE_FLOWER, -1, 1);
    expect(if cur_biome() == BIOME_WHITE_FLOWER && count_hostiles() == 0 { 1 } else { 0 }, "Early Alpha Cube (depth 2) is peaceful");

    // 2) Mid-game debut: Yellow Flower & Mylantis spawn enemies (Goblins/Rats/etc.)
    st.ring_cd_ms = 0;
    shrink_into(8, 2, 8, BLK_ALPHA_CUBE, -1, 1);
    expect(if cur_biome() == BIOME_YELLOW_FLOWER && count_hostiles() >= 2 { 1 } else { 0 }, "Mid-game Yellow Flower spawns enemies");

    st.ring_cd_ms = 0;
    shrink_into(4, 2, 8, BLK_MYLANTIS_M, -1, 1);
    expect(if cur_biome() == BIOME_MYLANTIS && count_hostiles() >= 2 { 1 } else { 0 }, "Mid-game Mylantis spawns enemies");

    // 3) Inner Core still permits shrinking deeper (never dead-ends at depth 6!)
    st.ring_cd_ms = 0;
    shrink_into(4, 2, 8, BLK_CORE_GATE, BIOME_INNER_CORE, 1);
    expect(if cur_biome() == BIOME_INNER_CORE { 1 } else { 0 }, "Core Gate enters Inner Core");
    expect(if count_shrink_rings() >= 2 { 1 } else { 0 }, "Inner Core keeps Green/Pink Shrink Rings");

    // 4) Unbounded Deep Shrinking: dive 250 levels deep, verify Long Marker & growing back!
    init_new_game();
    st.screen = SCREEN_PLAY;
    var d: i32 = 0;
    while d < 250 {
        st.ring_cd_ms = 0;
        shrink_targeted_block();
        d = d + 1;
    }
    expect(if st.depth == 250 && st.max_depth_reached == 250 { 1 } else { 0 }, "Can shrink continuously to depth 250");
    let seed_250 = cur_seed();
    st.px = 7.7; st.py = 3.5; st.pz = 9.1;
    drop_marker(1);
    st.ring_cd_ms = 0;
    grow_out_axis(8.0, 16.5, 8.0);
    expect(if st.depth == 249 { 1 } else { 0 }, "Growing out from depth 250 decrements cleanly to 249");
    let warped = warp_to_marker(st.active_marker);
    expect(if warped == 1 && st.depth == 250 && cur_seed() == seed_250 { 1 } else { 0 }, "Deep Marker at depth 250 restores exact fractal stack");

    // Can reach deep scale ceiling (3000) cleanly without overflowing
    st.ring_cd_ms = 0;
    shrink_into(8, 2, 8, BLK_BLACK_CUBE, -1, 2800);
    expect(if st.depth == MAX_POS_DEPTH { 1 } else { 0 }, "Deep shrinking supports up to MAX_POS_DEPTH (3000)");

    // 5) Genesis Mode removes all enemies everywhere
    st.genesis_mode = 1;
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into(8, 2, 9, BLK_BLACK_CUBE, -1, 1);
    st.ring_cd_ms = 0;
    shrink_into(8, 5, 12, BLK_FLOWER_Y_CORE, BIOME_YELLOW_FLOWER, 1);
    expect(if cur_biome() == BIOME_YELLOW_FLOWER && count_hostiles() == 0 { 1 } else { 0 }, "Genesis Mode has 0 enemies even in Yellow Flower");
    st.ring_cd_ms = 0;
    shrink_into(4, 2, 8, BLK_CORE_GATE, BIOME_INNER_CORE, 1);
    expect(if cur_biome() == BIOME_INNER_CORE && count_hostiles() == 0 { 1 } else { 0 }, "Genesis Mode has 0 enemies in Inner Core");
    st.genesis_mode = 0;
}

fn test_weapons_and_physics() {
    let st = core();
    st.genesis_mode = 0;
    init_new_game();
    st.screen = SCREEN_PLAY;

    // 0) Classic progression starts with ONLY 1:Plasma unlocked; Weapon Modules unlock the rest
    expect(if st.wep_unlocked[WEP_PLASMA] == 1 && st.wep_unlocked[WEP_RAILGUN] == 0 { 1 } else { 0 }, "Starts with Plasma unlocked and Railgun locked");
    st.weapon = WEP_RAILGUN;
    let rail_before = st.ammo[WEP_RAILGUN];
    fire_weapon(0);
    expect(if st.ammo[WEP_RAILGUN] == rail_before { 1 } else { 0 }, "Locked Railgun cannot fire until unlocked");
    unlock_all_weapons();

    // 1) Rocket Mode low drag vs Standard drag + Brake
    st.rocket_mode = 0;
    apply_thrust(0.0, 0.0, 5.0);
    let v_before_std = st.vz;
    step_simulation(100);
    let ratio_std = st.vz / v_before_std;

    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.rocket_mode = 1;
    apply_thrust(0.0, 0.0, 5.0);
    let v_before_rkt = st.vz;
    step_simulation(100);
    let ratio_rkt = st.vz / v_before_rkt;
    expect(if ratio_rkt > ratio_std { 1 } else { 0 }, "Rocket Mode retains more momentum than standard drag");

    apply_brake();
    expect(if fabs(st.vz) < v_before_rkt * 0.25 { 1 } else { 0 }, "Brake sharply reduces velocity");

    // 2) Test all 10 weapons (Primary + Secondary) & Plasma infinite ammo
    var w: i32 = 0;
    while w < NUM_WEAPONS {
        st.weapon = w;
        st.fire_cd_ms = 0;
        let before = st.ammo[w];
        fire_weapon(0);
        if w == WEP_PLASMA {
            expect(if st.ammo[w] == before { 1 } else { 0 }, "Plasma primary uses 0 ammo");
        } else {
            expect(if st.ammo[w] == before - 1 { 1 } else { 0 }, "Non-plasma weapon consumes ammo");
        }
        st.fire_cd_ms = 0;
        fire_weapon(1);
        w = w + 1;
    }

    // 3) Railgun / Nuke / Dark Hole Recoil Boost moves player opposite to aim (+Z aim -> -Z velocity)
    st.px = 8.0; st.py = 3.2; st.pz = 6.0;
    st.vx = 0.0; st.vy = 0.0; st.vz = 0.0;
    st.yaw = HALF_PI;
    st.pitch = 0.0;
    st.weapon = WEP_RAILGUN;
    st.fire_cd_ms = 0;
    fire_weapon(0);
    expect(if st.vz < -2.0 { 1 } else { 0 }, "Railgun imparts backward recoil boost");

    // 4) Laser Secondary freezes nearby enemies and restores +8 armor
    st.armor = 20;
    let e_idx = spawn_entity(ENT_GUARDIAN, st.px, st.py, st.pz + 2.5, 120, -1, 0);
    st.weapon = WEP_LASER;
    st.fire_cd_ms = 0;
    fire_weapon(1);
    expect(if st.armor == 28 { 1 } else { 0 }, "Laser Secondary restores +8 Armor");
    expect(if st.entities[e_idx].freeze_ms > 0 { 1 } else { 0 }, "Laser Secondary freezes Guardian");

    // 5) EMP Secondary freezes enemies around player
    st.entities[e_idx].freeze_ms = 0;
    st.weapon = WEP_EMP;
    st.fire_cd_ms = 0;
    fire_weapon(1);
    expect(if st.entities[e_idx].freeze_ms >= 3000 { 1 } else { 0 }, "EMP Secondary stuns nearby enemies");

    // 6) Singularity defeat unlocks Quasar Drive; rescuing K triggers Victory
    let boss_idx = spawn_entity(ENT_SINGULARITY, st.px, st.py, st.pz + 3.0, 10, -1, 0);
    damage_entity(boss_idx, 50, 0);
    expect(if st.quasar_drive == 1 { 1 } else { 0 }, "Defeating The Singularity unlocks Quasar Drive");
    let _ = spawn_entity(ENT_FRIEND_K, st.px + 0.5, st.py, st.pz, 1, -1, 0);
    step_simulation(20);
    expect(if st.k_rescued == 1 && st.screen == SCREEN_VICTORY { 1 } else { 0 }, "Touching Friend K triggers Victory");
}

fn test_economy_markers_and_respawn() {
    let st = core();
    st.genesis_mode = 0;
    init_new_game();
    st.screen = SCREEN_PLAY;

    // Gold cap 1,000,000
    add_gold(2000000);
    expect(if st.gold == MAX_GOLD { 1 } else { 0 }, "Gold caps at 1,000,000");

    // Buy & Sell stations
    st.gold = 100;
    st.hp = 40;
    handle_buy_action(1); // +50 HP for 15 gold
    expect(if st.gold == 85 && st.hp == 90 { 1 } else { 0 }, "Buy Station heals HP for Gold");
    handle_sell_action(1); // Sell 25 HP for +20 Gold
    expect(if st.gold == 105 && st.hp == 65 { 1 } else { 0 }, "Sell Station converts HP to Gold");

    // Black Market discounted Railgun unlocks & adds ammo
    let r_before = st.ammo[WEP_RAILGUN];
    handle_black_market_action(1);
    expect(if st.gold == 85 && st.wep_unlocked[WEP_RAILGUN] == 1 && st.ammo[WEP_RAILGUN] > r_before { 1 } else { 0 }, "Black Market unlocks & sells discounted Railgun ammo");

    // Upgrade block collection & persistence
    collect_upgrade_block(3, 2, 12, BLK_UPG_HP);
    expect(if st.max_hp == 120 { 1 } else { 0 }, "Health Upgrade increases max_hp to 120");
    collect_upgrade_block(3, 2, 11, BLK_UPG_DMG);
    expect(if st.dmg_lvl == 2 { 1 } else { 0 }, "Damage Upgrade increases dmg_lvl");

    // Markers & Warping
    st.ring_cd_ms = 0;
    shrink_into(8, 3, 9, BLK_BLACK_CUBE, -1, 1);
    st.px = 4.2; st.py = 3.5; st.pz = 11.4;
    drop_marker(1);
    expect(if st.active_marker >= 1 && st.markers[st.active_marker].depth == 1 { 1 } else { 0 }, "Long Marker stores depth 1 coordinates");

    // Death penalty (-30 Gold, respawn at Tutorial, upgrades & markers preserved!)
    st.gold = 100;
    damage_player(9999);
    expect(if st.depth == 0 && st.deaths == 1 { 1 } else { 0 }, "Death respawns at Tutorial depth 0");
    expect(if st.gold == 70 { 1 } else { 0 }, "Death deducts 30 Gold");
    expect(if st.max_hp == 120 && st.dmg_lvl == 2 { 1 } else { 0 }, "Death preserves upgrades");
    expect(if get_block(3, 2, 12) == BLK_AIR { 1 } else { 0 }, "Collected upgrade block delta persists across respawn");

    // Warp back to deep marker
    let warped = warp_to_marker(st.active_marker);
    expect(if warped == 1 && st.depth == 1 && fabs(st.px - 4.2) < 0.01 { 1 } else { 0 }, "Warp to Marker restores deep chunk and position");

    // Performance settings survive run reset
    st.render_scale = 2;
    st.is_termux = 1;
    init_new_game();
    expect(if st.render_scale == 2 && st.is_termux == 1 { 1 } else { 0 }, "init_new_game preserves render_scale and Termux flag");
}

fn test_in_place_shrink_and_parent_layers() {
    let st = core();
    st.genesis_mode = 0;
    init_new_game();
    st.screen = SCREEN_PLAY;

    // 1) In-place air shrink inside Tutorial Hall (preserving parent biome & world!)
    st.px = 9.5;
    st.py = 3.2;
    st.pz = 6.2;
    st.ring_cd_ms = 0;
    shrink_into_ex(9, 3, 6, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    expect(if st.depth == 1 && cur_parent_block() == BLK_AIR { 1 } else { 0 }, "In-place air shrink sets depth=1 and parent_block=BLK_AIR");
    expect(if cur_biome() == BIOME_TUTORIAL { 1 } else { 0 }, "In-place air shrink preserves parent biome (Tutorial Island)");
    expect(if fabs(st.px - 8.0) < 0.05 && fabs(st.py - 3.2) < 0.05 && fabs(st.pz - 3.2) < 0.05 { 1 } else { 0 }, "In-place air shrink scales fractional offsets by 16x");
    expect(if st.parent_valid[0] == 1 && st.parent_bx[0] == 9 && st.parent_by[0] == 3 && st.parent_bz[0] == 6 { 1 } else { 0 }, "Parent layer 0 caches exited voxel (9,3,6)");
    expect(if get_parent_block(0, 8, 2, 9) == BLK_BLACK_CUBE { 1 } else { 0 }, "Parent layer 0 exposes Tutorial Black Cube around player");
    expect(if st.parent_valid[1] == 1 && get_parent_block(1, 13, 8, 12) == BLK_MYLANTIS_M { 1 } else { 0 }, "Parent layer 1 exposes Outer Space Mylantis M");
    expect(if get_block(0, 8, 8) == BLK_AIR && get_block(15, 8, 8) == BLK_AIR && get_block(8, 0, 8) == BLK_AIR && get_block(8, 15, 8) == BLK_AIR && get_block(8, 8, 0) == BLK_AIR && get_block(8, 8, 15) == BLK_AIR { 1 } else { 0 }, "In-place air subchunk has zero enclosing walls");

    // 2) Break a block in Tutorial Hall, shrink in-place -> delta appears in parent layer 0
    init_new_game();
    st.screen = SCREEN_PLAY;
    break_block_at(6, 2, 9);
    expect(if get_block(6, 2, 9) == BLK_AIR { 1 } else { 0 }, "Tutorial crate broken at (6,2,9)");
    st.px = 9.5; st.py = 3.2; st.pz = 6.2;
    st.ring_cd_ms = 0;
    shrink_into_ex(9, 3, 6, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    expect(if get_parent_block(0, 6, 2, 9) == BLK_AIR { 1 } else { 0 }, "Parent layer 0 reflects broken Tutorial crate delta");

    // 3) 256x Pink Deep Dive inside air keeps Tutorial biome and populates 3 parent layers (depth 1, 0, -1)
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 3, 3, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    expect(if st.depth == 2 && cur_biome() == BIOME_TUTORIAL && st.parent_valid[2] == 1 { 1 } else { 0 }, "2-level air shrink keeps Tutorial biome and 3 valid parent layers");
    expect(if get_parent_block(2, 8, 7, 8) == BLK_YING_PLANET { 1 } else { 0 }, "Parent layer 2 exposes Ying Planet in Outer Space");

    // 4) Continuous 6-face grow-out from air subchunk lands right at voxel (9,3,6) edge
    let ex_x = [ -0.1, 16.1, 8.0, 8.0, 8.0, 8.0 ];
    let ex_y = [ 8.0, 8.0, -0.1, 16.1, 8.0, 8.0 ];
    let ex_z = [ 8.0, 8.0, 8.0, 8.0, -0.1, 16.1 ];
    var f: i32 = 0;
    while f < 6 {
        init_new_game();
        st.screen = SCREEN_PLAY;
        st.px = 9.5; st.py = 3.2; st.pz = 6.2;
        st.ring_cd_ms = 0;
        shrink_into_ex(9, 3, 6, BLK_AIR, -1, 1, st.px, st.py, st.pz);
        st.ring_cd_ms = 0;
        grow_out_axis(ex_x[f], ex_y[f], ex_z[f]);
        expect(if st.depth == 0 && st.px >= 8.9 && st.px <= 10.1 && st.py >= 2.9 && st.py <= 4.1 && st.pz >= 5.9 && st.pz <= 7.1 { 1 } else { 0 }, "Air subchunk 6-face grow returns continuously to parent voxel (9,3,6)");
        f = f + 1;
    }

    // 5) Face-preserving solid block entry
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 2, 9, BLK_BLACK_CUBE, -1, 1, 8.5, 2.5, 8.7);
    expect(if st.depth == 1 && st.pz < 3.5 { 1 } else { 0 }, "Approaching Black Cube from -Z lands near -Z face inside child");

    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 2, 9, BLK_BLACK_CUBE, -1, 1, 9.3, 2.5, 9.5);
    expect(if st.depth == 1 && st.px > 12.5 { 1 } else { 0 }, "Approaching Black Cube from +X lands near +X face inside child");

    // 6) Black Cube generates authentic 3D Menger Sponge with open center shafts on all 6 faces
    st.ring_cd_ms = 0;
    shrink_into(13, 2, 9, BLK_BLACK_CUBE, BIOME_BLACK_CUBE, 1);
    expect(if cur_biome() == BIOME_BLACK_CUBE { 1 } else { 0 }, "Entered BIOME_BLACK_CUBE");
    expect(if get_block(7, 7, 0) == BLK_AIR && get_block(0, 7, 7) == BLK_AIR && get_block(7, 15, 7) == BLK_AIR { 1 } else { 0 }, "Menger Sponge Black Cube has open shafts on faces");
    expect(if get_block(1, 1, 1) == BLK_BLACK_CUBE { 1 } else { 0 }, "Menger Sponge solid lattice corners exist");

    // 7) Pressing F (use_nearest) at Tutorial spawn activates the nearby Green Shrink Ring in-place
    init_new_game();
    st.screen = SCREEN_PLAY;
    use_nearest();
    expect(if st.screen == SCREEN_PLAY && st.depth == 1 && cur_parent_block() == BLK_AIR && cur_biome() == BIOME_TUTORIAL { 1 } else { 0 }, "use_nearest at Tutorial spawn shrinks 16x in-place via Green Ring");
}

fn count_solid_blocks() -> i32 {
    let st = core();
    var cnt: i32 = 0;
    var i: i32 = 0;
    while i < CHUNK_VOL {
        if st.blocks[i] != BLK_AIR { cnt = cnt + 1; }
        i = i + 1;
    }
    return cnt;
}

fn test_sibling_air_traversal_and_air_atoms() {
    let st = core();
    st.genesis_mode = 0;

    // 1) Stay shrunk when flying across multiple sibling air subchunks (East/West/Up)
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.px = 7.2; st.py = 3.2; st.pz = 5.2;
    st.ring_cd_ms = 0;
    shrink_into_ex(7, 3, 5, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    expect(if st.depth == 1 && st.parent_bx[0] == 7 { 1 } else { 0 }, "Shrank at parent voxel (7,3,5)");

    // Fly +X across 2 full sibling chunks (36 steps) -> enters parent_bx 8 then 9 while STILL at depth = 1!
    var step: i32 = 0;
    while step < 36 {
        st.vx = 12.0; st.vy = 0.0; st.vz = 0.0;
        step_simulation(100);
        step = step + 1;
    }
    expect(if st.depth == 1 && cur_parent_block() == BLK_AIR && st.parent_bx[0] >= 9 { 1 } else { 0 }, "Flying across sibling air edges stays at depth=1 and updates parent_bx");

    // 2) Hitting Tutorial Hall thick wall jamb (x=11, y=3.2, z=3.2, away from 6..9 center tunnel) stops cleanly
    step = 0;
    while step < 25 {
        st.vx = 12.0; st.vy = 0.0; st.vz = 0.0;
        step_simulation(100);
        step = step + 1;
    }
    expect(if st.depth == 1 && st.parent_bx[0] == 10 && st.vx == 0.0 { 1 } else { 0 }, "Macro Tutorial wall jamb at x=11 stops shrunken player at parent_bx=10 without growing");

    // 3) Manual [V] (grow_in_place) grows back 16x from air cleanly
    grow_in_place();
    expect(if st.depth == 0 && st.px >= 10.0 && st.px < 11.1 { 1 } else { 0 }, "grow_in_place [V] returns to depth=0 at continuous wall position");

    // 4) Multi-level carry across depth=1 -> depth=0 parent boundary at depth=2 (air_depth=2)
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.px = 8.5; st.py = 4.5; st.pz = 6.5;
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 4, 6, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    st.ring_cd_ms = 0;
    shrink_into_ex(15, 8, 8, BLK_AIR, -1, 1, 15.8, 8.5, 8.5);
    expect(if st.depth == 2 && compute_air_depth(2) == 2 { 1 } else { 0 }, "Double air shrink sets depth=2 and air_depth=2");
    st.px = 15.8; st.py = 8.5; st.pz = 8.5;
    st.vx = 10.0; st.vy = 0.0; st.vz = 0.0;
    step_simulation(100);
    expect(if st.depth == 2 && st.parent_bx[0] == 0 && st.parent_bx[1] == 9 { 1 } else { 0 }, "Multi-level air carry wraps parent_bx[0]=0 and increments parent_bx[1]=9 while staying at depth=2");

    // 5) Progressive microscopic air-atom density: air_depth 1 < 2 < 3 < 4
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 4, 6, BLK_AIR, -1, 1, 8.5, 4.5, 6.5);
    let c1 = count_solid_blocks();
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 8, 8, BLK_AIR, -1, 1, 8.5, 8.5, 8.5);
    let c2 = count_solid_blocks();
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 8, 8, BLK_AIR, -1, 1, 8.5, 8.5, 8.5);
    let c3 = count_solid_blocks();
    st.ring_cd_ms = 0;
    shrink_into_ex(8, 8, 8, BLK_AIR, -1, 1, 8.5, 8.5, 8.5);
    let c4 = count_solid_blocks();
    expect(if c1 == 2 && c2 > c1 && c3 > c2 && c4 > c3 { 1 } else { 0 }, "Air atom/molecule density increases monotonically across air_depth 1..4");

    // 6) Inward portal preview returns nested child chunk blocks (Tutorial Black Cube -> Ying Forest grass)
    init_new_game();
    st.screen = SCREEN_PLAY;
    let inner_grass = get_inward_preview_block(8, 2, 9, BLK_BLACK_CUBE, 8, 1, 8);
    let inner_air = get_inward_preview_block(8, 2, 9, BLK_BLACK_CUBE, 8, 8, 8);
    expect(if inner_grass == BLK_GRASS && inner_air == BLK_AIR { 1 } else { 0 }, "Inward portal preview exposes Ying Forest floor & sky inside Black Cube");

    // 7) grow_in_place [V] from solid Black Cube exits cleanly above/outside the cube
    st.ring_cd_ms = 0;
    shrink_into(8, 2, 9, BLK_BLACK_CUBE, -1, 1);
    expect(if st.depth == 1 && cur_parent_block() == BLK_BLACK_CUBE { 1 } else { 0 }, "Inside solid Black Cube");
    grow_in_place();
    expect(if st.depth == 0 && point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "grow_in_place [V] from solid Black Cube exits collision-free to depth=0");
}

fn test_v3_thick_walls_3d_holes_and_physical_entry() {
    let st = core();
    st.genesis_mode = 0;

    // 1) [F] does NOT teleport into Black Cube at depth=0; [B] shrinks in air and allows round-trip archway flight
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.px = 8.5; st.py = 3.2; st.pz = 8.4;
    use_nearest();
    expect(if st.depth == 0 { 1 } else { 0 }, "use_nearest [F] no longer touch-warps into Black Cube");

    shrink_targeted_block();
    expect(if st.depth == 1 && cur_parent_block() == BLK_AIR { 1 } else { 0 }, "[B] shrinks 16x in air near Black Cube");

    // Aim at solid wall jamb x=2.5 (outside x=6..9 archway) -> blocked by 2-thick perimeter!
    st.px = 2.5; st.py = 3.2; st.pz = 15.6;
    var step: i32 = 0;
    while step < 10 {
        st.vx = 0.0; st.vy = 0.0; st.vz = 8.0;
        step_simulation(50);
        step = step + 1;
    }
    expect(if cur_parent_block() == BLK_AIR && st.parent_bz[0] == 8 && st.vz == 0.0 { 1 } else { 0 }, "Solid 2-thick Black Cube wall jamb blocks off-center entry");

    // Align with x=8.0, y=4.0 inside x=6..9 archway -> flies physically into Ying Forest, then flies back out -Z staying at depth=1!
    st.px = 8.0; st.py = 4.0; st.pz = 15.5;
    step = 0;
    while step < 12 && cur_parent_block() == BLK_AIR {
        st.vx = 0.0; st.vy = 0.0; st.vz = 8.0;
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 1 && cur_parent_block() == BLK_BLACK_CUBE && cur_biome() == BIOME_YING_FOREST { 1 } else { 0 }, "Steered flight through Black Cube archway enters Ying Forest at depth=1");

    // Fly back -Z through Ying Forest archway -> exits back into Tutorial Hall air while staying shrunk at depth=1!
    st.px = 8.0; st.py = 4.0; st.pz = 0.5;
    step = 0;
    while step < 12 && cur_parent_block() == BLK_BLACK_CUBE {
        st.vx = 0.0; st.vy = 0.0; st.vz = -8.0;
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 1 && cur_parent_block() == BLK_AIR && cur_biome() == BIOME_TUTORIAL { 1 } else { 0 }, "Flying back out archway stays shrunk at depth=1 in Tutorial air");

    // 2) Generic small world block (BLK_WALL_TUT) has 2-3 thick shell, open 4x4 tunnel, ribs, gold pedestal, and 2-level micro-holes
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.ring_cd_ms = 0;
    shrink_into(11, 3, 5, BLK_WALL_TUT, -1, 1);
    expect(if st.depth == 1 && cur_biome() == BIOME_TUTORIAL { 1 } else { 0 }, "BLK_WALL_TUT preserves Tutorial biome");
    expect(if get_block(0, 8, 8) == BLK_AIR && get_block(1, 8, 8) == BLK_AIR && get_block(15, 8, 8) == BLK_AIR { 1 } else { 0 }, "BLK_WALL_TUT pierces open 4x4 3D tunnel through thick walls");
    expect(if get_block(0, 1, 1) == BLK_WALL_TUT && get_block(1, 1, 1) != BLK_AIR { 1 } else { 0 }, "BLK_WALL_TUT has 2-3 voxel thick solid outer girth");
    expect(if get_block(8, 2, 8) == BLK_GOLD_ORE || get_block(8, 3, 8) == BLK_GOLD_ORE { 1 } else { 0 }, "BLK_WALL_TUT has internal Gold Ore pedestal for visible depth");
    expect(if get_block(2, 2, 0) == BLK_AIR && get_block(2, 2, 1) == BLK_ALPHA_CUBE && get_block(14, 12, 12) == BLK_BLACK_CUBE { 1 } else { 0 }, "BLK_WALL_TUT wall alcove hides 2-level micro-hole targets");

    // Tutorial Hall 2-thick walls expose inner alcoves for Alpha Cube & Black Cube
    init_new_game();
    st.screen = SCREEN_PLAY;
    expect(if get_block(5, 3, 4) == BLK_AIR && get_block(4, 3, 4) == BLK_ALPHA_CUBE && get_block(11, 3, 10) == BLK_AIR && get_block(12, 3, 10) == BLK_BLACK_CUBE { 1 } else { 0 }, "Tutorial Hall 2-thick walls expose recessed 2-level alcoves inside room");

    // 3) Shrunken player in air aligned at (8.0, 8.0) flies physically into BLK_WALL_TUT 4x4 tunnel!
    init_new_game();
    st.screen = SCREEN_PLAY;
    st.px = 10.5; st.py = 3.5; st.pz = 5.5;
    st.ring_cd_ms = 0;
    shrink_into_ex(10, 3, 5, BLK_AIR, -1, 1, st.px, st.py, st.pz);
    st.px = 15.6; st.py = 8.0; st.pz = 8.0;
    step = 0;
    while step < 12 && cur_parent_block() == BLK_AIR {
        st.vx = 8.0; st.vy = 0.0; st.vz = 0.0;
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 1 && st.parent_bx[0] == 11 && cur_parent_block() == BLK_WALL_TUT { 1 } else { 0 }, "Shrunken player flies physically into small BLK_WALL_TUT 4x4 3D tunnel");

    // 4) Subchunk 3D lookup matches Ying Forest 2-thick walls & 4x8 archway from parent depth=0
    init_new_game();
    st.screen = SCREEN_PLAY;
    expect(if get_subchunk_block(cur_seed(), 0, BIOME_TUTORIAL, 8, 3, 9, BLK_BLACK_CUBE, 8, 3, 0) == BLK_AIR { 1 } else { 0 }, "get_subchunk_block exposes Black Cube open archway");
    expect(if get_subchunk_block(cur_seed(), 0, BIOME_TUTORIAL, 8, 3, 9, BLK_BLACK_CUBE, 2, 3, 1) == BLK_BLACK_CUBE { 1 } else { 0 }, "get_subchunk_block exposes 2-thick Black Cube wall jamb");
    expect(if get_subchunk_block(cur_seed(), 0, BIOME_TUTORIAL, 11, 3, 5, BLK_WALL_TUT, 0, 8, 8) == BLK_AIR && get_subchunk_block(cur_seed(), 0, BIOME_TUTORIAL, 11, 3, 5, BLK_WALL_TUT, 1, 1, 1) != BLK_AIR { 1 } else { 0 }, "get_subchunk_block exposes thick wall + 4x4 hole on BLK_WALL_TUT");
}

fn test_v4_lod_and_scale_gated_holes() {
    // 1) Level 0 never exposes 3D sub-voxel holes on any block or layer
    expect(if should_render_hole_lod(0, 0, BLK_WALL_TUT, 2.0) == 0 && should_render_hole_lod(0, 0, BLK_BLACK_CUBE, 2.0) == 0 && should_render_hole_lod(0, 1, BLK_BLACK_CUBE, 2.0) == 0 { 1 } else { 0 }, "Level 0 hides all 3D sub-voxel holes for clean solid blocks");

    // 2) Same-scale Layer 0 blocks stay crisp and solid at any shrink depth
    expect(if should_render_hole_lod(1, 0, BLK_BLACK_CUBE, 1.5) == 0 && should_render_hole_lod(3, 0, BLK_WALL_TUT, 1.5) == 0 { 1 } else { 0 }, "Layer 0 same-scale blocks never render noisy sub-voxel holes");

    // 3) At shallow shrink (depth=1..2), shrinkable blocks show close entrance holes while regular world blocks remain solid
    expect(if should_render_hole_lod(1, 1, BLK_BLACK_CUBE, 12.0) == 1 && should_render_hole_lod(1, 1, BLK_BLACK_CUBE, 40.0) == 0 { 1 } else { 0 }, "Layer 1 shrinkable portal blocks reveal close holes and fade via LOD at distance");
    expect(if should_render_hole_lod(1, 1, BLK_WALL_TUT, 8.0) == 0 && should_render_hole_lod(2, 2, BLK_GRASS, 12.0) == 0 { 1 } else { 0 }, "Regular world blocks stay clean & solid at depth < 3 on layers 1-2");

    // 4) Very small depth >= 3 (or hit_layer >= 3) reveals 3D holes on regular blocks with distance LOD
    expect(if should_render_hole_lod(3, 1, BLK_WALL_TUT, 12.0) == 1 && should_render_hole_lod(3, 1, BLK_WALL_TUT, 28.0) == 0 { 1 } else { 0 }, "At depth=3, regular Layer 1 blocks reveal close holes and cull far holes");
    expect(if should_render_hole_lod(3, 2, BLK_WALL_TUT, 40.0) == 1 && should_render_hole_lod(3, 2, BLK_WALL_TUT, 120.0) == 0 { 1 } else { 0 }, "Layer 2 (16x) holes obey 84.0 distance LOD");
    expect(if should_render_hole_lod(3, 3, BLK_WALL_TUT, 120.0) == 1 && should_render_hole_lod(3, 3, BLK_WALL_TUT, 300.0) == 0 { 1 } else { 0 }, "Layer 3 (256x) holes render up close and cull past 260.0 LOD");
}

extern fn exit_proc(code: i32) = "exit";

fn main() {
    test_tutorial_and_fractal_scaling();
    test_infinite_depth_and_early_peacefulness();
    test_weapons_and_physics();
    test_economy_markers_and_respawn();
    test_in_place_shrink_and_parent_layers();
    test_sibling_air_traversal_and_air_atoms();
    test_v3_thick_walls_3d_holes_and_physical_entry();
    test_v4_lod_and_scale_gated_holes();

    print("FBW Core Tests: ");
    print(g_pass);
    print(" passed, ");
    print(g_fail);
    print(" failed.\n");
    if g_fail > 0 { exit_proc(1); }
}
