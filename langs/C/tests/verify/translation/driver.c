#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fixture.c"

typedef struct {
    const char *name;
    const char *kinds;
} spec;

static const spec specs[] = {
    {"clamp", "iii"},       {"add_i32", "ii"},    {"twice", "i"},
    {"clamp_plus", "i"},    {"arith_u32", "uu"},  {"div_mod", "ii"},
    {"shifts", "ii"},       {"ushift", "Li"},     {"narrow", "cw"},
    {"conv", "l"},          {"logic", "ii"},      {"ternary", "ii"},
    {"bools", "bbi"},       {"doubles", "dd"},    {"d2i", "d"},
    {"i2d", "lL"},          {"dcmp", "dd"},       {"loop_while", "u"},
    {"loop_do", "i"},       {"loop_for", "i"},    {"nested_loops", "i"},
    {"choose", "i"},        {"switch_loop", "i"}, {"sum", "A"},
    {"at", "Bi"},           {"total", "I"},       {"item_value", "T"},
    {"dot", "PP"},          {"pick", "PPb"},      {"safe_div", "ii"},
    {"size_ops", "zL"},     {"use_helper", "i"},  {"uneg", "u"},
    {"lmix", "lu"},         {"lits", ""},         {"compare", "ii"},
    {"negate", "id"},       {"compound", "ii"},   {"nested_ternary", "ii"},
    {"and_ternary", "ii"},  {"bool_literal", ""}, {"shadow", "i"},
    {"lit_pick", "i"},      {"sum_twice", "A"},   {"sum_prefix", "Au"},
    {"div_sum", "iii"},     {"forward", "ii"},    {"div_or", "iii"},
    {"countdown", "ii"},    {"checked_sum", "A"}, {"total_or", "A"},
    {"count_pos", "B"},     {"count_or", "B"},    {"color_code", "K"},
    {"next_color", "K"},    {"keep_color", "Kb"}, {"shape_area", "S"},
    {"circle_radius", "S"}, {"shape_tag", "S"},   {"bigger", "SS"},
    {"color_sum", "E"},     {"area_sum", "U"},    {"area_tail", "UN"},
    {"color_at", "En"},     {"color_or", "En"},   {"largest", "U"},
    {"largest_area", "US"},
};

static uint64_t state = 1;

static uint64_t next(void) {
    state = state * 6364136223846793005u + 1442695040888963407u;
    return state ^ (state >> 29);
}

