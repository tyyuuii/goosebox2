// sudoku.goose — rewritten Sudoku for Goose + termbox2, Termux-friendly
//
// Build:  goose build sudoku.goose -o sudoku
// Run:    ./sudoku
//
// Controls:
//   HJKL / WASD     move cursor
//   Arrow keys      may or may not work (see note below)
//   1-9             enter digit, or toggle note in notes mode
//   0 / Backspace   clear cell (clears notes in notes mode)
//   N               toggle notes mode
//   ? or /          hint (fills one cell from the solver's solution)
//   U               undo
//   R               redo
//   Space           new game (back to menu)
//   Q               quit
//
// Termux note: the termbox2 port does not send smkx on init, so arrow keys
// in normal mode emit CSI sequences the port doesn't recognise. The result
// is an ESC event. We therefore ignore ESC entirely and rely on HJKL/WASD.

import termbox2;

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

const MAX_HISTORY: i32 = 500;

// Box-drawing glyphs
const CH_H:  u32 = 0x2500;  // ─
const CH_V:  u32 = 0x2502;  // │
const CH_TL: u32 = 0x250C;  // ┌
const CH_TR: u32 = 0x2510;  // ┐
const CH_BL: u32 = 0x2514;  // └
const CH_BR: u32 = 0x2518;  // ┘
const CH_TT: u32 = 0x252C;  // ┬
const CH_BT: u32 = 0x2534;  // ┴
const CH_LT: u32 = 0x251C;  // ├
const CH_RT: u32 = 0x2524;  // ┤
const CH_X:  u32 = 0x253C;  // ┼
const CH_DOT: u32 = 0x00B7; // ·

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

struct Cell {
    value: i32,
    fixed: i32,
    notes: u16,
    error: i32,
}

struct Move {
    x: i32,
    y: i32,
    old_value: i32,
    old_notes: u16,
    new_value: i32,
    new_notes: u16,
}

struct Game {
    grid: Cell[81],
    solution: i32[81],
    has_solution: i32,
    cursor_x: i32,
    cursor_y: i32,
    notes_mode: i32,
    moves: i32,
    history: Move[MAX_HISTORY],
    history_len: i32,
    redo: Move[MAX_HISTORY],
    redo_len: i32,
    game_instance: i32,
}

var game: Game;

// ---------------------------------------------------------------------------
// Puzzles
// ---------------------------------------------------------------------------

const PUZZLE_EASY: i32[81] = [
    5,3,0, 0,7,0, 0,0,0,
    6,0,0, 1,9,5, 0,0,0,
    0,9,8, 0,0,0, 0,6,0,
    8,0,0, 0,6,0, 0,0,3,
    4,0,0, 8,0,3, 0,0,1,
    7,0,0, 0,2,0, 0,0,6,
    0,6,0, 0,0,0, 2,8,0,
    0,0,0, 4,1,9, 0,0,5,
    0,0,0, 0,8,0, 0,7,9,
];

const PUZZLE_MEDIUM: i32[81] = [
    0,0,0, 2,6,0, 7,0,1,
    6,8,0, 0,7,0, 0,9,0,
    1,9,0, 0,0,4, 5,0,0,
    8,2,0, 1,0,0, 0,4,0,
    0,0,4, 6,0,2, 9,0,0,
    0,5,0, 0,0,3, 0,2,8,
    0,0,9, 3,0,0, 0,7,4,
    0,4,0, 0,5,0, 0,3,6,
    7,0,3, 0,1,8, 0,0,0,
];

const PUZZLE_HARD: i32[81] = [
    0,0,0, 0,0,0, 0,0,0,
    0,0,0, 0,0,3, 0,8,5,
    0,0,1, 0,2,0, 0,0,0,
    0,0,0, 5,0,7, 0,0,0,
    0,0,4, 0,0,0, 1,0,0,
    0,9,0, 0,0,0, 0,0,0,
    5,0,0, 0,0,0, 0,7,3,
    0,0,2, 0,1,0, 0,0,0,
    0,0,0, 0,4,0, 0,0,9,
];

// Project Euler #96, puzzle 1 — known to have a unique solution.
const PUZZLE_EXPERT: i32[81] = [
    3,0,6, 5,0,8, 4,0,0,
    5,2,0, 0,0,0, 0,0,0,
    0,8,7, 0,0,0, 0,3,1,
    0,0,3, 0,1,0, 0,8,0,
    9,0,0, 8,6,3, 0,0,5,
    0,5,0, 0,9,0, 6,0,0,
    1,3,0, 0,0,0, 2,5,0,
    0,0,0, 0,0,0, 0,7,4,
    0,0,5, 2,0,6, 3,0,0,
];

// ---------------------------------------------------------------------------
// Solver (used to compute the reference solution; hints pull from it)
// ---------------------------------------------------------------------------

fn can_place(g: i32[81]&, x: i32, y: i32, val: i32) -> i32 {
    var i = 0;
    for i in 9 {
        if g[y * 9 + i] == val { return 0; }
        if g[i * 9 + x] == val { return 0; }
    }
    let bx = (x / 3) * 3;
    let by = (y / 3) * 3;
    var dy = 0;
    for dy in 3 {
        var dx = 0;
        for dx in 3 {
            if g[(by + dy) * 9 + (bx + dx)] == val { return 0; }
        }
    }
    return 1;
}

// Validate that a puzzle (with clues) follows Sudoku rules:
// no duplicate non-zero values in any row, column, or box.
fn validate_puzzle(g: i32[81]&) -> i32 {
    // Check rows
    var y = 0;
    for y in 9 {
        var seen: u16 = 0;
        var x = 0;
        for x in 9 {
            let val = g[y * 9 + x];
            if val != 0 {
                let bit: u16 = (1 as u64 << val) as u16;
                if seen & bit != 0 { return 0; }
                seen = seen | bit;
            }
        }
    }
    // Check columns
    var x = 0;
    for x in 9 {
        var seen: u16 = 0;
        var y = 0;
        for y in 9 {
            let val = g[y * 9 + x];
            if val != 0 {
                let bit: u16 = (1 as u64 << val) as u16;
                if seen & bit != 0 { return 0; }
                seen = seen | bit;
            }
        }
    }
    // Check boxes
    var by = 0;
    for by in 3 {
        var bx = 0;
        for bx in 3 {
            var seen: u16 = 0;
            var dy = 0;
            for dy in 3 {
                var dx = 0;
                for dx in 3 {
                    let pos = (by * 3 + dy) * 9 + (bx * 3 + dx);
                    let val = g[pos];
                    if val != 0 {
                        let bit: u16 = (1 as u64 << val) as u16;
                        if seen & bit != 0 { return 0; }
                        seen = seen | bit;
                    }
                }
            }
        }
    }
    return 1;
}

