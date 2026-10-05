# =====================================================================
#  SPRFST — build system
#  macOS (Apple Silicon) is the shipping target; the toolchain also
#  builds on Linux for CI and development.
# =====================================================================

CC      ?= cc
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

SRCDIR  := compiler/src
INCDIR  := compiler/include
BUILD   := build
BIN     := $(BUILD)/bin
OBJDIR  := $(BUILD)/obj

CFLAGS  := -std=c11 -I$(INCDIR) -Wall -Wextra -Wno-unused-parameter \
           -Wno-missing-field-initializers -Wno-unused-function -fno-strict-aliasing \
           -MMD -MP
LDFLAGS := -lm

ifeq ($(DEBUG),1)
  CFLAGS += -g -O0 -DSPRFST_DEBUG=1
else
  CFLAGS += -O2 -DNDEBUG
endif

ifeq ($(UNAME_S),Darwin)
  CFLAGS  += -DSPRFST_MACOS=1
  ifeq ($(UNAME_M),arm64)
    CFLAGS += -DSPRFST_ARM64=1 -mcpu=apple-m1
  endif
  LDFLAGS += -framework CoreFoundation
else
  CFLAGS  += -D_GNU_SOURCE -pthread
  LDFLAGS += -pthread
endif

SRCS := $(wildcard $(SRCDIR)/*.c)
OBJS := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

.PHONY: all clean test install dirs app studio dmg pdf stage docs guidebook \
        browser browser-app browser-dmg browser-test

all: dirs $(BIN)/sprfst

dirs:
	@mkdir -p $(OBJDIR) $(BIN)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BIN)/sprfst: $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)
	@echo "  ✓ built $@  ($(UNAME_S)/$(UNAME_M))"

test: all
	@./tests/run_tests.sh

clean:
	rm -rf $(BUILD)

-include $(DEPS)

install: all
	install -d $(DESTDIR)/usr/local/bin
	install -m 755 $(BIN)/sprfst $(DESTDIR)/usr/local/bin/sprfst
	install -d $(DESTDIR)/usr/local/lib/sprfst
	cp -R std $(DESTDIR)/usr/local/lib/sprfst/

docs: all
	@SPRFST_HOME=$(CURDIR) $(BIN)/sprfst docs .

guidebook: all
	@./tools/check_guidebook.sh

# macOS application bundle + disk image (both need macOS)
app: all
	./tools/build_macos_app.sh

# the one people want: build the editor, put it in /Applications, open it
studio: all
	./tools/build_macos_app.sh --install

# on a Mac this wraps the built app; anywhere else it writes the
# installer image, which carries the project and builds it on arrival
dmg: all pdf
	./tools/make_dmg.sh

# ------------------------------------------------------------- browser
# the browser whose engine is written in SPRFST

# the one people want: build it, put it in /Applications, open it
browser: all
	./tools/build_browser_app.sh --install

browser-app: all
	./tools/build_browser_app.sh

# on a Mac this wraps the built app; anywhere else it writes the
# installer image, which carries the project and builds it on arrival
browser-dmg: all
	./tools/make_browser_dmg.sh

# the engine's own tests, then the engine against a real server
browser-test: all
	@cd browser && ../build/bin/sprfst test
	@./tools/browser_live.sh

# the guidebook as PDFs: one per chapter and one book, typeset by sprfst
pdf: all
	./build/bin/sprfst run tools/make_pdf.spf -- guidebook/pdf
	./build/bin/sprfst run tools/verify_pdf.spf -- guidebook/pdf/SPRFST-Guidebook.pdf

# lay out the bundle and the disk image contents anywhere, to check them
stage: all
	./tools/build_macos_app.sh --stage
	./tools/make_dmg.sh --stage
	./tools/build_browser_app.sh --stage
	./tools/make_browser_dmg.sh --stage
