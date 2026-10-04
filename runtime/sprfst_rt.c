#include "sprfst_rt.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <pthread.h>
#include <sqlite3.h>
#include <ctype.h>
#include <errno.h>

struct SpfText {
    int64_t refs;
    size_t len;
    char *data;
};

enum { SPF_CELL_INT, SPF_CELL_NUM, SPF_CELL_BOOL, SPF_CELL_PTR };

typedef struct {
    int tag;
    union {
        int64_t i;
        double n;
        bool b;
        void *p;
    } u;
} SpfCell;

struct SpfList {
    int64_t refs;
    size_t len;
    size_t cap;
    SpfCell *items;
};

typedef struct SpfMapEntry {
    SpfText *key;
    void *val;
    struct SpfMapEntry *next;
} SpfMapEntry;

struct SpfMap {
    int64_t refs;
    SpfMapEntry *heads[64];
    int64_t count;
};

struct SpfSet {
    SpfMap *inner;
};

struct SpfChan {
    pthread_mutex_t mu;
    pthread_cond_t cv;
    int64_t *q;
    size_t cap;
    size_t len;
    size_t head;
};

static int g_argc = 0;
static char **g_argv = NULL;
static sqlite3 *g_dbs[32];
static pthread_mutex_t g_spawn_mu = PTHREAD_MUTEX_INITIALIZER;

void spf_panic(const char *msg) {
    fprintf(stderr, "sprfst panic: %s\n", msg ? msg : "unknown");
    exit(1);
}

void spf_init(int argc, char **argv) {
    g_argc = argc;
    g_argv = argv;
    memset(g_dbs, 0, sizeof(g_dbs));
    srand((unsigned)time(NULL) ^ (unsigned)clock());
}

void spf_shutdown(void) {
    for (int i = 0; i < 32; i++) {
        if (g_dbs[i]) {
            sqlite3_close(g_dbs[i]);
            g_dbs[i] = NULL;
        }
    }
}

int64_t spf_argc(void) { return g_argc; }

SpfText *spf_argv(int64_t index) {
    if (index < 0 || index >= g_argc) return spf_text_from_cstr("");
    return spf_text_from_cstr(g_argv[index]);
}

static SpfText *text_alloc(size_t n) {
    SpfText *t = (SpfText *)calloc(1, sizeof(SpfText));
    if (!t) spf_panic("out of memory");
    t->refs = 1;
    t->len = n;
    t->data = (char *)calloc(n + 1, 1);
    if (!t->data) spf_panic("out of memory");
    return t;
}

SpfText *spf_text_from_n(const char *s, size_t n) {
    SpfText *t = text_alloc(n);
    if (s && n) memcpy(t->data, s, n);
    return t;
}

SpfText *spf_text_from_cstr(const char *s) {
    if (!s) s = "";
    return spf_text_from_n(s, strlen(s));
}

const char *spf_text_cstr(SpfText *t) { return t ? t->data : ""; }
int64_t spf_text_len(SpfText *t) { return t ? (int64_t)t->len : 0; }

SpfText *spf_text_concat(SpfText *a, SpfText *b) {
    size_t n1 = a ? a->len : 0;
    size_t n2 = b ? b->len : 0;
    SpfText *t = text_alloc(n1 + n2);
    if (n1) memcpy(t->data, a->data, n1);
    if (n2) memcpy(t->data + n1, b->data, n2);
    return t;
}

SpfText *spf_text_slice(SpfText *t, int64_t start, int64_t end) {
    int64_t n = spf_text_len(t);
    if (start < 0) start = 0;
    if (end > n) end = n;
    if (end < start) end = start;
    return spf_text_from_n(t->data + start, (size_t)(end - start));
}

int64_t spf_text_eq(SpfText *a, SpfText *b) {
    if (!a || !b) return a == b;
    if (a->len != b->len) return 0;
    return memcmp(a->data, b->data, a->len) == 0;
}

SpfText *spf_text_from_int(int64_t v) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%lld", (long long)v);
    return spf_text_from_cstr(buf);
}

SpfText *spf_text_from_num(double v) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.12g", v);
    return spf_text_from_cstr(buf);
}

int64_t spf_text_to_int(SpfText *t) { return t ? atoll(t->data) : 0; }
double spf_text_to_num(SpfText *t) { return t ? atof(t->data) : 0; }

