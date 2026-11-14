#ifndef TERMBOX2_ADAPTER_H
#define TERMBOX2_ADAPTER_H

#include <sys/ioctl.h>
#include <termios.h>
#include <stdarg.h>
#include <stddef.h>

/* Termios: hide the platform-specific struct from Goose. */
int tb_adapter_tcgetattr(int fd, struct termios *tios);
int tb_adapter_tcsetattr(int fd, int optional_actions, const struct termios *tios);

/* Winsize via ioctl (TIOCGWINSZ). */
int tb_adapter_ioctl_winsize(int fd, unsigned long request, void *ws);

/* fcntl wrappers (non-variadic subset we need). */
int tb_adapter_fcntl_getfl(int fd);
int tb_adapter_fcntl_setfl(int fd, int flags);

/* open wrapper (path must be NUL-terminated). */
int tb_adapter_open_tty(const char *path, int flags);

/* close, read, write, pipe, isatty — thin wrappers for symmetry. */
int tb_adapter_close(int fd);
int tb_adapter_write(int fd, const char *buf, size_t n);
int tb_adapter_read(int fd, char *buf, size_t n);
int tb_adapter_poll(int fd, int timeout_ms);
int tb_adapter_pipe(int *pipefd);
int tb_adapter_isatty(int fd);

/* errno access. */
int tb_adapter_errno(void);

/* ttyname — returns const char* as a numeric pointer. */
const char *tb_adapter_ttyname(int fd);

/* Copy terminal name from ttyname() into Goose buffer. */
int tb_adapter_get_ttyname(char *buf, size_t bufsz, const char *tty_name_ptr);

/* vsnprintf wrapper for tb_printf / tb_sendf. */
int tb_adapter_vsnprintf(char *buf, size_t bufsz, const char *fmt, va_list ap);

/* SIGWINCH handler setup: installs a handler that writes a byte to pipe_fd. */
int tb_adapter_setup_signwinch(int pipe_fd);

/* Resize pipe notification: write a byte to wake the poll loop. */
int tb_adapter_resize_notify(int fd);

/* Put the terminal into raw mode (disable canonical mode, echo, signals). */
int tb_adapter_set_raw_mode(int fd);

#endif /* TERMBOX2_ADAPTER_H */
