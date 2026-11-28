include external/choice/choice.mk
include external/settings/settings.mk
include generated/report/report.mk
include generated/area/area.mk
include generated/shapes/shapes.mk
include generated/flags/flags.mk
include embed/leanfran.mk

CFLAGS := -std=c11 -Wall -Wextra -Werror -pedantic

all: main flags app

main: main.c
	$(CC) $(CFLAGS) $(CHOICE_CFLAGS) $(SETTINGS_CFLAGS) $(REPORT_CFLAGS) $(AREA_CFLAGS) $(SHAPES_CFLAGS) $< -o $@ \
		$(CHOICE_LDLIBS) $(SETTINGS_LDLIBS) $(REPORT_LDLIBS) $(AREA_LDLIBS) $(SHAPES_LDLIBS)

flags: flags.c
	$(CC) $(CFLAGS) $(FLAGS_CFLAGS) $< -o $@ $(FLAGS_LDLIBS)

app: src/app.c
	$(CC) $(CFLAGS) $(LEANFRAN_CFLAGS) $< -o $@ $(LEANFRAN_LDLIBS)