static uint64_t bits(double value) {
    uint64_t result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static double from_bits(uint64_t value) {
    double result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static int64_t small(void) { return (int64_t)(next() % 101) - 50; }

static int64_t pick_int(const int64_t *edges, size_t count) {
    uint64_t r = next() % 4;
    if (r == 0)
        return edges[next() % count];
    if (r == 1)
        return small();
    return (int64_t)next();
}

static void print_scalar(char kind) {
    static const int64_t i32[] = {0,   1,  -1,        2,         -2,
                                  31,  32, 7,         100,       -100,
                                  -50, 50, INT32_MAX, INT32_MIN, INT32_MAX - 1};
    static const int64_t i64[] = {0, 1, -1, 63, 64, INT64_MAX, INT64_MIN, 1000};
    static const double reals[] = {
        0.0,    -0.0,         1.0,           -1.5,         0.1,          1e300,
        -1e300, 2147483647.5, -2147483648.5, 2147483648.0, 4294967296.0, 3.0};
    switch (kind) {
    case 'b':
        printf(" %d", (int)(next() % 2));
        break;
    case 'c':
        printf(" %d", (int)(int8_t)pick_int(i32, 15));
        break;
    case 'w':
        printf(" %u", (unsigned)(uint16_t)pick_int(i32, 15));
        break;
    case 'i':
        printf(" %" PRId32, (int32_t)pick_int(i32, 15));
        break;
    case 'u':
        printf(" %" PRIu32, (uint32_t)pick_int(i32, 15));
        break;
    case 'l':
        printf(" %" PRId64, pick_int(i64, 8));
        break;
    case 'L':
    case 'z':
        printf(" %" PRIu64, (uint64_t)pick_int(i64, 8));
        break;
    case 'd': {
        uint64_t r = next() % 5;
        double value;
        if (r < 2)
            value = reals[next() % 12];
        else if (r == 2)
            value = (double)small() / 4;
        else if (r == 3)
            value = from_bits(next() % 2 ? 0x7ff0000000000000u
                                         : 0x7ff8000000000000u);
        else
            value = (double)(int64_t)next() / 1e9;
        if (next() % 8 == 0)
            value = -value;
        printf(" %" PRIu64, bits(value));
        break;
    }
    default:
        abort();
    }
}

static void print_value(char kind) {
    if (kind == 'P') {
        print_scalar('i');
        print_scalar('i');
    } else if (kind == 'T') {
        printf(" %" PRIu64, 1 + next() % 1000);
        print_scalar('l');
        printf(" %" PRIu64, next() % 100000);
    } else if (kind == 'K') {
        printf(" %d", (int)(next() % 3));
    } else if (kind == 'n' || kind == 'N') {
        printf(" %d", (int)(next() % 6) - (kind == 'n'));
    } else if (kind == 'S') {
        int tag = (int)(next() % 5);
        printf(" %d", tag);
        if (tag == 3)
            printf(" %d", (int)(next() % 1000));
        else
            print_scalar('i');
        print_scalar('l');
        print_value('K');
    } else {
        print_scalar(kind);
    }
}

static void print_inputs(void) {
    int runs = 300;
    for (size_t s = 0; s < sizeof(specs) / sizeof(specs[0]); s++) {
        for (int run = 0; run < runs; run++) {
            printf("%s %s", specs[s].name,
                   specs[s].kinds[0] ? specs[s].kinds : "-");
            for (const char *k = specs[s].kinds; *k; k++) {
                if (strchr("ABIEU", *k)) {
                    size_t len = next() % 5;
                    printf(" %zu", len);
                    for (size_t i = 0; i < len; i++)
                        print_value(*k == 'A'   ? 'l'
                                    : *k == 'B' ? 'i'
                                    : *k == 'I' ? 'T'
                                    : *k == 'E' ? 'K'
                                                : 'S');
                } else {
                    print_value(*k);
                }
            }
            printf("\n");
            if (specs[s].kinds[0] == 0)
                break;
        }
    }
}

static int64_t read_int(void) { return strtoll(strtok(NULL, " "), NULL, 10); }

static uint64_t read_uint(void) {
    return strtoull(strtok(NULL, " "), NULL, 10);
}

static shapes_geo_point read_point(void) {
    shapes_geo_point p;
    p.x = (int32_t)read_int();
    p.y = (int32_t)read_int();
    return p;
}

static item read_item(void) {
    item it;
    it.qty = (uint32_t)read_uint();
    it.price = read_int();
    it.weight = (size_t)read_uint();
    return it;
}

static shapes_geo_shape read_shape(void) {
    shapes_geo_shape s;
    memset(&s, 0, sizeof(s));
    int tag = (int)read_int();
    int32_t a = (int32_t)read_int();
    int64_t b = read_int();
    shapes_geo_color c = (shapes_geo_color)read_int();
    switch (tag) {
    case 0:
        s.tag = shapes_geo_shape_circle;
        s.as.circle.r = a;
        break;
    case 1:
        s.tag = shapes_geo_shape_rect;
        s.as.rect.w = a;
        s.as.rect.h = (int32_t)b;
        break;
    case 2:
        s.tag = shapes_geo_shape_pair;
        s.as.pair.a0 = a;
        s.as.pair.a1 = b;
        break;
    case 3:
        s.tag = shapes_geo_shape_tinted;
        s.as.tinted.c = c;
        s.as.tinted.r = a;
        break;
    default:
        s.tag = shapes_geo_shape_dot;
    }
    return s;
}

static void print_shape(shapes_geo_shape s) {
    switch (s.tag) {
    case shapes_geo_shape_circle:
        printf("0 %" PRId32, s.as.circle.r);
        break;
    case shapes_geo_shape_rect:
        printf("1 %" PRId32 " %" PRId32, s.as.rect.w, s.as.rect.h);
        break;
    case shapes_geo_shape_pair:
        printf("2 %" PRId32 " %" PRId64, s.as.pair.a0, s.as.pair.a1);
        break;
    case shapes_geo_shape_tinted:
        printf("3 %d %" PRId32, (int)s.as.tinted.c, s.as.tinted.r);
        break;
    default:
        printf("4");
    }
}

static shapes_geo_color *read_colors(size_t *n) {
    *n = read_uint();
    shapes_geo_color *cs = malloc(*n * sizeof(*cs));
    for (size_t i = 0; i < *n; i++)
        cs[i] = (shapes_geo_color)read_int();
    return cs;
}

static shapes_geo_shape *read_shapes(size_t *n) {
    *n = read_uint();
    shapes_geo_shape *ss = malloc(*n * sizeof(*ss));
    for (size_t i = 0; i < *n; i++)
        ss[i] = read_shape();
    return ss;
}

static void print_double(double value) {
    if (value != value)
        printf("nan");
    else
        printf("%" PRIu64, bits(value));
}

static int64_t *read_array(size_t *n) {
    *n = read_uint();
    int64_t *xs = malloc(*n * sizeof(*xs));
    for (size_t i = 0; i < *n; i++)
        xs[i] = read_int();
    return xs;
}

static void print_status(lf_status status, int32_t out) {
    if (status == LF_OK)
        printf("%d %" PRId32, (int)status, out);
    else
        printf("%d -", (int)status);
}

#define NAME(s) (strcmp(name, s) == 0)

static void evaluate(char *line) {
    char *name = strtok(line, " ");
    (void)strtok(NULL, " ");
    if (NAME("clamp")) {
        int32_t a = read_int(), b = read_int(), c = read_int();
        printf("%" PRId32, clamp(a, b, c));
    } else if (NAME("add_i32")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, add_i32(a, b));
    } else if (NAME("twice")) {
        printf("%" PRId32, twice(read_int()));
    } else if (NAME("clamp_plus")) {
        printf("%" PRId32, clamp_plus(read_int()));
    } else if (NAME("arith_u32")) {
        uint32_t a = read_uint(), b = read_uint();
        printf("%" PRIu32, arith_u32(a, b));
    } else if (NAME("div_mod")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, div_mod(a, b));
    } else if (NAME("shifts")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, shifts(a, b));
    } else if (NAME("ushift")) {
        uint64_t a = read_uint();
        int32_t b = read_int();
        printf("%" PRIu64, ushift(a, b));
    } else if (NAME("narrow")) {
        int8_t a = read_int();
        uint16_t b = read_uint();
        printf("%" PRId32, narrow(a, b));
    } else if (NAME("conv")) {
        printf("%" PRId64, conv(read_int()));
    } else if (NAME("logic")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, logic(a, b));
    } else if (NAME("ternary")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, ternary(a, b));
    } else if (NAME("bools")) {
        bool p = read_int(), q = read_int();
        int32_t a = read_int();
        printf("%" PRId32, bools(p, q, a));
    } else if (NAME("doubles")) {
        double x = from_bits(read_uint()), y = from_bits(read_uint());
        print_double(doubles(x, y));
    } else if (NAME("d2i")) {
        printf("%" PRId32, d2i(from_bits(read_uint())));
    } else if (NAME("i2d")) {
        int64_t a = read_int();
        uint64_t b = read_uint();
        print_double(i2d(a, b));
    } else if (NAME("dcmp")) {
        double x = from_bits(read_uint()), y = from_bits(read_uint());
        printf("%d", (int)dcmp(x, y));
    } else if (NAME("loop_while")) {
        printf("%" PRIu32, loop_while(read_uint()));
    } else if (NAME("loop_do")) {
        printf("%" PRId32, loop_do(read_int()));
    } else if (NAME("loop_for")) {
        printf("%" PRId32, loop_for(read_int()));
    } else if (NAME("nested_loops")) {
        printf("%" PRId32, nested_loops(read_int()));
    } else if (NAME("choose")) {
        printf("%" PRId32, choose(read_int()));
    } else if (NAME("switch_loop")) {
        printf("%" PRId32, switch_loop(read_int()));
    } else if (NAME("sum")) {
        size_t n = read_uint();
        int64_t *xs = malloc(n * sizeof(*xs));
        for (size_t i = 0; i < n; i++)
            xs[i] = read_int();
        printf("%" PRId64, sum(xs, n));
        free(xs);
    } else if (NAME("at")) {
        size_t n = read_uint();
        int32_t *xs = malloc(n * sizeof(*xs));
        for (size_t i = 0; i < n; i++)
            xs[i] = read_int();
        int32_t i = read_int();
        printf("%" PRId32, at(xs, n, i));
        free(xs);
    } else if (NAME("total")) {
        size_t n = read_uint();
        item *items = malloc(n * sizeof(*items));
        for (size_t i = 0; i < n; i++)
            items[i] = read_item();
        printf("%" PRId64, total(items, n));
        free(items);
    } else if (NAME("item_value")) {
        printf("%" PRId64, item_value(read_item()));
    } else if (NAME("dot")) {
        shapes_geo_point p = read_point(), q = read_point();
        printf("%" PRId32, dot(p, q));
    } else if (NAME("pick")) {
        shapes_geo_point p = read_point(), q = read_point();
        bool first = read_int();
        shapes_geo_point r = pick(p, q, first);
        printf("%" PRId32 " %" PRId32, r.x, r.y);
    } else if (NAME("safe_div")) {
        int32_t a = read_int(), b = read_int(), out = 0;
        lf_status status = safe_div(a, b, &out);
        if (status == LF_OK)
            printf("%d %" PRId32, (int)status, out);
        else
            printf("%d -", (int)status);
    } else if (NAME("sum_twice")) {
        size_t n;
        int64_t *xs = read_array(&n);
        printf("%" PRId64, sum_twice(xs, n));
        free(xs);
    } else if (NAME("sum_prefix")) {
        size_t n;
        int64_t *xs = read_array(&n);
        uint32_t k = read_uint();
        printf("%" PRId64, sum_prefix(xs, n, k));
        free(xs);
    } else if (NAME("div_sum")) {
        int32_t a = read_int(), b = read_int(), c = read_int(), out = 0;
        lf_status status = div_sum(a, b, c, &out);
        print_status(status, out);
    } else if (NAME("forward")) {
        int32_t a = read_int(), b = read_int(), out = 0;
        lf_status status = forward(a, b, &out);
        print_status(status, out);
    } else if (NAME("div_or")) {
        int32_t a = read_int(), b = read_int(), c = read_int();
        printf("%" PRId32, div_or(a, b, c));
    } else if (NAME("countdown")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, countdown(a, b));
    } else if (NAME("checked_sum")) {
        size_t n;
        int64_t *xs = read_array(&n), out = 0;
        lf_status status = checked_sum(xs, n, &out);
        if (status == LF_OK)
            printf("%d %" PRId64, (int)status, out);
        else
            printf("%d -", (int)status);
        free(xs);
    } else if (NAME("total_or")) {
        size_t n;
        int64_t *xs = read_array(&n);
        printf("%" PRId64, total_or(xs, n));
        free(xs);
    } else if (NAME("count_pos")) {
        size_t n = read_uint(), out = 0;
        int32_t *xs = malloc(n * sizeof(*xs));
        for (size_t i = 0; i < n; i++)
            xs[i] = read_int();
        lf_status status = count_pos(xs, n, &out);
        if (status == LF_OK)
            printf("%d %zu", (int)status, out);
        else
            printf("%d -", (int)status);
        free(xs);
    } else if (NAME("count_or")) {
        size_t n = read_uint();
        int32_t *xs = malloc(n * sizeof(*xs));
        for (size_t i = 0; i < n; i++)
            xs[i] = read_int();
        printf("%zu", count_or(xs, n));
        free(xs);
    } else if (NAME("size_ops")) {
        size_t n = read_uint();
        unsigned long m = read_uint();
        printf("%zu", size_ops(n, m));
    } else if (NAME("use_helper")) {
        printf("%" PRId32, use_helper(read_int()));
    } else if (NAME("uneg")) {
        printf("%" PRIu32, uneg(read_uint()));
    } else if (NAME("lmix")) {
        long a = read_int();
        unsigned int b = read_uint();
        printf("%ld", lmix(a, b));
    } else if (NAME("compare")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, compare(a, b));
    } else if (NAME("negate")) {
        int32_t a = read_int();
        double x = from_bits(read_uint());
        printf("%" PRId32, negate(a, x));
    } else if (NAME("compound")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, compound(a, b));
    } else if (NAME("nested_ternary")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, nested_ternary(a, b));
    } else if (NAME("and_ternary")) {
        int32_t a = read_int(), b = read_int();
        printf("%" PRId32, and_ternary(a, b));
    } else if (NAME("bool_literal")) {
        printf("%" PRId64, bool_literal());
    } else if (NAME("shadow")) {
        printf("%" PRId32, shadow(read_int()));
    } else if (NAME("lit_pick")) {
        print_double(lit_pick(read_int()));
    } else if (NAME("color_code")) {
        printf("%" PRId32, color_code((shapes_geo_color)read_int()));
    } else if (NAME("next_color")) {
        printf("%d", (int)next_color((shapes_geo_color)read_int()));
    } else if (NAME("keep_color")) {
        shapes_geo_color c = (shapes_geo_color)read_int();
        bool swap = read_int();
        printf("%d", (int)keep_color(c, swap));
    } else if (NAME("shape_area")) {
        printf("%" PRId64, shape_area(read_shape()));
    } else if (NAME("circle_radius")) {
        printf("%" PRId32, circle_radius(read_shape()));
    } else if (NAME("shape_tag")) {
        printf("%" PRIu32, shape_tag(read_shape()));
    } else if (NAME("bigger")) {
        shapes_geo_shape a = read_shape(), b = read_shape();
        print_shape(bigger(a, b));
    } else if (NAME("color_sum")) {
        size_t n;
        shapes_geo_color *cs = read_colors(&n);
        printf("%" PRId32, color_sum(cs, n));
        free(cs);
    } else if (NAME("area_sum")) {
        size_t n;
        shapes_geo_shape *ss = read_shapes(&n);
        printf("%" PRId64, area_sum(ss, n));
        free(ss);
    } else if (NAME("area_tail")) {
        size_t n;
        shapes_geo_shape *ss = read_shapes(&n);
        uint32_t k = read_uint();
        printf("%" PRId64, area_tail(ss, n, k));
        free(ss);
    } else if (NAME("color_at")) {
        size_t n;
        shapes_geo_color *cs = read_colors(&n), out = shapes_geo_color_red;
        int32_t i = read_int();
        lf_status status = color_at(cs, n, i, &out);
        if (status == LF_OK)
            printf("%d %d", (int)status, (int)out);
        else
            printf("%d -", (int)status);
        free(cs);
    } else if (NAME("color_or")) {
        size_t n;
        shapes_geo_color *cs = read_colors(&n);
        int32_t i = read_int();
        printf("%d", (int)color_or(cs, n, i));
        free(cs);
    } else if (NAME("largest")) {
        size_t n;
        shapes_geo_shape *ss = read_shapes(&n), out;
        memset(&out, 0, sizeof(out));
        lf_status status = largest(ss, n, &out);
        printf("%d ", (int)status);
        if (status == LF_OK)
            print_shape(out);
        else
            printf("-");
        free(ss);
    } else if (NAME("largest_area")) {
        size_t n;
        shapes_geo_shape *ss = read_shapes(&n);
        shapes_geo_shape s = read_shape();
        printf("%" PRId64, largest_area(ss, n, s));
        free(ss);
    } else if (NAME("lits")) {
        print_double(lits());
    } else {
        fprintf(stderr, "unknown function %s\n", name);
        exit(2);
    }
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--inputs") == 0) {
        print_inputs();
        return 0;
    }
    char line[4096];
    while (fgets(line, sizeof(line), stdin)) {
        line[strcspn(line, "\n")] = 0;
        printf("%s = ", line);
        char copy[4096];
        strcpy(copy, line);
        evaluate(copy);
        printf("\n");
        fflush(stdout);
    }
    return 0;
}
