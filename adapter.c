#ifdef _WIN32

#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include "adapter.h"
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif
#ifndef DISABLE_NEWLINE_AUTO_RETURN
#define DISABLE_NEWLINE_AUTO_RETURN 0x0008
#endif
#ifndef ENABLE_VIRTUAL_TERMINAL_INPUT
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x0200
#endif
#ifndef ENABLE_EXTENDED_FLAGS
#define ENABLE_EXTENDED_FLAGS 0x0080
#endif
#ifndef ENABLE_QUICK_EDIT_MODE
#define ENABLE_QUICK_EDIT_MODE 0x0040
#endif

#define TB_WIN_CONSOLE_FD 100000
#define TB_WIN_MAX_CRT_FD 1024
#define TB_WIN_POLLIN 0x0001
#define TB_WIN_POLLERR 0x0008

static HANDLE g_win_con_in = INVALID_HANDLE_VALUE;
static HANDLE g_win_con_out = INVALID_HANDLE_VALUE;
static int g_win_con_owns_in = 0;
static int g_win_con_owns_out = 0;
static int g_win_con_nonblock = 0;

static DWORD g_win_orig_in_mode = 0;
static DWORD g_win_orig_out_mode = 0;
static UINT g_win_orig_in_cp = 0;
static UINT g_win_orig_out_cp = 0;
static int g_win_has_orig_mode = 0;

static int g_win_last_w = 0;
static int g_win_last_h = 0;
static int g_win_resize_pipe_fd = -1;

static int g_win_last_errno = 0;
static int g_win_last_again = 0;
static int g_poll_revents[2];
static unsigned char g_win_fd_nonblock[TB_WIN_MAX_CRT_FD];

static int win_is_fd_nonblock(int fd) {
    if (fd == TB_WIN_CONSOLE_FD) return g_win_con_nonblock;
    if (fd >= 0 && fd < TB_WIN_MAX_CRT_FD) return (int)g_win_fd_nonblock[fd];
    return 0;
}

static void win_set_fd_nonblock_state(int fd, int nb) {
    if (fd == TB_WIN_CONSOLE_FD) {
        g_win_con_nonblock = nb ? 1 : 0;
    } else if (fd >= 0 && fd < TB_WIN_MAX_CRT_FD) {
        g_win_fd_nonblock[fd] = nb ? 1 : 0;
    }
}

static int win_get_console_handles(int fd, HANDLE *out_in, HANDLE *out_out) {
    if (fd == TB_WIN_CONSOLE_FD) {
        if (g_win_con_in == INVALID_HANDLE_VALUE || g_win_con_out == INVALID_HANDLE_VALUE) {
            return 0;
        }
        if (out_in) *out_in = g_win_con_in;
        if (out_out) *out_out = g_win_con_out;
        return 1;
    }
    if (fd < 0) return 0;
    intptr_t osfh = _get_osfhandle(fd);
    if (osfh == -1) return 0;
    HANDLE h = (HANDLE)osfh;
    DWORD mode = 0;
    if (!GetConsoleMode(h, &mode)) return 0;

    CONSOLE_SCREEN_BUFFER_INFO csbi;
    if (GetConsoleScreenBufferInfo(h, &csbi)) {
        if (out_out) *out_out = h;
        if (out_in) *out_in = GetStdHandle(STD_INPUT_HANDLE);
    } else {
        if (out_in) *out_in = h;
        if (out_out) *out_out = GetStdHandle(STD_OUTPUT_HANDLE);
    }
    return 1;
}

static void win_notify_resize_if_changed(HANDLE h_out) {
    if (h_out == INVALID_HANDLE_VALUE || g_win_resize_pipe_fd < 0) return;
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    if (!GetConsoleScreenBufferInfo(h_out, &csbi)) return;
    int w = (int)(csbi.srWindow.Right - csbi.srWindow.Left + 1);
    int h = (int)(csbi.srWindow.Bottom - csbi.srWindow.Top + 1);
    if (w > 0 && h > 0 && (w != g_win_last_w || h != g_win_last_h)) {
        g_win_last_w = w;
        g_win_last_h = h;
        (void)tb_adapter_resize_notify(g_win_resize_pipe_fd);
    }
}

