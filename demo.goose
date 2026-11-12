// demo.goose — simple termbox2 demo (run from project root)
import termbox2;

fn main() {
    let rv = tb_init();
    if rv != TB_OK {
        print("tb_init failed: ", rv);
        return;
    }

    let _ = tb_clear();
    let _ = tb_print(0, 0, TB_WHITE, TB_BLACK, "Hello, termbox2 on Goose!");
    let _ = tb_print(0, 1, TB_CYAN, TB_BLACK, "Press 'q' or ESC to quit.");
    let _ = tb_present();

    loop {
        var ev = tb_event { .. };
        let rv = tb_poll_event(ev);
        if rv == TB_ERR_NO_EVENT { continue; }
        if rv != TB_OK { break; }

        if ev.kind == TB_EVENT_KEY {
            if ev.key == TB_KEY_ESC || ev.ch == 'q' { break; }
            if ev.ch != 0 {
                let _ = tb_clear();
                let _ = tb_print(0, 0, TB_GREEN, TB_BLACK, "Key pressed: ");
                let _ = tb_present();
            }
        } else if ev.kind == TB_EVENT_RESIZE {
            let _ = tb_clear();
            let _ = tb_present();
        }
    }

    let _ = tb_shutdown();
    print("goodbye\n");
}
