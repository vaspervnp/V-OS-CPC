# V-OS build
#   make          assemble build/vos.dsk (the system, drive A:) and
#                 build/apps.dsk (the programs, drive B:)
#   make run      boot it in Caprice32 (RUN"VOS")
#   make shot     boot headless and save a screenshot
#   make test-input  build/vos_test.dsk (drive A) and build/vos_b.dsk
#                 (drive B) with scripted key presses
#                 (src/kernel/test_script.asm) and six screenshots
#   make test-calc   the calculator (CALC.VBN) clicked, then CALC.VBS
#                 in Studio (TEST_SCRIPT=2)
#   make test-costume a costume drawn in Studio, run, opened again
#   make test-acc    CLOCK as the desk accessory, over the Launcher and Studio
#   make test-multi  DEMO and PONG side by side, each goes on where it was
#   make test-switch F6: the program switcher, also from the VIEW menu
#   make test-expand a 512K RAM expansion: STUDIO and CALC beside DEMO, PONG
#   make test-behind TICKER goes on in the background; Studio's IN BACKGROUND
#   make test-drag   windows dragged by their title bars: FILES, a dialog,
#                 the CLOCK accessory, CALC's window (TEST_SCRIPT=10)
#   make test-langs  Setup's LANGUAGE through Greek, French, Spanish, German
#                 and Italian; the Desktop and keyboard in Italian
#   make test-mines  MINES, a Studio program: cells opened until a mine
#   make test-vars   Studio's 128 variables: VARS.VBS opened and run,
#                    SAVE VARS and LOAD VARS
#   make test-bricks BRICKS, a block game: the bat moved, bricks hit
#   make test-lang   English at boot, Greek saved in Setup, then V-OS
#                 again starts in Greek (TEST_SCRIPT=3)
#   make test-paint-big PAINT on the whole screen (576K): the bars, .SCR
#   make test-m4     the M4 board's SD card in the 1984 emulator: DISK
#                 on the Desktop, a copy, a folder, a program from it
#   make test-scr    PAINT's EXPORT .SCR (run in a Z80 emulator, tools/scr_check.py)
#                 loaded in BASIC from a disc, and every pixel checked
#   make test-notepad-big NOTEPAD's text window in a Z80 emulator: 12K and
#                 16K texts with a data bank of its own, 4K on a 6128
#   make test-data   (576K) NOTEPAD with a 15K text, MARKDOWN meanwhile,
#                 NOTEPAD again: its text kept in its own data bank
#   make test-db     the database engine in a Z80 emulator: thousands of
#                 random calls checked against a model, the file page by page
#   make test-db-disc DB.SYS with the kernel's file system on a DSK image
#   make test-calc-sys the formula engine (CALC.SYS) in a Z80 emulator:
#                 fixed and random formulas checked against a model
#   make test-sheet-z80 SHEET in a Z80 emulator with CALC.SYS, its screen
#                 as text: values, errors, scrolling, SAVE, OPEN, UTF-8
#   make test-sheet  SHEET: numbers and a formula typed, CALC.SYS from A:,
#                 the sheet saved
#   make test-streets STREETS from its disc: a new STREETS.VDB, FIND, ADD
#   make test-database-z80 DATABASE in a Z80 emulator, its screen as text:
#                 records, key order, FIND, changes, scrolling, two tables
#   make test-database DATABASE: a database on B:, a table, records in the
#                 form, the list in key order without case, FIND, a change
#   make test-kbds   Setup's KEYBOARDS: ALL SIX, then NOTEPAD typed with
#                 each keyboard in turn (CONTROL+SHIFT)
#   make test-charset Greek, French, Spanish, German, Italian in one text
#                 file in UTF-8, in NOTEPAD: the V-OS character set
#   make test-reader-utf8 READER with an INDEX.MD in UTF-8
#   make test-utf8   VX_UTF8's code (src/kernel/utf8.asm) in a Z80
#                 emulator, against tools/voscs.py
#   make test-amsdos  the same script, then AMSDOS in BASIC reads the
#                 files V-OS wrote (one screenshot)
#   make test-reboot  the same, then RUN"VOS" with the saved SETUP.CFG
#   make test-system  the script with drive A in SYSTEM format
#   make new-app NAME=hello   a program of your own in myapps/hello,
#                 from sdk/template (sdk/README.md)
#   make app NAME=hello       it as build/HELLO.BIN, on build/vos.dsk
#   make test-vrouves VROUVES (myapps/vrouves) from its disc in B:: defenders built, a wave
#   make test-apps   the two discs given out, build/vos.dsk with the test
#                 keys in A: and build/apps.dsk in B:: PONG run from B:
#   make test-sdk    the template built as HELLO, run from the Launcher:
#                 the box moved, BEEP, its menu and ABOUT dialog
#   make linux     build/V-OS-linux.tar.gz: V-OS with CPCEMU 2.5 for Linux
#   make docs      the manual as PDFs: docs/V-OS.pdf (Greek, from
#                 docs/manual/*.md and sdk/README.md) and docs/V-OS-<code>.pdf
#                 for en fr es de it (docs/manual/<code>/, sdk/README.<code>.md)
#                 (tools/mkdocs.py: python markdown, pymupdf)
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
PACKS   := $(BUILD)/ENGLISH.MSG $(BUILD)/GREEK.LNG $(BUILD)/FRENCH.LNG \
           $(BUILD)/SPANISH.LNG $(BUILD)/GERMAN.LNG $(BUILD)/ITALIAN.LNG

.PHONY: test-window test-theme test-wall demo-sys test-apps test-calc-sys test-sheet-z80 test-sheet test-database-z80 test-database test-utf8 test-reader-utf8 test-kbds test-charset test-music-block test-styles test-reader test-webget test-clip test-sysinfo test-open test-markdown linux test-music songs FORCE test-about test-paint test-paint-big test-m4 test-scr test-notepad test-notepad-big test-data test-db test-db-disc test-streets windows docs new-app app test-sdk test-vrouves all run shot test-input test-calc test-lang test-costume test-acc test-multi test-switch test-expand test-behind test-drag test-langs test-mines test-vars test-bricks test-amsdos test-reboot test-system clean

all: $(DSK)

# RASM appends to an existing DSK, so start from a fresh one every time.
# Include paths in src/vos.asm are relative to src/; the DSK path is
# relative to the repo root, where make runs.
# The day of the build, for {DATE} in the texts (the About dialog): the
# texts are made again on a new day
$(BUILD)/date.txt: FORCE
	@mkdir -p $(BUILD)
	@d=$$(date +%d.%m.%Y); [ "$$(cat $@ 2>/dev/null)" = "$$d" ] || echo $$d > $@
FORCE:

$(LANG_KERNEL) $(BUILD)/ENGLISH.MSG &: lang/en/keymap.txt lang/en/messages.txt tools/mklng.py tools/voscs.py src/version.inc $(BUILD)/date.txt
	$(PYTHON) -I tools/mklng.py kernel lang/en src/lang $(BUILD)/ENGLISH.MSG

# the V-OS letters without case or accent, for DB_ALPHA keys in DB.SYS
src/db/fold.inc: tools/voscs.py
	$(PYTHON) -I tools/voscs.py fold > $@
# and the Unicode of the V-OS codes, for VX_UTF8 (kernel/utf8.asm)
src/kernel/utf8.inc: tools/voscs.py
	$(PYTHON) -I tools/voscs.py utf8 > $@

