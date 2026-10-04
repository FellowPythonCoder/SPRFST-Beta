#ifndef SPRFST_RT_H
#define SPRFST_RT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SpfText SpfText;
typedef struct SpfList SpfList;
typedef struct SpfMap SpfMap;
typedef struct SpfSet SpfSet;
typedef struct SpfObj SpfObj;
typedef struct SpfChan SpfChan;

void spf_init(int argc, char **argv);
void spf_shutdown(void);
int64_t spf_argc(void);
SpfText *spf_argv(int64_t index);

void spf_panic(const char *msg);
void spf_show_text(SpfText *t);
void spf_show_int(int64_t v);
void spf_show_num(double v);
void spf_show_bool(bool v);
void spf_show_cstr(const char *s);
void spf_newline(void);

SpfText *spf_text_from_cstr(const char *s);
SpfText *spf_text_from_n(const char *s, size_t n);
const char *spf_text_cstr(SpfText *t);
int64_t spf_text_len(SpfText *t);
SpfText *spf_text_concat(SpfText *a, SpfText *b);
SpfText *spf_text_slice(SpfText *t, int64_t start, int64_t end);
int64_t spf_text_eq(SpfText *a, SpfText *b);
SpfText *spf_text_from_int(int64_t v);
SpfText *spf_text_from_num(double v);
int64_t spf_text_to_int(SpfText *t);
double spf_text_to_num(SpfText *t);
int64_t spf_text_contains(SpfText *hay, SpfText *needle);
SpfText *spf_text_upper(SpfText *t);
SpfText *spf_text_lower(SpfText *t);
SpfText *spf_text_trim(SpfText *t);
SpfList *spf_text_split(SpfText *t, SpfText *sep);
int64_t spf_text_hash(SpfText *t);

SpfList *spf_list_new(void);
void spf_list_push_int(SpfList *l, int64_t v);
void spf_list_push_num(SpfList *l, double v);
void spf_list_push_bool(SpfList *l, bool v);
void spf_list_push_ptr(SpfList *l, void *v);
int64_t spf_list_len(SpfList *l);
int64_t spf_list_get_int(SpfList *l, int64_t i);
double spf_list_get_num(SpfList *l, int64_t i);
bool spf_list_get_bool(SpfList *l, int64_t i);
void *spf_list_get_ptr(SpfList *l, int64_t i);
void spf_list_set_int(SpfList *l, int64_t i, int64_t v);
void spf_list_set_ptr(SpfList *l, int64_t i, void *v);

SpfMap *spf_map_new(void);
void spf_map_set_ptr(SpfMap *m, SpfText *k, void *v);
void *spf_map_get_ptr(SpfMap *m, SpfText *k);
int64_t spf_map_has(SpfMap *m, SpfText *k);
int64_t spf_map_len(SpfMap *m);
SpfList *spf_map_keys(SpfMap *m);

SpfSet *spf_set_new(void);
void spf_set_add(SpfSet *s, SpfText *k);
int64_t spf_set_has(SpfSet *s, SpfText *k);
int64_t spf_set_len(SpfSet *s);

int64_t spf_now_ms(void);
double spf_clock(void);
void spf_sleep_ms(int64_t ms);
int64_t spf_rand_int(int64_t lo, int64_t hi);
double spf_sqrt(double x);
double spf_pow(double x, double y);
double spf_sin(double x);
double spf_cos(double x);
double spf_abs(double x);
int64_t spf_iabs(int64_t x);
int64_t spf_min_i(int64_t a, int64_t b);
int64_t spf_max_i(int64_t a, int64_t b);

SpfText *spf_fs_read(SpfText *path);
int64_t spf_fs_write(SpfText *path, SpfText *data);
int64_t spf_fs_exists(SpfText *path);
int64_t spf_fs_mkdir(SpfText *path);
SpfList *spf_fs_list(SpfText *path);
int64_t spf_fs_remove(SpfText *path);

SpfText *spf_http_get(SpfText *url);
SpfText *spf_net_tcp_send(SpfText *host, int64_t port, SpfText *payload);

int64_t spf_db_open(SpfText *path);
int64_t spf_db_exec(int64_t handle, SpfText *sql);
SpfList *spf_db_query(int64_t handle, SpfText *sql);
void spf_db_close(int64_t handle);

void spf_spawn(void (*fn)(void *), void *arg);
SpfChan *spf_chan_new(int64_t cap);
void spf_chan_send_int(SpfChan *c, int64_t v);
int64_t spf_chan_recv_int(SpfChan *c);

int64_t spf_gui_window(SpfText *title, int64_t w, int64_t h);
void spf_gui_label(int64_t win, SpfText *text, int64_t x, int64_t y);
int64_t spf_gui_button(int64_t win, SpfText *title, int64_t x, int64_t y, int64_t w, int64_t h);
void spf_gui_run(int64_t win);

typedef struct {
    int64_t rows;
    int64_t cols;
    double *data;
} SpfTensor;

SpfTensor *spf_tensor_new(int64_t rows, int64_t cols);
void spf_tensor_set(SpfTensor *t, int64_t r, int64_t c, double v);
double spf_tensor_get(SpfTensor *t, int64_t r, int64_t c);
SpfTensor *spf_tensor_mul(SpfTensor *a, SpfTensor *b);
SpfTensor *spf_tensor_add(SpfTensor *a, SpfTensor *b);
void spf_tensor_relu(SpfTensor *t);

#ifdef __cplusplus
}
#endif

#endif
