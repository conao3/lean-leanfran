#include "fixture.h"

int32_t clamp(int32_t lo, int32_t hi, int32_t x) {
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}

int32_t add_i32(int32_t a, int32_t b) { return a + b; }

int32_t twice(int32_t a) { return add_i32(a, a); }

int32_t clamp_plus(int32_t x) { return clamp(0, 10, x) + 1; }

uint32_t arith_u32(uint32_t a, uint32_t b) {
    return a * b + ((a - b) ^ ((a | b) & ~a));
}

int32_t div_mod(int32_t a, int32_t b) { return a / b + a % b; }

int32_t shifts(int32_t a, int32_t n) { return (a << n) + (a >> n); }

uint64_t ushift(uint64_t a, int32_t n) { return (a << n) | (a >> (63 - n)); }

int32_t narrow(int8_t a, uint16_t b) {
    int8_t c = a;
    c += 100;
    c++;
    uint16_t d = b;
    d -= 3;
    d *= 2;
    --d;
    return c + d;
}

int64_t conv(int64_t a) {
    return (int8_t)a + (uint8_t)a + (int16_t)a + (int64_t)(uint32_t)a +
           (int64_t)(bool)a;
}

int32_t logic(int32_t a, int32_t b) {
    return (a != 0 && b / a > 1) || !(b < 0);
}

int32_t ternary(int32_t a, int32_t b) { return b != 0 ? a / b : -1; }

int32_t bools(bool p, bool q, int32_t a) {
    bool r = p && !q;
    if (r)
        a = a * 2;
    else if (q)
        a -= 1;
    return r + a;
}

double doubles(double x, double y) {
    double z = x * y + 1.5;
    if (z > 0.1)
        z = z / y;
    z += x;
    return z - x * 3;
}

int32_t d2i(double x) { return (int32_t)x; }

double i2d(int64_t a, uint64_t b) { return (double)a + (double)b * 0.5; }

bool dcmp(double x, double y) { return x == y || (x != x && !(y < x)); }

uint32_t loop_while(uint32_t n) {
    uint32_t s = 0;
    while (n > 0) {
        s += n % 10;
        n /= 10;
    }
    return s;
}

int32_t loop_do(int32_t n) {
    int32_t c = 0;
    do {
        c++;
        if (c % 3 == 0)
            continue;
        n -= c;
    } while (n > 0);
    return c;
}

int32_t loop_for(int32_t n) {
    int32_t s = 0;
    for (int32_t i = 0; i < n; i++) {
        if (i == 5)
            continue;
        if (i > 20)
            break;
        s += i * i;
    }
    return s;
}

int32_t nested_loops(int32_t n) {
    int32_t s = 0;
    for (int32_t i = 0; i < 4; i++) {
        int32_t j = 0;
        while (1) {
            j++;
            if (j > i)
                break;
            s += n;
        }
    }
    return s;
}

int32_t choose(int32_t a) {
    int32_t r = 0;
    switch (a) {
    case 1:
    case 2:
        r = 10;
        break;
    case -1:
        r = a * 3;
        break;
    default:
        r = a + 1;
        break;
    case 7:
        return 70;
    }
    return r;
}

int32_t switch_loop(int32_t n) {
    int32_t s = 0;
    for (int32_t i = 0; i < 10; i++) {
        switch (i % 4) {
        case 0:
            continue;
        case 1:
            s += n;
            break;
        default:
            s -= i;
        }
    }
    return s;
}

int64_t sum(const int64_t *xs LF_ARRAY(n), size_t n) {
    int64_t acc = 0;
    for (size_t i = 0; i < n; i++)
        acc += xs[i];
    return acc;
}

int32_t at(const int32_t *xs LF_ARRAY(n), size_t n, int32_t i) {
    return xs[i] + (int32_t)n;
}

int64_t total(const item *items LF_ARRAY(len), size_t len) {
    int64_t t = 0;
    for (size_t i = 0; i < len; i++)
        t += items[i].qty * items[i].price + (int64_t)items[i].weight;
    return t;
}

int64_t item_value(item it) {
    item copy = it;
    return copy.price * it.qty;
}

int32_t dot(shapes_geo_point p, shapes_geo_point q) {
    return p.x * q.x + p.y * q.y;
}

