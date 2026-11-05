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
| `make` | `build/vos.dsk` (A:): il kernel, le viste, le lingue, DEMO, MIXED, STUDIO, CLOCK e i sorgenti `.VBS`; `build/apps.dsk` (B:): gli altri programmi e `myapps/*`; e il dischetto di ogni programma con `owndisc/`. Se un file non sta su un dischetto vero (180K), si ferma con un errore |
| `make run` | apre il dischetto in Caprice32 (`RUN"VOS"`) |
| `make shot` | si avvia senza finestra e cattura una schermata |
| `make docs` | il manuale in PDF: `docs/V-OS.pdf` (greco) e `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip`: `V-OS.exe` per Windows, con CPCEMU 3.0.2 (CPC 6128, 576K, mouse AMX, scheda M4), `vos.dsk` in A:, `apps.dsk` in B: e i dischetti dei programmi accanto. V-OS parte da solo. Servono WSL e lo zip portatile di CPCEMU (`CPCEMU_ZIP=…`) |
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
- **Documentazione:** in greco. `MILESTONES.md` (inglese), `MILESTONES.el.md` (greco) e `docs/REQUIREMENTS.md` hanno una sezione per ogni milestone. Il manuale è scritto in greco e tradotto nelle altre cinque lingue di V-OS.
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
| `test-calc` | CALC con clic, poi `CALC.VBS` in Studio e il suo titolo in inglese e in francese (^T) |
| `test-costume` | costume in Studio, esecuzione, riapertura |
| `test-acc` | l'orologio come accessorio di scrivania |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | più programmi, F6, espansione di memoria, background |
| `test-drag` | trascinamento delle finestre |
| `test-langs`, `test-lang` | le lingue, il salvataggio della lingua |
| `test-mines`, `test-bricks` | i giochi |
| `test-vars` | le 128 variabili, SAVE/LOAD VARS |
| `test-sdk` | il modello dell'SDK |
| `test-apps` | i due dischetti come vengono dati, `vos.dsk` (con i tasti del test) in A: e `apps.dsk` in B:: il Launcher mostra B: e PONG parte da lì |
| `test-vrouves` | VROUVES dal suo dischetto in B:, tramite il Launcher (TAB): costruzione, l'ondata 1, i soldi, HIGH SCORES |
| `test-notepad` | NOTEPAD: scrittura, DEL, il dialogo di salvataggio, OPEN con solo file `.TXT`; poi ^M: la pagina (modo 2) |
| `test-notepad-big` | la finestra di testo di NOTEPAD in un emulatore Z80 (`tools/notepad_check.py`): un file di 12K con il suo banco dati, spostamenti, scrittura e SAVE, testo fino a 16K, e 4K su un 6128 |
| `test-data` | (576K) NOTEPAD con un testo di 15K fino alla riga 33, MARKDOWN nel frattempo, poi NOTEPAD di nuovo all'inizio: le righe dal suo banco dati |
| `test-paint` | PAINT: linea, rettangolo, riempimento, i menu, poi i livelli (nasconderne uno), OTHER DRIVE ed EXPORT .SCR su B: ("SAVED AS .SCR") |
| `test-paint-big` | PAINT su tutto lo schermo (576K): linee, la finestra spostata dalle sue barre (un clic e un trascinamento), la sua posizione, salvata come `B:NONAME.SCR` e riaperta |
| `test-paint-undo` | l'UNDO di PAINT in uno Z80 (`tools/paint_check.py`): rettangolo, linea, matita, cerchio e riempimento annullati e ripristinati, su un'immagine 128×128 e su tutto lo schermo (anche con la finestra spostata, il riempimento oltre); i livelli, con un banco dati proprio o senza |
| `test-scr` | l'EXPORT .SCR di PAINT (il suo codice in un emulatore Z80, `tools/scr_check.py`) caricato in BASIC da un disco, con la palette; si controlla ogni pixel dello schermo |
| `test-about` | AIUTO > INFORMAZIONI SU V-OS |
| `test-music` | MUSIC da `music.dsk` in B:: un brano suona e continua dietro il Launcher |
| `test-markdown` | MARKDOWN da `markdown.dsk` in B:: apre `README.MD`, la pagina con ^P, una schermata più giù, ritorno al testo; poi ^M: la pagina (modo 2) |
| `test-open` | apertura per tipo nel Commander: `README.MD` in MARKDOWN da B:, un `.TXT` in NOTEPAD da A: |
| `test-sysinfo` | SYSINFO dal Commander: versione, API, memoria, K liberi su A: e B:, ^R, ^Q. Con `SYSINFO_RAM=576`, con un'espansione da 512K |
| `test-clip` | gli appunti: selezione con SHIFT, ^C e ^V in NOTEPAD, ^A, ^X, ^V, poi ^V in MARKDOWN |
| `test-webget` | a mano, nel CPCEMU di `make linux` (scheda M4; servono uno schermo e internet): WEBGET scarica `example.com/index.html`. Chiudi CPCEMU con F12 quando appare SAVED, e si cerca `INDEX.HTM` sul dischetto |
| `test-reader` | READER da `reader.dsk` in B: apre `INDEX.MD`, TAB sceglie un collegamento, RETURN apre `ABOUT.MD`, DEL torna indietro, e un collegamento `https://` dà un messaggio; poi ^M: la pagina (modo 2) |
| `test-db` | il motore dei database in un emulatore Z80 (`tools/db_check.py`): migliaia di chiamate a caso su quattro tabelle, controllate con un modello, il file pagina per pagina (`tools/vdb.py`), finché il disco è pieno |
| `test-db-disc` | `DB.SYS` con il file system del kernel su un'immagine DSK (`tools/db_disc_check.py`) |
| `test-streets` | STREETS da `streets.dsk` in B:: un nuovo `STREETS.VDB` con 24 vie, ricerca, una nuova via |
| `test-database-z80` | DATABASE in un emulatore Z80, con il database in Python e lo schermo come testo: due tabelle, 47 record dal modulo, l'ordine senza maiuscole né accenti, la ricerca, una modifica, una cancellazione, lo scorrimento |
| `test-database` | DATABASE in Caprice32: un database nuovo su B:, una tabella, tre record dal modulo, la lista, la ricerca, una modifica |
| `test-calc-sys` | il motore delle formule `CALC.SYS` in un emulatore Z80 (`tools/calc_check.py`): formule fisse e 40.000 casuali, numeri e testi, confrontati con un modello in Python |
| `test-sheet-z80` | SHEET in un emulatore Z80 con lo stesso `CALC.SYS` e lo schermo come testo: valori, `#ERR`, celle che si usano a vicenda, scorrimento, SAVE e OPEN, un file UTF-8, `BUDGET.VSH`, un foglio pieno; poi ^M: la pagina (modo 2) |
| `test-sheet` | SHEET in Caprice32: numeri e una formula digitati, `CALC.SYS` da A:, il foglio salvato su B:; poi ^M: la pagina (modo 2) |
| `test-kbds` | TASTIERE: TUTTE SEI in Setup, poi in NOTEPAD i tasti `:` e Z con ogni tastiera: `:z`, `:ζ`, `mw`, `ñz`, `öy`, `òz` |
| `test-charset`, `test-reader-utf8` | file UTF-8 in greco, francese, spagnolo, tedesco e italiano in NOTEPAD e in READER |
| `test-utf8` | il codice di `VX_UTF8` in un emulatore Z80, rispetto a `tools/voscs.py` |
| `test-view` | `VX_VIEW`: VIEWT (`apps/viewt`) disegna attraverso una vista di 160 × 96, controllata pixel per pixel (`tools/view_check.py`): la vista riempita, un rettangolo tagliato, 19 caratteri su 20, l'ultimo pixel, un'immagine dentro e una fuori; con 128K: NO EXPANSION |
| `test-wm` | `VX_WINDOW` e `WM.SYS` (576K): WINA e WINB (`apps/wint`) in finestre; sette schermate controllate (`tools/wm_check.py`): una davanti all'altra, portata davanti con un clic e la sua barra, un clic dentro dal suo angolo, spostata dal titolo, schermo intero con F7 e ritorno, chiuse con X fino al Commander |
| `test-wm-apps` | CLOCK, SYSINFO e WINA in finestre insieme (576K); cinque schermate controllate (`tools/wm_apps_check.py`): le tre una sull'altra, CLOCK portato davanti con un clic e spostato, SYSINFO davanti e CLOCK che scorre dietro, scoperto, SYSINFO rimpicciolito dal suo angolo |
| `test-wm-apps2` | DIARY, TELNET e CALC in finestre (576K, API 36: la finestra mostra una parte dello schermo del programma); quattro schermate controllate (`tools/wm_apps2_check.py`): DIARY, TELNET sopra, CALC con i suoi pulsanti nella sua finestra, e 1 + 2 = 3 cliccati lì |
| `test-wm-net` | MAIL e FTP in finestre (576K): FTP sopra MAIL; un clic sulla X di FTP: termina (^Q), MAIL di nuovo davanti; sulla X di MAIL: il Commander; quattro schermate controllate (`tools/wm_net_check.py`) |
| `test-wm-launch` | NOTEPAD dal Launcher (modo 0) in una finestra della sua misura (576K), con testo scritto; due schermate controllate (`tools/wm_launch_check.py`) |
| `test-wm-notepad` | NOTEPAD in una finestra con un NOTES.TXT (576K): rimpicciolita dal suo angolo, colonne e righe tagliate alla finestra, la riga di stato sotto; la pagina (^M) a schermo intero e la finestra di nuovo dov'era (`tools/wm_notepad_check.py`) |
| `test-wm-pages` | MARKDOWN con INDEX.MD e la sua anteprima, READER (a capo alla larghezza della finestra) e SHEET (4 colonne, 18 righe) in finestre (576K); la pagina di SHEET e il ritorno (`tools/wm_pages_check.py`) |
| `test-wm-copies` | copie delle finestre (576K): WINB spostata lontano da SYSINFO e WINA, sopra di loro e di nuovo lontano; WINA e WINB scrivono quante volte si sono disegnate e dicono ancora 001, sotto l'immagine della scrivania (`tools/wm_copies_check.py`) |
| `test-wm-desktop` | la scrivania tra le finestre (576K, SETUP.CFG con la finestra di A:): WINA con la finestra e le icone della scrivania dietro; la scrivania (F1) con WINA sulla sua superficie; ognuno davanti con un clic (`tools/wm_desktop_check.py`) |
| `test-wm-keys` | F5, F6, X e la palette tra le finestre (576K): CLOCK come accessorio, WINA e WINB; l'elenco dei programmi (F6) e l'accessorio sopra le finestre, le finestre di nuovo quando si chiudono; i rossi di WINA (P) lasciano i colori come sono; la X di WINA: ^Q, WINB davanti (`tools/wm_keys_check.py`) |
| `test-mail` | MAIL su uno Z80 in Python (`tools/mail_check.py`), con la scheda M4 di `tools/m4net.py` e server POP3 e SMTP in Python: l'account in `MAIL.CFG`, i 20 più recenti di 22 messaggi con gli oggetti decodificati, uno semplice, uno in quoted-printable UTF-8 e uno in più parti (base64, non il suo HTML), scorrimento, SAVE AS TEXT, DELETE al QUIT, WRITE e REPLY via SMTP (AUTH LOGIN, «.» raddoppiato, l'oggetto greco in Q), un rifiuto, una password sbagliata, nessuna risposta, nessuna scheda; un messaggio tagliato; tre allegati di un messaggio con parti dentro parti: su B: tramite il banco (uno oltre 16K rifiutato), su DISK sulla scheda man mano che arrivano (i file della scheda M4 di `tools/m4net.py`) |
| `test-ftp` | FTP su uno Z80 in Python (`tools/ftp_check.py`), con un server FTP in Python: anonymous, PASV verso l'indirizzo della connessione di controllo, LIST in righe Unix e DOS, RETR con un nome 8.3, CWD e CDUP, STOR a pezzi, DELE, oltre 16K non salvato, una password sbagliata, nessuna scheda; su DISK file di qualsiasi dimensione da e verso la scheda (70000 byte; uno con intestazione AMSDOS inviato senza) |
| `test-mail-m4`, `test-ftp-m4` | MAIL e FTP nell'emulatore 1984 con una scheda M4 (script 60 e 61), con i server `tools/mail_server.py` e `tools/ftp_server.py` su questo PC: l'elenco, un messaggio, un `.TXT` inviato; l'elenco di FTP, un file verso la scheda e uno da essa |
| `test-vosnet` | il server V-OS NET (`server/`, .NET 10) su questo PC, sulla porta 2323, e TELNET nell'emulatore 1984 con una scheda M4 (script 62): il benvenuto, ΕΛΛΗΝΙΚΑ, un ospite, il menu principale; il registro del server dice che TELNET ha risposto «V-OS» a TTYPE e che il profilo è V-OS. I test del server stesso (xUnit, con un falso client V-OS): `dotnet test server/VosNet.sln` |
| `test-styles` | STYLES.VBN (`blocks/examples/styles.vbt`) dal Commander: normale, grassetto, corsivo, sottolineato e tutti e tre, con il blocco STYLE |
| `test-music-block` | con 576K: TUNE.VBN (`blocks/examples/tune.vbt`) avvia MUSIC (da B:) dietro di sé con AGANAMEM.MUS; F6 mostra "> TUNE" e MUSIC, e RETURN porta MUSIC davanti: A:AGANAMEM, PLAYING. Con `MBLOCK_RAM=128`: "CHIUDI PRIMA UN ALTRO PROGRAMMA" |
| `test-amsdos`, `test-reboot`, `test-system` | file di V-OS in BASIC, riavvio, dischetto SYSTEM |

