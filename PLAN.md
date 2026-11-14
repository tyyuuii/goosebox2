# PLAN.md — Conway's Game of Life in Goose using termbox2.goose

## Goal

Build `cgol.goose` — a terminal-based Conway's Game of Life that runs on top of the existing `termbox2.goose` port. The program renders each generation to the terminal, supports interactive cell editing, pattern placement, pause/step, auto-run, and resizes cleanly. It must compile cleanly with `goose check cgol.goose` and build with `goose build cgol.goose -o cgol` (linking `adapter.c` via `cgol.build`).

---

## Research summary (sources that informed this plan)

| Source | Key takeaway applied |
|--------|----------------------|
| Rules (howtopython, kousen/gameoflife) | Classic B3/S23: live cell survives with 2–3 neighbors; dead cell born with exactly 3; everything else dies/stays dead. |
| x2c termbox2 example | Double buffering: two grids (current/next), swap each generation. Toroidal wrapping via modulo on both axes. `tb_clear()` → draw → `tb_present()`. `tb_peek_event(80)` waits ~80ms for input then advances. |
| peterhellberg/life (termbox-go) | Interactive controls: HJKL/arrows move a cursor, `x`/click toggles a cell, `space` steps, `enter` toggles auto-run, `c` clears, `q`/ESC quits, letter keys place named patterns (glider, block, blinker, gosper gun, acorn, diehard, r-pentomino, loafer, LWSS). |
| nbu/go-life | Fixed (boarded) grid sized to terminal width/height; infinite/sparse optional. We choose fixed boarded grid (simpler, fits Goose data-stack model). |

---

## Goose-language constraints respected (from agents.md + termbox2.goose)

- No heap/GC/malloc/free. One resizable value per stack; `root struct` globals may own multiple resizable fields.
- `extern fn` cannot be variadic → we only call existing `termbox2.goose` functions (already declared against `adapter.c`), no new FFI needed.
- `match` is a keyword → name local variables `matched`, never `match`.
- `let c = cell_at(...)` copies; `let c .= cell_at(...)` binds by reference.
- Build with `goose build` (not `goose run`) so `adapter.c` links.
- `gbl()` returns `tb_global&`; don't mutate resizable fields through a reference while other borrows exist.
- `tb_init()` returns `TB_ERR_INIT_OPEN` (-4) without a real TTY — test in Termux, not in Pi-Bolt.

---

## Design

### 1. World representation

Two flattened 1D `u8[>..]` grids, indexed as `y * width + x`. Each cell holds `0` (dead) or `1` (alive). Grid dimensions come from `tb_width()`/`tb_height()` at init and on resize.

A `root struct cgol_world` owns both grids (multiple resizables allowed on a root struct):

```goose
root struct cgol_world {
    width: i32,
    height: i32,
    cur: u8[>..],     // current generation
    nxt: u8[>..],     // next generation
    gen: i64,         // generation counter
    running: i32,     // auto-run on/off
    cx: i32,          // cursor x
    cy: i32,          // cursor y
    speed_ms: i32,    // peek timeout (animation speed)
}
var world: cgol_world;
```

### 2. Core functions

| Function | Purpose |
|----------|---------|
| `cgol_init()` | Call `tb_init()`, read term size, allocate `cur`/`nxt` to `width*height`, randomize ~50% alive, hide cursor, set `running=1`, `speed_ms=100`. |
| `cgol_shutdown()` | Call `tb_shutdown()`. |
| `cgol_index(x, y)` | Return `y * width + x` (helper). |
| `cgol_neighbors(x, y)` | Sum 8 neighbors with toroidal wrapping: `((y+dy+height)%height)*width + ((x+dx+width)%width)`. |
| `cgol_step()` | Read `cur`, write `nxt` using B3/S23, then swap `cur`/`nxt` references, increment `gen`. |
| `cgol_draw()` | `tb_clear()`, then for each alive cell `tb_set_cell(x, y, '█', TB_GREEN|TB_BOLD, TB_DEFAULT)`, draw cursor cell distinctively, `tb_present()`. |
| `cgol_toggle(x, y)` | Flip cell at `(x,y)` in `cur`. |
| `cgol_place_pattern(name, x, y)` | Stamp a named pattern (glider, blinker, block, etc.) with origin at cursor. |
| `cgol_clear()` | Zero `cur`. |
| `cgol_randomize()` | Fill `cur` with ~50% random cells. |

### 3. Predefined patterns (from peterhellberg/life research)

Stored as small fixed `i32` arrays of `{dx, dy}` offsets relative to origin:

