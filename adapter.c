#include "adapter.h"

#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* The pipe fd that the SIGWINCH handler writes to. */
static int g_sigwinch_pipe_fd = -1;

/* SIGWINCH handler: wake up the poll loop by writing to the resize pipe. */
static void sigwinch_handler(int signum) {
    (void)signum;
    if (g_sigwinch_pipe_fd >= 0) {
        const char b = 1;
        write(g_sigwinch_pipe_fd, &b, 1);
    }
}

/* Termios: hide the platform-specific struct from Goose. */
int tb_adapter_tcgetattr(int fd, struct termios *tios) {
    return tcgetattr(fd, tios);
}

int tb_adapter_tcsetattr(int fd, int optional_actions, const struct termios *tios) {
    return tcsetattr(fd, optional_actions, tios);
}

/* Winsize via ioctl (TIOCGWINSZ). */
int tb_adapter_ioctl_winsize(int fd, unsigned long request, void *ws) {
    return ioctl(fd, request, ws);
}

/* fcntl wrappers (non-variadic subset we need). */
int tb_adapter_fcntl_getfl(int fd) {
    return fcntl(fd, F_GETFL, 0);
}

int tb_adapter_fcntl_setfl(int fd, int flags) {
    return fcntl(fd, F_SETFL, flags);
}

/* open wrapper (path must be NUL-terminated). */
int tb_adapter_open_tty(const char *path, int flags) {
    return open(path, flags);
}

int tb_adapter_close(int fd) {
    return close(fd);
}

int tb_adapter_write(int fd, const char *buf, size_t n) {
    return write(fd, buf, n);
}

int tb_adapter_read(int fd, char *buf, size_t n) {
    return read(fd, buf, n);
}

int tb_adapter_pipe(int *pipefd) {
    return pipe(pipefd);
}

int tb_adapter_poll(int fd, int timeout_ms) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLIN;
    pfd.revents = 0;
    return poll(&pfd, 1, timeout_ms);
}

int tb_adapter_isatty(int fd) {
    return isatty(fd);
}

/* errno access. */
int tb_adapter_errno(void) {
    return errno;
}

/* ttyname — returns const char* as a numeric pointer. */
const char *tb_adapter_ttyname(int fd) {
    return ttyname(fd);
}

/* vsnprintf wrapper for tb_printf / tb_sendf. */
int tb_adapter_vsnprintf(char *buf, size_t bufsz, const char *fmt, va_list ap) {
    return vsnprintf(buf, bufsz, fmt, ap);
}

/* SIGWINCH handler setup: installs a handler that writes a byte to pipe_fd. */
int tb_adapter_setup_signwinch(int pipe_fd) {
    g_sigwinch_pipe_fd = pipe_fd;
    return signal(SIGWINCH, sigwinch_handler) == SIG_ERR ? -1 : 0;
}

/* Resize pipe notification: write a byte to wake the poll loop. */
int tb_adapter_resize_notify(int fd) {
    const char b = 1;
    return write(fd, &b, 1);
}
