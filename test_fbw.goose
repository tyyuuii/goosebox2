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

fn test_tutorial_and_fractal_scaling() {
    init_new_game();
    let st = core();
    st.screen = SCREEN_PLAY;
    expect(if st.depth == 0 { 1 } else { 0 }, "starts at depth 0");
    expect(if st.stack[MACRO_OFFSET].biome == BIOME_TUTORIAL { 1 } else { 0 }, "starts in BIOME_TUTORIAL");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "spawn is collision-free");
    expect(if get_block(8, 2, 9) == BLK_BLACK_CUBE { 1 } else { 0 }, "Tutorial Black Cube ahead");

    // 1) Fly forward (+Z) into the Tutorial Black Cube -> shrinks to depth 1 (Ying Forest)
    st.ring_cd_ms = 0;
    var step: i32 = 0;
    while step < 30 && st.depth == 0 {
        apply_thrust(0.0, 0.0, 3.0);
        step_simulation(50);
        step = step + 1;
    }
    expect(if st.depth == 1 { 1 } else { 0 }, "touching Tutorial Black Cube shrinks to depth 1");
    expect(if st.stack[1 + MACRO_OFFSET].biome == BIOME_YING_FOREST { 1 } else { 0 }, "Tutorial Black Cube opens Ying Forest");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "Ying Forest spawn is collision-free");

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
    expect(if st.stack[-1 + MACRO_OFFSET].biome == BIOME_SPACE { 1 } else { 0 }, "depth -1 biome is BIOME_SPACE");
    expect(if get_block(13, 8, 12) == BLK_MYLANTIS_M { 1 } else { 0 }, "Mylantis M block exists in Outer Space");
    expect(if point_collides(st.px, st.py, st.pz) == 0 { 1 } else { 0 }, "Outer Space exit is collision-free outside Ying Planet");

    // 4) Pink Ring 256x dive skips 2 levels at once
    st.ring_cd_ms = 0;
    shrink_into(13, 8, 12, BLK_MYLANTIS_M, BIOME_MYLANTIS, 2);
    expect(if st.depth == 1 { 1 } else { 0 }, "2-step 256x shrink from -1 lands at depth 1");
}

fn test_weapons_and_physics() {
    init_new_game();
    let st = core();
    st.screen = SCREEN_PLAY;

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
    init_new_game();
    let st = core();
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

    // Black Market discounted Railgun
    let r_before = st.ammo[WEP_RAILGUN];
    handle_black_market_action(1);
    expect(if st.gold == 85 && st.ammo[WEP_RAILGUN] > r_before { 1 } else { 0 }, "Black Market sells discounted Railgun ammo");

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

extern fn exit_proc(code: i32) = "exit";

fn main() {
    test_tutorial_and_fractal_scaling();
    test_weapons_and_physics();
    test_economy_markers_and_respawn();

    print("FBW Core Tests: ");
    print(g_pass);
    print(" passed, ");
    print(g_fail);
    print(" failed.\n");
    if g_fail > 0 { exit_proc(1); }
}