recursive fn solve_puzzle(g: i32[81]&, pos: i32) -> i32 {
    if pos >= 81 { return 1; }
    if g[pos] != 0 { return solve_puzzle(g, pos + 1); }
    let x = pos % 9;
    let y = pos / 9;
    var v = 1;
    for v in 1..10 {
        if can_place(g, x, y, v as i32) != 0 {
            g[pos] = v as i32;
            if solve_puzzle(g, pos + 1) != 0 { return 1; }
            g[pos] = 0;
        }
    }
    return 0;
}

// Seeded version: uses PRNG to shuffle digit try order at each step
recursive fn solve_puzzle_seeded(g: i32[81]&, pos: i32, prng_state: u64&) -> i32 {
    if pos >= 81 { return 1; }
    if g[pos] != 0 { return solve_puzzle_seeded(g, pos + 1, prng_state); }
    let x = pos % 9;
    let y = pos / 9;
    // Create shuffled digit order 1-9
    var digits: i32[9];
    var d = 0;
    for d in 9 { digits[d] = (d + 1) as i32; }
    var k = 8;
    while k > 0 {
        let r = (prng_next(prng_state) % (k + 1) as u64) as i32;
        let tmp = digits[k];
        digits[k] = digits[r];
        digits[r] = tmp;
        k = k - 1;
    }
    var v_idx = 0;
    for v_idx in 9 {
        let v = digits[v_idx];
        if can_place(g, x, y, v) != 0 {
            g[pos] = v;
            if solve_puzzle_seeded(g, pos + 1, prng_state) != 0 { return 1; }
            g[pos] = 0;
        }
    }
    return 0;
}

fn prng_next(state: u64&) -> u32 {
    state ^= state >> 12;
    state ^= state << 25;
    state ^= state >> 27;
    return (state * 0x2545F4914F6CDD1D) as u32;
}

// Count solutions up to a limit (used for uniqueness checking).
recursive fn count_solutions(g: i32[81]&, pos: i32, limit: i32) -> i32 {
    if pos >= 81 { return 1; }
    if g[pos] != 0 { return count_solutions(g, pos + 1, limit); }
    let x = pos % 9;
    let y = pos / 9;
    var total: i32 = 0;
    var v = 1;
    for v in 1..10 {
        if can_place(g, x, y, v as i32) != 0 {
            g[pos] = v as i32;
            total = total + count_solutions(g, pos + 1, limit);
            g[pos] = 0;
            if total >= limit { return total; }
        }
    }
    return total;
}

// Generate a complete solved Sudoku board using backtracking with some
// randomization (shuffle the order we try digits).
fn generate_solved_board(g: i32[81]&, seed: i32) -> i32 {
    // Clear the board
    var i = 0;
    for i in 81 { g[i] = 0; }
    fn prng_next(state: u64&) -> u32 {
        state ^= state >> 12;
        state ^= state << 25;
        state ^= state >> 27;
        return (state * 0x2545F4914F6CDD1D) as u32;
    }

    // Generate a complete solved Sudoku board using backtracking with PRNG
    // Simple, reliable approach: fill board cell by cell with backtracking
    // using PRNG to shuffle digit order at each step.
    recursive fn solve_full_board(g: i32[81]&, prng_state: u64&) -> i32 {
        var pos = 0;
        while pos < 81 {
            if g[pos] != 0 {
                pos = pos + 1;
                continue;
            }
            let x = (pos % 9) as i32;
            let y = (pos / 9) as i32;
            // Create shuffled digit order 1-9
            var digits: i32[9];
            var d = 0;
            for d in 9 { digits[d] = (d + 1) as i32; }
            var k = 8;
            while k > 0 {
                let r = (prng_next(prng_state) % (k + 1) as u64) as i32;
                let tmp = digits[k];
                digits[k] = digits[r];
                digits[r] = tmp;
                k = k - 1;
            }
            var placed = 0;
            for v_idx in 9 {
                let v = digits[v_idx];
                if can_place(g, x, y, v) != 0 {
                    g[pos] = v;
                    if solve_full_board(g, prng_state) != 0 {
                        placed = 1;
                        break;
                    }
                    g[pos] = 0;
                }
            }
            if placed == 0 {
                return 0;
            }
            pos = pos + 1;
        }
        return 1;
    }

    // Generate a complete solved Sudoku board using backtracking with PRNG
    // Simple, reliable approach: fill board from scratch with backtracking
    // using PRNG to shuffle digit order at each step.
    var prng_state: u64 = seed as u64;
    if prng_state == 0 { prng_state = 0x9E3779B97F4A7C15; }
    if prng_state == 0 { prng_state = 0x9E3779B97F4A7C15; }
    var ok = solve_full_board(g, prng_state);
    // Validate the generated board
    if ok != 0 && validate_puzzle(g) == 0 {
        ok = 0;
    }
    return ok;
}

// Check if removing cell at position `pos` still leaves a unique solution
// AND the puzzle remains valid (no duplicates in rows/cols/boxes).
fn can_remove(g: i32[81]&, pos: i32) -> i32 {
    let saved = g[pos];
    g[pos] = 0;
    let valid = validate_puzzle(g);
    if valid == 0 {
        g[pos] = saved;
        return 0;
    }
    let cnt = count_solutions(g, 0, 2);
    g[pos] = saved;
    if cnt == 1 { return 1; }
    return 0;
}