shapes_geo_point pick(shapes_geo_point p, shapes_geo_point q, bool first) {
    shapes_geo_point r = q;
    if (first)
        r = p;
    return r;
}

lf_status safe_div(int32_t a, int32_t b, int32_t *out) {
    if (b == 0)
        return LF_INVALID;
    *out = a / b;
    return LF_OK;
}

int64_t sum_twice(const int64_t *xs LF_ARRAY(n), size_t n) {
    return sum(xs, n) - sum(xs, n) + sum(xs, n);
}

int64_t sum_prefix(const int64_t *xs LF_ARRAY(n), size_t n, uint32_t k) {
    return sum(xs, k) - (int64_t)n;
}

lf_status div_sum(int32_t a, int32_t b, int32_t c, int32_t *out) {
    int32_t q = 0;
    lf_status st = safe_div(a, b, &q);
    if (st != LF_OK)
        return st;
    int32_t r = 0;
    st = safe_div(a, c, &r);
    if (st == LF_INVALID)
        return LF_INVALID;
    *out = q + r;
    return LF_OK;
}

lf_status forward(int32_t a, int32_t b, int32_t *out) {
    *out = -1;
    return safe_div(a, b, out);
}

int32_t div_or(int32_t a, int32_t b, int32_t fallback) {
    int32_t q = fallback;
    safe_div(a, b, &q);
    return q;
}

int32_t countdown(int32_t a, int32_t b) {
    int32_t q = a;
    int32_t steps = 0;
    while (safe_div(q, b, &q) == LF_OK) {
        steps++;
        if (q == 0 || steps > 64)
            break;
    }
    return steps;
}

lf_status checked_sum(const int64_t *xs LF_ARRAY(n), size_t n, int64_t *out) {
    if (n == 0)
        return LF_INVALID;
    *out = sum(xs, n);
    return LF_OK;
}

int64_t total_or(const int64_t *xs LF_ARRAY(n), size_t n) {
    int64_t t = -1;
    if (checked_sum(xs, n, &t) == LF_OK)
        return t;
    return t - 1;
}

lf_status count_pos(const int32_t *xs LF_ARRAY(n), size_t n, size_t *out) {
    size_t c = 0;
    for (size_t i = 0; i < n; i++)
        if (xs[i] > 0)
            c++;
    *out = c;
    return LF_OK;
}

size_t count_or(const int32_t *xs LF_ARRAY(n), size_t n) {
    size_t c = 99;
    if (count_pos(xs, n, &c) != LF_OK)
        return 0;
    return c + n;
}

size_t size_ops(size_t n, unsigned long m) {
    size_t k = n + m;
    return k * 2;
}

static int32_t helper(int32_t x) { return x - 1; }

int32_t use_helper(int32_t x) { return helper(x) * 2; }

uint32_t uneg(uint32_t a) { return -a + (a > 5u); }

long lmix(long a, unsigned int b) { return a + b; }

double lits(void) { return 0.1 + 1e-5 + 3.25e10 - 2.5; }

int32_t compare(int32_t a, int32_t b) {
    return (a <= b) * 4 + (a >= b) * 2 + (a == b);
}

int32_t negate(int32_t a, double x) {
    int32_t n = -a;
    double y = -x;
    return n + (y > 0.0);
}

int32_t compound(int32_t a, int32_t b) {
    int32_t r = a;
    r %= b;
    r <<= (b & 7);
    r >>= 1;
    r &= a;
    r |= b;
    r ^= 3;
    int64_t w = a;
    w += b;
    w -= r;
    int32_t d = a;
    d += 0.5 * b;
    return r + (int32_t)w + d;
}

int32_t nested_ternary(int32_t a, int32_t b) {
    return b != 0 ? (a / b > 1 ? 1 : 2) : 0;
}

int32_t and_ternary(int32_t a, int32_t b) {
    return b != 0 && (a / b > 1 ? 1 : 0);
}

int64_t bool_literal(void) {
    int64_t r = (int32_t)(bool)5;
    return r + (int64_t)(double)3 + (int64_t)(bool)0;
}