int64_t spf_text_contains(SpfText *hay, SpfText *needle) {
    if (!hay || !needle) return 0;
    return strstr(hay->data, needle->data) != NULL;
}

SpfText *spf_text_upper(SpfText *t) {
    SpfText *o = spf_text_from_n(t->data, t->len);
    for (size_t i = 0; i < o->len; i++) o->data[i] = (char)toupper((unsigned char)o->data[i]);
    return o;
}

SpfText *spf_text_lower(SpfText *t) {
    SpfText *o = spf_text_from_n(t->data, t->len);
    for (size_t i = 0; i < o->len; i++) o->data[i] = (char)tolower((unsigned char)o->data[i]);
    return o;
}

SpfText *spf_text_trim(SpfText *t) {
    if (!t) return spf_text_from_cstr("");
    size_t i = 0, j = t->len;
    while (i < j && isspace((unsigned char)t->data[i])) i++;
    while (j > i && isspace((unsigned char)t->data[j - 1])) j--;
    return spf_text_from_n(t->data + i, j - i);
}

SpfList *spf_text_split(SpfText *t, SpfText *sep) {
    SpfList *out = spf_list_new();
    if (!t) return out;
    const char *s = t->data;
    const char *needle = sep && sep->len ? sep->data : " ";
    size_t nlen = sep && sep->len ? sep->len : 1;
    const char *p = s;
    while (1) {
        const char *f = strstr(p, needle);
        if (!f) {
            spf_list_push_ptr(out, spf_text_from_cstr(p));
            break;
        }
        spf_list_push_ptr(out, spf_text_from_n(p, (size_t)(f - p)));
        p = f + nlen;
    }
    return out;
}

int64_t spf_text_hash(SpfText *t) {
    uint64_t h = 1469598103934665603ULL;
    if (!t) return 0;
    for (size_t i = 0; i < t->len; i++) {
        h ^= (unsigned char)t->data[i];
        h *= 1099511628211ULL;
    }
    return (int64_t)h;
}

void spf_show_text(SpfText *t) { fputs(spf_text_cstr(t), stdout); }
void spf_show_int(int64_t v) { printf("%lld", (long long)v); }
void spf_show_num(double v) { printf("%.12g", v); }
void spf_show_bool(bool v) { fputs(v ? "true" : "false", stdout); }
void spf_show_cstr(const char *s) { fputs(s ? s : "", stdout); }
void spf_newline(void) { fputc('\n', stdout); fflush(stdout); }

SpfList *spf_list_new(void) {
    SpfList *l = (SpfList *)calloc(1, sizeof(SpfList));
    l->refs = 1;
    l->cap = 8;
    l->items = (SpfCell *)calloc(l->cap, sizeof(SpfCell));
    return l;
}

static void list_grow(SpfList *l) {
    if (l->len + 1 <= l->cap) return;
    l->cap *= 2;
    l->items = (SpfCell *)realloc(l->items, l->cap * sizeof(SpfCell));
}

void spf_list_push_int(SpfList *l, int64_t v) {
    list_grow(l);
    l->items[l->len].tag = SPF_CELL_INT;
    l->items[l->len++].u.i = v;
}
void spf_list_push_num(SpfList *l, double v) {
    list_grow(l);
    l->items[l->len].tag = SPF_CELL_NUM;
    l->items[l->len++].u.n = v;
}
void spf_list_push_bool(SpfList *l, bool v) {
    list_grow(l);
    l->items[l->len].tag = SPF_CELL_BOOL;
    l->items[l->len++].u.b = v;
}
void spf_list_push_ptr(SpfList *l, void *v) {
    list_grow(l);
    l->items[l->len].tag = SPF_CELL_PTR;
    l->items[l->len++].u.p = v;
}
int64_t spf_list_len(SpfList *l) { return l ? (int64_t)l->len : 0; }

static SpfCell *cell_at(SpfList *l, int64_t i) {
    if (!l || i < 0 || (size_t)i >= l->len) spf_panic("list index out of range");
    return &l->items[i];
}

int64_t spf_list_get_int(SpfList *l, int64_t i) { return cell_at(l, i)->u.i; }
double spf_list_get_num(SpfList *l, int64_t i) { return cell_at(l, i)->u.n; }
bool spf_list_get_bool(SpfList *l, int64_t i) { return cell_at(l, i)->u.b; }
void *spf_list_get_ptr(SpfList *l, int64_t i) { return cell_at(l, i)->u.p; }

