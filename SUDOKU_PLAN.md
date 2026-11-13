# Sudoku Game Plan — goosebox2 / termbox2 port

**Goal:** A polished, playable sudoku terminal game built on goosebox2.
**Scope:** Single-file `sudoku.goose` using only the goosebox2 API (no new C sidecar).
**Constraint:** Do NOT commit until explicitly told to.

---

## 1. Problems with current version

| Issue | Why it matters |
|-------|----------------|
| Single hard-coded puzzle | No replayability |
| No difficulty levels | Too hard or too easy for most users |
| No puzzle generation | Can't scale |
| No notes / pencil marks | Essential for real sudoku solving |
| No undo/redo | Mistakes are permanent |
| No timer | No sense of progress or challenge |
| No win celebration | Anti-climactic finish |
| No visual highlighting | Hard to track row/column/box constraints |
| No error highlighting | Wrong numbers blend in |
| No hint system | Stuck players can't continue |

---

## 2. Design pillars

1. **Replayability** — procedurally generated puzzles at 4 difficulty levels
2. **Clarity** — board highlights related cells (row, column, box, matching digit)
3. **Forgiveness** — undo/redo, notes mode, hints
4. **Feedback** — errors shown in red, solved cells frozen, timer, win screen

---

## 3. Data model

```goose
struct sudoku_cell {
    value: i32,      // 0 = empty, 1-9 = filled
    fixed: i32,      // 1 = puzzle clue (read-only), 0 = user entry
    notes: u16,      // bitmask: bit n = note n is set (bit 0 unused)
    error: i32,      // 1 = currently conflicting, 0 = OK
}

struct sudoku_game {
    grid: sudoku_cell[81],   // flat 9x9
    cursor_x: i32,           // 0-8
    cursor_y: i32,           // 0-8
    notes_mode: i32,         // 1 = entering pencil marks, 0 = entering values
    start_time: f64,         // game start (os.clock())
    moves: i64,              // count of value/note changes
    undone: i64,             // count of undone moves (for redo limit)
    history: Move[>..],      // undo stack
}

struct Move {
    x: i32,
    y: i32,
    old_value: i32,
    old_notes: u16,
    new_value: i32,
    new_notes: u16,
    old_error: i32,
    new_error: i32,
}
```

### Why a flat `sudoku_cell[81]`?
Goose arrays with struct-of-arrays layout keep everything inline and indexable. `sudoku_cell` is fixed-size (scalars only), so `grid[idx(x,y)]` is O(1) and cache-friendly.

---

## 4. Rendering plan

### 4.1 Board layout (monospace terminal)

Each cell is 2 columns wide, with separators:

```
  1 2 3   4 5 6   7 8 9
1 . . . | . . . | . . .
2 . . . | . . . | . . .
3 . . . | . . . | . . .
--------+-------+-------
4 . . . | . . . | . . .
5 . . . | . . . | . . .
6 . . . | . . . | . . .
--------+-------+-------
7 . . . | . . . | . . .
8 . . . | . . . | . . .
9 . . . | . . . | . . .
```

- Column headers at top (1-9)
- Row numbers on left (1-9)
- `|` vertical separators after cols 3, 6
- `-` horizontal separators after rows 3, 6
- Cursor cell: blue background, white bold text
- Fixed clues: cyan
- User entries: green
- Empty cells: `.` in dim white
- Errors: red background or red text
- Highlighted row/col/box: dim background tint (use `TB_DIM` attribute)
- Matching digit highlight: bold when same digit as cursor cell

### 4.2 Status panel (below board)

```
Difficulty: Medium   Time: 04:32   Moves: 12
Notes: OFF        [H]int  [U]ndo  [R]edo  [N]ew  [Q]uit
```

### 4.3 Color scheme

| Element | FG | BG | Attr |
|---------|----|-----|------|
| Fixed clue | CYAN | DEFAULT | none |
| User value | GREEN | DEFAULT | none |
| Error | WHITE | RED | BOLD |
| Cursor cell | WHITE | BLUE | BOLD |
| Highlight row/col | WHITE | DEFAULT | DIM |
| Matching digit | YELLOW | DEFAULT | BOLD |
| Notes | MAGENTA | DEFAULT | none |
| UI text | YELLOW | DEFAULT | none |
| Win message | GREEN | DEFAULT | BOLD |

---

## 5. Core algorithms

### 5.1 Puzzle generation (backtracking + symmetry removal)