static int win_is_non_vt_key(const KEY_EVENT_RECORD *ke) {
    if (!ke->bKeyDown) return 1;
    if (ke->uChar.UnicodeChar != 0) return 0;
    switch (ke->wVirtualKeyCode) {
        case VK_SHIFT:
        case VK_CONTROL:
        case VK_MENU:
        case VK_LSHIFT:
        case VK_RSHIFT:
        case VK_LCONTROL:
        case VK_RCONTROL:
        case VK_LMENU:
        case VK_RMENU:
        case VK_LWIN:
        case VK_RWIN:
        case VK_CAPITAL:
        case VK_NUMLOCK:
        case VK_SCROLL:
        case VK_PAUSE:
        case VK_SNAPSHOT:
        case VK_APPS:
        case VK_PROCESSKEY:
            return 1;
        default:
            return 0;
    }
}

/* Drain non-stream console records (resize, focus, menu, key-up, pure modifiers,
 * bare mouse hover) so ReadFile never blocks; return 1 if VT input is ready. */
static int win_check_and_drain_console(HANDLE h_in, HANDLE h_out) {
    win_notify_resize_if_changed(h_out);
    for (;;) {
        INPUT_RECORD rec;
        DWORD n = 0;
        if (!PeekConsoleInputW(h_in, &rec, 1, &n) || n == 0) {
            return 0;
        }
        if (rec.EventType == WINDOW_BUFFER_SIZE_EVENT) {
            INPUT_RECORD dummy;
            DWORD nr = 0;
            (void)ReadConsoleInputW(h_in, &dummy, 1, &nr);
            if (g_win_resize_pipe_fd >= 0) {
                CONSOLE_SCREEN_BUFFER_INFO csbi;
                if (GetConsoleScreenBufferInfo(h_out, &csbi)) {
                    g_win_last_w = (int)(csbi.srWindow.Right - csbi.srWindow.Left + 1);
                    g_win_last_h = (int)(csbi.srWindow.Bottom - csbi.srWindow.Top + 1);
                }
                (void)tb_adapter_resize_notify(g_win_resize_pipe_fd);
            }
            continue;
        }
        if (rec.EventType == FOCUS_EVENT || rec.EventType == MENU_EVENT) {
            INPUT_RECORD dummy;
            DWORD nr = 0;
            (void)ReadConsoleInputW(h_in, &dummy, 1, &nr);
            continue;
        }
        if (rec.EventType == KEY_EVENT) {
            if (win_is_non_vt_key(&rec.Event.KeyEvent)) {
                INPUT_RECORD dummy;
                DWORD nr = 0;
                (void)ReadConsoleInputW(h_in, &dummy, 1, &nr);
                continue;
            }
            return 1;
        }
        if (rec.EventType == MOUSE_EVENT) {
            const MOUSE_EVENT_RECORD *me = &rec.Event.MouseEvent;
            if (me->dwEventFlags == MOUSE_MOVED && me->dwButtonState == 0) {
                INPUT_RECORD dummy;
                DWORD nr = 0;
                (void)ReadConsoleInputW(h_in, &dummy, 1, &nr);
                continue;
            }
            return 1;
        }
        /* Unknown record type: discard safely */
        {
            INPUT_RECORD dummy;
            DWORD nr = 0;
            (void)ReadConsoleInputW(h_in, &dummy, 1, &nr);
        }
    }
}

/* Return 1 if pipe has >=1 byte available, 0 if empty, 2 if broken/EOF, -1 if not a pipe. */
static int win_pipe_status(int fd) {
    if (fd < 0) return -1;
    intptr_t osfh = _get_osfhandle(fd);
    if (osfh == -1) return -1;
    HANDLE h = (HANDLE)osfh;
    if (GetFileType(h) != FILE_TYPE_PIPE) return -1;
    DWORD avail = 0;
    if (PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) {
        return avail > 0 ? 1 : 0;
    }
    DWORD err = GetLastError();
    if (err == ERROR_BROKEN_PIPE || err == ERROR_NO_DATA) {
        return 2;
    }
    g_win_last_errno = (int)err;
    return 2;
}

int tb_adapter_save_termios(int fd) {
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    if (!win_get_console_handles(fd, &h_in, &h_out)) {
        g_win_last_errno = EINVAL;
        return -1;
    }
    if (!GetConsoleMode(h_in, &g_win_orig_in_mode) ||
        !GetConsoleMode(h_out, &g_win_orig_out_mode)) {
        g_win_last_errno = (int)GetLastError();
        return -1;
    }
    g_win_orig_in_cp = GetConsoleCP();
    g_win_orig_out_cp = GetConsoleOutputCP();
    g_win_has_orig_mode = 1;
    return 0;
}