# every pack has the keyboards of all the packs (CONTROL+SHIFT, Setup's
# KEYBOARDS)
LANG_KBDS := $(wildcard lang/*/keymap.txt lang/*/pack.txt)
$(BUILD)/GREEK.LNG: $(wildcard lang/el/*.txt) $(LANG_KBDS) lang/vos/font.txt tools/voscs.py lang/en/messages.txt lang/en/keymap.txt tools/mklng.py src/version.inc $(BUILD)/date.txt
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/el $@ --master lang/en

# every pack has the font of the V-OS character set, lang/vos/font.txt
LATIN_PACK = $(wildcard lang/$(1)/*.txt) $(LANG_KBDS) lang/vos/font.txt tools/voscs.py lang/en/messages.txt lang/en/keymap.txt tools/mklng.py src/version.inc $(BUILD)/date.txt
$(BUILD)/FRENCH.LNG: $(call LATIN_PACK,fr)
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/fr $@ --master lang/en
$(BUILD)/SPANISH.LNG: $(call LATIN_PACK,es)
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/es $@ --master lang/en
$(BUILD)/GERMAN.LNG: $(call LATIN_PACK,de)
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/de $@ --master lang/en
$(BUILD)/ITALIAN.LNG: $(call LATIN_PACK,it)
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/mklng.py pack lang/it $@ --master lang/en

# The kernel loads packs into bank 7 itself (fs_load), so the header
# addresses only document it.
define add_packs
	for p in $(PACKS); do $(IDSK) $(1) -i $$p -t 1 -c 8000 -e 8000 > /dev/null; done
endef
# English and Greek only, for the test discs of one program (TEST_APPS)
TEST_PACKS := $(BUILD)/ENGLISH.MSG $(BUILD)/GREEK.LNG
define add_test_packs
	for p in $(TEST_PACKS); do $(IDSK) $(1) -i $$p -t 1 -c 8000 -e 8000 > /dev/null; done
endef

# Programs (apps/): each is assembled on its own, with only the API
# include, and goes on the disc as a binary loading at #4000.
APPS    := $(BUILD)/DEMO.BIN $(BUILD)/MIXED.BIN $(BUILD)/STUDIO.BIN $(BUILD)/PONG.VBN $(BUILD)/CATCH.VBN $(BUILD)/STARCAT.VBN \
           $(BUILD)/COUNTER.VBN $(BUILD)/FLAP.VBN $(BUILD)/FLAP.VBS \
           $(BUILD)/CALC.VBN $(BUILD)/CALC.VBS $(BUILD)/CLOCK.BIN $(BUILD)/TICKER.VBN \
           $(BUILD)/TICKER.VBS $(BUILD)/VBRUN.SYS $(BUILD)/MINES.VBN $(BUILD)/MINES.VBS \
           $(BUILD)/BRICKS.VBN
# A real disc holds 180K, not all of them: the system disc, build/vos.dsk,
# has the system's programs and the VB sources (Studio opens them on A:);
# the VB programs go on build/apps.dsk, for B:, with your own programs.
SYS_APPS := $(BUILD)/DEMO.BIN $(BUILD)/MIXED.BIN $(BUILD)/STUDIO.BIN \
            $(BUILD)/CLOCK.BIN $(BUILD)/VBRUN.SYS $(filter %.VBS,$(APPS))
DISC_APPS := $(filter-out $(SYS_APPS),$(APPS))
APPS_DSK := $(BUILD)/apps.dsk
APP_SOURCES := $(shell find apps -name '*.asm') src/api/vos_api.inc
# the test discs whose program comes after them: without the Studio
# sources (the Launcher does not list them), so that it stays inside
# the 180 blocks V-OS reads
TEST_APPS := $(filter-out %.VBS,$(APPS))

# Your own programs (sdk/README.md): each folder myapps/name holds
# name.asm, texts.txt and icon.txt (and may include more .asm of its
# own), and becomes build/NAME.BIN, with a relocation table, on
# build/apps.dsk (not on the test discs), with the files of its disc/
# folder as they are (its data files); with an owndisc/ folder, on a
# disc of its own instead, build/<name>.dsk, below.
#   make new-app NAME=hello   myapps/hello, from sdk/template
#   make app NAME=hello       build/HELLO.BIN and build/apps.dsk
upper = $(shell echo $(1) | tr a-z A-Z)
MYAPPS := $(notdir $(wildcard myapps/*))
MYAPP_BINS := $(foreach a,$(MYAPPS),$(BUILD)/$(call upper,$(a)).BIN)
MYAPP_DISC := $(wildcard myapps/*/disc/*)   # their data files, as they are
# one with a disc of its own (owndisc/, below) is only there
OWN_APPS := $(patsubst myapps/%/owndisc/,%,$(wildcard myapps/*/owndisc/))
DSK_MYAPPS := $(foreach a,$(filter-out $(OWN_APPS),$(MYAPPS)),$(BUILD)/$(call upper,$(a)).BIN) \
              $(foreach a,$(filter-out $(OWN_APPS),$(MYAPPS)),$(wildcard myapps/$(a)/disc/*))

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

# The player (blocks/player.asm): the runtime and a compiler for
# Studio's programs. Studio's RUN reads VBRUN.SYS from the disc and
# writes it in front of one (not a .BIN or .VBN: the Launcher does not
# list it).
$(BUILD)/VBRUN.BIN: blocks/player.asm blocks/runtime.asm $(BUILD)/icon_blocks.asm src/api/vos_api.inc
	$(RASM) blocks/player.asm -I src -I blocks -I $(BUILD) -o $(BUILD)/vbrun > /dev/null

$(BUILD)/VBRUN.SYS: $(BUILD)/VBRUN.BIN
	cp $< $@

$(BUILD)/STUDIO.BIN: apps/studio/studio.asm $(BUILD)/studio_texts.asm $(BUILD)/studio_blocks.asm $(BUILD)/icon_studio.asm src/api/vos_api.inc
	$(RASM) apps/studio/studio.asm -I src -I $(BUILD) -o $(BUILD)/studio > /dev/null

# Block programs (blocks/): compiled to assembly by vbc.py, with the
# runtime. The .VBN (a V-OS program, of its own type so that the
# Desktop marks it) takes the name inside the .vbp.
BLOCKS_RT := blocks/vbc.py blocks/runtime.asm src/api/vos_api.inc lang/en/keymap.txt apps/icons/blocks.txt tools/mkicon.py tools/mkreloc.py

$(BUILD)/PONG.VBN: blocks/examples/pong.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/CATCH.VBN: blocks/examples/catch.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/STARCAT.VBN: blocks/examples/starcat.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

$(BUILD)/COUNTER.VBN: blocks/examples/counter.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

# BRICKS: its .vbp is written by tools/mkbricks.py (32 bricks, 32 alike
# scripts)
blocks/examples/bricks.vbp: tools/mkbricks.py
	$(PYTHON) -I tools/mkbricks.py $@

$(BUILD)/BRICKS.VBN: blocks/examples/bricks.vbp $(BLOCKS_RT)
	$(PYTHON) -I blocks/vbc.py $< -o $(BUILD) > /dev/null

# Studio programs from text (tools/mkvbs.py): the .VBS Studio opens, and
# the .VBN its RUN would write (the player, then the program)
$(BUILD)/CALC.VBN $(BUILD)/CALC.VBS &: blocks/examples/calc.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/CALC.VBS $(BUILD)/VBRUN.SYS $(BUILD)/CALC.VBN
$(BUILD)/FLAP.VBN $(BUILD)/FLAP.VBS &: blocks/examples/flap.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/FLAP.VBS $(BUILD)/VBRUN.SYS $(BUILD)/FLAP.VBN
$(BUILD)/TICKER.VBN $(BUILD)/TICKER.VBS &: blocks/examples/ticker.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/TICKER.VBS $(BUILD)/VBRUN.SYS $(BUILD)/TICKER.VBN
$(BUILD)/MINES.VBN $(BUILD)/MINES.VBS &: blocks/examples/mines.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/MINES.VBS $(BUILD)/VBRUN.SYS $(BUILD)/MINES.VBN

# $(1): a folder in myapps (or build/sdk_test), $(2): its name; the
# texts and icon go to $(BUILD)/myapp_$(2), where the source includes
# them from
define myapp_rule
$(BUILD)/$(call upper,$(2)).BIN: $(1)/$(2).asm $(wildcard $(1)/*.asm) $(1)/texts.txt $(1)/icon.txt $(wildcard src/api/*) tools/mkreloc.py tools/mktexts.py tools/mkicon.py
	@mkdir -p $(BUILD)/myapp_$(2)
	$(PYTHON) -I tools/mktexts.py $(1)/texts.txt $(BUILD)/myapp_$(2)/app_texts.asm
	$(PYTHON) -I tools/mkicon.py $(1)/icon.txt $(BUILD)/myapp_$(2)/app_icon.asm
	@$(RASM) $(1)/$(2).asm -I src -I $(BUILD)/myapp_$(2) -I $(1) -o $(BUILD)/myapp_$(2)/lo > $(BUILD)/myapp_$(2)/rasm.log || { cat $(BUILD)/myapp_$(2)/rasm.log; exit 1; }
	@$(RASM) $(1)/$(2).asm -I src -I $(BUILD)/myapp_$(2) -I $(1) -DVOS_RELOC_PASS=1 -o $(BUILD)/myapp_$(2)/hi > $(BUILD)/myapp_$(2)/rasm.log || { cat $(BUILD)/myapp_$(2)/rasm.log; exit 1; }
	$(PYTHON) -I tools/mkreloc.py $(BUILD)/myapp_$(2)/lo.bin $(BUILD)/myapp_$(2)/hi.bin $$@
endef
$(foreach a,$(MYAPPS),$(eval $(call myapp_rule,myapps/$(a),$(a))))

# One with an owndisc/ folder gets a disc of its own instead,
# build/<name>.dsk: NAME.BIN and the files of owndisc/, as they are
OWN_DSKS := $(foreach a,$(OWN_APPS),$(BUILD)/$(a).dsk)
define own_disc_rule
$(BUILD)/$(1).dsk: $(BUILD)/$(call upper,$(1)).BIN $(wildcard myapps/$(1)/owndisc/*) tools/dsk_ext.py
	@rm -f $$@
	$(IDSK) $$@ -n > /dev/null
	$$(call add_apps,$$@,$(BUILD)/$(call upper,$(1)).BIN $(wildcard myapps/$(1)/owndisc/*))
	$(PYTHON) -I tools/dsk_ext.py --fit $$@
endef
$(foreach a,$(OWN_APPS),$(eval $(call own_disc_rule,$(a))))
all: $(OWN_DSKS)

# MUSIC's songs (myapps/music): Arkos Tracker's .aks songs made into .MUS
# files on build/music.dsk by tools/mkmusic.py and Arkos Tracker's
# SongToAkm; they are not in the repository (their authors' rights).
#   make songs ARKOS=path/to/ArkosTracker3 [SONGS=folder or song.aks]
ARKOS ?= $(BUILD)/dl/arkos/x/ArkosTracker3
SONGS ?= $(ARKOS)/songs/ArkosTracker3
songs:
	$(PYTHON) -I tools/mkmusic.py "$(ARKOS)/tools/SongToAkm" "$(SONGS)" -o myapps/music/owndisc
	$(MAKE) $(BUILD)/music.dsk

# V-OS for Windows (tools/mkwindows.sh, under WSL): build/V-OS-windows.zip,
# V-OS.exe with CPCEMU (576K, AMX mouse, M4 board), vos.dsk in A:,
# apps.dsk in B: and the programs' own discs beside them.
# CPCEMU_ZIP is its portable zip, from cpc-emu.org/download.html.
CPCEMU_ZIP ?= $(BUILD)/dl/cpcemu/cpcemu_portable-win32-x86-3.0.2.zip
windows: $(DSK) $(APPS_DSK) $(OWN_DSKS) tools/mkwindows.sh tools/windows/launcher.cs tools/windows/README.txt
	bash tools/mkwindows.sh $(CPCEMU_ZIP)

# V-OS for Linux (tools/mklinux.sh): build/V-OS-linux.tar.gz, the V-OS
# script with CPCEMU 2.5 for x86_64 (576K, AMX mouse, M4 board), vos.dsk
# in A:, apps.dsk in B: and the programs' own discs beside them.
# CPCEMU_TGZ is its Linux tar.gz, from cpc-emu.org/download.html.
CPCEMU_TGZ ?= $(BUILD)/dl/cpcemu-linux/cpcemu-linux-x86_64-2.5.tar.gz
linux: $(DSK) $(APPS_DSK) $(OWN_DSKS) tools/mklinux.sh tools/linux/V-OS tools/linux/README.txt
	bash tools/mklinux.sh $(CPCEMU_TGZ)

# The manual as a PDF (python's user packages: no -I)
DOC_LANGS := en fr es de it
docs: docs/V-OS.pdf $(foreach l,$(DOC_LANGS),docs/V-OS-$(l).pdf)
docs/V-OS.pdf: $(sort $(wildcard docs/manual/*.md)) sdk/README.md tools/mkdocs.py
	$(PYTHON) tools/mkdocs.py $@
define doc_rule
docs/V-OS-$(1).pdf: $(sort $(wildcard docs/manual/$(1)/*.md)) sdk/README.$(1).md tools/mkdocs.py
	$(PYTHON) tools/mkdocs.py $$@ $(1)
endef
$(foreach l,$(DOC_LANGS),$(eval $(call doc_rule,$(l))))

new-app:
	@echo "$(NAME)" | grep -Eq '^[a-z][a-z0-9]{0,7}$$' || { echo "make new-app NAME=name: 1-8 lower-case letters or digits, a letter first"; exit 1; }
	@test ! -e myapps/$(NAME) || { echo "myapps/$(NAME) is there already"; exit 1; }
	@test -z "$(filter $(addprefix $(BUILD)/$(call upper,$(NAME)).,BIN VBN SYS),$(APPS))" || { echo "$(call upper,$(NAME)) is a V-OS program already: choose another name"; exit 1; }
	mkdir -p myapps/$(NAME)
	sed 's/APPNAME/$(call upper,$(NAME))/g; s/appname/$(NAME)/g' sdk/template/app.asm > myapps/$(NAME)/$(NAME).asm
	sed 's/APPNAME/$(call upper,$(NAME))/g' sdk/template/texts.txt > myapps/$(NAME)/texts.txt
	sed 's/APPNAME/$(call upper,$(NAME))/g' sdk/template/icon.txt > myapps/$(NAME)/icon.txt
	@echo "myapps/$(NAME) is ready: make app NAME=$(NAME), then make run"

app:
	@test -d "myapps/$(NAME)" || { echo "make app NAME=name, for a folder in myapps (make new-app NAME=name)"; exit 1; }
	$(MAKE) $(BUILD)/$(call upper,$(NAME)).BIN $(DSK) $(APPS_DSK) $(if $(wildcard myapps/$(NAME)/owndisc),$(BUILD)/$(NAME).dsk)

define add_apps
	for p in $(2); do $(IDSK) $(1) -i $$p -t 1 -c 4000 -e 4000 > /dev/null; done
endef

$(DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(SYS_APPS)
	@mkdir -p $(BUILD)
	@rm -f $(DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos -s -sl
	$(call add_packs,$(DSK))
	$(call add_apps,$(DSK),$(SYS_APPS))
	$(PYTHON) -I tools/dsk_ext.py --fit $(DSK)

$(APPS_DSK): $(DISC_APPS) $(DSK_MYAPPS) tools/dsk_ext.py
	@mkdir -p $(BUILD)
	@rm -f $@
	$(IDSK) $@ -n > /dev/null
	$(call add_apps,$@,$(DISC_APPS) $(DSK_MYAPPS))
	$(PYTHON) -I tools/dsk_ext.py --fit $@
all: $(APPS_DSK)

run: $(DSK) $(APPS_DSK)
	$(CAP32) -a 'run"vos\n' $(abspath $(DSK)) $(abspath $(APPS_DSK))

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
CALC_SHOTS := 200 420 840 960 1070 1180
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
# the program running, and opened again. Only Studio and what comes
# before it in the Launcher, so that there is room to save (the other
# test discs are full)
COSTUME_DSK := $(BUILD)/vos_costume.dsk
COSTUME_SHOTS := 400 440 600 800
COSTUME_APPS := $(BUILD)/DEMO.BIN $(BUILD)/MIXED.BIN $(BUILD)/STUDIO.BIN $(BUILD)/VBRUN.SYS
$(COSTUME_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(COSTUME_APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_costume -DTEST_SCRIPT=4
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(COSTUME_APPS))
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

# A 512K RAM expansion (TEST_SCRIPT=8, Caprice32 with 576K): STUDIO and
# CALC, which need a whole bank, run beside DEMO and PONG
EXPAND_DSK := $(BUILD)/vos_expand.dsk
EXPAND_SHOTS := 200 400 520 560 600 640 700
$(EXPAND_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_expand -DTEST_SCRIPT=8
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-expand: $(EXPAND_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(EXPAND_SHOTS); do \
	  cp $(EXPAND_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=576 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The background (TEST_SCRIPT=9, 576K): Studio's IN BACKGROUND, then
# TICKER goes on behind the Launcher and DEMO
BEHIND_DSK := $(BUILD)/vos_behind.dsk
BEHIND_SHOTS := 330 430 600 630 760 810 850 880
$(BEHIND_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_behind -DTEST_SCRIPT=9
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-behind: $(BEHIND_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(BEHIND_SHOTS); do \
	  cp $(BEHIND_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=576 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# Windows that move (TEST_SCRIPT=10): the Desktop's window, a dialog,
# the accessory, a block program's window, by their title bars
DRAG_DSK := $(BUILD)/vos_drag.dsk
DRAG_SHOTS := 145 160 222 236 405 575 590 630
$(DRAG_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_drag -DTEST_SCRIPT=10
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-drag: $(DRAG_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(DRAG_SHOTS); do \
	  cp $(DRAG_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The language packs (TEST_SCRIPT=11): Setup's LANGUAGE through each
# pack, the Desktop and the keyboard in Italian
LANGS_DSK := $(BUILD)/vos_langs.dsk
LANGS_SHOTS := 185 225 265 305 345 390 500
$(LANGS_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_langs -DTEST_SCRIPT=11
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-langs: $(LANGS_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(LANGS_SHOTS); do \
	  cp $(LANGS_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# MINES (TEST_SCRIPT=12): a Studio program, cells clicked
MINES_DSK := $(BUILD)/vos_mines.dsk
MINES_SHOTS := 330 400 470 540 600 660
$(MINES_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_mines -DTEST_SCRIPT=12
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-mines: $(MINES_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(MINES_SHOTS); do \
	  cp $(MINES_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# BRICKS (TEST_SCRIPT=14): a block game, run from the Launcher
BRICKS_DSK := $(BUILD)/vos_bricks.dsk
BRICKS_SHOTS := 340 760 1100 1250 1400 1600
$(BRICKS_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_bricks -DTEST_SCRIPT=14
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-bricks: $(BRICKS_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(BRICKS_SHOTS); do \
	  cp $(BRICKS_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The SDK's template (TEST_SCRIPT=15): built as TEMPLATE.BIN, as
# make new-app would make it, last on the test disc
$(BUILD)/sdk_test/template.asm $(BUILD)/sdk_test/texts.txt $(BUILD)/sdk_test/icon.txt &: sdk/template/app.asm sdk/template/texts.txt sdk/template/icon.txt
	@mkdir -p $(BUILD)/sdk_test
	sed 's/APPNAME/TEMPLATE/g; s/appname/template/g' sdk/template/app.asm > $(BUILD)/sdk_test/template.asm
	sed 's/APPNAME/TEMPLATE/g' sdk/template/texts.txt > $(BUILD)/sdk_test/texts.txt
	sed 's/APPNAME/TEMPLATE/g' sdk/template/icon.txt > $(BUILD)/sdk_test/icon.txt
$(eval $(call myapp_rule,$(BUILD)/sdk_test,template))

SDK_DSK := $(BUILD)/vos_sdk.dsk
SDK_SHOTS := 250 330 370 400 470
$(SDK_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/TEMPLATE.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_sdk -DTEST_SCRIPT=15
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/TEMPLATE.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-sdk: $(SDK_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(SDK_SHOTS); do \
	  cp $(SDK_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# VROUVES (TEST_SCRIPT=16): myapps/vrouves from its own disc,
# build/vrouves.dsk, in drive B:, run from the Launcher (TAB)
VROUVES_DSK := $(BUILD)/vos_vrouves.dsk
VROUVES_SHOTS := 150 200 280 470 700
$(VROUVES_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_vrouves -DTEST_SCRIPT=16
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-vrouves: $(VROUVES_DSK) $(BUILD)/vrouves.dsk
	rm -rf $(BUILD)/shots
	for d in $(VROUVES_SHOTS); do \
	  cp $(VROUVES_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/vrouves.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The two discs given out (TEST_SCRIPT=16, as test-vrouves): the system
# disc as build/vos.dsk has it, with the test keys, in A: and
# build/apps.dsk in B:: TAB shows the programs of B:, RETURN starts the
# first, PONG
APPS_TEST_DSK := $(BUILD)/vos_apps.dsk
APPS_SHOTS := 200 280
$(APPS_TEST_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(SYS_APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_apps -DTEST_SCRIPT=16
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(SYS_APPS))
	$(PYTHON) -I tools/dsk_ext.py --fit $@

# The demo for the videos (tools/video): V-OS built with -DDEMO plays
# DEMO.KEY (tools/video/demo.py) by itself (kernel/demo.asm), with a
# RAM expansion. build/demo_sys.dsk has the system and ENGLISH.MSG;
# tools/video/record.py adds a language, DEMO.KEY and the programs, all
# on A: (CPCEMU 2.5 for Linux has no drive B:), records it in CPCEMU
# (576K, M4) and puts the captions on.
#   make demo-sys linux; tools/video/record.py en (el fr es de it)
DEMO_SYS := $(BUILD)/demo_sys.dsk
$(BUILD)/DEMO1.KEY $(BUILD)/DEMO2.KEY $(BUILD)/demo_captions.json &: tools/video/demo.py
	@mkdir -p $(BUILD)
	$(PYTHON) -I tools/video/demo.py $(BUILD)/DEMO.KEY $(BUILD)/demo_captions.json
$(DEMO_SYS): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_demo -DDEMO=1
	mv $(DSK) $@
	$(IDSK) $@ -i $(BUILD)/ENGLISH.MSG -t 1 -c 8000 -e 8000 > /dev/null
demo-sys: $(DEMO_SYS) $(BUILD)/DEMO1.KEY $(APPS) $(MYAPP_BINS)

test-apps: $(APPS_TEST_DSK) $(APPS_DSK)
	rm -rf $(BUILD)/shots
	for d in $(APPS_SHOTS); do \
	  cp $(APPS_TEST_DSK) $(BUILD)/vos_run.dsk; cp $(APPS_DSK) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# MUSIC (TEST_SCRIPT=20): myapps/music from build/music.dsk in drive B:
MUSIC_DSK := $(BUILD)/vos_music.dsk
MUSIC_SHOTS := 300 380 450 520
$(MUSIC_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_music -DTEST_SCRIPT=20
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-music: $(MUSIC_DSK) $(BUILD)/music.dsk
	rm -rf $(BUILD)/shots
	for d in $(MUSIC_SHOTS); do \
	  cp $(MUSIC_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/music.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# READER (TEST_SCRIPT=26): myapps/reader from build/reader.dsk in B:
READER_DSK := $(BUILD)/vos_reader.dsk
READER_SHOTS := 290 330 380 470 600 760
$(READER_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_reader -DTEST_SCRIPT=26
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-reader: $(READER_DSK) $(BUILD)/reader.dsk
	rm -rf $(BUILD)/shots
	for d in $(READER_SHOTS); do \
	  cp $(READER_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/reader.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# READER with a page in UTF-8 (as test-reader): INDEX.MD in Greek,
# French, Spanish, German and Italian, as a PC writes it
test-reader-utf8: $(READER_DSK) $(BUILD)/reader.dsk tools/voscs.py
	rm -rf $(BUILD)/shots
	cp $(BUILD)/reader.dsk $(BUILD)/reader_utf8.dsk
	$(PYTHON) -I -c "open('$(BUILD)/INDEX.MD', 'wb').write('# ΚΑΛΩΣ ΗΡΘΑΤΕ, BIENVENUE\r\n\r\nΜια σελίδα σε **UTF-8**, όπως τη γράφει ένα PC: ελληνικά, français (à bientôt, ça va?), español (¿qué tal, niño?), Deutsch (Grüße aus Köln) und italiano (è così).\r\n\r\n- “Εισαγωγικά” – παύλες — € £ °\r\n'.encode('utf-8'))"
	iDSK $(BUILD)/reader_utf8.dsk -r INDEX.MD > /dev/null
	iDSK $(BUILD)/reader_utf8.dsk -i $(BUILD)/INDEX.MD -t 0 > /dev/null
	for d in 290; do \
	  cp $(READER_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/reader_utf8.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The UTF-8 code of VX_UTF8 (src/kernel/utf8.asm; tools/utf8_check.py, a
# Z80 emulator): texts in
# many languages, in pieces of every size, against tools/voscs.py
test-utf8:
	@mkdir -p $(BUILD)/utf8_test
	printf '        org #4000\n        include "kernel/utf8.asm"\n' > $(BUILD)/utf8_test/t.asm
	$(RASM) $(BUILD)/utf8_test/t.asm -I src -I src/kernel -o $(BUILD)/utf8_test/t -s > $(BUILD)/utf8_test/rasm.log
	$(PYTHON) tools/utf8_check.py $(BUILD)/utf8_test/t.bin $(BUILD)/utf8_test/t.sym

# WEBGET and the M4 board (TEST_SCRIPT=25), in CPCEMU for Linux (the
# package of make linux, with its M4), by hand: it needs a screen and the
# internet. When WEBGET says SAVED, close CPCEMU with F12; it writes the
# disc then, and the downloaded file is looked for on it.
WEBGET_DSK := $(BUILD)/vos_webget.dsk
$(WEBGET_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/WEBGET.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_webget -DTEST_SCRIPT=25
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	printf '10 RUN"VOS"\r\n\032' > $(BUILD)/DISC.BAS
	iDSK $@ -i $(BUILD)/DISC.BAS -t 0 > /dev/null
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/WEBGET.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-webget: $(WEBGET_DSK)
	@test -x $(BUILD)/linux/V-OS/cpcemu/cpcemu || { echo "make linux first"; exit 1; }
	cp $(WEBGET_DSK) $(BUILD)/linux/V-OS/cpcemu/DISC/VOS.DSK
	-cd $(BUILD)/linux/V-OS/cpcemu && ./cpcemu -c vos.cfg -t 2 > /dev/null 2>&1
	iDSK $(BUILD)/linux/V-OS/cpcemu/DISC/VOS.DSK -l | grep -i "INDEX" || { echo "test-webget: no INDEX.HTM on the disc"; exit 1; }

# The clipboard (TEST_SCRIPT=24): A: with NOTEPAD.BIN, B: as test-open
CLIP_DSK := $(BUILD)/vos_clip.dsk
CLIP_SHOTS := 320 380 400 430 460 490 560 700
$(CLIP_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_clip -DTEST_SCRIPT=24
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-clip: $(CLIP_DSK) $(BUILD)/markdown.dsk $(BUILD)/NOTEPAD.BIN
	rm -rf $(BUILD)/shots
	printf 'HELLO FROM THE COMMANDER.\r\nRETURN OPENED THIS IN NOTEPAD.\r\n' > $(BUILD)/HELLO.TXT
	cp $(BUILD)/markdown.dsk $(BUILD)/vos_clip_b.dsk
	iDSK $(BUILD)/vos_clip_b.dsk -i $(BUILD)/HELLO.TXT -t 0 > /dev/null
	for d in $(CLIP_SHOTS); do \
	  cp $(CLIP_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/vos_clip_b.dsk $(BUILD)/vos_run_b.dsk; \
	  iDSK $(BUILD)/vos_run.dsk -i $(BUILD)/NOTEPAD.BIN -t 1 -c 4000 -e 4000 > /dev/null; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# SYSINFO and VOS_EXT (TEST_SCRIPT=23): SYSINFO.BIN added last on A:.
# make test-sysinfo SYSINFO_RAM=576: with a 512K expansion
SYSINFO_DSK := $(BUILD)/vos_sysinfo.dsk
SYSINFO_SHOTS := 290 330 360 440
SYSINFO_RAM := 128
$(SYSINFO_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_sysinfo -DTEST_SCRIPT=23
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-sysinfo: $(SYSINFO_DSK) $(BUILD)/markdown.dsk $(BUILD)/SYSINFO.BIN
	rm -rf $(BUILD)/shots
	for d in $(SYSINFO_SHOTS); do \
	  cp $(SYSINFO_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/markdown.dsk $(BUILD)/vos_run_b.dsk; \
	  iDSK $(BUILD)/vos_run.dsk -i $(BUILD)/SYSINFO.BIN -t 1 -c 4000 -e 4000 > /dev/null; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=$(SYSINFO_RAM) VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The STYLE block (TEST_SCRIPT=23, as test-sysinfo): STYLES.VBN, from
# blocks/examples/styles.vbt, last on A:, run from the Commander
$(BUILD)/STYLES.VBN $(BUILD)/STYLES.VBS &: blocks/examples/styles.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/STYLES.VBS $(BUILD)/VBRUN.SYS $(BUILD)/STYLES.VBN

STYLES_SHOTS := 330
test-styles: $(SYSINFO_DSK) $(BUILD)/markdown.dsk $(BUILD)/STYLES.VBN
	rm -rf $(BUILD)/shots
	for d in $(STYLES_SHOTS); do \
	  cp $(SYSINFO_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/markdown.dsk $(BUILD)/vos_run_b.dsk; \
	  iDSK $(BUILD)/vos_run.dsk -i $(BUILD)/STYLES.VBN -t 1 -c 4000 -e 4000 > /dev/null; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The MUSIC block (TEST_SCRIPT=27, 576K): TUNE.VBN (blocks/examples/
# tune.vbt) and AGANAMEM.MUS last on A:, MUSIC.BIN on B: (music.dsk)
$(BUILD)/TUNE.VBN $(BUILD)/TUNE.VBS &: blocks/examples/tune.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/TUNE.VBS $(BUILD)/VBRUN.SYS $(BUILD)/TUNE.VBN

MBLOCK_DSK := $(BUILD)/vos_mblock.dsk
MBLOCK_SHOTS := 380 520 600 680
MBLOCK_RAM := 576
$(MBLOCK_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/TUNE.VBN $(BUILD)/music.dsk
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_mblock -DTEST_SCRIPT=27
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS))
	$(call add_apps,$@,myapps/music/owndisc/AGANAMEM.MUS $(BUILD)/TUNE.VBN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-music-block: $(MBLOCK_DSK) $(BUILD)/music.dsk
	rm -rf $(BUILD)/shots
	for d in $(MBLOCK_SHOTS); do \
	  cp $(MBLOCK_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/music.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=$(MBLOCK_RAM) VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# Files opened by type (TEST_SCRIPT=22): A: with NOTEPAD.BIN only (the
# other programs would push it past block 179); B: is markdown.dsk with a text
OPEN_DSK := $(BUILD)/vos_open.dsk
OPEN_SHOTS := 215 235 330 370 400
$(OPEN_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(BUILD)/NOTEPAD.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_open -DTEST_SCRIPT=22
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(BUILD)/NOTEPAD.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-open: $(OPEN_DSK) $(BUILD)/markdown.dsk $(BUILD)/NOTEPAD.BIN
	rm -rf $(BUILD)/shots
	printf 'HELLO FROM THE COMMANDER.\r\nRETURN OPENED THIS IN NOTEPAD.\r\n' > $(BUILD)/HELLO.TXT
	cp $(BUILD)/markdown.dsk $(BUILD)/vos_open_b.dsk
	iDSK $(BUILD)/vos_open_b.dsk -i $(BUILD)/HELLO.TXT -t 0 > /dev/null
	for d in $(OPEN_SHOTS); do \
	  cp $(OPEN_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/vos_open_b.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The V-OS character set (as test-open): HELLO.TXT in Greek, French,
# Spanish, German and Italian together, written in UTF-8 as on a PC,
# opened in NOTEPAD with the English texts: into the V-OS set
# (VX_UTF8); check the letters in the last shot
CHARSET_SHOTS := 400
test-charset: $(OPEN_DSK) $(BUILD)/markdown.dsk $(BUILD)/NOTEPAD.BIN tools/voscs.py
	rm -rf $(BUILD)/shots
	$(PYTHON) -I -c "import sys; sys.path.insert(0, 'tools'); import voscs; \
	  open('$(BUILD)/HELLO.TXT', 'wb').write(('ΕΛΛΗΝΙΚΑ: ΓΕΙΑ ΣΟΥ, ΚΟΣΜΕ! άέήίόύώ ϊϋΐΰ\r\nFRANÇAIS: À BIENTÔT, ÇA VA? être élève\r\nESPAÑOL: ¿QUÉ TAL? ¡OLÉ! niño\r\nDEUTSCH: GRÜßE AUS KÖLN. Straße\r\nITALIANO: È COSÌ, PERCHÉ? città\r\n£ € § ° « » ´ µ\r\n' * 3).encode('utf-8'))"
	cp $(BUILD)/markdown.dsk $(BUILD)/vos_open_b.dsk
	iDSK $(BUILD)/vos_open_b.dsk -i $(BUILD)/HELLO.TXT -t 0 > /dev/null
	for d in $(CHARSET_SHOTS); do \
	  cp $(OPEN_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/vos_open_b.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# Data banks of their own (TEST_SCRIPT=28, 576K): NOTEPAD with a 15K
# BIG.TXT from B: down past its window, MARKDOWN meanwhile, then
# NOTEPAD back up to its start
DATA_DSK := $(BUILD)/vos_data.dsk
DATA_SHOTS := 550 720 860 1220
$(DATA_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_data -DTEST_SCRIPT=28
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-data: $(DATA_DSK) $(BUILD)/markdown.dsk $(BUILD)/NOTEPAD.BIN
	rm -rf $(BUILD)/shots
	$(PYTHON) -I -c 'import sys; sys.stdout.buffer.write(b"".join(b"LINE %04d: THE QUICK BROWN FOX JUMPS OVER THE DOG\r\n" % i for i in range(300)))' > $(BUILD)/BIG.TXT
	cp $(BUILD)/markdown.dsk $(BUILD)/vos_data_b.dsk
	iDSK $(BUILD)/vos_data_b.dsk -i $(BUILD)/BIG.TXT -t 0 > /dev/null
	for d in $(DATA_SHOTS); do \
	  cp $(DATA_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/vos_data_b.dsk $(BUILD)/vos_run_b.dsk; \
	  iDSK $(BUILD)/vos_run.dsk -i $(BUILD)/NOTEPAD.BIN -t 1 -c 4000 -e 4000 > /dev/null; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=576 VOS_TIMEOUT=90 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The database engine (tools/db_check.py, a Z80 emulator): src/db/db.asm
# built alone (-DDB_HARNESS), with 4 cache pages (as in V-OS) and 2
test-db:
	@mkdir -p $(BUILD)/db_test
	for n in 4 2; do \
	  $(RASM) src/db/db.asm -I src -DDB_HARNESS=1 -DDB_SLOTS=$$n -o $(BUILD)/db_test/db$$n -s > $(BUILD)/db_test/rasm.log || exit 1; \
	  $(PYTHON) tools/db_check.py $(BUILD)/db_test/db$$n.bin $(BUILD)/db_test/db$$n.sym 4000 || exit 1; \
	done

# The formula engine (tools/calc_check.py, a Z80 emulator): src/calc/
# calc.asm built alone (-DCALC_HARNESS), checked against a model
test-calc-sys:
	@mkdir -p $(BUILD)/calc_test
	$(RASM) src/calc/calc.asm -I src -DCALC_HARNESS=1 -o $(BUILD)/calc_test/calc -s > $(BUILD)/calc_test/rasm.log
	for s in 1 2; do $(PYTHON) tools/calc_check.py $(BUILD)/calc_test/calc.bin $(BUILD)/calc_test/calc.sym 20000 $$s || exit 1; done

# DB.SYS with the kernel's own file system (tools/db_disc_check.py, a
# Z80 emulator, the floppy controller on a DSK image): STREETS.VDB on B:
DB_DISC := $(BUILD)/db_disc
test-db-disc: $(DSK) $(BUILD)/streets.dsk
	@rm -rf $(DB_DISC) && mkdir -p $(DB_DISC)
	cd $(DB_DISC) && iDSK $(abspath $(DSK)) -g VOS.BIN > /dev/null && iDSK $(abspath $(DSK)) -g DB.SYS > /dev/null
	cp $(BUILD)/streets.dsk $(DB_DISC)/b.dsk
	$(PYTHON) tools/db_disc_check.py $(DB_DISC)/VOS.BIN $(DB_DISC)/DB.SYS $(BUILD)/vos.sym $(DB_DISC)/b.dsk 600

# DATABASE in a Z80 emulator (tools/database_check.py): the V-OS calls
# stubbed, VX_DB a model of the engine; the screen read back as text
test-database-z80: $(BUILD)/DATABASE.BIN
	$(RASM) myapps/database/database.asm -I src -I $(BUILD)/myapp_database -I myapps/database -o $(BUILD)/myapp_database/check -s > $(BUILD)/myapp_database/check.log
	$(PYTHON) tools/database_check.py $(BUILD)/myapp_database/check.bin $(BUILD)/myapp_database/check.sym

# SHEET in a Z80 emulator (tools/sheet_check.py): the V-OS calls
# stubbed, VX_CALC CALC.SYS itself in a second emulator
test-sheet-z80: $(BUILD)/SHEET.BIN
	@mkdir -p $(BUILD)/calc_test
	$(RASM) src/calc/calc.asm -I src -DCALC_HARNESS=1 -o $(BUILD)/calc_test/calc -s > $(BUILD)/calc_test/rasm.log
	$(RASM) myapps/sheet/sheet.asm -I src -I $(BUILD)/myapp_sheet -I myapps/sheet -o $(BUILD)/myapp_sheet/check -s > $(BUILD)/myapp_sheet/check.log
	$(PYTHON) tools/sheet_check.py $(BUILD)/myapp_sheet/check.bin $(BUILD)/myapp_sheet/check.sym $(BUILD)/calc_test/calc.bin $(BUILD)/calc_test/calc.sym

# DATABASE (TEST_SCRIPT=31): a database made on B:, a table, records
# added in the form, the list in key order, FIND, a change saved
DATABASE_DSK := $(BUILD)/vos_database.dsk
DATABASE_SHOTS := 1250 3450 3800 4400
$(DATABASE_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/DATABASE.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_database -DTEST_SCRIPT=31
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/DATABASE.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-database: $(DATABASE_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(DATABASE_SHOTS); do \
	  cp $(DATABASE_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_TIMEOUT=60 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# SHEET (TEST_SCRIPT=32): numbers and a formula typed, worked out by
# CALC.SYS from A:, the sheet saved as B:T.VSH
SHEET_DSK := $(BUILD)/vos_sheet.dsk
SHEET_SHOTS := 1600 4500 5600
$(SHEET_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/SHEET.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_sheet -DTEST_SCRIPT=32
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/SHEET.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-sheet: $(SHEET_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(SHEET_SHOTS); do \
	  cp $(SHEET_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_TIMEOUT=60 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The keyboards of all the packs (TEST_SCRIPT=30): Setup's KEYBOARDS,
# then NOTEPAD with each keyboard in turn (CONTROL+SHIFT)
KBDS_DSK := $(BUILD)/vos_kbds.dsk
KBDS_SHOTS := 200 230 520 700
$(KBDS_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/NOTEPAD.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_kbds -DTEST_SCRIPT=30
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(BUILD)/NOTEPAD.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-kbds: $(KBDS_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(KBDS_SHOTS); do \
	  cp $(KBDS_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# STREETS (TEST_SCRIPT=29): myapps/streets from build/streets.dsk in B:
STREETS_DSK := $(BUILD)/vos_streets.dsk
STREETS_SHOTS := 400 560 800 840 1260
$(STREETS_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_streets -DTEST_SCRIPT=29
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-streets: $(STREETS_DSK) $(BUILD)/streets.dsk
	rm -rf $(BUILD)/shots
	for d in $(STREETS_SHOTS); do \
	  cp $(STREETS_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/streets.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_TIMEOUT=60 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The dark theme (TEST_SCRIPT=38): A:SETUP.CFG with THEME DARK; the
# Desktop, the Launcher, the Commander and a menu, Setup, then LIGHT
THEME_DSK := $(BUILD)/vos_theme.dsk
THEME_SHOTS := 90 150 240 330 420 560 760 1100
$(THEME_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_theme -DTEST_SCRIPT=38
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	printf 'VCFG\004\000\000\031\003\001\001\001\000\000\001' > $(BUILD)/SETUP.CFG
	$(IDSK) $@ -i $(BUILD)/SETUP.CFG -t 1 > /dev/null
	$(PYTHON) -I tools/dsk_ext.py $@

test-theme: $(THEME_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(THEME_SHOTS); do \
	  cp $(THEME_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_TIMEOUT=90 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The Desktop's window (TEST_SCRIPT=40): closed at first, TAB, its X,
# a drive icon, the corner that sizes it, its scroll bar
WINDOW_DSK := $(BUILD)/vos_window.dsk
WINDOW_SHOTS := 95 110 170 260 330 480 760
$(WINDOW_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_window -DTEST_SCRIPT=40
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(PYTHON) -I tools/dsk_ext.py $@

test-window: $(WINDOW_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(WINDOW_SHOTS); do \
	  cp $(WINDOW_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_TIMEOUT=90 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The desk's picture (TEST_SCRIPT=39, 576K): Setup's BACKGROUND chooses
# A:TEST.SCR (tools/mk_test_scr.py, as PAINT saves one), the Desktop
# shows it; WALL_RAM=128: NEEDS A MEMORY EXPANSION
WALL_DSK := $(BUILD)/vos_wall.dsk
WALL_SHOTS := 200 330 450 600 800
WALL_RAM ?= 576
$(WALL_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) tools/mk_test_scr.py
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_wall -DTEST_SCRIPT=39
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(PYTHON) -I tools/mk_test_scr.py $(BUILD)/TEST.SCR
	$(IDSK) $@ -i $(BUILD)/TEST.SCR -t 1 -c C000 -e C000 > /dev/null
	$(PYTHON) -I tools/dsk_ext.py $@

test-wall: $(WALL_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(WALL_SHOTS); do \
	  cp $(WALL_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=$(WALL_RAM) VOS_TIMEOUT=90 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# NOTEPAD's text window (tools/notepad_check.py, a Z80 emulator): a 12K
# file moved through and edited, with a data bank of its own and on a
# 6128, a 16K text typed, and SAVE
test-notepad-big: $(BUILD)/NOTEPAD.BIN
	@mkdir -p $(SCR_TEST)
	$(RASM) myapps/notepad/notepad.asm -I src -I $(BUILD)/myapp_notepad -I myapps/notepad -o $(SCR_TEST)/notepad -s > $(SCR_TEST)/rasm.log
	$(PYTHON) tools/notepad_check.py $(SCR_TEST)/notepad.bin $(SCR_TEST)/notepad.sym

# MARKDOWN (TEST_SCRIPT=21): myapps/markdown from build/markdown.dsk in B:
MARKDOWN_DSK := $(BUILD)/vos_markdown.dsk
MARKDOWN_SHOTS := 300 380 430 530 700 900
$(MARKDOWN_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_markdown -DTEST_SCRIPT=21
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-markdown: $(MARKDOWN_DSK) $(BUILD)/markdown.dsk
	rm -rf $(BUILD)/shots
	for d in $(MARKDOWN_SHOTS); do \
	  cp $(MARKDOWN_DSK) $(BUILD)/vos_run.dsk; cp $(BUILD)/markdown.dsk $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# V-OS's About dialog (TEST_SCRIPT=19)
ABOUT_DSK := $(BUILD)/vos_about.dsk
ABOUT_SHOTS := 200 260
$(ABOUT_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_about -DTEST_SCRIPT=19
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-about: $(ABOUT_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(ABOUT_SHOTS); do \
	  cp $(ABOUT_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# PAINT (TEST_SCRIPT=18): myapps/paint, last on the test disc
PAINT_DSK := $(BUILD)/vos_paint.dsk
PAINT_SHOTS := 260 330 380 430 480
$(PAINT_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/PAINT.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_paint -DTEST_SCRIPT=18
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/PAINT.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-paint: $(PAINT_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(PAINT_SHOTS); do \
	  cp $(PAINT_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The M4 board's SD card in the 1984 emulator for Windows (tools/
# m4_shot.sh, VOS_1984): the Desktop on DISK, a copy to A:, folders,
# NOTEPAD run from the card (TEST_SCRIPT=34, build/shots/NNNN.png); the
# Commander and the Launcher on DISK (35, build/shots/v-NNNN.png);
# NOTEPAD's OPEN and SAVE on DISK (36, build/shots/o-NNNN.png, then the
# card's HELLO.TXT checked); STREETS makes its database on DISK (37,
# a card with STREETS.BIN only, build/shots/d-NNNN.png, then the card's
# STREETS.VDB checked). M4.SYS
# is on these discs only.
M4_DSK := $(BUILD)/vos_m4.dsk
M4V_DSK := $(BUILD)/vos_m4v.dsk
M4O_DSK := $(BUILD)/vos_m4o.dsk
M4D_DSK := $(BUILD)/vos_m4d.dsk
M4_SHOTS = 900 1200 1500 1800 2050 2300 2500 2700
M4V_SHOTS = 500 900 1200 1500 1800 2100 2400
M4O_SHOTS = 900 1250 1400 1800 2700 3000 3500
M4D_SHOTS = 1100 1800 2400
$(BUILD)/vos_m4%.dsk: $(SOURCES) $(LANG_KERNEL) $(PACKS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(basename $@) \
	  -DTEST_SCRIPT=$(if $(findstring m4v,$@),35,$(if $(findstring m4o,$@),36,$(if $(findstring m4d,$@),37,34))) -s
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(PYTHON) -I tools/dsk_ext.py $@

test-m4: $(M4_DSK) $(M4V_DSK) $(M4O_DSK) $(M4D_DSK) $(BUILD)/NOTEPAD.BIN $(BUILD)/STREETS.BIN
	rm -rf $(BUILD)/shots
	for d in $(M4_SHOTS); do \
	  cp $(M4_DSK) $(BUILD)/vos_run.dsk; bash tools/m4_shot.sh $$d; \
	done
	for d in $(M4V_SHOTS); do \
	  cp $(M4V_DSK) $(BUILD)/vos_run.dsk; \
	  M4_SYM=$(BUILD)/vos_m4v.sym M4_SHOT=v-$$d bash tools/m4_shot.sh $$d; \
	done
	for d in $(M4O_SHOTS); do \
	  cp $(M4O_DSK) $(BUILD)/vos_run.dsk; \
	  M4_SYM=$(BUILD)/vos_m4o.sym M4_SHOT=o-$$d bash tools/m4_shot.sh $$d; \
	done
	grep -aq "xHello from the SD card" $(BUILD)/m4run/HELLO.TXT
	for d in $(M4D_SHOTS); do \
	  cp $(M4D_DSK) $(BUILD)/vos_run.dsk; \
	  M4_CARD=db M4_SYM=$(BUILD)/vos_m4d.sym M4_SHOT=d-$$d bash tools/m4_shot.sh $$d; \
	done
	$(PYTHON) -I tools/vdb.py check $(BUILD)/m4run/STREETS.VDB

# PAINT on the whole screen (TEST_SCRIPT=33, 576K: a data bank of its
# own): lines, the window moved by its bars, saved as B:NONAME.SCR and
# opened again
PAINTB_DSK := $(BUILD)/vos_paint_big.dsk
PAINTB_SHOTS := 300 380 430 520 800 880 950
$(PAINTB_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/PAINT.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_paint_big -DTEST_SCRIPT=33
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(TEST_APPS) $(BUILD)/PAINT.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-paint-big: $(PAINTB_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(PAINTB_SHOTS); do \
	  cp $(PAINTB_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_RAM=576 VOS_TIMEOUT=90 VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# EXPORT .SCR: PAINT's export code makes PICTURE.SCR in a Z80 emulator
# (pip package z80, so not python -I), BASIC loads it in Caprice32 with
# the inks from &C7D0, and the screenshot is checked pixel by pixel.
SCR_TEST := $(BUILD)/scr_test
test-scr: $(BUILD)/PAINT.BIN
	@mkdir -p $(SCR_TEST)
	$(RASM) myapps/paint/paint.asm -I src -I $(BUILD)/myapp_paint -I myapps/paint -o $(SCR_TEST)/paint -s > $(SCR_TEST)/rasm.log
	$(PYTHON) tools/scr_check.py make $(SCR_TEST)/paint.bin $(SCR_TEST)/paint.sym $(SCR_TEST)/PICTURE.SCR
	rm -rf $(SCR_TEST)/scr.dsk $(SCR_TEST)/shots
	iDSK $(SCR_TEST)/scr.dsk -n > /dev/null
	iDSK $(SCR_TEST)/scr.dsk -i $(SCR_TEST)/PICTURE.SCR -t 1 -c C000 -e C000 > /dev/null
	snap run --shell caprice32.launcher -c "bash $(abspath tools/cap32_scr_check.sh) $(abspath $(SCR_TEST))/scr.dsk $(abspath $(SCR_TEST))/shots"
	$(PYTHON) tools/scr_check.py check $(SCR_TEST)/shots/*.png

# NOTEPAD (TEST_SCRIPT=17): myapps/notepad, last on the test disc
NOTEPAD_DSK := $(BUILD)/vos_notepad.dsk
NOTEPAD_SHOTS := 330 430 480 510 600 2100
$(NOTEPAD_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/NOTEPAD.BIN
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_notepad -DTEST_SCRIPT=17
	mv $(TEST_DSK) $@
	$(call add_test_packs,$@)
	$(call add_apps,$@,$(BUILD)/NOTEPAD.BIN)
	$(PYTHON) -I tools/dsk_ext.py $@

test-notepad: $(NOTEPAD_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(NOTEPAD_SHOTS); do \
	  cp $(NOTEPAD_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  VOS_TIMEOUT=60 snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# Studio's 128 variables (TEST_SCRIPT=13): VARS.VBS, on the test disc
# only, opened in Studio and run
$(BUILD)/VARS.VBN $(BUILD)/VARS.VBS &: blocks/examples/vars.vbt tools/mkvbs.py apps/studio/blocks.txt $(BUILD)/VBRUN.SYS
	$(PYTHON) -I tools/mkvbs.py $< $(BUILD)/VARS.VBS $(BUILD)/VBRUN.SYS $(BUILD)/VARS.VBN
VARS_DSK := $(BUILD)/vos_vars.dsk
VARS_SHOTS := 350 480 600
$(VARS_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS) $(BUILD)/VARS.VBS
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_vars -DTEST_SCRIPT=13
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS) $(BUILD)/VARS.VBS)
	$(PYTHON) -I tools/dsk_ext.py $@

test-vars: $(VARS_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(VARS_SHOTS); do \
	  cp $(VARS_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
	  snap run --shell caprice32.launcher -c "VOS_SHOTS=$(abspath $(BUILD))/shots/$$d VOS_DSK=$(abspath $(BUILD))/vos_run.dsk VOS_DSK_B=$(abspath $(BUILD))/vos_run_b.dsk bash $(abspath tools/cap32_shot.sh) $$d"; \
	done
	ls $(BUILD)/shots/*/*.png

# The program switcher (TEST_SCRIPT=7): F6 with no program, then with
# DEMO and PONG, and PROGRAMS in the Commander's VIEW menu
SWITCH_DSK := $(BUILD)/vos_switch.dsk
SWITCH_SHOTS := 115 420 480 550 795 860 1000
$(SWITCH_DSK): $(SOURCES) $(LANG_KERNEL) $(PACKS) $(APPS)
	@mkdir -p $(BUILD)
	@rm -f $@ $(TEST_DSK)
	$(RASM) src/vos.asm -o $(BUILD)/vos_switch -DTEST_SCRIPT=7
	mv $(TEST_DSK) $@
	$(call add_packs,$@)
	$(call add_apps,$@,$(APPS))
	$(PYTHON) -I tools/dsk_ext.py $@

test-switch: $(SWITCH_DSK) $(TEST_DSK_B)
	rm -rf $(BUILD)/shots
	for d in $(SWITCH_SHOTS); do \
	  cp $(SWITCH_DSK) $(BUILD)/vos_run.dsk; cp $(TEST_DSK_B) $(BUILD)/vos_run_b.dsk; \
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