void spf_list_set_int(SpfList *l, int64_t i, int64_t v) {
    cell_at(l, i)->tag = SPF_CELL_INT;
    cell_at(l, i)->u.i = v;
}
void spf_list_set_ptr(SpfList *l, int64_t i, void *v) {
    cell_at(l, i)->tag = SPF_CELL_PTR;
    cell_at(l, i)->u.p = v;
}

static uint64_t hash_text(SpfText *t) {
    uint64_t h = (uint64_t)spf_text_hash(t);
    return h;
}

SpfMap *spf_map_new(void) {
    SpfMap *m = (SpfMap *)calloc(1, sizeof(SpfMap));
    m->refs = 1;
    return m;
}

void spf_map_set_ptr(SpfMap *m, SpfText *k, void *v) {
    uint64_t h = hash_text(k) & 63;
    for (SpfMapEntry *e = m->heads[h]; e; e = e->next) {
        if (spf_text_eq(e->key, k)) {
            e->val = v;
            return;
        }
    }
    SpfMapEntry *e = (SpfMapEntry *)calloc(1, sizeof(SpfMapEntry));
    e->key = k;
    e->val = v;
    e->next = m->heads[h];
    m->heads[h] = e;
    m->count++;
}

void *spf_map_get_ptr(SpfMap *m, SpfText *k) {
    uint64_t h = hash_text(k) & 63;
    for (SpfMapEntry *e = m->heads[h]; e; e = e->next) {
        if (spf_text_eq(e->key, k)) return e->val;
    }
    return NULL;
}

int64_t spf_map_has(SpfMap *m, SpfText *k) { return spf_map_get_ptr(m, k) != NULL; }
int64_t spf_map_len(SpfMap *m) { return m ? m->count : 0; }

SpfList *spf_map_keys(SpfMap *m) {
    SpfList *keys = spf_list_new();
    for (int i = 0; i < 64; i++) {
        for (SpfMapEntry *e = m->heads[i]; e; e = e->next) {
            spf_list_push_ptr(keys, e->key);
        }
    }
    return keys;
}

SpfSet *spf_set_new(void) {
    SpfSet *s = (SpfSet *)calloc(1, sizeof(SpfSet));
    s->inner = spf_map_new();
    return s;
}
void spf_set_add(SpfSet *s, SpfText *k) { spf_map_set_ptr(s->inner, k, (void *)1); }
int64_t spf_set_has(SpfSet *s, SpfText *k) { return spf_map_has(s->inner, k); }
int64_t spf_set_len(SpfSet *s) { return spf_map_len(s->inner); }

int64_t spf_now_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}
double spf_clock(void) {
    return (double)clock() / (double)CLOCKS_PER_SEC;
}
void spf_sleep_ms(int64_t ms) {
    if (ms < 0) ms = 0;
    usleep((useconds_t)(ms * 1000));
}
int64_t spf_rand_int(int64_t lo, int64_t hi) {
    if (hi <= lo) return lo;
    return lo + (int64_t)(rand() % (int)(hi - lo + 1));
}
double spf_sqrt(double x) { return sqrt(x); }
double spf_pow(double x, double y) { return pow(x, y); }
double spf_sin(double x) { return sin(x); }
double spf_cos(double x) { return cos(x); }
double spf_abs(double x) { return fabs(x); }
int64_t spf_iabs(int64_t x) { return x < 0 ? -x : x; }
int64_t spf_min_i(int64_t a, int64_t b) { return a < b ? a : b; }
int64_t spf_max_i(int64_t a, int64_t b) { return a > b ? a : b; }

SpfText *spf_fs_read(SpfText *path) {
    FILE *f = fopen(spf_text_cstr(path), "rb");
    if (!f) return spf_text_from_cstr("");
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (n < 0) n = 0;
    SpfText *t = text_alloc((size_t)n);
    if (n) fread(t->data, 1, (size_t)n, f);
    fclose(f);
    return t;
}

int64_t spf_fs_write(SpfText *path, SpfText *data) {
    FILE *f = fopen(spf_text_cstr(path), "wb");
    if (!f) return 0;
    fwrite(spf_text_cstr(data), 1, (size_t)spf_text_len(data), f);
    fclose(f);
    return 1;
}