int tb_adapter_restore_termios(int fd) {
    if (!g_win_has_orig_mode) return 0;
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    int ok = 1;
    if (win_get_console_handles(fd, &h_in, &h_out)) {
        if (!SetConsoleMode(h_in, g_win_orig_in_mode)) ok = 0;
        if (!SetConsoleMode(h_out, g_win_orig_out_mode)) ok = 0;
    }
    if (g_win_orig_in_cp != 0) (void)SetConsoleCP(g_win_orig_in_cp);
    if (g_win_orig_out_cp != 0) (void)SetConsoleOutputCP(g_win_orig_out_cp);
    g_win_has_orig_mode = 0;
    return ok ? 0 : -1;
}

int tb_adapter_ioctl_winsize(int fd, unsigned long request, void *ws) {
    (void)fd;
    (void)request;
    (void)ws;
    g_win_last_errno = ENOSYS;
    return -1;
}

int tb_adapter_get_winsize(int fd, int *out_w, int *out_h) {
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    if (!win_get_console_handles(fd, &h_in, &h_out) || h_out == INVALID_HANDLE_VALUE) {
        g_win_last_errno = ENOTTY;
        return -1;
    }
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    if (!GetConsoleScreenBufferInfo(h_out, &csbi)) {
        g_win_last_errno = (int)GetLastError();
        return -1;
    }
    int w = (int)(csbi.srWindow.Right - csbi.srWindow.Left + 1);
    int h = (int)(csbi.srWindow.Bottom - csbi.srWindow.Top + 1);
    if (w <= 0 || h <= 0) return -1;
    if (out_w) *out_w = w;
    if (out_h) *out_h = h;
    return 0;
}

int tb_adapter_fcntl_getfl(int fd) {
    return win_is_fd_nonblock(fd) ? 1 : 0;
}

int tb_adapter_fcntl_setfl(int fd, int flags) {
    win_set_fd_nonblock_state(fd, flags != 0);
    return 0;
}

int tb_adapter_set_nonblock(int fd) {
    win_set_fd_nonblock_state(fd, 1);
    return 0;
}

int tb_adapter_save_and_set_nonblock(int fd, int *out_orig_flags) {
    int prev = win_is_fd_nonblock(fd);
    if (out_orig_flags) *out_orig_flags = prev;
    win_set_fd_nonblock_state(fd, 1);
    return 0;
}

int tb_adapter_restore_fd_flags(int fd, int orig_flags) {
    win_set_fd_nonblock_state(fd, orig_flags != 0);
    return 0;
}

int tb_adapter_open_tty(const char *path, int flags) {
    (void)flags;
    return tb_adapter_open_tty_rw(path);
}

