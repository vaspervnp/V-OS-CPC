# V-OS build
#   make          assemble build/vos.dsk
#   make run      boot it in Caprice32 (RUN"VOS")
#   make shot     boot headless and save a screenshot
#   make test-input  build/vos_test.dsk (drive A) and build/vos_b.dsk
#                 (drive B) with scripted key presses
#                 (src/kernel/test_script.asm) and six screenshots
#   make test-calc   the calculator (CALC.BIN) clicked, then CALC.VBS
#                 in Studio (TEST_SCRIPT=2)
#   make test-costume a costume drawn in Studio, run, opened again
#   make test-acc    CLOCK as the desk accessory, over the Launcher and Studio
#   make test-multi  DEMO and PONG side by side, each goes on where it was
#   make test-lang   English at boot, Greek saved in Setup, then V-OS
#                 again starts in Greek (TEST_SCRIPT=3)
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
PACKS   := $(BUILD)/ENGLISH.MSG $(BUILD)/GREEK.LNG

.PHONY: all run shot test-input test-calc test-lang test-costume test-acc test-multi test-amsdos test-reboot test-system clean

all: $(DSK)

# RASM appends to an existing DSK, so start from a fresh one every time.
# Include paths in src/vos.asm are relative to src/; the DSK path is
# relative to the repo root, where make runs.
$(LANG_KERNEL) $(BUILD)/ENGLISH.MSG &: lang/en/keymap.txt lang/en/messages.txt tools/mklng.py
	$(PYTHON) -I tools/mklng.py kernel lang/en src/lang $(BUILD)/ENGLISH.MSG

