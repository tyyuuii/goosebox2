// demo.goose — simple termbox2 demo (run from project root)

import termbox2;

fn draw_demo(has_key: i32, ch: u32, key: u16) {
    let _ = tb_clear();
    let _ = tb_print(0, 0, TB_WHITE, TB_BLACK, "Hello, termbox2 on Goose!");
    let _ = tb_print(0, 1, TB_CYAN, TB_BLACK, "Press 'q' or ESC to quit.");
    if has_key != 0 {
        let _ = tb_print(0, 3, TB_GREEN, TB_BLACK, "Last key: ");
        if ch != 0 {
            let _ = tb_set_cell(10, 3, ch, TB_YELLOW | TB_BOLD, TB_BLACK);
        } else if key == TB_KEY_ENTER {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "ENTER");
        } else if key == TB_KEY_TAB {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "TAB");
        } else if key == TB_KEY_BACKSPACE || key == TB_KEY_BACKSPACE2 {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "BACKSPACE");
        } else if key == TB_KEY_ARROW_UP {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "UP");
        } else if key == TB_KEY_ARROW_DOWN {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "DOWN");
        } else if key == TB_KEY_ARROW_LEFT {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "LEFT");
        } else if key == TB_KEY_ARROW_RIGHT {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "RIGHT");
        } else {
            let _ = tb_print(10, 3, TB_YELLOW | TB_BOLD, TB_BLACK, "SPECIAL");
        }
    }
    let _ = tb_present();
}

fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("tb_init failed: ", rv);
        return;
    }

    draw_demo(0, 0, 0);

    var last_ch: u32 = 0;
    var last_key: u16 = 0;
    var has_key: i32 = 0;

    loop {
        var ev = tb_event { .. };
        let rv = tb_poll_event(ev);
        if rv == TB_ERR_NO_EVENT { continue; }
        if rv != TB_OK { break; }
        if ev.kind == TB_EVENT_KEY {
            if ev.key == TB_KEY_ESC || ev.ch == 'q' { break; }
            last_ch = ev.ch;
            last_key = ev.key;
            has_key = 1;
            draw_demo(has_key, last_ch, last_key);
        } else if ev.kind == TB_EVENT_RESIZE {
            draw_demo(has_key, last_ch, last_key);
        }
    }

    let _ = tb_shutdown();
    print("goodbye\n");
}
