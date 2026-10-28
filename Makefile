# V-OS build
#   make          assemble build/vos.dsk
#   make run      boot it in Caprice32 (RUN"VOS")
#   make shot     boot headless and save a screenshot
#   make test-input  build/vos_test.dsk (drive A) and build/vos_b.dsk
#                 (drive B) with scripted key presses
#                 (src/kernel/test_script.asm) and six screenshots
#   make test-amsdos  the same script, then AMSDOS in BASIC reads the
#                 files V-OS wrote (one screenshot)
#   make test-reboot  the same, then RUN"VOS" with the saved SETUP.CFG
#   make test-system  the script with drive A in SYSTEM format
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

.PHONY: all run shot test-input test-amsdos test-reboot test-system clean

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
	@ls -t $(BUILD)/shots/*.png | head -1

TEST_DSK := $(BUILD)/vos_test.dsk
TEST_DSK_B := $(BUILD)/vos_b.dsk

# Drive B for the tests: a text file without a header, and a 20000-byte
# binary (byte i = (i + i / 256) & 255), bigger than one 16K bank.
$(TEST_DSK_B): tools/dsk_ext.py
	@mkdir -p $(BUILD)
	@rm -f $@
	printf 'HELLO FROM DRIVE B\r\nSECOND LINE\r\n\032' > $(BUILD)/HELLO.TXT
	$(PYTHON) -I -c "open('$(BUILD)/BIG.BIN','wb').write(bytes((i + (i >> 8)) & 255 for i in range(20000)))"
	$(IDSK) $@ -n > /dev/null
	$(IDSK) $@ -i $(BUILD)/HELLO.TXT -t 0 > /dev/null
	$(IDSK) $@ -i $(BUILD)/BIG.BIN -t 1 -c 4000 -e 4000 > /dev/null
	$(PYTHON) -I tools/dsk_ext.py $@

# Fresh copies for each run: the emulator writes to the images. $(1) is
# the script and its delay; shots go to build/shots/<delay>.
define run_test
	cp $(TEST_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$(2) VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath $(1)) $(2)"; \
	ls $(BUILD)/shots/$(2)/*.png
endef

$(TEST_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_test -DTEST_SCRIPT=1
	$(call add_packs,$(TEST_DSK))
	$(PYTHON) -I tools/dsk_ext.py $(TEST_DSK)

# Shots along the script (src/kernel/test_script.asm): selection kept
# from Desktop to Commander, copy, "replace?", format of B:, Setup.
# One run per shot: runs are short, shots are per second.
TEST_SHOTS := 110 170 230 260 300 500 820 900
test-input: $(TEST_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(TEST_SHOTS); do \
	  $(call run_test,tools/cap32_shot.sh,$$d); \
	done

# Caprice32 keeps disc writes in memory only, so V-OS's writes are
# checked in the same run: the script ends by restarting into BASIC.
test-amsdos: $(TEST_DSK) $(TEST_DSK_B)
	$(call run_test,tools/cap32_amsdos_check.sh,1100)

# The same, then RUN"VOS" again: V-OS starts as SETUP.CFG says.
test-reboot: $(TEST_DSK) $(TEST_DSK_B)
	$(call run_test,tools/cap32_reboot_check.sh,1100)

# The script with drive A: in SYSTEM format, up to the copy to A:.
test-system: $(TEST_DSK) $(TEST_DSK_B)
	$(PYTHON) -I tools/dsk_system.py $(TEST_DSK) $(BUILD)/vos_sys.dsk
	cp $(BUILD)/vos_sys.dsk $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/system VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) 820"; \
	ls $(BUILD)/shots/system/*.png

clean:
	rm -rf $(BUILD)