// Generate a puzzle with approximately `clues` given digits.
// Simple, reliable algorithm: shuffle all positions, try removing each,
// keep removal only if puzzle still has unique solution.
fn generate_puzzle(src: i32[81]&, clues: i32, seed: i32) -> i32 {
    // Start from a solved board
    var solved: i32[81] = src;

    // Build a removal order (shuffled) with xorshift PRNG
    var order: i32[81];
    var j = 0;
    for j in 81 { order[j] = j as i32; }
    var prng_state: u64 = seed as u64;
    if prng_state == 0 { prng_state = 0x9E3779B97F4A7C15; }
    var k = 80;
    while k > 0 {
        prng_state ^= prng_state >> 12;
        prng_state ^= prng_state << 25;
        prng_state ^= prng_state >> 27;
        let r = (prng_state * 0x2545F4914F6CDD1D) % (k + 1) as u64;
        let tmp = order[k];
        order[k] = order[r as i32];
        order[r as i32] = tmp;
        k = k - 1;
    }

    // Try to remove cells one by one in shuffled order
    var removed: i32 = 0;
    var target_removed = 81 - clues;
    var idx2 = 0;
    while removed < target_removed && idx2 < 81 {
        let pos = order[idx2];
        if solved[pos] != 0 {
            // Try removing this cell
            let saved = solved[pos];
            solved[pos] = 0;
            
            // Check if puzzle still has unique solution
            if validate_puzzle(solved) != 0 {
                let cnt = count_solutions(solved, 0, 2);
                if cnt == 1 {
                    // Good removal - keep it removed
                    removed = removed + 1;
                } else {
                    // Not unique - restore
                    solved[pos] = saved;
                }
            } else {
                // Invalid (duplicates) - restore
                solved[pos] = saved;
            }
        }
        idx2 = idx2 + 1;
    }

    // If we couldn't remove enough, try a second pass (different order)
    if removed < target_removed {
        // Re-shuffle and try again
        k = 80;
        while k > 0 {
            prng_state ^= prng_state >> 12;
            prng_state ^= prng_state << 25;
            prng_state ^= prng_state >> 27;
            let r = (prng_state * 0x2545F4914F6CDD1D) % (k + 1) as u64;
            let tmp = order[k];
            order[k] = order[r as i32];
            order[r as i32] = tmp;
            k = k - 1;
        }
        idx2 = 0;
        while removed < target_removed && idx2 < 81 {
            let pos = order[idx2];
            if solved[pos] != 0 {
                let saved = solved[pos];
                solved[pos] = 0;
                if validate_puzzle(solved) != 0 {
                    let cnt = count_solutions(solved, 0, 2);
                    if cnt == 1 {
                        removed = removed + 1;
                    } else {
                        solved[pos] = saved;
                    }
                } else {
                    solved[pos] = saved;
                }
            }
            idx2 = idx2 + 1;
        }
    }

    // Final validation
    if validate_puzzle(solved) == 0 {
        return -1;
    }
    if count_solutions(solved, 0, 2) != 1 {
        return -1;
    }

    // Copy result back to src
    var i2 = 0;
    for i2 in 81 { src[i2] = solved[i2]; }
    return removed;
}

// ---------------------------------------------------------------------------
// Coordinate helpers
// ---------------------------------------------------------------------------

fn board_x() -> i32 {
    let w = tb_width();
    if w >= 35 { return 4; }
    if w >= 33 { return 2; }
    return 1;
}

fn board_y() -> i32 {
    if tb_height() >= 19 { return 2; }
    return 1;
}

fn status_y() -> i32 {
    if tb_height() >= 19 { return board_y() + 14; }
    return board_y() + 13;
}

fn cell_sx(x: i32) -> i32 {
    return board_x() + 1 + x * 3 + x / 3;
}

fn cell_sy(y: i32) -> i32 {
    return board_y() + 1 + y + y / 3;
}

fn idx(x: i32, y: i32) -> i32 {
    return y * 9 + x;
}

fn cell_ref(x: i32, y: i32) -> Cell& {
    return game.grid[idx(x, y)];
}

// ---------------------------------------------------------------------------
// Drawing primitives
// ---------------------------------------------------------------------------

fn put(x: i32, y: i32, ch: u32, fg: u64, bg: u64) {
    let _ = tb_set_cell(x, y, ch, fg, bg);
}

fn put_str(x: i32, y: i32, fg: u64, bg: u64, s: const u8[:]) {
    let _ = tb_print(x, y, fg, bg, s);
}

fn put_num(x: i32, y: i32, n: i32, fg: u64, bg: u64) -> i32 {
    var buf: u8[12];
    var len: i32 = 0;
    var v = n;
    if v == 0 {
        buf[0] = 0x30;
        len = 1;
    } else {
        while v > 0 {
            buf[len] = (0x30 + (v % 10)) as u8;
            v = v / 10;
            len = len + 1;
        }
        var i = 0;
        for i in len / 2 {
            let t = buf[i];
            buf[i] = buf[len - 1 - i];
            buf[len - 1 - i] = t;
        }
    }
    var j = 0;
    for j in len {
        put(x + j, y, buf[j], fg, bg);
    }
    return len;
}

fn clear_line(y: i32) {
    let w = tb_width();
    let h = tb_height();
    if y < 0 || y >= h || w <= 0 { return; }
    var i = 0;
    for i in w {
        put(i, y, ' ', TB_DEFAULT, TB_DEFAULT);
    }
}

// ---------------------------------------------------------------------------
// Borders
// ---------------------------------------------------------------------------

fn draw_hline(y: i32, l: u32, m: u32, r: u32) {
    let bx = board_x();
    put(bx, y, l, TB_WHITE, TB_DEFAULT);
    var i = 0;
    for i in 9 { put(bx + 1 + (i as i32), y, CH_H, TB_WHITE, TB_DEFAULT); }
    put(bx + 10, y, m, TB_WHITE, TB_DEFAULT);
    var j = 0;
    for j in 9 { put(bx + 11 + (j as i32), y, CH_H, TB_WHITE, TB_DEFAULT); }
    put(bx + 20, y, m, TB_WHITE, TB_DEFAULT);
    var k = 0;
    for k in 9 { put(bx + 21 + (k as i32), y, CH_H, TB_WHITE, TB_DEFAULT); }
    put(bx + 30, y, r, TB_WHITE, TB_DEFAULT);
}

