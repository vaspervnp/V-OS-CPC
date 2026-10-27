# V-OS

Γραφικό λειτουργικό σύστημα για τον Amstrad CPC 6128, γραμμένο σε Z80 assembly.

- Τι απαιτείται και τι έχει αποφασιστεί: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)
- Πρότυπα interface: [docs/interface-templates.html](docs/interface-templates.html)

## Build

Απαιτούνται [RASM](https://github.com/EdouardBERGE/rasm) και GNU make. Για δοκιμή χρειάζεται ο Caprice32 (snap).

```bash
make          # build/vos.dsk
make run      # εκκίνηση στον Caprice32 με RUN"VOS"
make shot     # εκκίνηση χωρίς παράθυρο και screenshot
```

Στον CPC: `RUN"VOS"` από τη δισκέτα.

## Δομή

```
src/vos.asm          ρίζα του build: loader + kernel image, εγγραφή στο DSK
src/boot/            loader που τρέχει η AMSDOS στο #4000
src/kernel/          vectors (#0000), είσοδος kernel, interrupts
src/drivers/         Gate Array, CRTC (και αργότερα FDC, πληκτρολόγιο, ποντίκι)
src/gfx/             γραφικά overscan, κείμενο, γραμματοσειρά (font_ascii.asm παράγεται)
src/include/         θύρες υλικού, χάρτης μνήμης
tools/               scripts: screenshot στον Caprice32, mkfont.py (γραμματοσειρά → ASM)
docs/                απαιτήσεις, πρότυπα
```

Τα hex στον κώδικα γράφονται με `#` (π.χ. `#C000`), γιατί η RASM διαβάζει το `&` ως AND.

## Κατάσταση

**M1 (οθόνη):** overscan 32K στο `#8000–#FFFF` (384×272 σε mode 1, 192×272 σε mode 0). Υπάρχουν πίνακας διευθύνσεων για τις 272 γραμμές και ρουτίνες `gfx_plot`, `gfx_fill_rect`, `gfx_cls`, `txt_char` και `txt_print`, που δουλεύουν και στα δύο modes. Η γραμματοσειρά ASCII 8×8 είναι η font8x8, public domain. Η οθόνη δοκιμής εναλλάσσει mode 1 και mode 0 κάθε 3 δευτερόλεπτα και δείχνει στον τίτλο πόσα frames πήρε η σχεδίαση: 34 σε mode 1, 39 σε mode 0, χωρίς βελτιστοποιήσεις ακόμα.

**M0 (υποδομή):** η AMSDOS φορτώνει το `VOS.BIN` στο `#4000`. Ο loader κλείνει τις ROM και μεταφέρει τον kernel στο `#0000`. Ο kernel εγκαθιστά δικό του IM 1 handler, συγχρονισμένο με το VSYNC. Η οθόνη δοκιμής του M0 (πριν την αντικαταστήσει αυτή του M1) έδειχνε:
- 4 κάθετες ζώνες με τα pens 0–3,
- 6 χρωματιστές λωρίδες στο περίγραμμα, μία για κάθε interrupt slice,
- το pen 3, που αλλάζει χρώμα κάθε δευτερόλεπτο.
