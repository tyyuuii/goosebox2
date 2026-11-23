#ifndef TERMBOX2_ADAPTER_H
#define TERMBOX2_ADAPTER_H

#include <sys/ioctl.h>
#include <termios.h>
#include <stddef.h>

/* Termios: hide the platform-specific struct from Goose. */
int tb_adapter_tcgetattr(int fd, struct termios *tios);
int tb_adapter_tcsetattr(int fd, int optional_actions, const struct termios *tios);
int tb_adapter_save_termios(int fd);
int tb_adapter_restore_termios(int fd);

/* Winsize via ioctl (TIOCGWINSZ). */
int tb_adapter_ioctl_winsize(int fd, unsigned long request, void *ws);
int tb_adapter_get_winsize(int fd, int *out_w, int *out_h);

/* fcntl wrappers (non-variadic subset we need). */
int tb_adapter_fcntl_getfl(int fd);
int tb_adapter_fcntl_setfl(int fd, int flags);
int tb_adapter_set_nonblock(int fd);

/* open wrapper (path must be NUL-terminated). */
int tb_adapter_open_tty(const char *path, int flags);
int tb_adapter_open_tty_rw(const char *path);

/* close, read, write, pipe, isatty — thin wrappers for symmetry. */
int tb_adapter_close(int fd);

/* Match Goose's i64 return type: use long long and size_t (u64). */
long long tb_adapter_write(int fd, const char *buf, size_t n);
long long tb_adapter_read(int fd, char *buf, size_t n);
int tb_adapter_poll(int fd, int timeout_ms);
int tb_adapter_poll_out(int fd, int timeout_ms);
int tb_adapter_poll_multi(int fd1, int fd2, int timeout_ms);
int tb_adapter_poll_revents(int idx);
int tb_adapter_poll_is_in(int idx);
int tb_adapter_poll_is_err(int idx);
int tb_adapter_pipe(int *pipefd);
int tb_adapter_isatty(int fd);

/* errno access and portable predicates. */
int tb_adapter_errno(void);
int tb_adapter_is_eintr(void);
int tb_adapter_is_again(void);

/* ttyname — returns const char* as a numeric pointer. */
const char *tb_adapter_ttyname(int fd);

/* Copy terminal name from ttyname() into Goose buffer. */
int tb_adapter_get_ttyname(char *buf, size_t bufsz, const char *tty_name_ptr);

/* SIGWINCH handler setup: installs a handler that writes a byte to pipe_fd. */
int tb_adapter_setup_signwinch(int pipe_fd);

/* Clear SIGWINCH handler (restore default) and reset pipe fd. */
int tb_adapter_clear_signwinch(void);

/* Resize pipe notification: write a byte to wake the poll loop. */
int tb_adapter_resize_notify(int fd);

/* Put the terminal into raw mode (disable canonical mode, echo, signals). */
int tb_adapter_set_raw_mode(int fd);

/* Current time in milliseconds (CLOCK_MONOTONIC). */
long long tb_adapter_now_ms(void);

/* Sleep for milliseconds. */
void tb_adapter_sleep_ms(int ms);

/* Get TERM or arbitrary environment variable into buffer. */
int tb_adapter_get_term(char *buf, size_t bufsz);
int tb_adapter_getenv(const char *name, char *buf, size_t bufsz);

/* Read a small binary file (e.g. terminfo) into buffer; returns bytes read or -1. */
long long tb_adapter_read_file(const char *path, char *buf, size_t max_bytes);

#endif /* TERMBOX2_ADAPTER_H */