fn draw_borders() {
    let bx = board_x();
    let by = board_y();
    draw_hline(by,      CH_TL, CH_TT, CH_TR);
    draw_hline(by + 4,  CH_LT, CH_X,  CH_RT);
    draw_hline(by + 8,  CH_LT, CH_X,  CH_RT);
    draw_hline(by + 12, CH_BL, CH_BT, CH_BR);

    var yy = 0;
    for yy in 11 {
        if yy == 3 || yy == 7 { continue; }  // skip horizontal-border rows
        let y = by + 1 + (yy as i32);
        put(bx,       y, CH_V, TB_WHITE, TB_DEFAULT);
        put(bx + 10,  y, CH_V, TB_WHITE, TB_DEFAULT);
        put(bx + 20,  y, CH_V, TB_WHITE, TB_DEFAULT);
        put(bx + 30,  y, CH_V, TB_WHITE, TB_DEFAULT);
    }
}

// ---------------------------------------------------------------------------
// Labels & cell rendering
// ---------------------------------------------------------------------------

fn draw_labels() {
    let bx = board_x();
    let by = board_y();
    var x = 0;
    for x in 9 {
        put(cell_sx(x as i32) + 1, by - 1, (0x31 + (x as i32)) as u32,
            TB_CYAN, TB_DEFAULT);
    }
    var y = 0;
    for y in 9 {
        put(bx - 2, cell_sy(y as i32), (0x31 + (y as i32)) as u32,
            TB_CYAN, TB_DEFAULT);
    }
}

fn is_peer(x1: i32, y1: i32, x2: i32, y2: i32) -> i32 {
    if x1 == x2 || y1 == y2 { return 1; }
    if (x1 / 3) == (x2 / 3) && (y1 / 3) == (y2 / 3) { return 1; }
    return 0;
}

// Return 1 if placing `val` at (x, y) would conflict with existing digits.
fn would_conflict(x: i32, y: i32, val: i32) -> i32 {
    var i = 0;
    for i in 9 {
        let ii = i as i32;
        if ii != x && cell_ref(ii, y).value == val { return 1; }
    }
    var j = 0;
    for j in 9 {
        let jj = j as i32;
        if jj != y && cell_ref(x, jj).value == val { return 1; }
    }
    let bx = (x / 3) * 3;
    let by = (y / 3) * 3;
    var dy = 0;
    for dy in 3 {
        let dyy = dy as i32;
        var dx = 0;
        for dx in 3 {
            let dxx = dx as i32;
            let nx = bx + dxx;
            let ny = by + dyy;
            if (nx != x || ny != y) && cell_ref(nx, ny).value == val { return 1; }
        }
    }
    return 0;
}