int tb_adapter_open_tty_rw(const char *path) {
    if (!path) {
        g_win_last_errno = EINVAL;
        return -1;
    }
    if (strcmp(path, "/dev/tty") == 0 ||
        _stricmp(path, "CON") == 0 ||
        _stricmp(path, "CONIN$") == 0 ||
        _stricmp(path, "CONOUT$") == 0) {
        HANDLE h_in = CreateFileW(
            L"CONIN$", GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        int owns_in = 1;
        if (h_in == INVALID_HANDLE_VALUE) {
            h_in = GetStdHandle(STD_INPUT_HANDLE);
            owns_in = 0;
        }
        HANDLE h_out = CreateFileW(
            L"CONOUT$", GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        int owns_out = 1;
        if (h_out == INVALID_HANDLE_VALUE) {
            h_out = GetStdHandle(STD_OUTPUT_HANDLE);
            owns_out = 0;
        }
        DWORD m_in = 0, m_out = 0;
        if (h_in == INVALID_HANDLE_VALUE || h_out == INVALID_HANDLE_VALUE ||
            !GetConsoleMode(h_in, &m_in) || !GetConsoleMode(h_out, &m_out)) {
            if (owns_in && h_in != INVALID_HANDLE_VALUE) CloseHandle(h_in);
            if (owns_out && h_out != INVALID_HANDLE_VALUE) CloseHandle(h_out);
            g_win_last_errno = ENODEV;
            return -1;
        }
        g_win_con_in = h_in;
        g_win_con_out = h_out;
        g_win_con_owns_in = owns_in;
        g_win_con_owns_out = owns_out;
        g_win_con_nonblock = 0;
        return TB_WIN_CONSOLE_FD;
    }
    int fd = _open(path, _O_RDWR | _O_BINARY);
    if (fd < 0) g_win_last_errno = errno;
    return fd;
}

int tb_adapter_close(int fd) {
    if (fd == TB_WIN_CONSOLE_FD) {
        if (g_win_con_owns_in && g_win_con_in != INVALID_HANDLE_VALUE) {
            CloseHandle(g_win_con_in);
        }
        if (g_win_con_owns_out && g_win_con_out != INVALID_HANDLE_VALUE) {
            CloseHandle(g_win_con_out);
        }
        g_win_con_in = INVALID_HANDLE_VALUE;
        g_win_con_out = INVALID_HANDLE_VALUE;
        g_win_con_owns_in = 0;
        g_win_con_owns_out = 0;
        g_win_con_nonblock = 0;
        return 0;
    }
    if (fd >= 0 && fd < TB_WIN_MAX_CRT_FD) {
        g_win_fd_nonblock[fd] = 0;
    }
    int rv = _close(fd);
    if (rv < 0) g_win_last_errno = errno;
    return rv;
}

long long tb_adapter_write(int fd, const char *buf, size_t n) {
    g_win_last_again = 0;
    if (!buf || n == 0) return 0;
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    if (win_get_console_handles(fd, &h_in, &h_out) && h_out != INVALID_HANDLE_VALUE) {
        DWORD to_write = (n > 0x7fffffffULL) ? 0x7fffffffU : (DWORD)n;
        DWORD nw = 0;
        if (!WriteFile(h_out, buf, to_write, &nw, NULL)) {
            g_win_last_errno = (int)GetLastError();
            return -1;
        }
        return (long long)nw;
    }
    unsigned int to_write = (n > 0x7fffffffULL) ? 0x7fffffffU : (unsigned int)n;
    int rv = _write(fd, buf, to_write);
    if (rv < 0) g_win_last_errno = errno;
    return (long long)rv;
}

long long tb_adapter_read(int fd, char *buf, size_t n) {
    g_win_last_again = 0;
    if (!buf || n == 0) return 0;
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    if (win_get_console_handles(fd, &h_in, &h_out) && h_in != INVALID_HANDLE_VALUE) {
        int nb = win_is_fd_nonblock(fd);
        for (;;) {
            if (win_check_and_drain_console(h_in, h_out)) {
                break;
            }
            if (nb) {
                g_win_last_again = 1;
                g_win_last_errno = EAGAIN;
                return -1;
            }
            (void)WaitForSingleObject(h_in, 25);
        }
        DWORD to_read = (n > 0x7fffffffULL) ? 0x7fffffffU : (DWORD)n;
        DWORD nr = 0;
        if (!ReadFile(h_in, buf, to_read, &nr, NULL)) {
            g_win_last_errno = (int)GetLastError();
            return -1;
        }
        return (long long)nr;
    }
    int pst = win_pipe_status(fd);
    if (pst == 2) return 0; /* broken pipe = EOF */
    if (pst == 0 && win_is_fd_nonblock(fd)) {
        g_win_last_again = 1;
        g_win_last_errno = EAGAIN;
        return -1;
    }
    unsigned int to_read = (n > 0x7fffffffULL) ? 0x7fffffffU : (unsigned int)n;
    int rv = _read(fd, buf, to_read);
    if (rv < 0) g_win_last_errno = errno;
    return (long long)rv;
}

int tb_adapter_pipe(int *pipefd) {
    if (!pipefd) return -1;
    if (_pipe(pipefd, 4096, _O_BINARY) != 0) {
        g_win_last_errno = errno;
        return -1;
    }
    win_set_fd_nonblock_state(pipefd[0], 1);
    win_set_fd_nonblock_state(pipefd[1], 1);
    return 0;
}

int tb_adapter_poll(int fd, int timeout_ms) {
    long long start = tb_adapter_now_ms();
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    int is_con = win_get_console_handles(fd, &h_in, &h_out);
    for (;;) {
        if (is_con) {
            if (win_check_and_drain_console(h_in, h_out)) return 1;
        } else {
            int pst = win_pipe_status(fd);
            if (pst == 1 || pst == 2) return 1;
            if (pst < 0) return 1;
        }
        if (timeout_ms == 0) return 0;
        DWORD wait_ms = 10;
        if (timeout_ms > 0) {
            long long elapsed = tb_adapter_now_ms() - start;
            if (elapsed >= (long long)timeout_ms) return 0;
            long long rem = (long long)timeout_ms - elapsed;
            if (rem < (long long)wait_ms) wait_ms = (DWORD)rem;
        }
        if (is_con) {
            (void)WaitForSingleObject(h_in, wait_ms);
        } else {
            Sleep(wait_ms > 2 ? 2 : wait_ms);
        }
    }
}

int tb_adapter_poll_out(int fd, int timeout_ms) {
    (void)timeout_ms;
    if (fd < 0) return -1;
    return 1;
}

int tb_adapter_poll_multi(int fd1, int fd2, int timeout_ms) {
    g_poll_revents[0] = 0;
    g_poll_revents[1] = 0;
    long long start = tb_adapter_now_ms();
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    int is_con = win_get_console_handles(fd1, &h_in, &h_out);

    for (;;) {
        int ready = 0;
        if (fd2 >= 0) {
            int p2 = win_pipe_status(fd2);
            if (p2 == 1) {
                g_poll_revents[1] |= TB_WIN_POLLIN;
                ready++;
            } else if (p2 == 2) {
                g_poll_revents[1] |= TB_WIN_POLLERR;
                ready++;
            }
        }
        if (is_con) {
            if (win_check_and_drain_console(h_in, h_out)) {
                g_poll_revents[0] |= TB_WIN_POLLIN;
                ready++;
            }
            if (fd2 >= 0 && win_pipe_status(fd2) == 1 && (g_poll_revents[1] & TB_WIN_POLLIN) == 0) {
                g_poll_revents[1] |= TB_WIN_POLLIN;
                ready++;
            }
        } else if (fd1 >= 0) {
            int p1 = win_pipe_status(fd1);
            if (p1 == 1) {
                g_poll_revents[0] |= TB_WIN_POLLIN;
                ready++;
            } else if (p1 == 2) {
                g_poll_revents[0] |= TB_WIN_POLLERR;
                ready++;
            } else if (p1 < 0) {
                g_poll_revents[0] |= TB_WIN_POLLIN;
                ready++;
            }
        }
        if (ready > 0) return ready;
        if (timeout_ms == 0) return 0;

        DWORD wait_ms = is_con ? 50 : 2;
        if (timeout_ms > 0) {
            long long elapsed = tb_adapter_now_ms() - start;
            if (elapsed >= (long long)timeout_ms) return 0;
            long long rem = (long long)timeout_ms - elapsed;
            if (rem < (long long)wait_ms) wait_ms = (DWORD)rem;
        }
        if (is_con) {
            (void)WaitForSingleObject(h_in, wait_ms);
        } else {
            Sleep(wait_ms);
        }
    }
}

int tb_adapter_poll_revents(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return g_poll_revents[idx];
}

int tb_adapter_poll_is_in(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return (g_poll_revents[idx] & TB_WIN_POLLIN) ? 1 : 0;
}

int tb_adapter_poll_is_err(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return (g_poll_revents[idx] & TB_WIN_POLLERR) ? 1 : 0;
}

int tb_adapter_isatty(int fd) {
    return win_get_console_handles(fd, NULL, NULL) ? 1 : 0;
}

int tb_adapter_errno(void) {
    return g_win_last_errno;
}

int tb_adapter_is_eintr(void) {
    return 0;
}

int tb_adapter_is_again(void) {
    return g_win_last_again ? 1 : 0;
}

const char *tb_adapter_ttyname(int fd) {
    if (tb_adapter_isatty(fd)) return "CONIN$";
    return NULL;
}

int tb_adapter_get_ttyname(char *buf, size_t bufsz, const char *tty_name_ptr) {
    if (!buf || !tty_name_ptr || bufsz == 0) return -1;
    size_t len = strlen(tty_name_ptr);
    if (len >= bufsz) len = bufsz - 1;
    memcpy(buf, tty_name_ptr, len);
    buf[len] = '\0';
    return (int)len;
}

int tb_adapter_getenv(const char *name, char *buf, size_t bufsz) {
    if (!name || !buf || bufsz == 0) return -1;
    const char *val = getenv(name);
    if (val) {
        size_t len = strlen(val);
        if (len >= bufsz) len = bufsz - 1;
        memcpy(buf, val, len);
        buf[len] = '\0';
        return (int)len;
    }
    DWORD got = GetEnvironmentVariableA(name, buf, (DWORD)bufsz);
    if (got == 0) return -1;
    if (got >= (DWORD)bufsz) {
        buf[bufsz - 1] = '\0';
        return (int)(bufsz - 1);
    }
    return (int)got;
}

int tb_adapter_get_term(char *buf, size_t bufsz) {
    if (!buf || bufsz == 0) return -1;
    const char *val = getenv("TERM");
    if (val) {
        if (val[0] == '\0') return -1;
        size_t len = strlen(val);
        if (len >= bufsz) len = bufsz - 1;
        memcpy(buf, val, len);
        buf[len] = '\0';
        return (int)len;
    }
    SetLastError(ERROR_SUCCESS);
    DWORD got = GetEnvironmentVariableA("TERM", buf, (DWORD)bufsz);
    if (got > 0) {
        if (got >= (DWORD)bufsz) {
            buf[bufsz - 1] = '\0';
            return (int)(bufsz - 1);
        }
        return (int)got;
    }
    if (GetLastError() == ERROR_ENVVAR_NOT_FOUND) {
        static const char fallback[] = "xterm-256color";
        size_t flen = sizeof(fallback) - 1;
        if (flen >= bufsz) flen = bufsz - 1;
        memcpy(buf, fallback, flen);
        buf[flen] = '\0';
        return (int)flen;
    }
    return -1;
}

long long tb_adapter_read_file(const char *path, char *buf, size_t max_bytes) {
    if (!path || !buf || max_bytes == 0) return -1;
    int fd = _open(path, _O_RDONLY | _O_BINARY);
    if (fd < 0) return -1;
    size_t total = 0;
    while (total < max_bytes) {
        size_t rem = max_bytes - total;
        unsigned int chunk = (rem > 0x7fffffffULL) ? 0x7fffffffU : (unsigned int)rem;
        int n = _read(fd, buf + total, chunk);
        if (n > 0) {
            total += (size_t)n;
        } else if (n == 0) {
            break;
        } else {
            _close(fd);
            return -1;
        }
    }
    _close(fd);
    return (long long)total;
}

int tb_adapter_setup_signwinch(int pipe_fd) {
    g_win_resize_pipe_fd = pipe_fd;
    return 0;
}

int tb_adapter_clear_signwinch(void) {
    g_win_resize_pipe_fd = -1;
    return 0;
}

int tb_adapter_resize_notify(int fd) {
    const char b = 1;
    return _write(fd, &b, 1);
}

int tb_adapter_set_raw_mode(int fd) {
    HANDLE h_in = INVALID_HANDLE_VALUE;
    HANDLE h_out = INVALID_HANDLE_VALUE;
    if (!win_get_console_handles(fd, &h_in, &h_out)) {
        g_win_last_errno = EINVAL;
        return -1;
    }
    DWORD in_mode = 0, out_mode = 0;
    if (!GetConsoleMode(h_in, &in_mode) || !GetConsoleMode(h_out, &out_mode)) {
        g_win_last_errno = (int)GetLastError();
        return -1;
    }
    (void)SetConsoleCP(CP_UTF8);
    (void)SetConsoleOutputCP(CP_UTF8);

    DWORD new_out = out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN;
    if (!SetConsoleMode(h_out, new_out)) {
        new_out = out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        if (!SetConsoleMode(h_out, new_out)) {
            g_win_last_errno = (int)GetLastError();
            return -1;
        }
    }

    DWORD clear_in = ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT | ENABLE_QUICK_EDIT_MODE;
    DWORD new_in = (in_mode & ~clear_in) |
                   ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT |
                   ENABLE_MOUSE_INPUT | ENABLE_EXTENDED_FLAGS;
    if (!SetConsoleMode(h_in, new_in)) {
        new_in = (in_mode & ~(DWORD)(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT)) |
                 ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT;
        if (!SetConsoleMode(h_in, new_in)) {
            g_win_last_errno = (int)GetLastError();
            return -1;
        }
    }

    CONSOLE_SCREEN_BUFFER_INFO csbi;
    if (GetConsoleScreenBufferInfo(h_out, &csbi)) {
        g_win_last_w = (int)(csbi.srWindow.Right - csbi.srWindow.Left + 1);
        g_win_last_h = (int)(csbi.srWindow.Bottom - csbi.srWindow.Top + 1);
    }
    return 0;
}

long long tb_adapter_now_ms(void) {
    return (long long)GetTickCount64();
}

void tb_adapter_sleep_ms(int ms) {
    if (ms <= 0) return;
    Sleep((DWORD)ms);
}

#else /* POSIX */

#define _POSIX_C_SOURCE 200809L
#include "adapter.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Saved original termios (kept in C so platform struct size never leaks into Goose). */
static struct termios g_orig_tios;
static int g_has_orig_tios = 0;

/* The pipe fd that the SIGWINCH handler writes to. */
static volatile sig_atomic_t g_sigwinch_pipe_fd = -1;
static struct sigaction g_orig_sigwinch;
static int g_has_orig_sigwinch = 0;

/* SIGWINCH handler: wake up the poll loop by writing to the resize pipe. */
static void sigwinch_handler(int signum) {
    (void)signum;
    int saved_errno = errno;
    int fd = g_sigwinch_pipe_fd;
    if (fd >= 0) {
        const char b = 1;
        ssize_t r = write(fd, &b, 1);
        (void)r;
    }
    errno = saved_errno;
}

/* Termios: hide the platform-specific struct from Goose. */
int tb_adapter_tcgetattr(int fd, struct termios *tios) {
    return tcgetattr(fd, tios);
}

int tb_adapter_tcsetattr(int fd, int optional_actions, const struct termios *tios) {
    return tcsetattr(fd, optional_actions, tios);
}

int tb_adapter_save_termios(int fd) {
    if (tcgetattr(fd, &g_orig_tios) != 0) return -1;
    g_has_orig_tios = 1;
    return 0;
}

int tb_adapter_restore_termios(int fd) {
    if (!g_has_orig_tios) return 0;
    int rv = tcsetattr(fd, TCSAFLUSH, &g_orig_tios);
    g_has_orig_tios = 0;
    return rv;
}

/* Winsize via ioctl (TIOCGWINSZ). */
int tb_adapter_ioctl_winsize(int fd, unsigned long request, void *ws) {
    return ioctl(fd, request, ws);
}

int tb_adapter_get_winsize(int fd, int *out_w, int *out_h) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    if (ioctl(fd, TIOCGWINSZ, &ws) != 0) return -1;
    if (out_w) *out_w = (int)ws.ws_col;
    if (out_h) *out_h = (int)ws.ws_row;
    return 0;
}

/* fcntl wrappers (non-variadic subset we need). */
int tb_adapter_fcntl_getfl(int fd) {
    return fcntl(fd, F_GETFL, 0);
}

int tb_adapter_fcntl_setfl(int fd, int flags) {
    return fcntl(fd, F_SETFL, flags);
}

int tb_adapter_set_nonblock(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return -1;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int tb_adapter_save_and_set_nonblock(int fd, int *out_orig_flags) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return -1;
    if (out_orig_flags) *out_orig_flags = flags;
    if ((flags & O_NONBLOCK) == 0) {
        if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) return -1;
    }
    return 0;
}

