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
