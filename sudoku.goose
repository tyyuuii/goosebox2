// sudoku.goose — a simple sudoku game using goosebox2 (termbox2 port)
// Build: goose build sudoku.goose -o sudoku
// Run:   ./sudoku

import termbox2;

// ---------------------------------------------------------------------------
// Game state
// ---------------------------------------------------------------------------

struct sudoku_game {
    grid: i32[81],      // 0 = empty, 1-9 = filled
    fixed: u8[81],      // 1 = pre-filled (read-only), 0 = user-editable
    cursor_x: i32,      // 0-8
    cursor_y: i32,      // 0-8
}

var game: sudoku_game;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn idx(x: i32, y: i32) -> i32 {
    return y * 9 + x;
}

// Return 1 if placing val at (x, y) does not conflict, 0 otherwise.
fn is_valid(x: i32, y: i32, val: i32) -> i32 {
    var i = 0;
    for i in 9 {
        if i != x && game.grid[idx(i as i32, y)] == val { return 0; }
    }
    var j = 0;
    for j in 9 {
        if j != y && game.grid[idx(x, j as i32)] == val { return 0; }
    }
    let bx = (x / 3) * 3;
    let by = (y / 3) * 3;
    var dy = 0;
    for dy in 3 {
        var dx = 0;
        for dx in 3 {
            let nx = bx + dx;
            let ny = by + dy;
            if (nx != x || ny != y) && game.grid[idx(nx as i32, ny as i32)] == val { return 0; }
        }
    }
    return 1;
}

// Return 1 if the board is completely and correctly filled.
fn is_solved() -> i32 {
    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            let v = game.grid[idx(x as i32, y as i32)];
            if v == 0 { return 0; }
            if is_valid(x as i32, y as i32, v) == 0 { return 0; }
        }
    }
    return 1;
}

// Load a built-in puzzle.
fn init_puzzle() {
    let puzzle: i32[81] = [
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
    var i = 0;
    for i in 81 {
        game.grid[i] = puzzle[i];
        game.fixed[i] = if puzzle[i] != 0 { 1 } else { 0 };
    }
    game.cursor_x = 0;
    game.cursor_y = 0;
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

fn draw_cell(x: i32, y: i32) {
    let i = idx(x, y);
    let val = game.grid[i];
    let is_fixed = game.fixed[i] != 0;
    let is_cursor = x == game.cursor_x && y == game.cursor_y;

    var fg: u64;
    var bg: u64;
    var ch: u32;

    if is_cursor {
        bg = TB_BLUE;
        fg = TB_WHITE | TB_BOLD;
    } else if is_fixed {
        fg = TB_CYAN;
        bg = TB_DEFAULT;
    } else if val != 0 {
        fg = TB_GREEN;
        bg = TB_DEFAULT;
    } else {
        fg = TB_WHITE;
        bg = TB_DEFAULT;
    }

    if val == 0 {
        ch = '.';
    } else {
        ch = ('0' + val) as u32;
    }

    // Each cell takes 2 columns so digits are readable.
    let _ = tb_set_cell(x * 2, y, ch, fg, bg);
    let _ = tb_set_cell(x * 2 + 1, y, ' ', fg, bg);
}

fn draw_board() {
    let _ = tb_clear();

    var y = 0;
    for y in 9 {
        var x = 0;
        for x in 9 {
            draw_cell(x as i32, y as i32);
        }
    }

    let _ = tb_print(0, 10, TB_YELLOW, TB_DEFAULT,
        "Arrows: move  1-9: fill  BS/Del: clear");
    let _ = tb_print(0, 11, TB_YELLOW, TB_DEFAULT,
        "ENTER: check   ESC: quit");

    let _ = tb_present();
}

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------

fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("tb_init failed: ", rv);
        return;
    }

    init_puzzle();
    draw_board();

    loop {
        var ev = tb_event { .. };
        let rv = tb_poll_event(ev);
        if rv != TB_OK { break; }

        if ev.kind == TB_EVENT_KEY {
            if ev.key == TB_KEY_ESC || ev.ch == 'q' {
                break;
            } else if ev.key == TB_KEY_ARROW_UP {
                if game.cursor_y > 0 { game.cursor_y = game.cursor_y - 1; }
            } else if ev.key == TB_KEY_ARROW_DOWN {
                if game.cursor_y < 8 { game.cursor_y = game.cursor_y + 1; }
            } else if ev.key == TB_KEY_ARROW_LEFT {
                if game.cursor_x > 0 { game.cursor_x = game.cursor_x - 1; }
            } else if ev.key == TB_KEY_ARROW_RIGHT {
                if game.cursor_x < 8 { game.cursor_x = game.cursor_x + 1; }
            } else if ev.ch >= '1' && ev.ch <= '9' {
                let val = ev.ch - '0';
                let i = idx(game.cursor_x, game.cursor_y);
                if game.fixed[i] == 0 {
                    game.grid[i] = val as i32;
                }
            } else if ev.key == TB_KEY_BACKSPACE || ev.key == TB_KEY_BACKSPACE2 {
                let i = idx(game.cursor_x, game.cursor_y);
                if game.fixed[i] == 0 {
                    game.grid[i] = 0;
                }
            } else if ev.key == TB_KEY_ENTER {
                if is_solved() != 0 {
                    let _ = tb_clear();
                    let _ = tb_print(10, 5, TB_GREEN | TB_BOLD, TB_DEFAULT,
                        "SOLVED! Congratulations!");
                    let _ = tb_print(8, 7, TB_YELLOW, TB_DEFAULT,
                        "Press any key to quit");
                    let _ = tb_present();
                    let _ = tb_poll_event(ev);
                    break;
                } else {
                    let _ = tb_clear();
                    let _ = tb_print(10, 5, TB_RED | TB_BOLD, TB_DEFAULT,
                        "Not solved yet! Keep going.");
                    let _ = tb_print(6, 7, TB_YELLOW, TB_DEFAULT,
                        "Press any key to continue");
                    let _ = tb_present();
                    let _ = tb_poll_event(ev);
                    draw_board();
                }
            }
        } else if ev.kind == TB_EVENT_RESIZE {
            draw_board();
        }

        draw_board();
    }

    let _ = tb_shutdown();
    print("thanks for playing\n");
}