int tb_adapter_restore_fd_flags(int fd, int orig_flags) {
    return fcntl(fd, F_SETFL, orig_flags);
}

/* open wrapper (path must be NUL-terminated). */
int tb_adapter_open_tty(const char *path, int flags) {
    return open(path, flags);
}

int tb_adapter_open_tty_rw(const char *path) {
    return open(path, O_RDWR);
}

int tb_adapter_close(int fd) {
    return close(fd);
}

long long tb_adapter_write(int fd, const char *buf, size_t n) {
    return (long long)write(fd, buf, n);
}

long long tb_adapter_read(int fd, char *buf, size_t n) {
    return (long long)read(fd, buf, n);
}

int tb_adapter_pipe(int *pipefd) {
    if (pipe(pipefd) != 0) return -1;
    int f0 = fcntl(pipefd[0], F_GETFL, 0);
    int f1 = fcntl(pipefd[1], F_GETFL, 0);
    if (f0 >= 0) (void)fcntl(pipefd[0], F_SETFL, f0 | O_NONBLOCK);
    if (f1 >= 0) (void)fcntl(pipefd[1], F_SETFL, f1 | O_NONBLOCK);
    return 0;
}

int tb_adapter_poll(int fd, int timeout_ms) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLIN;
    pfd.revents = 0;
    return poll(&pfd, 1, timeout_ms);
}