```
generate_full_board():
    fill diagonal 3x3 blocks with random permutations of 1-9
    solve remaining cells via backtracking with randomization
    return complete 9x9 board

make_puzzle(difficulty):
    board = generate_full_board()
    cells = shuffle(all 81 positions)
    removals = difficulty_removal_count(difficulty)  # easy=30, med=38, hard=46, expert=52
    for each cell in cells:
        backup = board[cell]
        board[cell] = 0
        if not has_unique_solution(board):
            board[cell] = backup  # restore, keep clue
    return board
```

`has_unique_solution` uses a solver that stops after finding 2 solutions.

### 5.2 Solver (backtracking with constraint propagation)

Standard recursive backtracking:
1. Find empty cell with fewest candidates (MRV heuristic)
2. Try candidates 1-9 in random order
3. Check row/col/box constraints
4. Recurse; backtrack on failure
5. Count solutions (stop at 2)

### 5.3 Difficulty levels

| Level | Clues removed | Description |
|-------|--------------|-------------|
| Easy  | 30 | Many singles, solvable by basic logic |
| Medium | 38 | Requires some pencil marks |
| Hard | 46 | Needs advanced techniques |
| Expert | 52 | Very few clues, hard search |

### 5.4 Notes (pencil marks)

- Toggle with `N` key
- In notes mode, pressing `1-9` toggles that note bit in the current cell
- Notes shown as small numbers (can't render small in termbox2, so show as `1`..`9` in magenta, or use `.` if no notes)
- Value entry disabled while notes mode is on

### 5.5 Error detection

After every move, recompute errors for:
- The changed cell's row
- The changed cell's column  
- The changed cell's 3x3 box

A cell is an error if its value appears more than once in its row/col/box.

### 5.6 Undo/redo

- Every value/note change pushes a `Move` to `history`
- `U` pops last move and restores state (pushes to redo stack)
- `R` reapplies from redo stack
- Limit: keep last 100 moves (drop oldest when full)

---

## 6. Controls

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor |
| `1`-`9` | Enter value (or toggle note in notes mode) |
| `0`, `Backspace`, `Del` | Clear cell / remove note |
| `N` | Toggle notes mode |
| `H` | Hint (fill one random solvable cell) |
| `U` | Undo |
| `R` | Redo |
| `Space` | New game (prompt difficulty) |
| `Esc`, `q` | Quit |

---

## 7. Game flow states

```
MENU → DIFFICULTY SELECT → PLAYING → WON → MENU
                          ↑
                    (quit → MENU)
```

- **MENU**: Show title, instructions, difficulty options
- **DIFFICULTY SELECT**: Choose Easy/Medium/Hard/Expert
- **PLAYING**: Main loop, render board + status, handle input
- **WON**: Show time, moves, "SOLVED!" message, wait for key

---

## 8. Implementation notes for goosebox2

### 8.1 What works (verified)
- `tb_init`, `tb_shutdown` — TTY setup/teardown
- `tb_clear`, `tb_set_cell`, `tb_present` — rendering
- `tb_poll_event` — blocking input (now fixed for arrows/ESC)
- `tb_print` — text output at position
- Color/attribute constants (`TB_CYAN`, `TB_GREEN`, `TB_RED`, `TB_BOLD`, `TB_DIM`, etc.)

### 8.2 Limitations to work around
- No small-font rendering — notes will be full-size digits in magenta
- No mouse support needed (keyboard only)
- `tb_printf` variadic not available — use `tb_print` with string concatenation via `str()` or manual formatting
- `tb_set_cell` takes `u32` for char — pass `'0' + value` style

### 8.3 Random numbers
Goose `std::rng` is available via `import std;`. Use `rand_int(r, n)` for random choices.

---

## 9. File structure

```
sudoku.goose      # Complete game (~400 lines)
sudoku.build      # c_sources = ["adapter.c"] (unchanged)
```

No changes to `termbox2.goose` or `adapter.c` needed — everything uses existing API.

---

## 10. Next steps (when told to commit)

1. Write `sudoku.goose` per this plan
2. `goose check sudoku.goose` → fix any type errors
3. `goose build sudoku.goose -o sudoku` → verify build
4. Run in terminal to test gameplay
5. Commit `sudoku.goose` + `sudoku.build` only
6. Push to `origin master`

---

**Status:** PLANNED. Not yet implemented. Awaiting commit instruction.