$(BUILD)/GREEK.LNG: $(wildcard lang/el/*.txt) lang/en/messages.txt lang/en/keymap.txt tools/mklng.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/el $@ --master lang/en

# The kernel loads packs into bank 7 itself (fs_load), so the header
# addresses only document it.
define add_packs
	for p in $(PACKS); do $(IDSK) $(1) -i $$p -t 1 -c 8000 -e 8000 > /dev/null; done
endef

# Programs (apps/): each is assembled on its own, with only the API
# include, and goes on the disc as a binary loading at #4000.
APPS    := $(BUILD)/DEMO.BIN $(BUILD)/MIXED.BIN $(BUILD)/STUDIO.BIN $(BUILD)/PONG.BIN $(BUILD)/CATCH.BIN $(BUILD)/STARCAT.BIN \
           $(BUILD)/COUNTER.BIN $(BUILD)/FLAP.BIN $(BUILD)/FLAP.VBS \
           $(BUILD)/CALC.BIN $(BUILD)/CALC.VBS $(BUILD)/CLOCK.BIN
APP_SOURCES := $(shell find apps -name '*.asm') src/api/vos_api.inc

# Icons for the Launcher (VOS_ICON): text in apps/icons, made into
# assembly by tools/mkicon.py
$(BUILD)/icon_%.asm: apps/icons/%.txt tools/mkicon.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mkicon.py $< $@

# A program that may be moved (src/api/vos_api.inc): assembled at #4000
# and at #4100 (it saves build/<name>_lo.bin and _hi.bin), then
# tools/mkreloc.py appends the relocation table from the difference.
# $(1) is the source, $(2) the name.
define reloc_app
	$(RASM) $(1) -I src -I $(BUILD) -o $(BUILD)/$(2) > /dev/null
	$(RASM) $(1) -I src -I $(BUILD) -DVOS_RELOC_PASS=1 -o $(BUILD)/$(2)_hi > /dev/null
	$(PYTHON) -I tools/mkreloc.py $(BUILD)/$(2)_lo.bin $(BUILD)/$(2)_hi.bin $@
endef

$(BUILD)/DEMO.BIN: apps/demo/demo.asm $(BUILD)/icon_demo.asm src/api/vos_api.inc tools/mkreloc.py
	$(call reloc_app,apps/demo/demo.asm,demo)

$(BUILD)/MIXED.BIN: apps/mixed/mixed.asm $(BUILD)/icon_mixed.asm src/api/vos_api.inc tools/mkreloc.py
	$(call reloc_app,apps/mixed/mixed.asm,mixed)

# CLOCK, also a desk accessory
$(BUILD)/clock_texts.asm: apps/clock/texts.txt tools/mktexts.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mktexts.py $< $@

$(BUILD)/CLOCK.BIN: apps/clock/clock.asm $(BUILD)/clock_texts.asm $(BUILD)/icon_clock.asm src/api/vos_api.inc tools/mkreloc.py
	$(call reloc_app,apps/clock/clock.asm,clock)

# Studio: its texts (English and Greek) come from texts.txt, the
# blocks' texts from blocks.txt (a second table)
$(BUILD)/studio_texts.asm: apps/studio/texts.txt tools/mktexts.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mktexts.py $< $@

$(BUILD)/studio_blocks.asm: apps/studio/blocks.txt tools/mktexts.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mktexts.py $< $@ block_texts

# Studio carries the player (blocks/player.asm): the runtime and a
# compiler for Studio's programs, which RUN writes in front of one.
$(BUILD)/VBRUN.BIN: blocks/player.asm blocks/runtime.asm $(BUILD)/icon_blocks.asm src/api/vos_api.inc
	$(RASM) blocks/player.asm -I src -I blocks -I $(BUILD) -o $(BUILD)/vbrun > /dev/null

$(BUILD)/STUDIO.BIN: apps/studio/studio.asm $(BUILD)/studio_texts.asm $(BUILD)/studio_blocks.asm $(BUILD)/icon_studio.asm $(BUILD)/VBRUN.BIN src/api/vos_api.inc
	$(RASM) apps/studio/studio.asm -I src -I $(BUILD) -o $(BUILD)/studio > /dev/null

# Block programs (blocks/): compiled to assembly by vbc.py, with the
# runtime. The .BIN takes the name inside the .vbp.
BLOCKS_RT := blocks/vbc.py blocks/runtime.asm src/api/vos_api.inc lang/en/keymap.txt apps/icons/blocks.txt tools/mkicon.py tools/mkreloc.py

$(BUILD)/PONG.BIN: blocks/examples/pong.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/CATCH.BIN: blocks/examples/catch.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/STARCAT.BIN: blocks/examples/starcat.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/COUNTER.BIN: blocks/examples/counter.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

# Studio programs from text (tools/mkvbs.py): the .VBS Studio opens, and
# the .BIN its RUN would write (the player, then the program)
$(BUILD)/CALC.BIN $(BUILD)/CALC.VBS &: blocks/examples/calc.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.BIN
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/CALC.VBS $(BUILD)/VBRUN.BIN $(BUILD)/CALC.BIN
$(BUILD)/FLAP.BIN $(BUILD)/FLAP.VBS &: blocks/examples/flap.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.BIN
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/FLAP.VBS $(BUILD)/VBRUN.BIN $(BUILD)/FLAP.BIN

define add_apps
	for p in $(2); do $(IDSK) $(1) -i $$p -t 1 -c 4000 -e 4000 > /dev/null; done
endef

$(DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $(DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos -s -sl
	$(call add_packs,$(DSK))
	$(call add_apps,$(DSK),$(APPS))
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

$(TEST_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_test -DTEST_SCRIPT=1
	$(call add_packs,$(TEST_DSK))
	$(call add_apps,$(TEST_DSK),$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $(TEST_DSK)

# Shots along the script (src/kernel/test_script.asm): Studio, a slot
# typed into, a block added, the sprite moved, the name dialog, the
# file list, the program opened again, running, and Studio after it.
# One run per shot: runs are short, shots are per second.
TEST_SHOTS := 230 290 350 410 450 560 680 830 1000
test-input: $(TEST_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(TEST_SHOTS); do \
	  $(call run_test,tools/cap32_shot.sh,$$d); \
	done

# The calculator (blocks/examples/calc.vbt) with clicks on its buttons,
# then Studio with CALC.VBS (src/kernel/test_script.asm, TEST_SCRIPT=2).
# src/vos.asm writes test builds to $(TEST_DSK): the image is moved.
CALC_DSK := $(BUILD)/vos_calc.dsk
CALC_SHOTS := 200 420 840 960
$(CALC_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_calc -DTEST_SCRIPT=2
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-calc: $(CALC_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(CALC_SHOTS); do \
	  cp $(CALC_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The default language (TEST_SCRIPT=3): English at boot, Greek chosen
# and saved in Setup, then V-OS again from BASIC starts in Greek
LANG_DSK := $(BUILD)/vos_lang.dsk
$(LANG_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_lang -DTEST_SCRIPT=3
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-lang: $(LANG_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in 150; do \
	  cp $(LANG_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	cp $(LANG_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/reboot VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_reboot_check.sh) 300" || true
	ls $(BUILD)/shots/*/*.png

# A costume drawn in Studio (TEST_SCRIPT=4): the editor, the stage,
# the program running, and opened again
COSTUME_DSK := $(BUILD)/vos_costume.dsk
COSTUME_SHOTS := 400 440 600 800
$(COSTUME_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_costume -DTEST_SCRIPT=4
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-costume: $(COSTUME_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(COSTUME_SHOTS); do \
	  cp $(COSTUME_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# CLOCK as the desk accessory (TEST_SCRIPT=5): over the Launcher, then
# over Studio's mixed screen
ACC_DSK := $(BUILD)/vos_acc.dsk
ACC_SHOTS := 205 222 400 470
$(ACC_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_acc -DTEST_SCRIPT=5
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-acc: $(ACC_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(ACC_SHOTS); do \
	  cp $(ACC_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# Programs side by side (TEST_SCRIPT=6): DEMO and PONG run, each goes
# on where it was, STUDIO is refused while PONG runs
MULTI_DSK := $(BUILD)/vos_multi.dsk
MULTI_SHOTS := 165 250 340 425 800
$(MULTI_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_multi -DTEST_SCRIPT=6
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-multi: $(MULTI_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(MULTI_SHOTS); do \
	  cp $(MULTI_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

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