fn draw_cell(x: i32, y: i32) {
    let c = cell_ref(x, y);
    let cx = game.cursor_x;
    let cy = game.cursor_y;
    let cur = cell_ref(cx, cy);

    let is_focus = (x == cx && y == cy);
    let peer = !is_focus && is_peer(x, y, cx, cy) != 0;
    let same = !is_focus && cur.value != 0 && c.value == cur.value;

    var fg: u64 = TB_WHITE;
    var bg: u64 = TB_DEFAULT;
    var attr: u64 = 0;

    if is_focus {
        bg = TB_BLUE;   fg = TB_WHITE; attr = TB_BOLD;
    } else if c.error != 0 {
        bg = TB_RED;    fg = TB_WHITE; attr = TB_BOLD;
    } else if same {
        bg = TB_YELLOW; fg = TB_BLACK; attr = TB_BOLD;
    } else if peer {
        bg = TB_DEFAULT; fg = TB_WHITE; attr = TB_DIM;
    } else if c.fixed != 0 {
        fg = TB_CYAN;    attr = TB_BOLD;
    } else if c.value != 0 {
        fg = TB_GREEN;
    } else if c.notes != 0 {
        fg = TB_MAGENTA;
    } else {
        attr = TB_DIM;
    }

    let sx = cell_sx(x);
    let sy = cell_sy(y);

    if c.value != 0 {
        put(sx,     sy, ' ', fg | attr, bg);
        put(sx + 1, sy, (0x30 + c.value) as u32, fg | attr, bg);
        put(sx + 2, sy, ' ', fg | attr, bg);
    } else if c.notes != 0 {
        var shown: i32 = 0;
        var n = 1;
        for n in 1..10 {
            let bit: u16 = (1 as u64 << n) as u16;
            if c.notes & bit != 0 {
                if shown < 3 {
                    put(sx + shown, sy, (0x30 + n) as u32, fg | attr, bg);
                }
                shown = shown + 1;
            }
        }
        if shown > 3 {
            put(sx + 2, sy, CH_DOT, fg | attr, bg);
        } else {
            var j = 0;
            for j in 3 - shown {
                put(sx + shown + j, sy, ' ', fg | attr, bg);
            }
        }
    } else {
        put(sx,     sy, ' ',     fg | attr, bg);
        put(sx + 1, sy, CH_DOT, fg | attr, bg);
        put(sx + 2, sy, ' ',     fg | attr, bg);
    }
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

fn draw_status() {
    let w = tb_width();
    let h = tb_height();
    let sy = status_y();
    let c = cell_ref(game.cursor_x, game.cursor_y);

    clear_line(sy);
    clear_line(sy + 1);
    clear_line(sy + 2);

    if sy >= h { return; }

    if w >= 74 {
        put_str(0, sy, TB_YELLOW, TB_DEFAULT,
            "HJKL/WASD:move  1-9:fill  0:clear  N:notes  ?:hint");
        put_str(62, sy, TB_CYAN, TB_DEFAULT, "Notes:");
        if game.notes_mode != 0 {
            put_str(69, sy, TB_GREEN | TB_BOLD, TB_DEFAULT, "ON ");
        } else {
            put_str(69, sy, TB_WHITE, TB_DEFAULT, "OFF");
        }

        if sy + 1 < h {
            put_str(0, sy + 1, TB_YELLOW, TB_DEFAULT,
                "U:undo  R:redo  Space:new  Q:quit");
            put_str(62, sy + 1, TB_CYAN, TB_DEFAULT, "Moves:");
            put_num(69, sy + 1, game.moves, TB_WHITE, TB_DEFAULT);
        }

        if sy + 2 < h {
            put_str(0, sy + 2, TB_CYAN, TB_DEFAULT, "Cell R");
            put_num(6, sy + 2, game.cursor_y + 1, TB_WHITE, TB_DEFAULT);
            put_str(7, sy + 2, TB_CYAN, TB_DEFAULT, " C");
            put_num(9, sy + 2, game.cursor_x + 1, TB_WHITE, TB_DEFAULT);
            if c.value == 0 && c.notes != 0 {
                put_str(15, sy + 2, TB_CYAN, TB_DEFAULT, "Notes:");
                var col2: i32 = 0;
                var n2: i32 = 1;
                for n2 in 1..10 {
                    let bit2: u16 = (1 as u64 << n2) as u16;
                    if c.notes & bit2 != 0 {
                        put(22 + col2, sy + 2, (0x30 + n2) as u32,
                            TB_MAGENTA, TB_DEFAULT);
                        col2 = col2 + 1;
                    }
                }
            }
        }
        return;
    }

    // Compact Termux layout (width < 74): keep cell info, Notes, and Moves inside viewport
    put_str(0, sy, TB_CYAN, TB_DEFAULT, "Cell R");
    put_num(6, sy, game.cursor_y + 1, TB_WHITE, TB_DEFAULT);
    put_str(7, sy, TB_CYAN, TB_DEFAULT, " C");
    put_num(9, sy, game.cursor_x + 1, TB_WHITE, TB_DEFAULT);

    put_str(12, sy, TB_CYAN, TB_DEFAULT, "Notes:");
    if game.notes_mode != 0 {
        put_str(18, sy, TB_GREEN | TB_BOLD, TB_DEFAULT, "ON ");
    } else {
        put_str(18, sy, TB_WHITE, TB_DEFAULT, "OFF");
    }
    put_str(22, sy, TB_CYAN, TB_DEFAULT, "Mv:");
    put_num(25, sy, game.moves, TB_WHITE, TB_DEFAULT);

    if sy + 1 < h {
        if w >= 50 {
            put_str(0, sy + 1, TB_YELLOW, TB_DEFAULT,
                "HJKL/WASD:move  1-9:fill  0:clear  N:notes  ?:hint");
        } else if w >= 39 {
            put_str(0, sy + 1, TB_YELLOW, TB_DEFAULT,
                "HJKL:move 1-9:fill 0:clr N:note ?:hint");
        } else {
            put_str(0, sy + 1, TB_YELLOW, TB_DEFAULT,
                "HJKL:mv 1-9:set 0:clr N:n ?:h");
        }
    }

    if sy + 2 < h {
        if c.value == 0 && c.notes != 0 {
            put_str(0, sy + 2, TB_CYAN, TB_DEFAULT, "Nts:");
            var col3: i32 = 0;
            var n3: i32 = 1;
            for n3 in 1..10 {
                let bit3: u16 = (1 as u64 << n3) as u16;
                if c.notes & bit3 != 0 {
                    put(4 + col3, sy + 2, (0x30 + n3) as u32,
                        TB_MAGENTA, TB_DEFAULT);
                    col3 = col3 + 1;
                }
            }
            if w >= 34 {
                put_str(14, sy + 2, TB_YELLOW, TB_DEFAULT, "U:un R:re Sp:new Q");
            }
        } else if w >= 33 {
            put_str(0, sy + 2, TB_YELLOW, TB_DEFAULT,
                "U:undo R:redo Space:new Q:quit");
        }
    }
}

// ---------------------------------------------------------------------------
// Full redraw
// ---------------------------------------------------------------------------

fn draw_too_small(min_w: i32, min_h: i32) {
    let w = tb_width();
    let h = tb_height();
    let _ = tb_clear();
    if h >= 1 && w >= 6 {
        put_str(0, 0, TB_CYAN | TB_BOLD, TB_DEFAULT, "SUDOKU");
    }
    if h >= 2 && w >= 12 {
        put_str(0, 1, TB_YELLOW, TB_DEFAULT, "Zoom out to fit");
    }
    if h >= 3 && w >= 16 {
        var cx: i32 = 0;
        put_str(cx, 2, TB_WHITE, TB_DEFAULT, "Need ");
        cx = 5 + put_num(5, 2, min_w, TB_WHITE, TB_DEFAULT);
        put(cx, 2, 'x', TB_WHITE, TB_DEFAULT);
        cx = cx + 1;
        let _ = put_num(cx, 2, min_h, TB_WHITE, TB_DEFAULT);
    }
    if h >= 4 && w >= 14 {
        var cx2: i32 = 0;
        put_str(cx2, 3, TB_CYAN, TB_DEFAULT, "Now: ");
        cx2 = 5 + put_num(5, 3, w, TB_CYAN, TB_DEFAULT);
        put(cx2, 3, 'x', TB_CYAN, TB_DEFAULT);
        cx2 = cx2 + 1;
        let _ = put_num(cx2, 3, h, TB_CYAN, TB_DEFAULT);
    }
    if h >= 5 && w >= 8 {
        put_str(0, 4, TB_YELLOW, TB_DEFAULT, "Q:quit");
    }
    let _ = tb_present();
}

fn draw_all() {
    let w = tb_width();
    let h = tb_height();
    if w < 33 || h < 14 {
        draw_too_small(33, 14);
        return;
    }
    let _ = tb_clear();
    draw_labels();
    draw_borders();
    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            draw_cell(x as i32, y as i32);
        }
    }
    draw_status();
    let _ = tb_present();
}

// ---------------------------------------------------------------------------
// Error detection
// ---------------------------------------------------------------------------

