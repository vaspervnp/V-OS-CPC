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
src/include/         θύρες υλικού, χάρτης μνήμης
tools/               βοηθητικά scripts
docs/                απαιτήσεις, πρότυπα
```

Τα hex στον κώδικα γράφονται με `#` (π.χ. `#C000`), γιατί η RASM διαβάζει το `&` ως AND.

## Κατάσταση

**M0 (υποδομή):** η AMSDOS φορτώνει το `VOS.BIN` στο `#4000`. Ο loader κλείνει τις ROM και μεταφέρει τον kernel στο `#0000`. Ο kernel εγκαθιστά δικό του IM 1 handler, συγχρονισμένο με το VSYNC. Στην οθόνη δοκιμής φαίνονται:
- 4 κάθετες ζώνες με τα pens 0–3,
- 6 χρωματιστές λωρίδες στο περίγραμμα, μία για κάθε interrupt slice,
- το pen 3, που αλλάζει χρώμα κάθε δευτερόλεπτο.