**Nuovo script:**

1. Aggiungi un `IF TEST_SCRIPT == n` all'inizio della catena in `test_script.asm`, con `ELSE` prima del successivo e un `ENDIF` in più alla fine.
2. Aggiungi un target al Makefile, come `test-sdk`.

Ogni tasto si scrive come `dw from, to : db row, bit` della tastiera. Il numero del tasto è riga·8 + bit, ad es. RETURN = 18 = riga 2, bit 2.

**Senza emulatore:** il codice di un programma gira anche su uno Z80 dentro Python (il pacchetto `z80`). Carichi il `.BIN` a `#4000` e fai sì che le chiamate dell'API ritornino subito (o facciano quello che serve, ad es. file in un dizionario). Poi chiami init ed event e leggi la memoria. È molto più veloce delle schermate per gli errori in numeri, file e salti. Gli indirizzi delle etichette vengono da `rasm … -s -sl` (un file `.sym`). Alle chiamate `VX_M4` dei programmi di rete risponde `tools/m4net.py`, una scheda M4 in Python con server in Python all'altro capo.

## A ogni milestone

1. Codice, e un test in Caprice32: nuovo o esistente, con schermate.
2. I test che la modifica tocca.
3. Una sezione in `MILESTONES.md` e `MILESTONES.el.md`, e una sezione "Υλοποίηση M…" (implementazione) in `docs/REQUIREMENTS.md`.
4. **Aggiorna il manuale in tutte e sei le lingue** (`docs/manual/` in greco, `docs/manual/<code>/` per en, fr, es, de, it, e `sdk/README.md`, `sdk/README.<code>.md` se l'API cambia), poi `make docs` per tutti i PDF.
5. Commit e push.