fn check_errors() -> i32 {
    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            let c .= cell_ref(x as i32, y as i32);
            c.error = 0;
        }
    }

    // Rows
    var r = 0;
    for r in 9 {
        var i = 0;
        for i in 9 {
            var jj = i + 1;
            while jj < 9 {
                let a .= cell_ref(i as i32, r as i32);
                let b .= cell_ref(jj as i32, r as i32);
                if a.value != 0 && a.value == b.value {
                    a.error = 1;
                    b.error = 1;
                }
                jj = jj + 1;
            }
        }
    }

    // Columns
    var cc = 0;
    for cc in 9 {
        var i = 0;
        for i in 9 {
            var jj = i + 1;
            while jj < 9 {
                let a .= cell_ref(cc as i32, i as i32);
                let b .= cell_ref(cc as i32, jj as i32);
                if a.value != 0 && a.value == b.value {
                    a.error = 1;
                    b.error = 1;
                }
                jj = jj + 1;
            }
        }
    }

    // 3x3 boxes
    var bx = 0;
    for bx in 3 {
        var by = 0;
        for by in 3 {
            var i = 0;
            for i in 9 {
                var jj = i + 1;
                while jj < 9 {
                    let x1 = (bx as i32) * 3 + (i as i32) % 3;
                    let y1 = (by as i32) * 3 + (i as i32) / 3;
                    let x2 = (bx as i32) * 3 + (jj as i32) % 3;
                    let y2 = (by as i32) * 3 + (jj as i32) / 3;
                    let a .= cell_ref(x1, y1);
                    let b .= cell_ref(x2, y2);
                    if a.value != 0 && a.value == b.value {
                        a.error = 1;
                        b.error = 1;
                    }
                    jj = jj + 1;
                }
            }
        }
    }

    var total: i32 = 0;
    var y2 = 0;
    for y2 in 9 {
        var x2 = 0;
        for x2 in 9 {
            if cell_ref(x2 as i32, y2 as i32).error != 0 { total = total + 1; }
        }
    }
    return total;
}

// ---------------------------------------------------------------------------
// History / undo / redo
// ---------------------------------------------------------------------------

fn record_move(mv: Move) {
    if game.history_len < MAX_HISTORY {
        game.history[game.history_len] = mv;
        game.history_len = game.history_len + 1;
    }
    game.redo_len = 0;
}

fn set_cell_value(x: i32, y: i32, new_val: i32, new_notes: u16) -> i32 {
    let c .= cell_ref(x, y);
    let old_val = c.value;
    let old_notes = c.notes;
    c.value = new_val;
    c.notes = new_notes;
    c.error = 0;
    game.moves = game.moves + 1;
    record_move(Move {
        x: x, y: y,
        old_value: old_val, old_notes: old_notes,
        new_value: new_val, new_notes: new_notes,
    });
    return TB_OK;
}

fn undo() {
    if game.history_len <= 0 { return; }
    game.history_len = game.history_len - 1;
    let mv = game.history[game.history_len];
    let c .= cell_ref(mv.x, mv.y);
    c.value = mv.old_value;
    c.notes = mv.old_notes;
    c.error = 0;
    if game.moves > 0 { game.moves = game.moves - 1; }
    if game.redo_len < MAX_HISTORY {
        game.redo[game.redo_len] = mv;
        game.redo_len = game.redo_len + 1;
    }
}

fn redo() {
    if game.redo_len <= 0 { return; }
    game.redo_len = game.redo_len - 1;
    let mv = game.redo[game.redo_len];
    let c .= cell_ref(mv.x, mv.y);
    c.value = mv.new_value;
    c.notes = mv.new_notes;
    c.error = 0;
    game.moves = game.moves + 1;
    if game.history_len < MAX_HISTORY {
        game.history[game.history_len] = mv;
        game.history_len = game.history_len + 1;
    }
}

// ---------------------------------------------------------------------------
// Hint / solve check / init
// ---------------------------------------------------------------------------

fn hint() -> i32 {
    if game.has_solution == 0 { return 0; }
    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            let c = cell_ref(x as i32, y as i32);
            if c.value == 0 && c.fixed == 0 {
                let sv = game.solution[y * 9 + x];
                if sv != 0 && would_conflict(x as i32, y as i32, sv) == 0 {
                    let _ = set_cell_value(x as i32, y as i32, sv, 0);
                    return 1;
                }
            }
        }
    }
    return 0;
}

fn is_solved() -> i32 {
    if game.has_solution == 0 { return 0; }
    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            let c = cell_ref(x as i32, y as i32);
            if c.value == 0 { return 0; }
            if c.value != game.solution[y * 9 + x] { return 0; }
        }
    }
    return 1;
}

fn init_puzzle(diff: i32) {
    // Increment game instance for entropy
    game.game_instance = game.game_instance + 1;
    var base_seed: i32 = game.game_instance;

    // Map difficulty to clue count
    var clues: i32 = 36;
    if diff == 0 { clues = 40; }      // Easy: more clues = easier
    else if diff == 1 { clues = 34; } // Medium
    else if diff == 2 { clues = 28; } // Hard
    else { clues = 24; }              // Expert

    // Mix current monotonic time + instance + difficulty so puzzles vary per run
    let t_mix = (tb_internal_now_ms() & 0x7ffffff) as i32;
    var seed: i32 = (t_mix ^ (base_seed * 2654435761 as i32)) + diff;
    if seed == 0 { seed = base_seed * 4 + diff + 1; }

    // Generate a solved board with entropy from game instance + difficulty
    // Retry with different seeds if generation fails - NO PUZZLE_EASY FALLBACK
    var src: i32[81] = PUZZLE_EASY;  // Initialize to avoid 'used before assigned'
    var gen_attempts: i32 = 0;
    var ok: i32 = 0;
    while gen_attempts < 50 {
        var i = 0;
        for i in 81 { src[i] = 0; }
        ok = generate_solved_board(src, seed);
        if ok != 0 { break; }
        seed = seed + 4;
        gen_attempts = gen_attempts + 1;
    }
    if ok == 0 {
        // Should never happen, but use PUZZLE_EASY as absolute last resort
        src = PUZZLE_EASY;
        clues = 40;
    }

    // Generate puzzle with target clue count, keeping best unique-solution board
    let target_removed = 81 - clues;
    var best_src: i32[81] = src;
    var best_removed: i32 = -1;
    var attempts: i32 = 0;
    while attempts < 50 {
        var candidate: i32[81] = src;
        let removed = generate_puzzle(candidate, clues, seed);
        if removed >= 0 && validate_puzzle(candidate) != 0 {
            if removed > best_removed {
                best_removed = removed;
                best_src = candidate;
            }
            if removed >= target_removed { break; }
        }
        seed = seed + 4;
        attempts = attempts + 1;
    }
    if best_removed >= 0 {
        src = best_src;
    }

    var i2 = 0;
    for i2 in 81 {
        let ci = i2 as i32;
        let c .= cell_ref(ci % 9, ci / 9);
        c.value = src[ci];
        c.fixed = if src[ci] != 0 { 1 } else { 0 };
        c.notes = 0;
        c.error = 0;
    }

    // Compute reference solution for hints.
    var sol: i32[81] = src;
    let sol_ok = solve_puzzle(sol, 0);
    if sol_ok != 0 {
        var k = 0;
        for k in 81 { game.solution[k] = sol[k]; }
        game.has_solution = 1;
    } else {
        var k = 0;
        for k in 81 { game.solution[k] = 0; }
        game.has_solution = 0;
    }

    game.cursor_x = 0;
    game.cursor_y = 0;
    game.notes_mode = 0;
    game.moves = 0;
    game.history_len = 0;
    game.redo_len = 0;
}

