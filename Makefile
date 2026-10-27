# V-OS build
#   make          assemble build/vos.dsk
#   make run      boot it in Caprice32 (RUN"VOS")
#   make shot     boot headless and save a screenshot
#   make test-input  build/vos_test.dsk with scripted key presses
#                 (src/kernel/test_script.asm) and six screenshots
#   make test-amsdos  the same script, then AMSDOS in BASIC loads and
#                 lists the file V-OS wrote (one screenshot)
#   make test-system  the script on a SYSTEM format copy of the disc
#   make clean

RASM    ?= rasm
CAP32   ?= caprice32.launcher
BUILD   := build
DSK     := $(BUILD)/vos.dsk
SOURCES := $(shell find src -name '*.asm' -o -name '*.inc')
PYTHON  ?= python3
IDSK    ?= iDSK

# Language data generated from lang/ by tools/mklng.py. The kernel
# files are committed (like src/gfx/font_ascii.asm); packs are build
# products added to the disk.
LANG_KERNEL := src/lang/msg_ids.inc src/lang/lang_en.asm
PACKS   := $(BUILD)/GREEK.LNG

.PHONY: all run shot test-input test-amsdos test-system clean

all: $(DSK)

# RASM appends to an existing DSK, so start from a fresh one every time.
# Include paths in src/vos.asm are relative to src/; the DSK path is
# relative to the repo root, where make runs.
$(LANG_KERNEL) &: lang/en/keymap.txt lang/en/messages.txt tools/mklng.py
	$(PYTHON) -I tools/mklng.py kernel lang/en src/lang

$(BUILD)/GREEK.LNG: $(wildcard lang/el/*.txt) lang/en/messages.txt lang/en/keymap.txt tools/mklng.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/el $@ --master lang/en

# The kernel loads packs into bank 7 itself (fs_load), so the header
# addresses only document it.
define add_packs
	for p in $(PACKS); do $(IDSK) $(1) -i $$p -t 1 -c 8000 -e 8000 > /dev/null; done
endef

$(DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $(DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos -s -sl
	$(call add_packs,$(DSK))
	$(PYTHON) -I tools/dsk_ext.py $(DSK)

run: $(DSK)
	$(CAP32) -a 'run"vos\n' $(abspath $(DSK))

shot: $(DSK)
	snap run --shell caprice32.launcher -c "bash $(abspath tools/cap32_shot.sh)"
	@ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1

TEST_DSK := $(BUILD)/vos_test.dsk

$(TEST_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_test -DTEST_SCRIPT=1
	$(call add_packs,$(TEST_DSK))
	$(PYTHON) -I tools/dsk_ext.py $(TEST_DSK)

# Shots of the saved, opened, deleted and disc info dialogs. Each run
# starts from a fresh copy, since the emulator writes to the image.
test-input: $(TEST_DSK)
	for d in 120 330 440 480 600 760; do \
	  cp $(TEST_DSK) $(BUILD)/vos_run.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_DSK=$(abspath $(BUILD))/vos_run.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	  ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1; sleep 1; \
	done

# Caprice32 keeps disc writes in memory only, so V-OS's writes are
# checked in the same run: the script ends by restarting into BASIC.
test-amsdos: $(TEST_DSK)
	cp $(TEST_DSK) $(BUILD)/vos_run.dsk
	snap run --shell caprice32.launcher -c "VOS_DSK=$(abspath $(BUILD))/vos_run.dsk bash $(abspath tools/cap32_amsdos_check.sh)"
	ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1

# Shots of the opened file and of the deleted file on a SYSTEM disc.
test-system: $(TEST_DSK)
	$(PYTHON) -I tools/dsk_system.py $(TEST_DSK) $(BUILD)/vos_sys.dsk
	for d in 330 480; do \
	  cp $(BUILD)/vos_sys.dsk $(BUILD)/vos_run.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_DSK=$(abspath $(BUILD))/vos_run.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	  ls -t $(HOME)/snap/caprice32/current/screenshots/*.png | head -1; sleep 1; \
	done

clean:
	rm -rf $(BUILD)