int32_t shadow(int32_t first) {
    int32_t total = 0;
    for (int32_t i = 0; i < 3; i++) {
        bool first = i == 0;
        total += first;
    }
    return total + first;
}

double lit_pick(int32_t k) {
    switch (k) {
    case 0:
        return 0.1;
    case 1:
        return 0.30000000000000004;
    case 2:
        return 1.7976931348623157e308;
    case 3:
        return 2.2250738585072014e-308;
    case 4:
        return 4.9406564584124654e-324;
    case 5:
        return 123456789.12345679;
    case 6:
        return 6.02214076e23;
    case 7:
        return 1.0000000000000002;
    case 8:
        return 9007199254740993.0;
    case 9:
        return 1e-310;
    default:
        return 2.718281828459045;
    }
}

int32_t color_code(shapes_geo_color c) {
    switch (c) {
    case shapes_geo_color_red:
        return 1;
    case shapes_geo_color_green:
        return 20;
    default:
        return c * 100;
    }
}

shapes_geo_color next_color(shapes_geo_color c) {
    if (c == shapes_geo_color_red)
        return shapes_geo_color_green;
    if (c == shapes_geo_color_green)
        return shapes_geo_color_blue;
    return shapes_geo_color_red;
}

shapes_geo_color keep_color(shapes_geo_color c, bool swap) {
    shapes_geo_color d = c;
    if (swap)
        d = 0;
    return d;
}

int64_t shape_area(shapes_geo_shape s) {
    switch (s.tag) {
    case shapes_geo_shape_circle:
        return 3 * s.as.circle.r * s.as.circle.r;
    case shapes_geo_shape_rect:
        return (int64_t)s.as.rect.w * s.as.rect.h;
    case shapes_geo_shape_pair:
        return s.as.pair.a0 + s.as.pair.a1;
    case shapes_geo_shape_tinted:
        return color_code(s.as.tinted.c) + s.as.tinted.r;
    default:
        return 0;
    }
}

int32_t circle_radius(shapes_geo_shape s) { return s.as.circle.r; }

uint32_t shape_tag(shapes_geo_shape s) {
    shapes_geo_shape_tag t = s.tag;
    return t * 10 + (s.tag == shapes_geo_shape_dot);
}

shapes_geo_shape bigger(shapes_geo_shape a, shapes_geo_shape b) {
    return shape_area(a) >= shape_area(b) ? a : b;
}

int32_t color_sum(const shapes_geo_color *cs LF_ARRAY(n), size_t n) {
    int32_t t = 0;
    for (size_t i = 0; i < n; i++)
        t += color_code(cs[i]);
    return t;
}

int64_t area_sum(const shapes_geo_shape *ss LF_ARRAY(n), size_t n) {
    int64_t t = 0;
    for (size_t i = 0; i < n; i++)
        t += shape_area(ss[i]);
    return t;
}

int64_t area_tail(const shapes_geo_shape *ss LF_ARRAY(n), size_t n,
                  uint32_t k) {
    if (k > n)
        return -1;
    return area_sum(ss, n) - area_sum(ss, k);
}

lf_status color_at(const shapes_geo_color *cs LF_ARRAY(n), size_t n, int32_t i,
                   shapes_geo_color *out) {
    if (i < 0 || (size_t)i >= n)
        return LF_INVALID;
    *out = cs[i];
    return LF_OK;
}

shapes_geo_color color_or(const shapes_geo_color *cs LF_ARRAY(n), size_t n,
                          int32_t i) {
    shapes_geo_color c = shapes_geo_color_blue;
    color_at(cs, n, i, &c);
    return c;
}

lf_status largest(const shapes_geo_shape *ss LF_ARRAY(n), size_t n,
                  shapes_geo_shape *out) {
    if (n == 0)
        return LF_INVALID;
    shapes_geo_shape best = ss[0];
    for (size_t i = 1; i < n; i++)
        best = bigger(best, ss[i]);
    *out = best;
    return LF_OK;
}

int64_t largest_area(const shapes_geo_shape *ss LF_ARRAY(n), size_t n,
                     shapes_geo_shape s) {
    shapes_geo_shape b = s;
    if (largest(ss, n, &b) != LF_OK)
        return -shape_area(b);
    return shape_area(b);
}