// ---------------------------------------------------------------------------
// Menu / win screen
// ---------------------------------------------------------------------------

fn draw_menu() {
    let w = tb_width();
    let h = tb_height();
    let _ = tb_clear();
    if w < 24 || h < 10 {
        if h >= 1 && w >= 6 { put_str(0, 0, TB_CYAN | TB_BOLD, TB_DEFAULT, "SUDOKU"); }
        if h >= 2 && w >= 14 { put_str(0, 1, TB_YELLOW, TB_DEFAULT, "1-4:Play Q:Quit"); }
        let _ = tb_present();
        return;
    }

    let mx: i32 = if w >= 34 { 8 } else { 1 };
    if h >= 16 {
        put_str(mx, 3, TB_CYAN | TB_BOLD, TB_DEFAULT, "===================");
        put_str(mx, 4, TB_CYAN | TB_BOLD, TB_DEFAULT, "      SUDOKU       ");
        put_str(mx, 5, TB_CYAN | TB_BOLD, TB_DEFAULT, "===================");
        put_str(mx, 7, TB_WHITE, TB_DEFAULT, "Select difficulty:");
        put_str(mx, 9,  TB_YELLOW, TB_DEFAULT, "1. Easy");
        put_str(mx, 10, TB_YELLOW, TB_DEFAULT, "2. Medium");
        put_str(mx, 11, TB_YELLOW, TB_DEFAULT, "3. Hard");
        put_str(mx, 12, TB_YELLOW, TB_DEFAULT, "4. Expert");
        put_str(mx, 14, TB_CYAN, TB_DEFAULT, "Press 1-4   (Q to quit)");
    } else {
        put_str(mx, 0, TB_CYAN | TB_BOLD, TB_DEFAULT, "=== SUDOKU ===");
        put_str(mx, 2, TB_WHITE, TB_DEFAULT, "Select difficulty:");
        put_str(mx, 4, TB_YELLOW, TB_DEFAULT, "1. Easy");
        put_str(mx, 5, TB_YELLOW, TB_DEFAULT, "2. Medium");
        put_str(mx, 6, TB_YELLOW, TB_DEFAULT, "3. Hard");
        put_str(mx, 7, TB_YELLOW, TB_DEFAULT, "4. Expert");
        put_str(mx, 9, TB_CYAN, TB_DEFAULT, "1-4:Start  Q:Quit");
    }
    let _ = tb_present();
}

fn show_menu(diff: i32&) -> i32 {
    draw_menu();

    // Clear input buffer to prevent rapid key press glitches
    let g = gbl();
    g.inbuf_len = 0;
    g.inbuf_pos = 0;

    loop {
        var ev = tb_event { .. };
        let rv = tb_poll_event(ev);
        if rv == TB_ERR_READ { return 0; }
        if rv != TB_OK { continue; }
        if ev.kind == TB_EVENT_RESIZE {
            draw_menu();
            continue;
        }
        if ev.kind != TB_EVENT_KEY { continue; }
        if ev.ch == '1' { diff = 0; return 1; }
        if ev.ch == '2' { diff = 1; return 1; }
        if ev.ch == '3' { diff = 2; return 1; }
        if ev.ch == '4' { diff = 3; return 1; }
        if ev.ch == 'q' || ev.ch == 'Q' { return 0; }
    }
}

fn draw_win() {
    let w = tb_width();
    let h = tb_height();
    let _ = tb_clear();
    if w < 28 || h < 9 {
        if h >= 1 && w >= 7 { put_str(0, 0, TB_GREEN | TB_BOLD, TB_DEFAULT, "SOLVED!"); }
        if h >= 2 && w >= 14 { put_str(0, 1, TB_YELLOW, TB_DEFAULT, "Sp:New M:Menu Q"); }
        let _ = tb_present();
        return;
    }

    let wx: i32 = if w >= 44 { 8 } else { 1 };
    let bx: i32 = if w >= 38 { 10 } else { 1 };
    if h >= 14 {
        put_str(bx, 4, TB_GREEN | TB_BOLD, TB_DEFAULT,
            "===========================");
        put_str(bx, 5, TB_GREEN | TB_BOLD, TB_DEFAULT,
            "     PUZZLE SOLVED!     ");
        put_str(bx, 6, TB_GREEN | TB_BOLD, TB_DEFAULT,
            "===========================");
        put_str(wx + 3, 8, TB_WHITE, TB_DEFAULT, "Moves: ");
        put_num(wx + 10, 8, game.moves, TB_WHITE, TB_DEFAULT);
        put_str(wx, 10, TB_YELLOW, TB_DEFAULT, "Space: new puzzle (same difficulty)");
        put_str(wx, 11, TB_YELLOW, TB_DEFAULT, "M: main menu (new difficulty)");
        put_str(wx, 12, TB_YELLOW, TB_DEFAULT, "Q: quit");
    } else {
        put_str(wx, 1, TB_GREEN | TB_BOLD, TB_DEFAULT, "PUZZLE SOLVED!");
        put_str(wx, 3, TB_WHITE, TB_DEFAULT, "Moves: ");
        put_num(wx + 7, 3, game.moves, TB_WHITE, TB_DEFAULT);
        put_str(wx, 5, TB_YELLOW, TB_DEFAULT, "Space: new puzzle");
        put_str(wx, 6, TB_YELLOW, TB_DEFAULT, "M: menu  Q: quit");
    }
    let _ = tb_present();
}