int tb_adapter_poll_out(int fd, int timeout_ms) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLOUT;
    pfd.revents = 0;
    return poll(&pfd, 1, timeout_ms);
}

/* Poll two fds simultaneously. Stores revents in g_poll_revents[0]/[1]. */
static int g_poll_revents[2];

int tb_adapter_poll_multi(int fd1, int fd2, int timeout_ms) {
    struct pollfd pfds[2];
    pfds[0].fd = fd1;
    pfds[0].events = POLLIN;
    pfds[0].revents = 0;
    pfds[1].fd = fd2;
    pfds[1].events = POLLIN;
    pfds[1].revents = 0;
    g_poll_revents[0] = 0;
    g_poll_revents[1] = 0;
    int rv = poll(pfds, 2, timeout_ms);
    if (rv > 0) {
        g_poll_revents[0] = pfds[0].revents;
        g_poll_revents[1] = pfds[1].revents;
    }
    return rv;
}

/* Return revents for fd index (0=fd1, 1=fd2) from the last tb_adapter_poll_multi call. */
int tb_adapter_poll_revents(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return g_poll_revents[idx];
}

int tb_adapter_poll_is_in(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return (g_poll_revents[idx] & POLLIN) ? 1 : 0;
}

int tb_adapter_poll_is_err(int idx) {
    if (idx < 0 || idx > 1) return 0;
    return (g_poll_revents[idx] & (POLLERR | POLLHUP | POLLNVAL)) ? 1 : 0;
}

