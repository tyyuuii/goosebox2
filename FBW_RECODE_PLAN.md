# FBW_RECODE_PLAN.md — Faithful Recode Plan for `fbw.goose` (Fractal Block World / Xar)

## 1. Gap Analysis: Current `fbw.goose` vs Original *Fractal Block World* (Xar)

The current `fbw.goose` prototype implements a 24-bit truecolor half-block 3D DDA raycaster on top of `termbox2.goose`, but diverges substantially from Dan Hathaway's *Fractal Block World* (Xar):

| Area | Current `fbw.goose` | Original *Fractal Block World* (Xar) |
|---|---|---|
| **Shrinking & Growing** | Only via floating billboard rings (`E`) or flying straight up (`py > 15.6`); `px`/`pz` are hard-clamped inside `[0.35, 15.65]`. | **Leaving ANY of the 6 chunk faces** (`x, y, z < 0` or `>= 16`) grows `16×` outward into the parent chunk at the corresponding parent face; **entering shrinkable fractal blocks/portals** (plus Green `16×`, Pink `256×`, Blue teleporter rings) shrinks deeper. |
| **Starting World** | Generic clearing in `Ying Forest` with invented `Core Guardian` & `K's Core Beacon`. | Starts in the **Tutorial Room / Tutorial Island** (`LVL 0`) with the iconic **Tutorial Black Cube** (containing an accessible Ying Forest), **Small White Flower** (containing an **Alpha Cube**), and outer exit to **Outer Space (`LVL -1`)** where **Mylantis** (orange `M` block) & planets float. |
| **Biomes & Progression** | 7 generic rooms (`Macro Garden`, `Ying Forest`, etc.). | Authentic Xar progression: **Tutorial Island** -> **Outer Space** / **Ying Forest** -> **Small White Flower (Alpha Cube)** -> **Yellow Flowers (Small & Jumbo)** -> **Mylantis Crust & Caves** -> **Black Cube / I1 / I2 / I3** -> **The Core (Singularity & K)**. |
| **Weapons (`1..9, 0`)** | Only 6 weapons (`1..6`), no secondary fire (`RMB` mapped to interact), no recoil physics. | **10 weapons** (`1` Plasma, `2` Cannon, `3` Laser, `4` Rocket, `5` Homing, `6` Minigun, `7` Railgun, `8` EMP, `9` Nuke, `0` Dark Hole), **Primary (`LMB`/`Enter`) & Secondary (`RMB`/`R`) fire**, Laser/EMP **enemy freeze**, Homing **target seeking**, Dark Hole **gravity pull**, **Quasar Drive**, and **Recoil Boosting** (Railgun, Nuke, Dark Hole). |
| **Flight & Controls** | Snap-step `0.42` movement per keypress, no momentum, `Q` quits, `U` opens global anywhere-shop. | Smooth **velocity + drag 6-DOF flight**, **Rocket Mode (`Tab`)** low-drag momentum, **Brake (`X`)**, **Camera Roll (`Q`/`E`)** with **True Up (`U`)** toggle, **`F` Use**, **`T` Telekinesis**, **`M`/`N` Short & Long Markers**, **`F1`–`F5` Info Screens**. |
| **Economy & Upgrades** | Single `U` shop modal accessible anywhere. | **In-world Upgrade Blocks** (`+Max HP`, `+HP Regen`, `+Max Armor`, `+Damage`, `+Fire Rate`, `+Ammo Cap`, `+Speed`), **Buy Stations**, **Sell Stations** (sell excess HP/Armor for Gold), **Black Markets** (cheaper Rail/EMP/Nuke/Dark Hole ammo), **Gold cap 1,000,000**, **-30 Gold death respawn** without wiping progress, **Keys & Locked Vaults**, and **Lore Tomes**. |
| **Enemies** | Generic Goblin, Slime, Turret, Warden, Boss. | Xar Monster Manual roster: **Goblin**, **Marine**, **Pirate**, **Spider**, **Rat**, **Menace**, **Yin Yang**, **Demon**, **Guardian (Pool Ball)**, and **The Singularity** (starting mid-game after peaceful Tutorial, Space `-1`, Ying Forest `1`, and Alpha Cube `2`; plus optional **Genesis Mode**). |
| **Code Structure** | Single 2,735-line monolithic file; no unit tests. | Modular split: `fbw_core.goose` (pure world, unbounded `-128..3000` fractal stack, combat, AI, economy, markers), `fbw.goose` (termbox2 3D DDA renderer, roll camera, HUD, `F1–F5` & station UIs), and `test_fbw.goose` (deterministic unit & simulation tests). |

