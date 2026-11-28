#include "area.h"
#include "choice.h"
#include "report.h"
#include "settings.h"
#include "shapes.h"
#include <inttypes.h>
#include <stdio.h>

static int fail(const char *step, const lf_error *err) {
    fprintf(stderr, "%s: %s\n", step,
            err->message == NULL ? "no message" : err->message);
    return 1;
}

int main(void) {
    lf_error err = {0};
    if (shapes_init(&err) != LF_OK || area_init(&err) != LF_OK ||
        report_init(&err) != LF_OK || choice_init(&err) != LF_OK ||
        settings_init(&err) != LF_OK) {
        return fail("init", &err);
    }

    shapes_shapes_template template = {
        .seed = {.point = {.x = lf_nat_from_u64(1), .y = lf_nat_from_u64(2)}}};
    shapes_shapes_area_seed seed;
    if (shapes_seed(&template, &seed, &err) != LF_OK) {
        return fail("shapes_seed", &err);
    }
    lf_str json = {0};
    area_shapes_area_seed area_seed;
    if (shapes_shapes_area_seed_to_json(&seed, &json, &err) != LF_OK ||
        area_shapes_area_seed_from_json(json.ptr, json.len, &area_seed, &err) !=
            LF_OK) {
        return fail("seed json", &err);
    }
    lf_free(json.ptr);
    area_shapes_area_rect rect;
    if (area_place(&area_seed, &rect, &err) != LF_OK) {
        return fail("area_place", &err);
    }

    report_report_line line = {.label = {.ptr = "line", .len = 4}};
    if (area_shapes_area_rect_to_json(&rect, &json, &err) != LF_OK ||
        report_shapes_area_rect_from_json(json.ptr, json.len, &line.size,
                                          &err) != LF_OK) {
        return fail("rect json", &err);
    }
    lf_free(json.ptr);
    line.origin =
        (report_shapes_point){.x = lf_nat_from_u64(0), .y = lf_nat_from_u64(0)};
    report_list_report_line lines = {.items = &line, .len = 1};
    lf_nat total;
    uint64_t total_value = 0;
    if (report_total(&lines, &total, &err) != LF_OK ||
        !lf_nat_to_u64(&total, &total_value)) {
        return fail("report_total", &err);
    }

    area_shapes_status ready = area_shapes_status_ready;
    area_shapes_packet_shapes_status packet;
    report_shapes_packet_shapes_status report_packet;
    report_shapes_status status;
    if (area_packet(&ready, &packet, &err) != LF_OK ||
        area_shapes_packet_shapes_status_to_json(&packet, &json, &err) !=
            LF_OK ||
        report_shapes_packet_shapes_status_from_json(
            json.ptr, json.len, &report_packet, &err) != LF_OK ||
        report_status(&report_packet, &status, &err) != LF_OK) {
        return fail("packet", &err);
    }
    lf_free(json.ptr);

    choice_choice_flag flag = {.enabled = true};
    bool enabled = false;
    settings_settings_level level = {.value = 3};
    uint64_t level_value = 0;
    if (choice_enabled(&flag, &enabled, &err) != LF_OK ||
        settings_value(&level, &level_value, &err) != LF_OK) {
        return fail("external", &err);
    }

    printf("total=%" PRIu64 " status=%s enabled=%d level=%" PRIu64 "\n",
           total_value, status == report_shapes_status_ready ? "ready" : "busy",
           enabled, level_value);
    area_shapes_area_rect_free(&rect);
    report_shapes_area_rect_free(&line.size);
    return 0;
}
