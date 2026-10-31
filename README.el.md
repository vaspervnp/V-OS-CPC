# V-OS

Γραφικό λειτουργικό σύστημα για τον Amstrad CPC 6128, γραμμένο σε Z80 assembly.

*In English: [README.md](README.md).*

- **Τεκμηρίωση** (χρήση, Studio, SDK, ανάπτυξη): [docs/manual/](docs/manual/00-index.md), και ως PDF στο [docs/V-OS.pdf](docs/V-OS.pdf) (`make docs`)
- **Manual** in English, Français, Español, Deutsch, Italiano: [docs/manual/en/](docs/manual/en/00-index.md), [fr](docs/manual/fr/00-index.md), [es](docs/manual/es/00-index.md), [de](docs/manual/de/00-index.md), [it](docs/manual/it/00-index.md); PDFs: `docs/V-OS-<en|fr|es|de|it>.pdf`
- **Milestones**, με ό,τι ελέγχθηκε σε καθένα: [MILESTONES.el.md](MILESTONES.el.md)
- Τι απαιτείται και τι έχει αποφασιστεί: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)
- Πρότυπα interface: [docs/interface-templates.html](docs/interface-templates.html)

## Build

Απαιτούνται [RASM](https://github.com/EdouardBERGE/rasm), [iDSK](https://github.com/cpcsdk/idsk), Python 3 και GNU make (4.3 ή νεότερο). Για δοκιμή χρειάζεται ο Caprice32 (snap).

```bash
make          # build/vos.dsk
make run      # εκκίνηση στον Caprice32 με RUN"VOS"
make shot     # εκκίνηση χωρίς παράθυρο και screenshot
make test-input  # σενάριο πλήκτρων με δισκέτες στα A: και B:, screenshots στο build/shots/<καθυστέρηση>
make test-calc   # η αριθμομηχανή CALC (mode 1) με κλικ στα κουμπιά, μετά το CALC.VBS στο Studio
make test-costume # κοστούμι στο Studio: σχεδίαση, ΕΚΤΕΛΕΣΗ, άνοιγμα ξανά
make test-acc    # το ΡΟΛΟΙ ως desk accessory, πάνω από τον Launcher και το Studio
make test-multi  # DEMO και PONG μαζί: το καθένα συνεχίζει από εκεί που ήταν
make test-switch # F6: η λίστα των προγραμμάτων που τρέχουν, και από το μενού VIEW
make test-expand # με επέκταση 512K: STUDIO και CALC δίπλα στα DEMO και PONG
make test-behind # το ΣΤΟ ΠΑΡΑΣΚΗΝΙΟ του Studio, και το TICKER που μετρά πίσω από τον Launcher και το DEMO
make test-drag   # σύρσιμο: το ΑΡΧΕΙΑ, ένας διάλογος, το ΡΟΛΟΙ και το παράθυρο του CALC
make test-mines  # το MINES: κλικ σε κάθε κελί ώσπου να βρεθεί νάρκη, μετά NEW
make test-bricks # το BRICKS: η ρακέτα κινείται, τούβλα σπάνε, GAME OVER, και SPACE για νέο παιχνίδι
make test-vars   # οι 128 μεταβλητές και τα SAVE/LOAD VARS: το VARS.VBS ανοίγει στο Studio, αλλάζει και τρέχει
make test-langs  # η ΓΛΩΣΣΑ του Setup σε όλες τις γλώσσες, και το Desktop και το πληκτρολόγιο στα ιταλικά
make test-lang   # Αγγλικά στην εκκίνηση, Ελληνικά αποθηκευμένα στο Setup, μετά RUN"VOS" ξανά
make test-amsdos # το ίδιο σενάριο, μετά η AMSDOS στη BASIC διαβάζει τα αρχεία του V-OS
make test-reboot # το ίδιο, μετά RUN"VOS" ξανά με το SETUP.CFG που αποθηκεύτηκε
make test-system # το σενάριο με το A: σε μορφή SYSTEM
make test-sdk    # το πρότυπο του SDK ως TEMPLATE: ανοίγει από τον Launcher, κουτί, μενού, ABOUT, BACK
make docs        # τα PDF του manual: docs/V-OS.pdf (ελληνικά) και docs/V-OS-en/fr/es/de/it.pdf
```

Δικά σου προγράμματα σε assembly, με το API του V-OS (οδηγός και λίστα κλήσεων: [sdk/README.md](sdk/README.md)):

```bash
make new-app NAME=hello   # myapps/hello από το πρότυπο του SDK
make app NAME=hello       # build/HELLO.BIN, και στη build/vos.dsk
```

Προγράμματα με blocks: άνοιξε το `blocks/editor.html` σε browser, φτιάξε το πρόγραμμα, αποθήκευσε το `.vbp` και μεταγλώττισέ το:

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

Στον CPC: `RUN"VOS"` από τη δισκέτα.

## Δομή

```
src/vos.asm          ρίζα του build: loader + kernel image, εγγραφή στο DSK
src/boot/            loader που τρέχει η AMSDOS στο #4000, ανίχνευση επέκτασης RAM
src/kernel/          vectors (#0000), είσοδος kernel, interrupts, filesystem, ext.asm (kernel extension στη bank 7)
src/drivers/         Gate Array, CRTC, πληκτρολόγιο, ποντίκι, FDC
src/ui/              μενού, κουμπιά, εστίαση, διάλογοι, επιλογή αρχείου
src/shell/           όψεις του shell ως overlays: Desktop (A), Launcher (B), Commander (C), Setup
src/api/vos_api.inc  το API για προγράμματα: διευθύνσεις, συμβάντα, πλήκτρα, μορφή αρχείου
apps/                προγράμματα για το V-OS (apps/demo: το πρώτο, apps/mixed: η μικτή οθόνη, apps/studio: ο editor blocks, apps/clock: το ρολόι, το πρώτο desk accessory, apps/icons: τα εικονίδιά τους)
blocks/              προγράμματα με blocks: editor.html (Blockly), vbc.py (μεταγλωττιστής), runtime.asm, player.asm (ο παίκτης του Studio, VBRUN.SYS στη δισκέτα), examples/
src/gfx/             γραφικά overscan, κείμενο, γραμματοσειρά (font_ascii.asm παράγεται)
src/include/         θύρες υλικού, χάρτης μνήμης
src/lang/            παραγόμενα: αριθμοί μηνυμάτων, αγγλικά κείμενα και πληκτρολόγιο
lang/                πηγές γλωσσών: en (βασική: ENGLISH.MSG και το πληκτρολόγιο του kernel), el (GREEK.LNG), fr, es, de, it (FRENCH, SPANISH, GERMAN, ITALIAN.LNG), latin1 (το κοινό font τους)
tools/               scripts: screenshot στον Caprice32, mkfont.py, mklng.py, mktexts.py, mkicon.py
docs/                manual/ (η τεκμηρίωση, ανά κεφάλαιο), V-OS.pdf, απαιτήσεις, πρότυπα
sdk/                 το SDK για προγράμματα σε assembly: οδηγός, API, template/ (πρότυπο προγράμματος)
myapps/              τα δικά σου προγράμματα (make new-app), που μπαίνουν στη build/vos.dsk
```

Τα hex στον κώδικα γράφονται με `#` (π.χ. `#C000`), γιατί η RASM διαβάζει το `&` ως AND.

## Κατάσταση

Το V-OS είναι στο **M44** (έκδοση 0.15 beta· κάθε milestone προσθέτει 0.01). Τι πρόσθεσε κάθε milestone και πώς ελέγχθηκε: [MILESTONES.el.md](MILESTONES.el.md).