---

## 2. Goose Language & `termbox2.goose` Constraints

1. **Preallocated Pools + Expandable Stack:** Fixed-size arrays inside `root struct fbw_state` handle `16×16×16` chunks, entities, shots, and framebuffers with zero per-frame allocation, while dynamic `[>..]` `pos_stack` / `neg_stack` / `marker_frames` allow shrinking up to **3,000 levels deep**.
2. **Terminal Input Constraints:**
   - Bare `Shift` does not produce a standalone event in terminals, so **Fly Down** binds `C`, `Z`, and `PgDn` (alongside `Space`/`PgUp` for Fly Up).
   - **`Q` cannot quit during play** because `Q`/`E` control **Camera Roll**; quitting uses `Esc` -> Pause menu `[Q]`, or `Ctrl+Q` / `Ctrl+C`.
   - **`F1`–`F5`** are natively decoded by `termbox2.goose` (`TB_KEY_F1`..`TB_KEY_F5`) and work cleanly for Xar's 5 info overlays.
3. **24-bit Truecolor + 256-Color Half-Block Renderer:** Preserves `CH_HALF_TOP` (`▀`) 2x vertical pixel resolution with `TB_OUTPUT_TRUECOLOR` and instant `V` toggle to `TB_OUTPUT_256`.

---

## 3. Target Architecture

### Module Split
1. **`fbw_core.goose`** — Pure simulation & fractal universe engine (no `termbox2` dependency so it compiles and tests standalone):
   - `16×16×16` unbounded recursive chunk stack (`MAX_NEG_DEPTH = -128`, `MAX_POS_DEPTH = 3000`), bidirectional **Grow on any of the 6 chunk boundaries** + **Shrink into permeable fractal blocks / rings / `[B]` targeted block / `[H]` ShrinkAny**.
   - Deterministic `splitmix64` world generator for: **Tutorial Room/Island**, **Outer Space (Mylantis M-block, Ying Planets, Ice World, Desert World)**, **Ying Forest**, **Small White Flower / Alpha Cube**, **Yellow Flowers**, **Mylantis Crust/Caves**, **Black Cube / I1 / I2 / I3**, and **The Core (Singularity & K)**.
   - Peaceful early game (Tutorial, Space `-1`, Ying Forest `LVL 1`, Alpha Cube `LVL 2`) transitioning to enemies in mid-game (`Yellow Flower`, `Mylantis`, `Black Cube`, `Inner Core`), plus **Genesis Mode (`[G]`)** for peaceful exploration.
   - Persistent `BlockDelta` table (crates, spawners, locked doors, collected upgrade blocks, placed markers).
   - 10 weapons (`0..9`, starting with `1:Plasma` and unlocking `2..0` via Weapon Modules & Stations) with primary & secondary fire, ammo caps, recoil boost velocity, homing steering, EMP/Laser freeze timers, Dark Hole gravity pull, and Quasar Drive unlock.
   - 6-DOF velocity/drag physics, Rocket Mode, Brake, True Up + Roll, Telekinesis (`T`), Health Regen, Buy/Sell/Black Market transactions, Markers (`M`/`N`), and `-30` gold checkpoint respawn.
2. **`fbw.goose`** — `termbox2.goose` frontend:
   - True 3D camera basis supporting **Yaw, Pitch, and Roll (`Q`/`E` + `True Up`)**.
   - DDA raycaster with FBW's signature **crisp bordered blocks**, concentric fractal tile patterns, deep-depth (`500..2000`) gradual sky/block darkening, and outer-space starfield when rays exit open chunks.
   - Authentic FBW HUD: HP/Armor/Gold/Keys, 10-slot compact weapon strip with unlock state, Scale/Depth & `(X, Y, Z)` + Biome, Active Marker bearing/distance, Rocket/TrueUp/ShrinkAny/Genesis flags, and Target HP bar.
   - Interactive overlays: Title Screen (`Classic` & `Genesis Mode`), Buy Station, Sell Station, Black Market, Lore Tome reader, Pause menu, and **`F1`–`F5`** info modals.
3. **`test_fbw.goose`** — Automated Goose test binary verifying fractal grow/shrink on all 6 boundaries, 250–3,000 level deep shrinking, peaceful early biomes vs mid-game enemies & Genesis Mode, progressive weapon unlocks, all 10 weapons + secondary fire + recoil + EMP freeze + Dark Hole pull, Buy/Sell economy, `-30` gold respawn, and deep Markers.