int tb_adapter_isatty(int fd) {
    return isatty(fd);
}

/* errno access. */
int tb_adapter_errno(void) {
    return errno;
}

int tb_adapter_is_eintr(void) {
    return errno == EINTR ? 1 : 0;
}

int tb_adapter_is_again(void) {
    return (errno == EAGAIN || errno == EWOULDBLOCK) ? 1 : 0;
}

/* ttyname — returns const char* as a numeric pointer. */
const char *tb_adapter_ttyname(int fd) {
    static __thread char buf[64];
    int result = ttyname_r(fd, buf, sizeof(buf));
    if (result == 0) return buf;
    return NULL;
}

/* Copy terminal name from ttyname() into Goose buffer. */
int tb_adapter_get_ttyname(char *buf, size_t bufsz, const char *tty_name_ptr) {
    if (!buf || !tty_name_ptr || bufsz == 0) return -1;
    strncpy(buf, tty_name_ptr, bufsz - 1);
    buf[bufsz - 1] = '\0';
    return (int)strlen(buf);
}

/* Get environment variable by name into buffer. */
int tb_adapter_getenv(const char *name, char *buf, size_t bufsz) {
    if (!name || !buf || bufsz == 0) return -1;
    const char *val = getenv(name);
    if (!val) return -1;
    size_t len = strlen(val);
    if (len >= bufsz) len = bufsz - 1;
    memcpy(buf, val, len);
    buf[len] = '\0';
    return (int)len;
}