- **glider** (3×3): `{(1,0),(2,1),(0,2),(1,2),(2,2)}`
- **blinker** (3×1): `{(0,1),(1,1),(2,1)}`
- **block** (2×2): `{(0,0),(1,0),(0,1),(1,1)}`
- **beehive**, **loaf**, **boat**, **tub**, **toad**, **beacon**, **r-pentomino**, **acorn**, **diehard**, **lightweight spaceship (LWSS)**
- **gosper glider gun** — optional large pattern (36×9), include if space permits.

### 4. Input handling

Main loop uses `tb_peek_event(&event, world.speed_ms)` so animation advances automatically when no key is pressed, but input is still responsive.

Keys:
- `q` / `ESC` → quit
- `SPACE` → if running: pause; else single step
- `ENTER`/`r` → toggle auto-run
- `c` → clear grid, reset gen
- `R` → randomize
- `g` → place glider at cursor; `b` → block; `B` → blinker; `t` → toad; `p` → r-pentomino; `a` → acorn; `d` → diehard; `l` → LWSS; `G` → gosper gun
- `h`/`LEFT` → cursor left; `j`/`DOWN` → down; `k`/`UP` → up; `l`/`RIGHT` → right (clamped to bounds)
- `x` / left-click → toggle cell at cursor

Mouse: termbox2 reports `TB_EVENT_MOUSE`; on left-click toggle the clicked cell.

### 5. Resize handling

On `TB_EVENT_RESIZE`, update `world.width`/`world.height` from `tb_width()`/`tb_height()`, reallocate `cur`/`nxt` to the new size, clear, and `tb_invalidate()` so the next `tb_present()` redraws everything.

### 6. Build files to create

| File | Contents |
|------|----------|
| `cgol.goose` | Full program (world, rules, draw, input, main loop). |
| `cgol.build` | `c_sources = []; c_headers = [];` (no new C — reuses `termbox2.build`'s `adapter.c`). Actually termbox2 is a library with no main; we link against its compiled object. Verify how termbox2.build is used for a consumer program. |
| `PLAN.md` | This document. |

> Note: `termbox2.build` declares `c_sources = ["adapter.c"]`. A consumer program `cgol.goose` that imports nothing from termbox2 as a Goose module (it just #includes via the build config) needs its own `.build` listing `adapter.c` as a c_source, OR termbox2.goose must be compiled together. Confirm the build composition; simplest robust approach: `cgol.build` lists `c_sources = ["adapter.c"]; c_headers = ["adapter.h"];` so `adapter.c` compiles into the cgol binary, and `cgol.goose` declares the same `extern fn` set it needs (or reuses termbox2's declarations — but Goose has no import/namespace for extern fns, so redeclare needed ones).

### 7. Build & test verification

```
goose check cgol.goose        # typecheck, expect no output
goose build cgol.goose -o cgol  # links adapter.c, produces ~100KB binary
./cgol                        # run in a real TTY (Termux), not Pi-Bolt
```

### 8. Milestones (check off as done)

- [ ] `cgol.build` created, `goose check cgol.goose` passes
- [ ] World init + shutdown + randomize works
- [ ] `cgol_step()` applies B3/S23 correctly (glider moves, blinker oscillates)
- [ ] `cgol_draw()` renders grid + cursor
- [ ] Input loop: quit, pause/step, toggle run, clear, randomize
- [ ] Cursor movement (HJKL/arrows) clamped to bounds
- [ ] Cell toggle via `x` / click
- [ ] Pattern placement: glider, block, blinker, toad, r-pentomino, acorn, diehard, LWSS
- [ ] Resize event reallocates grids and redraws
- [ ] No memory/borrow violations under Goose checker
- [ ] Runs smoothly in Termux at ~10 FPS (speed_ms ~100)

---

## Notes on Goose-specific risks

- **One resizable per stack**: `cur` and `nxt` live in `cgol_world` (a root struct global), so this rule does not apply to them. Avoid declaring additional `u8[>..]` locals inside hot functions.
- **Reference stability**: When swapping `cur`/`nxt`, rebind via `world.cur .= world.nxt` style or swap the `u8[>..]` values carefully — since they're struct fields of a root struct, assignment copies the reference (pointer), not the elements. This is O(1) and safe.
- **`tb_set_cell` takes `const u32&` for `ch` in `tb_set_cell_ex`**; use `tb_set_cell(x, y, 0x2588, fg, bg)` where `0x2588` is '█' (full block). For a plain ASCII fallback use `'#'` (0x23).
- **`tb_peek_event` timeout**: pass `world.speed_ms`; a negative value blocks. Use positive so the loop auto-advances.

---

## Inspiration credit

This plan is informed by:
- x2c termbox2 Game of Life example (double buffering, toroidal wrap, `tb_peek_event` timing)
- peterhellberg/life (termbox-go) — controls, pattern library, cursor editing
- nbu/go-life — boarded fixed grid
- Classic Conway rules B3/S23