int64_t spf_fs_exists(SpfText *path) {
    return access(spf_text_cstr(path), F_OK) == 0;
}

int64_t spf_fs_mkdir(SpfText *path) {
    return mkdir(spf_text_cstr(path), 0755) == 0 || errno == EEXIST;
}

SpfList *spf_fs_list(SpfText *path) {
    SpfList *out = spf_list_new();
    DIR *d = opendir(spf_text_cstr(path));
    if (!d) return out;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
        spf_list_push_ptr(out, spf_text_from_cstr(e->d_name));
    }
    closedir(d);
    return out;
}

int64_t spf_fs_remove(SpfText *path) {
    return remove(spf_text_cstr(path)) == 0;
}

SpfText *spf_http_get(SpfText *url) {
    /* Minimal GET via `curl` so networking works without extra deps. */
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "curl -sL --max-time 20 %s", spf_text_cstr(url));
    FILE *p = popen(cmd, "r");
    if (!p) return spf_text_from_cstr("");
    char buf[4096];
    SpfText *acc = spf_text_from_cstr("");
    while (fgets(buf, sizeof(buf), p)) {
        SpfText *chunk = spf_text_from_cstr(buf);
        SpfText *next = spf_text_concat(acc, chunk);
        acc = next;
    }
    pclose(p);
    return acc;
}

SpfText *spf_net_tcp_send(SpfText *host, int64_t port, SpfText *payload) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return spf_text_from_cstr("");
    struct hostent *he = gethostbyname(spf_text_cstr(host));
    if (!he) {
        close(fd);
        return spf_text_from_cstr("");
    }
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)port);
    memcpy(&addr.sin_addr, he->h_addr_list[0], (size_t)he->h_length);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return spf_text_from_cstr("");
    }
    const char *msg = spf_text_cstr(payload);
    send(fd, msg, strlen(msg), 0);
    char buf[4096];
    ssize_t n = recv(fd, buf, sizeof(buf) - 1, 0);
    close(fd);
    if (n < 0) n = 0;
    buf[n] = 0;
    return spf_text_from_cstr(buf);
}

int64_t spf_db_open(SpfText *path) {
    for (int i = 1; i < 32; i++) {
        if (!g_dbs[i]) {
            if (sqlite3_open(spf_text_cstr(path), &g_dbs[i]) != SQLITE_OK) return 0;
            return i;
        }
    }
    return 0;
}

int64_t spf_db_exec(int64_t handle, SpfText *sql) {
    if (handle <= 0 || handle >= 32 || !g_dbs[handle]) return 0;
    char *err = NULL;
    int rc = sqlite3_exec(g_dbs[handle], spf_text_cstr(sql), NULL, NULL, &err);
    if (err) sqlite3_free(err);
    return rc == SQLITE_OK;
}

static int query_cb(void *ud, int argc, char **argv, char **cols) {
    (void)cols;
    SpfList *rows = (SpfList *)ud;
    SpfList *row = spf_list_new();
    for (int i = 0; i < argc; i++) {
        spf_list_push_ptr(row, spf_text_from_cstr(argv[i] ? argv[i] : ""));
    }
    spf_list_push_ptr(rows, row);
    return 0;
}

SpfList *spf_db_query(int64_t handle, SpfText *sql) {
    SpfList *rows = spf_list_new();
    if (handle <= 0 || handle >= 32 || !g_dbs[handle]) return rows;
    sqlite3_exec(g_dbs[handle], spf_text_cstr(sql), query_cb, rows, NULL);
    return rows;
}

void spf_db_close(int64_t handle) {
    if (handle <= 0 || handle >= 32) return;
    if (g_dbs[handle]) {
        sqlite3_close(g_dbs[handle]);
        g_dbs[handle] = NULL;
    }
}

typedef struct {
    void (*fn)(void *);
    void *arg;
} SpawnJob;

static void *spawn_thunk(void *p) {
    SpawnJob *j = (SpawnJob *)p;
    j->fn(j->arg);
    free(j);
    return NULL;
}