/* Get TERM environment variable into buffer. */
int tb_adapter_get_term(char *buf, size_t bufsz) {
    return tb_adapter_getenv("TERM", buf, bufsz);
}

/* Read a small binary file (e.g. compiled terminfo) into buffer. */
long long tb_adapter_read_file(const char *path, char *buf, size_t max_bytes) {
    if (!path || !buf || max_bytes == 0) return -1;
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    size_t total = 0;
    while (total < max_bytes) {
        ssize_t n = read(fd, buf + total, max_bytes - total);
        if (n > 0) {
            total += (size_t)n;
        } else if (n == 0) {
            break;
        } else if (errno == EINTR) {
            continue;
        } else {
            close(fd);
            return -1;
        }
    }
    close(fd);
    return (long long)total;
}

/* SIGWINCH handler setup: installs a handler that writes a byte to pipe_fd. */
int tb_adapter_setup_signwinch(int pipe_fd) {
    g_sigwinch_pipe_fd = pipe_fd;
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sigwinch_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGWINCH, &sa, &g_orig_sigwinch) == -1) {
        return -1;
    }
    g_has_orig_sigwinch = 1;
    return 0;
}

/* Clear SIGWINCH handler (restore previous handler) and reset pipe fd. */
int tb_adapter_clear_signwinch(void) {
    g_sigwinch_pipe_fd = -1;
    if (g_has_orig_sigwinch) {
        g_has_orig_sigwinch = 0;
        return sigaction(SIGWINCH, &g_orig_sigwinch, NULL) == -1 ? -1 : 0;
    }
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_DFL;
    sigemptyset(&sa.sa_mask);
    return sigaction(SIGWINCH, &sa, NULL) == -1 ? -1 : 0;
}

/* Resize pipe notification: write a byte to wake the poll loop. */
int tb_adapter_resize_notify(int fd) {
    const char b = 1;
    return (int)write(fd, &b, 1);
}

int tb_adapter_set_raw_mode(int fd) {
    struct termios raw;
    if (tcgetattr(fd, &raw) != 0) return -1;
    /* Disable canonical mode, echo, signal chars, output processing */
    raw.c_lflag &= ~(tcflag_t)(ICANON | ECHO | ECHOE | ECHOK | ECHONL | ISIG);
    raw.c_iflag &= ~(tcflag_t)(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(tcflag_t)(OPOST);
    raw.c_cflag &= ~(tcflag_t)(CSIZE | PARENB);
    raw.c_cflag |= (tcflag_t)(CS8);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    return tcsetattr(fd, TCSAFLUSH, &raw);
}

/* Current time in milliseconds using CLOCK_MONOTONIC. */
long long tb_adapter_now_ms(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

void tb_adapter_sleep_ms(int ms) {
    if (ms <= 0) return;
    struct timespec ts, rem;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (long)(ms % 1000) * 1000000L;
    while (nanosleep(&ts, &rem) == -1 && errno == EINTR) {
        ts = rem;
    }
}

#endif /* _WIN32 */
