# 8. Sviluppare V-OS

Per chi lavora su V-OS stesso. I programmi *per* V-OS sono descritti nell'[SDK](../../../sdk/README.it.md).

## Cosa serve

- [RASM](https://github.com/EdouardBERGE/rasm), l'assembler
- [iDSK](https://github.com/cpcsdk/idsk), per le immagini disco
- Python 3, per gli strumenti. `make docs` ha bisogno anche di `markdown` e `pymupdf`.
- GNU make 4.3 o successivo
- per i test, Caprice32 (snap `caprice32`)

## Build

| Comando | Cosa fa |
|---|---|
| `make` | `build/vos.dsk`: il kernel, le viste, le lingue, tutti i programmi e `myapps/*` |
| `make run` | apre il dischetto in Caprice32 (`RUN"VOS"`) |
| `make shot` | si avvia senza finestra e cattura una schermata |
| `make docs` | il manuale in PDF: `docs/V-OS.pdf` (greco) e `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip`: `V-OS.exe` per Windows, con CPCEMU 3.0.2 (CPC 6128, 576K, mouse AMX, scheda M4), `vos.dsk` in A: e `vrouves.dsk` in B:. V-OS parte da solo. Servono WSL e lo zip portatile di CPCEMU (`CPCEMU_ZIP=…`) |
| `make linux` | `build/V-OS-linux.tar.gz`: lo script `V-OS` per Linux (x86_64), con CPCEMU 2.5 (la 3.0.2 non è uscita per Linux) e le stesse impostazioni e dischetti. Servono SDL2 sul sistema e il tar.gz di CPCEMU per Linux (`CPCEMU_TGZ=…`) |
| `make songs` | i brani di Arkos Tracker 3 come file `.MUS` in `myapps/music/owndisc` (`tools/mkmusic.py`; serve Arkos Tracker 3, `ARKOS=…`) |
| `make new-app NAME=x`, `make app NAME=x` | il tuo programma (SDK) |
| `make clean` | cancella `build/` |

## Struttura del repository

| Cartella | Contenuto |
|---|---|
| `src/vos.asm` | la radice della build: loader e kernel, scrittura sul dischetto |
| `src/boot/` | il loader che AMSDOS esegue a `#4000`, rilevamento dell'espansione RAM |
| `src/kernel/` | vettori, interrupt, file system, viste, API (`api.asm`), impostazioni, estensione del kernel (`ext.asm`), script di test (`test_script.asm`) |
| `src/drivers/` | Gate Array, CRTC, tastiera, mouse AMX, FDC, AY |
| `src/gfx/` | grafica overscan, testo, schermo misto |
| `src/ui/` | menu, pulsanti, dialoghi, inserimento di testo, selettore di file |
| `src/shell/` | le viste come overlay: Scrivania, Launcher, Commander, Impostazioni |
| `src/api/vos_api.inc` | l'API per i programmi |
| `lang/` | le lingue (testi, tastiere, font) |
| `apps/` | i programmi in assembly: DEMO, MIXED, STUDIO, CLOCK, e le loro icone |
| `blocks/` | l'editor web, `vbc.py`, `runtime.asm`, il player di Studio (`player.asm`), esempi |
| `sdk/` | l'SDK: guida e modello di programma |
| `tools/` | strumenti: font, lingue, testi, icone, rilocazione, `.VBS` da testo, schermate, PDF |
| `docs/` | questo manuale in greco (`manual/`) e in inglese, francese, spagnolo, tedesco e italiano (`manual/en/`, `fr/`, `es/`, `de/`, `it/`), i PDF, i requisiti (`REQUIREMENTS.md`) |

## La memoria, in breve

| Area | Cosa contiene |
|---|---|
| `#0000–#3DFF` | il kernel. Nella pagina zero, dopo i vettori di restart, la tabella dell'API a `#0108` |
| fino a `#4000` | lo stack del kernel |
| `#4000–#7FFF` | la "finestra" dei banchi |
| `#8000–#FFFF` | lo schermo overscan da 32K. Nei suoi spazi vuoti, buffer del kernel |

I banchi che entrano nella finestra:

| Banco | Cosa contiene |
|---|---|
| 4 | buffer dei file e di caricamento, e il banco dati del programma in esecuzione |
| 5 | la vista a `#4000–#4FFF`, e da `#5000` i programmi con una tabella di rilocazione (o un programma senza tabella in tutto il banco) |
| 6 | quello che coprono i menu e i dialoghi, e da `#7000` l'accessorio di scrivania |
| 7 | il pacchetto di lingua, gli elenchi del Commander, i testi inglesi, e da `#7000` l'estensione del kernel |

Con un'espansione di memoria, i suoi banchi ospitano programmi. I dettagli, indirizzo per indirizzo, sono in `docs/REQUIREMENTS.md` (§4.2 e in ogni sezione "Υλοποίηση M…" (implementazione)).

## Convenzioni

- **RASM:** l'esadecimale si scrive `#C000` e non `&C000`, perché RASM legge `&` come AND. Le etichette non distinguono maiuscole e minuscole.
- **Commenti:** in inglese, brevi, come nel codice esistente. Ogni file inizia con un blocco che dice che cosa fa.
- **Documentazione:** in greco. `README.md` e `docs/REQUIREMENTS.md` hanno una sezione per ogni milestone. Il manuale è scritto in greco e tradotto nelle altre cinque lingue di V-OS.
- **Testi:** i testi di sistema sono in `lang/*/messages.txt`, e i testi dei programmi in `texts.txt` (per `tools/mktexts.py`).

## Test

I test eseguono V-OS in Caprice32 senza finestra e catturano schermate in `build/shots/<delay>/`.

**Come funzionano:**

- Caprice32 senza finestra non può premere frecce, COPY o tasti f. Per questo le pressioni dei tasti sono fatte da una build speciale: un `-DTEST_SCRIPT=n` inserisce lo script n in `src/kernel/test_script.asm`, una tabella di tasti per frame.
- Ogni target `make test-…` costruisce un dischetto con il suo script e cattura una schermata a ogni ritardo in `…_SHOTS`.
- Il ritardo si misura in pressioni di "Z": circa 2,5–3,5 frame ciascuna. La corrispondenza non è fissa, quindi un momento si cattura con due o tre ritardi intorno a esso.
- Quando V-OS scrive sul dischetto, Caprice32 non si chiude da solo, e il test finisce per timeout. Questo è previsto in test-vars, test-costume e altri.
- Le schermate le guardi tu, ad es. combinate in un'unica immagine con `ffmpeg … hstack/vstack`.

| Target | Cosa testa |
|---|---|
| `test-input` | tasti, Studio: blocchi, file, esecuzione |
| `test-calc` | CALC con clic, poi `CALC.VBS` in Studio |
| `test-costume` | costume in Studio, esecuzione, riapertura |
| `test-acc` | l'orologio come accessorio di scrivania |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | più programmi, F6, espansione di memoria, background |
| `test-drag` | trascinamento delle finestre |
| `test-langs`, `test-lang` | le lingue, il salvataggio della lingua |
| `test-mines`, `test-bricks` | i giochi |
| `test-vars` | le 128 variabili, SAVE/LOAD VARS |
| `test-sdk` | il modello dell'SDK |
| `test-vrouves` | VROUVES dal suo dischetto in B:, tramite il Launcher (TAB): costruzione, l'ondata 1, i soldi, HIGH SCORES |
| `test-notepad` | NOTEPAD: scrittura, DEL, il dialogo di salvataggio, OPEN con solo file `.TXT` |
| `test-paint` | PAINT: linea, rettangolo, riempimento, i menu, poi i livelli (nasconderne uno) |
| `test-about` | AIUTO > INFORMAZIONI SU V-OS |
| `test-music` | MUSIC da `music.dsk` in B:: un brano suona e continua dietro il Launcher |
| `test-markdown` | MARKDOWN da `markdown.dsk` in B:: apre `README.MD`, la pagina con ^P, una schermata più giù, ritorno al testo |
| `test-amsdos`, `test-reboot`, `test-system` | file di V-OS in BASIC, riavvio, dischetto SYSTEM |

**Nuovo script:**

1. Aggiungi un `IF TEST_SCRIPT == n` all'inizio della catena in `test_script.asm`, con `ELSE` prima del successivo e un `ENDIF` in più alla fine.
2. Aggiungi un target al Makefile, come `test-sdk`.

Ogni tasto si scrive come `dw from, to : db row, bit` della tastiera. Il numero del tasto è riga·8 + bit, ad es. RETURN = 18 = riga 2, bit 2.

**Senza emulatore:** il codice di un programma gira anche su uno Z80 dentro Python (il pacchetto `z80`). Carichi il `.BIN` a `#4000` e fai sì che le chiamate dell'API ritornino subito (o facciano quello che serve, ad es. file in un dizionario). Poi chiami init ed event e leggi la memoria. È molto più veloce delle schermate per gli errori in numeri, file e salti. Gli indirizzi delle etichette vengono da `rasm … -s -sl` (un file `.sym`).

## A ogni milestone

1. Codice, e un test in Caprice32: nuovo o esistente, con schermate.
2. I test che la modifica tocca.
3. Una sezione in `README.md` e una sezione "Υλοποίηση M…" (implementazione) in `docs/REQUIREMENTS.md`.
4. **Aggiorna il manuale in tutte e sei le lingue** (`docs/manual/` in greco, `docs/manual/<code>/` per en, fr, es, de, it, e `sdk/README.md`, `sdk/README.<code>.md` se l'API cambia), poi `make docs` per tutti i PDF.
5. Commit e push.
