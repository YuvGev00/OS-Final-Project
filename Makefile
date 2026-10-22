# Builds the analyzer and every plugin in plugins/*.c (except plugin_common.c)
# as a shared library in output/. Equivalent to ./build.sh.

CC      ?= gcc
CFLAGS  ?= -Wall -Wextra -O2
LDLIBS  := -ldl -lpthread
OUT     := output

SYNC_SRC    := plugins/sync/monitor.c plugins/sync/consumer_producer.c
COMMON_SRC  := plugins/plugin_common.c $(SYNC_SRC)
PLUGIN_SRC  := $(filter-out plugins/plugin_common.c,$(wildcard plugins/*.c))
PLUGINS     := $(patsubst plugins/%.c,$(OUT)/%.so,$(PLUGIN_SRC))
HEADERS     := $(wildcard plugins/*.h plugins/sync/*.h)

.PHONY: all test clean

all: $(OUT)/analyzer $(PLUGINS)

$(OUT):
	mkdir -p $@

$(OUT)/analyzer: main.c $(HEADERS) | $(OUT)
	$(CC) $(CFLAGS) -o $@ main.c $(LDLIBS)

$(OUT)/%.so: plugins/%.c $(COMMON_SRC) $(HEADERS) | $(OUT)
	$(CC) $(CFLAGS) -fPIC -shared -o $@ $< $(COMMON_SRC) $(LDLIBS)

test: all
	./test.sh

clean:
	rm -rf $(OUT)