void spf_spawn(void (*fn)(void *), void *arg) {
    pthread_t th;
    SpawnJob *j = (SpawnJob *)malloc(sizeof(SpawnJob));
    j->fn = fn;
    j->arg = arg;
    pthread_mutex_lock(&g_spawn_mu);
    pthread_create(&th, NULL, spawn_thunk, j);
    pthread_detach(th);
    pthread_mutex_unlock(&g_spawn_mu);
}

SpfChan *spf_chan_new(int64_t cap) {
    if (cap < 1) cap = 1;
    SpfChan *c = (SpfChan *)calloc(1, sizeof(SpfChan));
    pthread_mutex_init(&c->mu, NULL);
    pthread_cond_init(&c->cv, NULL);
    c->cap = (size_t)cap;
    c->q = (int64_t *)calloc(c->cap, sizeof(int64_t));
    return c;
}

void spf_chan_send_int(SpfChan *c, int64_t v) {
    pthread_mutex_lock(&c->mu);
    while (c->len == c->cap) pthread_cond_wait(&c->cv, &c->mu);
    size_t i = (c->head + c->len) % c->cap;
    c->q[i] = v;
    c->len++;
    pthread_cond_signal(&c->cv);
    pthread_mutex_unlock(&c->mu);
}

int64_t spf_chan_recv_int(SpfChan *c) {
    pthread_mutex_lock(&c->mu);
    while (c->len == 0) pthread_cond_wait(&c->cv, &c->mu);
    int64_t v = c->q[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    pthread_cond_signal(&c->cv);
    pthread_mutex_unlock(&c->mu);
    return v;
}

SpfTensor *spf_tensor_new(int64_t rows, int64_t cols) {
    if (rows < 1) rows = 1;
    if (cols < 1) cols = 1;
    SpfTensor *t = (SpfTensor *)calloc(1, sizeof(SpfTensor));
    t->rows = rows;
    t->cols = cols;
    t->data = (double *)calloc((size_t)(rows * cols), sizeof(double));
    return t;
}

void spf_tensor_set(SpfTensor *t, int64_t r, int64_t c, double v) {
    if (!t || r < 0 || c < 0 || r >= t->rows || c >= t->cols) return;
    t->data[r * t->cols + c] = v;
}

double spf_tensor_get(SpfTensor *t, int64_t r, int64_t c) {
    if (!t || r < 0 || c < 0 || r >= t->rows || c >= t->cols) return 0;
    return t->data[r * t->cols + c];
}

SpfTensor *spf_tensor_add(SpfTensor *a, SpfTensor *b) {
    SpfTensor *o = spf_tensor_new(a->rows, a->cols);
    int64_t n = a->rows * a->cols;
    for (int64_t i = 0; i < n; i++) o->data[i] = a->data[i] + b->data[i];
    return o;
}

SpfTensor *spf_tensor_mul(SpfTensor *a, SpfTensor *b) {
    SpfTensor *o = spf_tensor_new(a->rows, b->cols);
    for (int64_t i = 0; i < a->rows; i++) {
        for (int64_t j = 0; j < b->cols; j++) {
            double s = 0;
            for (int64_t k = 0; k < a->cols; k++) {
                s += a->data[i * a->cols + k] * b->data[k * b->cols + j];
            }
            o->data[i * o->cols + j] = s;
        }
    }
    return o;
}

void spf_tensor_relu(SpfTensor *t) {
    int64_t n = t->rows * t->cols;
    for (int64_t i = 0; i < n; i++) if (t->data[i] < 0) t->data[i] = 0;
}

/* Weak stubs so programs link without the Cocoa GUI object file. */
__attribute__((weak)) int64_t spf_gui_window(SpfText *title, int64_t w, int64_t h) {
    (void)w; (void)h;
    printf("[gui] window %s\n", spf_text_cstr(title));
    return 1;
}
__attribute__((weak)) void spf_gui_label(int64_t win, SpfText *text, int64_t x, int64_t y) {
    (void)win; (void)x; (void)y;
    printf("[gui] %s\n", spf_text_cstr(text));
}
__attribute__((weak)) int64_t spf_gui_button(int64_t win, SpfText *title, int64_t x, int64_t y, int64_t w, int64_t h) {
    (void)win; (void)x; (void)y; (void)w; (void)h;
    printf("[gui] button %s\n", spf_text_cstr(title));
    return 1;
}
__attribute__((weak)) void spf_gui_run(int64_t win) {
    (void)win;
}