fn show_win() -> i32 {
    // Returns: 0 = quit, 1 = play again (same difficulty), 2 = new game (menu)
    draw_win();

    // Clear input buffer to prevent rapid key press glitches
    let g = gbl();
    g.inbuf_len = 0;
    g.inbuf_pos = 0;

    loop {
        var ev = tb_event { .. };
        let rv = tb_poll_event(ev);
        if rv == TB_ERR_READ { return 0; }
        if rv != TB_OK { continue; }
        if ev.kind == TB_EVENT_RESIZE {
            draw_win();
            continue;
        }
        if ev.kind != TB_EVENT_KEY { continue; }
        if ev.ch == ' ' { return 1; }
        if ev.ch == 'm' || ev.ch == 'M' { return 2; }
        if ev.ch == 'q' || ev.ch == 'Q' { return 0; }
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("tb_init failed: ", rv, "\n");
        return;
    }

    var diff: i32 = 1;
    if show_menu(diff) == 0 {
        let _ = tb_shutdown();
        return;
    }

    init_puzzle(diff);
    let _ = check_errors();
    draw_all();

    loop {
        var ev = tb_event { .. };
        let rv2 = tb_poll_event(ev);
        if rv2 == TB_ERR_READ { break; }
        if rv2 != TB_OK { continue; }
        if ev.kind == TB_EVENT_RESIZE { draw_all(); continue; }
        if ev.kind != TB_EVENT_KEY { draw_all(); continue; }

        // Quit on 'q' / 'Q' or ESC (defensive: mis-parsed arrows can flood ESC events).
        if ev.ch == 'q' || ev.ch == 'Q' || ev.key == TB_KEY_ESC { break; }

        if ev.ch == ' ' {
            // Clear input buffer to prevent rapid key press glitches
            let g = gbl();
            g.inbuf_len = 0;
            g.inbuf_pos = 0;

            if show_menu(diff) == 0 { break; }
            init_puzzle(diff);
            let _ = check_errors();
            let _ = tb_clear();
            let _ = tb_present();
            draw_all();
            continue;
        }

        // Movement: HJKL, WASD, plus arrow keys if the terminal sends them.
        if ev.ch == 'h' || ev.ch == 'a' || ev.key == TB_KEY_ARROW_LEFT {
            if game.cursor_x > 0 { game.cursor_x = game.cursor_x - 1; }
        } else if ev.ch == 'j' || ev.ch == 's' || ev.key == TB_KEY_ARROW_DOWN {
            if game.cursor_y < 8 { game.cursor_y = game.cursor_y + 1; }
        } else if ev.ch == 'k' || ev.ch == 'w' || ev.key == TB_KEY_ARROW_UP {
            if game.cursor_y > 0 { game.cursor_y = game.cursor_y - 1; }
        } else if ev.ch == 'l' || ev.ch == 'd' || ev.key == TB_KEY_ARROW_RIGHT {
            if game.cursor_x < 8 { game.cursor_x = game.cursor_x + 1; }
        } else if ev.ch == 'n' || ev.ch == 'N' {
            game.notes_mode = if game.notes_mode == 0 { 1 } else { 0 };
        } else if ev.ch == '?' || ev.ch == '/' {
            let _ = hint();
        } else if ev.ch == 'u' || ev.ch == 'U' {
            undo();
        } else if ev.ch == 'r' || ev.ch == 'R' {
            redo();
        } else if ev.key == TB_KEY_BACKSPACE || ev.key == TB_KEY_BACKSPACE2 || ev.key == TB_KEY_DELETE || ev.ch == '0' {
            let c = cell_ref(game.cursor_x, game.cursor_y);
            if c.fixed == 0 {
                if game.notes_mode != 0 {
                    let _ = set_cell_value(game.cursor_x, game.cursor_y, c.value, 0);
                } else {
                    let _ = set_cell_value(game.cursor_x, game.cursor_y, 0, 0);
                }
            }
        } else if ev.ch >= '1' && ev.ch <= '9' {
            let val = (ev.ch - '0') as i32;
            let c = cell_ref(game.cursor_x, game.cursor_y);
            if c.fixed == 0 {
                if game.notes_mode != 0 {
                    let bit: u16 = (1 as u64 << val) as u16;
                    let new_notes = c.notes ^ bit;
                    let _ = set_cell_value(game.cursor_x, game.cursor_y, c.value, new_notes);
                } else {
                    // Reject moves that would create a conflict
                    if would_conflict(game.cursor_x, game.cursor_y, val) != 0 {
                        // Do nothing — wrong move is rejected
                    } else {
                        let _ = set_cell_value(game.cursor_x, game.cursor_y, val, 0);
                    }
                }
            }
        }

        let _ = check_errors();
        draw_all();
        if is_solved() != 0 {
            let choice = show_win();
            if choice == 0 {
                break;
            } else if choice == 2 {
                // Go back to main menu
                if show_menu(diff) == 0 { break; }
                init_puzzle(diff);
                let _ = check_errors();
                let _ = tb_clear();
                let _ = tb_present();
                draw_all();
                continue;
            } else {
                // choice == 1: new puzzle, same difficulty
                init_puzzle(diff);
                let _ = check_errors();
                let _ = tb_clear();
                let _ = tb_present();
                draw_all();
                continue;
            }
        }
    }

    let _ = tb_shutdown();
    print("thanks for playing\n");
}
