# V-OS build
#   make          assemble build/vos.dsk
#   make run      boot it in Caprice32 (RUN"VOS")
#   make shot     boot headless and save a screenshot
#   make test-input  build/vos_test.dsk with scripted key presses
#                 (src/kernel/test_script.asm) and two screenshots
#   make clean

RASM    ?= rasm
CAP32   ?= caprice32.launcher
BUILD   := build
DSK     := $(BUILD)/vos.dsk
SOURCES := $(shell find src -name '*.asm' -o -name '*.inc')

.PHONY: all run shot test-input clean

all: $(DSK)

# RASM appends to an existing DSK, so start from a fresh one every time.
# Include paths in src/vos.asm are relative to src/; the DSK path is
# relative to the repo root, where make runs.
$(DSK): $(SOURCES)
	@mkdir -p $(BUILD)
	@rm -f $(DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos -s -sl

run: $(DSK)
	$(CAP32) -a 'run"vos\n' $(abspath $(DSK))

shot: $(DSK)
	snap run --shell caprice32.launcher -c "bash $(abspath tools/cap32_shot.sh)"
	@ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1

TEST_DSK := $(BUILD)/vos_test.dsk

$(TEST_DSK): $(SOURCES)
	@mkdir -p $(BUILD)
	@rm -f $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_test -DTEST_SCRIPT=1

# Shots after the mode 1 part of the script and after the mode 0 part.
test-input: $(TEST_DSK)
	for d in 300 700; do \
	  snap run --shell caprice32.launcher -c "VOS_DSK=$(abspath $(TEST_DSK)) bash $(abspath tools/cap32_shot.sh) $$d"; \
	  ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1; sleep 1; \
	done

clean:
	rm -rf $(BUILD)
