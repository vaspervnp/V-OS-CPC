# L'SDK di V-OS: programmi in assembly

Con questo SDK scrivi i tuoi programmi in assembly Z80. Girano dentro V-OS come DEMO o CLOCK: compaiono nel Launcher, nella Scrivania e nel Commander, e hanno il proprio menu, pulsanti, dialoghi, suono e file. Girano anche accanto ad altri programmi.

## Avvio rapido

```bash
make new-app NAME=hello
```

Questo crea la cartella `myapps/hello/` da `sdk/template/`. Contiene tre file:

- `hello.asm`: il programma. Le frecce muovono un riquadro, c'è un pulsante BEEP, un contatore dei secondi e un menu proprio (ABOUT, BACK) accanto a VISTA e AIUTO.
- `texts.txt`: i suoi testi, in inglese e in greco.
- `icon.txt`: la sua icona, 16×16, per il Launcher.

```bash
make app NAME=hello
```

Questo costruisce `build/HELLO.BIN` e lo mette sul dischetto dei programmi, `build/apps.dsk`. `make run` lo mette in B:; nel Launcher, TAB mostra B:.

```bash
make run
```

Questo apre il dischetto in Caprice32. HELLO è nel Launcher, nell'ultima pagina.

- Il semplice `make` costruisce tutti i programmi in `myapps/` e li mette sul dischetto, insieme a V-OS.
- Il nome ha 1–8 lettere minuscole o cifre e inizia con una lettera. Non può essere il nome di un programma di V-OS (ad es. demo).
- Servono RASM, Python 3 e iDSK, come per tutto V-OS.
- In Caprice32 il programma lo avvii tu, dal Launcher.

Un programma più grande:

- Metti altri file `.asm` nella sua cartella (ad es. `art.asm` con gli sprite) e includili con `include "art.asm"`. Il build li trova, e ricostruisce il programma quando cambiano.
- Quello che metti nella sottocartella `disc/` (ad es. `disc/LEVEL1.DAT`) va così com'è sul dischetto, per `VOS_LOAD`.
- Con una sottocartella `owndisc/`, il programma ha anche un dischetto suo, `build/<nome>.dsk`, con il `.BIN` e i file di `owndisc/`. Non va su `apps.dsk`. Lo metti in B: e lo avvii dal Launcher (TAB, l'altra unità). Il drive da cui è partito, per caricare da lì i suoi file, è in `VOS_SELF`: `db drive`, poi il suo nome (11 byte).
- **Un file da aprire (versione 14):** quando RETURN nella Scrivania o nel Commander apre un file nel tuo programma, `VOS_OPEN` (`#B000`) contiene `db 1, unità, nome di 11 byte` (0: nessuno). Leggilo in `init`, con A = 0 e anche con A = 2 (il programma era già in esecuzione), poi scrivici 0. I tipi e i loro programmi sono nella tabella `ft_open` del kernel (`src/kernel/files_ext.asm`).
- Un programma con tabella di rilocazione (come quelli dell'SDK) gira accanto ad altri fino a 12K; uno più grande (fino a 16K) gira da solo senza espansione di memoria, come uno senza tabella (MARKDOWN, READER). Per il resto, carica file nel banco dati.

## Come funziona un programma

Un programma è un `.BIN`, costruito per `VOS_APP_ADDR` (`#4000`). Inizia così:

```
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0
        jp event                ; +3  HL -> l'evento
        jp redraw               ; +6
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12 l'icona (facoltativa)
```

- **`init`** imposta modo, palette, menu e pulsanti, attiva `VE_FRAME` se serve, e disegna tutto.
  - A = 0: un avvio da zero.
  - A = 2: il programma torna da una vista o da un altro programma. Il suo stato è come l'aveva lasciato; imposta di nuovo quanto sopra e disegna.
- **`event`** viene chiamata per ogni evento e ritorna subito. Un programma non aspetta mai da solo (nessun ciclo di attesa). Per movimento o tempo, `VOS_TICKS` con A = 1, e poi arriva un `VE_FRAME` 50 volte al secondo.
- **`redraw`** ridisegna tutto, ad es. quando cambia la lingua o si chiude l'accessorio di scrivania.
- **Uscita:** `VOS_EXIT`, che torna alla vista che l'ha avviato.

### L'ordine dentro `event`

```
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame        ; i frame
        push hl
        call VOS_UI_EVENT               ; menu, pulsanti, CONTROL+lettera
        pop hl
        or a : jr nz,command            ; A = il comando
        call VOS_MENU_OPEN : ret nz     ; menu aperto: i tasti sono suoi
        ...                             ; i tuoi tasti e clic
command: ...
        jp VOS_COMMAND                  ; quello che non è tuo (VISTA, AIUTO)
```

**Mentre un menu è aperto, non disegnare.** Altrimenti disegnerai sopra di esso. Su `VE_FRAME`, aggiorna lo stato, ma disegna solo se `VOS_MENU_OPEN` dà Z. I dialoghi (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) hanno un proprio ciclo, quindi mentre sono aperti non arriva nessun evento.

### Gli eventi

`HL` → 8 byte: `db type, code, char, mods; dw x, y`.

| type | cosa | code / char / x, y |
|---|---|---|
| `VE_KEY_DOWN` 1, `VE_KEY_REPEAT` 3, `VE_KEY_UP` 2 | tasto | code = numero del tasto (`VK_*`, riga della tastiera·8 + bit), char = il carattere nella lingua del pacchetto |
| `VE_PTR_DOWN` 5, `VE_PTR_UP` 6, `VE_PTR_MOVE` 4 | puntatore | x, y in pixel del modo |
| `VE_FRAME` 8 | frame (con `VOS_TICKS`) | — |
| `VE_LANG` 7 | la lingua della tastiera è cambiata | — |

### Tre tipi di programma

- **Con una tabella di rilocazione (il predefinito dell'SDK):** `make app` lo costruisce due volte, a `#4000` e a `#4100`. `tools/mkreloc.py` aggiunge la tabella dalla differenza.
  - Gira accanto ad altri programmi, nei 12K da `#5000`, e riprende da dove si era fermato (F6 mostra i programmi in esecuzione).
  - I suoi dati devono stare dentro i suoi stessi byte (etichette, `ds`), mai a indirizzi fissi.
  - Se `mkreloc.py` dà un errore, da qualche parte un indirizzo è usato in un modo che non sopravvive alla rilocazione. Ad es. `ld a,label & 255`, o solo il byte basso di un indirizzo.
- **Senza tabella:** prende tutto il banco (fino a 16K, codice e dati), ma gira solo da solo, a meno che non ci sia un'espansione di memoria. Serve una tua regola nel Makefile (vedi `STUDIO.BIN`).
- **Accessorio di scrivania:** fino a 4K, con una tabella. Si apre con F5 sopra qualsiasi cosa, e `init` riceve A = 1. Vedi `apps/clock/clock.asm` e la descrizione in `src/api/vos_api.inc`.

### Regole

- **Registri:** le chiamate alterano tutti i registri tranne IX. Gli argomenti vanno in A, BC, DE, HL (IX per `VOS_RECT` e `VOS_BLIT`). I risultati tornano in A o HL. In caso di errore, il carry è impostato e A = numero dell'errore, che `VOS_ERROR` mostra.
- **Memoria:** non mappare un altro banco a `#4000`, perché il programma ti sparirebbe da sotto. Per altri 16K c'è il banco dati (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). È condiviso con le viste e con altri programmi, e conserva i suoi dati solo mentre il programma è in esecuzione. Con un'espansione di memoria (API 21) ogni programma ne riceve uno suo, che conserva ciò che contiene fino alla fine del programma, qualunque cosa giri nel frattempo; `VX_DATA` dice quale (A = 1: il suo).
- **Coordinate:** x in pixel del modo (modo 0: 0–191, modo 1: 0–383, modo 2: 0–767), y da 0 a 258. La barra dei menu occupa y 0–11.
- **RASM:** le etichette non distinguono maiuscole e minuscole (`BOX` e `box` sono la stessa). L'esadecimale si scrive con `#` e non con `&`.

## I formati dei dati

- **Barra dei menu** (`VOS_SET_BAR`): `db count; dw menu, ...`. I comuni VISTA e AIUTO vengono da `VOS_MENU_VIEW` e `VOS_MENU_HELP`.
- **Menu:** `db title, count` e per ogni voce `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` per una linea
  - command: 1.., quello che restituisce `VOS_UI_EVENT`
  - letter: scorciatoia CONTROL+lettera, o 0
- **Pulsanti** (`VOS_SET_WIDGETS`, poi `VOS_DRAW_WIDGETS`): `db count`, e per ogni pulsante `dw x, y; db larghezza in caratteri, text, command, 0`.
- **Dialogo** (`VOS_DIALOG` → A = pulsante, 0 il primo, ESC dà l'ultimo): `db title, text, numero di pulsanti (1–3), pulsante, ...`. Per i pulsanti, `VM_OK`, `VM_YES` e `VM_NO`.
- **Testi** (`VOS_TEXTS`): creati da `tools/mktexts.py` a partire da `texts.txt`, con righe `NAME | English | Greek`. Le due colonne si scrivono in UTF-8 e diventano byte del set di caratteri di V-OS (`tools/voscs.py`), che contiene il greco e le lettere latine di francese, spagnolo, tedesco e italiano.
  - Dà `T_NAME` (`VT_FIRST` = `#C0` e oltre) e la tabella `texts:`. Fino a 64 testi.
  - Un `|` senza spazi intorno inizia una nuova riga nei dialoghi.
  - I testi vanno dove viene chiesto un "testo" (menu, pulsanti, dialoghi). Con `VOS_MSG` ottieni il loro indirizzo per `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`): 17 colori del firmware (0–26): 16 penne e il bordo. In modo 1 contano le penne 0–3.
- **Rettangolo** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icona:** 16 righe di 16 caratteri in `icon.txt`. Ogni carattere è una penna in esadecimale (modo 0, palette del Launcher) o `.` per trasparente. Il Launcher la legge dal disco: mentre il programma gira, i 256 byte dopo "IC" sono liberi per dei buffer (PAINT ci tiene le sue righe).
- **Nomi di file** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 byte, `"NAME    EXT"`. Unità 0 = A:, 1 = B:.

## L'API (versione 22)

| Chiamata | Ingresso → uscita | Cosa fa |
|---|---|---|
| `VOS_EXIT` | — | fine, ritorno alla vista che l'ha avviato |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 volte al secondo, o nessuno. Con `VOS_PTR_KEYS` (2) le frecce e COPY muovono anche il puntatore e fanno clic |
| `VOS_FRAMES` | → HL (e A bit 16–23) | frame dall'avvio |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = comando | i comandi comuni di VISTA e AIUTO (6–19). Numera i tuoi comandi da `VC_APP` (32) in su, altrimenti una voce di VISTA o AIUTO esegue uno dei tuoi |
| `VOS_ERROR` | A = errore | dialogo di errore |
| `VOS_MODE` | A = 0 / 1 / 2 | modo 0 (192×259, 16 penne), 1 (384×259, 4 penne) o 2 (768×259, 2 penne, 96 colonne di testo; versione 25). In modo 2 menu e dialoghi si disegnano con la penna 1 sulla 0: penna 0 bianca e 1 nera danno testo nero su carta bianca (NOTEPAD, MARKDOWN, READER, SHEET con ^M) |
| `VOS_PALETTE` | HL → 17 colori | |
| `VOS_CLS` | A = penna | cancella lo schermo |
| `VOS_PLOT` | HL = x, DE = y, A = penna | un pixel |
| `VOS_RECT` | IX → rettangolo | rettangolo pieno |
| `VOS_COLOURS` | A = penna del testo (+ `VOS_BOLD`, `VOS_ITALIC`, `VOS_UNDERLINE`), C = sfondo | per `VOS_PRINT` e `VOS_CHAR`. Gli stili nascono dallo stesso font, per ogni lingua |
| `VOS_PRINT` | HL = x, DE = y, BC → testo, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = carattere | |
| `VOS_MSG` | A = testo → HL | l'indirizzo di un testo (`T_*` o uno di sistema) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → barra dei menu | |
| `VOS_UI_EVENT` | (l'evento corrente) → A | comando di menu, pulsante o scorciatoia, 0 per nessuno |
| `VOS_DIALOG` | HL → dialogo → A | |
| `VOS_INPUT` | A = titolo, HL → testo, C = massimo → carry se annullato | inserimento di testo (servono C + 2 byte) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → pulsanti | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | i menu comuni |
| `VOS_CATALOG` | A = unità → A = file, HL → elenco | 16 byte ciascuno: 11 il nome, a +12 la dimensione in K. Con A = unità + `VOS_CAT_EXT` e HL → `"EXT"`, solo i file con quell'estensione |
| `VOS_FILE_PICK` | A = titolo → A = file, carry se annullato | dialogo di scelta, dopo `VOS_CATALOG` |
| `VOS_LOAD` | A = unità, HL → nome, DE = dove → BC = lunghezza | |
| `VOS_SAVE` | A = unità, HL → nome, DE = da, BC = lunghezza | file binario, che sostituisce il vecchio. Con A + `VOS_LOAD_IX` (#40, versione 20) la sua intestazione dice che si carica a IX, non a DE (un `.SCR`: IX = #C000) |
| `VOS_DELETE` | A = unità, HL → nome | |
| `VOS_TEXTS` | HL → tabella dei testi | i testi del programma |
| `VOS_MENU_OPEN` | → NZ se un menu è aperto | |
| `VOS_KEY_HELD` | A = tasto → NZ mentre è premuto | per i giochi |
| `VOS_BLIT` | IX → `dw x, y; db bytes, lines; dw source; db source stride` | immagine: coppie (maschera, pixel) |
| `VOS_SOUND` | A = canale 0–2, HL = periodo (bit 15: rumore), C = volume 0–15, B = frame | una nota; 440 Hz è il periodo 142 |
| `VOS_SPLIT` | HL → `dw y1, y2; db 8 colors` (0 = disattiva) | schermo misto: modo 0 tra y1 e y2 |
| `VOS_RUN` | A = unità, HL → nome | avvia un altro programma, e poi questo riparte |
| `VOS_KEEP` | → HL → 16 byte | memoria che resta tra un programma e l'altro |
| `VOS_BANK_GET`, `VOS_BANK_PUT` | HL = da, DE = a, BC = byte | copia da e verso il banco dati |
| `VOS_BACKGROUND` | A = 1 / 0 | continua a girare o si blocca quando è dietro un altro |
| `VOS_DRAG` | HL = x, DE = y, BC = w, A = h → carry: nuovi HL, DE | trascinamento di una finestra per il titolo |
| `VOS_FIT` | come sopra → HL, DE | riporta una finestra dentro lo schermo |
| `VOS_EXT` | A = una chiamata `VX_*`, BC, DE, HL come vuole → A, HL, C, DE, carry | le chiamate dopo la tabella (versione 15), sotto |

**Unità:** 0 = A:, 1 = B:, 2 = DISK, la scheda SD di una M4 (versione 28), nella cartella in cui la Scrivania o il Commander sono entrati per ultimi. Le chiamate di file e `VX_FREE` funzionano lì come su un dischetto (nomi 8.3; senza M4: carry, A = 35), e il catalogo ha anche le cartelle (a +13, 1). I database (`VX_DB`) funzionano anche lì (versione 29). Dalla versione 29, `VOS_CAT_EXT` tiene le cartelle, e `VOS_FILE_PICK` entra in una cartella scelta (o `..`) e la elenca come ha chiesto l'ultimo `VOS_CATALOG`: ciò che restituisce è sempre un file, nella cartella attuale. `VX_DRIVE` C = unità → A = la seguente (A: → B: → DISK con una M4 → A:), per un comando OTHER DRIVE; `src/api/vos_drive.inc` ha `vos_next_drive` (A: ↔ B: su un V-OS più vecchio) e `vos_drive_text` (`A:`, `B:`, `DISK:`).

**Le chiamate di `VOS_EXT`:** `VX_VERSION` → A = API, HL = versione di V-OS (BCD). `VX_FREE` C = unità → A = K liberi. Sconosciuta: carry `VX_CLIP_PUT` HL = testo, BC = byte → gli appunti (fino a 1K). `VX_CLIP_GET` DE = dove, BC = spazio → HL = dimensione (versione 16). `VX_M4` HL → un comando per la scheda M4 (db dimensione, dw comando, dati), DE → la risposta, BC = byte; carry: niente scheda M4 (versione 17); HL = 0: BC byte del `sock_info` della ROM della M4 in DE, 16 per socket (il suo stato, il suo ultimo comando, i byte ricevuti, un ip e una porta; il socket 0 è quello di C_NETHOSTIP, il suo ip quello del nome cercato) (versione 32; così aspetta TELNET). `VX_MEM` → HL = la RAM in K, DE = i K liberi per i programmi (versione 18). `VX_BEHIND` DE → db unità, nome di 11 byte di un file: il suo programma (per tipo) parte dietro questo, con `init` A = 3 e il file in `VOS_OPEN` (versione 19; MUSIC lo conosce). `VX_DATA` → A = 1 se il banco dati è del programma (espansione di memoria), 0 se è il banco 4 condiviso (versione 21; NOTEPAD tiene così testo fino a 16K). `VX_DB` C = una chiamata `DB_*`, DE, HL → un database (versione 22, sotto). `VX_UTF8` HL → un testo, BC = byte, E = 0 nella memoria del programma o `VOS_DATA` nel suo banco dati: se è in UTF-8 (da un PC o dal web), diventa lì il set di caratteri di V-OS → BC = byte ora, A = 1; A = 0: non era UTF-8 e resta com'era (versione 23; così fanno NOTEPAD e READER). `VX_CALC` C = una chiamata `CALC_*`, DE → un blocco, HL → testo → formule e numeri (versione 24, sotto). `VX_LANG` → HL = il codice della lingua che mostra V-OS (`"EN"`, `"EL"`, `"FR"`…; L la prima lettera) (versione 26; così VBRUN mostra le traduzioni dei programmi di Studio). `VX_IRQ` HL = una routine del programma → il kernel la chiama una volta per fotogramma dall'interrupt, davanti o dietro, con il suo banco al suo posto e gli interrupt disattivati; 0 la ferma, come la fine del programma; carry: non per un accessorio né per un programma da solo nel banco 5 (versione 27; così MUSIC suona le sue canzoni, che non si fermano più mentre un altro programma carica o disegna). Deve essere breve, conservare IY, EXX e AF', scrivere solo la propria memoria e l'AY, e non chiamare nulla di V-OS. `VX_PRINT` HL → un testo, BC = byte, E = 0 nella memoria del programma o `VOS_DATA` nel suo banco dati → alla stampante (la porta Centronics del CPC, 7 bit), così com'è: 13, 10 chiudono una riga, 12 inizia una pagina nuova; le lettere sopra 127 escono come ASCII semplice (senza accenti, il greco in Greeklish: Θ 8, Ξ 3, Ψ 4); carry, A = 41: la stampante è rimasta occupata per due secondi (nessuna, fuori linea, senza carta) (versione 30; così NOTEPAD, SHEET e DATABASE stampano con ^P). Dopo 60 righe una pagina nuova inizia da sola; BC = 0 con HL → il nome di 11 byte di un file (come lo dà `VOS_CATALOG`) inizia una stampa le cui pagine hanno un'intestazione, `NOTES.TXT  PAGINA 2`; HL = 0: senza intestazioni (versione 31). `VX_VIEW` HL → dw x, y, w, h: da lì in poi il programma disegna con (0, 0) in (x, y) e nulla fuori da quel rettangolo (tagliato allo schermo): `VOS_CLS` lo riempie, `VOS_RECT` vi è tagliato, un punto, un carattere (ognuno di `VOS_PRINT`) o un'immagine di `VOS_BLIT` è disegnato solo se tutto dentro; menu, dialoghi e barra non cambiano; HL = 0: nessuna; di nuovo dopo `VOS_MODE` e in `redraw` (finisce quando un altro programma passa davanti); carry: niente espansione di memoria (versione 33; il primo passo verso i programmi in finestre, docs/WINDOWS.md). `VX_WINDOW` HL → dw w, h: il programma in una finestra sulla scrivania, il suo interno w × h (w multiplo di 8) come vista e i suoi eventi del puntatore con x, y da lì; chiamarlo per primo in init, ogni volta (anche con A = 2: così le finestre dietro sono ridisegnate, con il loro init); il titolo la sposta, X lo termina, + o F7 la mettono a schermo intero e ritorno, un clic su un'altra la porta davanti con la sua barra; modo 1, i colori del tema; carry: niente espansione di memoria o niente `WM.SYS` su A: (schermo intero come prima; versione 34). Dalla versione 35 `VX_WINDOW` riscrive in HL la dimensione che ha ora il suo interno (schermo intero: lo schermo sotto la barra), così init dispone ciò che mostra per essa; l'angolo in basso a destra cambia la dimensione (e init viene richiamato con A = 2); con `VOS_BACKGROUND` il programma disegna nella sua finestra anche da dietro, finché nessuna la copre (`VOS_CLS`, `PLOT`, `RECT`, `COLOURS`, `PRINT`, `CHAR`, `BLIT`; non `VOS_MSG`). Esempi: `apps/clock`, `myapps/sysinfo`. Dalla versione 36 HL punta a dw w, h, x0, y0: la finestra mostra la parte dello schermo del programma da x0, y0 (0, 0: come prima), così un programma fatto per tutto lo schermo disegna come prima, e i suoi widget ed eventi lo seguono (p. es. `dw 376, 232, 0, 12` in `myapps/telnet`); un programma con la versione 36 nella sua intestazione dà sempre tutti e quattro. Se lo chiama fuori da init, ridisegna poi la sua barra (`VOS_DRAW_BAR`). Da V-OS 0.49 una finestra dietro che ha una copia di sé (presa mentre nulla la copriva) viene invece ricopiata: il suo init allora non è chiamato, quindi un programma non deve contare di essere chiamato a disegnare quando è dietro; uno che continua in background (`VOS_BACKGROUND`) disegna come prima finché non è coperto. Anche la finestra dei file e le icone delle unità della scrivania sono tra le finestre (0.50): fino a otto finestre in tutto. Con w = 0 (V-OS 0.48) il programma esce dalle finestre: la sua finestra se ne va (carry), e imposta modo e palette e disegna a schermo intero, come per una pagina in modo 2; se la richiede più tardi, la finestra torna dov'era, grande com'era. Con la dimensione riscritta un programma si dispone per la sua finestra: NOTEPAD, MARKDOWN, READER e SHEET (`set_mode`) prendono w / 8 colonne e tante righe quante ne entrano, di nuovo a ogni ridimensionamento, ed escono dalle finestre per la loro pagina (^M).

### Database (versione 22)

`VOS_EXT` con A = `VX_DB` e C = una chiamata `DB_*` lavora su un database: un file `NOME.VDB` di pagine da 1K, grande quanto il disco permette (fino a 255K). Ha fino a 8 tabelle; una tabella ha fino a 10 campi, testo (fino a 255 caratteri) o un numero (2 byte), e può avere un campo chiave (testo fino a 64 caratteri, o un numero) con un indice, perché FIND sia veloce. Un record è i suoi campi uno dopo l'altro; il suo id (rid) è un numero a 16 bit. È aperto un database alla volta, per il programma che lo ha aperto. Ogni chiamata scrive le sue modifiche sul disco prima di tornare. Il kernel carica il motore, `DB.SYS`, dall'unità A: la prima volta.

| Chiamata | Ingresso → uscita |
|---|---|
| `DB_CREATE`, `DB_OPEN` | DE → db unità, nome di 11 byte (`"STREETS VDB"`); OPEN → A = 1: Latin-1 (di V-OS 0.15) |
| `DB_CLOSE` | |
| `DB_TABLE` | DE → nome (8), campi, campo chiave (0: nessuno), poi ogni campo: nome (8), tipo, lunghezza → A = tabella |
| `DB_USE` | E = la tabella che usano le chiamate sotto |
| `DB_INFO` | E = tabella, HL → 124 byte: la sua descrizione → A = tabelle |
| `DB_ADD` | HL → record → DE = rid |
| `DB_GET`, `DB_PUT` | DE = rid, HL → il record |
| `DB_DEL` | DE = rid |
| `DB_FIND` | HL → chiave come in un record (spazio per un record), E = byte che contano (0: tutti) → DE = il primo record con quella chiave o dopo |
| `DB_FIRST`, `DB_LAST`, `DB_NEXT`, `DB_PREV` | HL → spazio per il record, o 0 → DE = rid, in ordine di chiave; carry alla fine |
| `DB_COUNT` | → HL = record |

Errori: carry e A (`DB_ERR_*`, e gli errori del disco), che `VOS_ERROR` mostra. Il testo è tenuto come è scritto, nel set di caratteri di V-OS, lo stesso in tutte le lingue: un database può avere greco, francese e tedesco insieme. Solo un database di V-OS 0.15 con lettere latine (Latin-1) è diverso: `DB_OPEN` dà allora A = 1; mostra `DB_ERR_ALPHABET` con `VOS_ERROR`. L'ordinamento e FIND confrontano byte: in una chiave `DB_TEXT` maiuscole e minuscole, e lettere accentate, sono diverse. Un campo `DB_ALPHA` (tipo 2, dalla versione 23) è testo come `DB_TEXT`, ma come chiave si ordina e si trova senza maiuscole né accenti: ΕΛΕΝΗ, Ελένη ed ελένη, o Élodie ed ELODIE, sono la stessa cosa; il record tiene il testo com'è stato scritto. Esempi sono STREETS (`myapps/streets`), uno stradario, e DATABASE (`myapps/database`), un intero programma di database con tabelle, lista e modulo; `tools/vdb.py` mostra e controlla un file `.VDB` sul PC.

### Formule (versione 24)

`VOS_EXT` con A = `VX_CALC` e C = una chiamata `CALC_*` calcola formule, come un foglio di calcolo. Il kernel carica il motore, `CALC.SYS`, dall'unità A: la prima volta. Un numero è di 32 bit, in centesimi (1234 è 12.34), da -21474836.46 a 21474836.46. Una formula ha `+ - * /`, parentesi, numeri (`12`, `3.5`, `.25`; un terzo decimale arrotonda), celle (da `A1` a `Z255`) e le funzioni SUM, AVG, MIN, MAX, COUNT (di valori, celle e intervalli come `B2:D9`, separati da `,` o `;`), ABS(x), INT(x) (verso il basso, a un intero) e ROUND(x) o ROUND(x, 0–2), in maiuscolo o no. Prodotti e quozienti si arrotondano al centesimo.

DE → il blocco del programma, `CB_SIZE` (10) byte: `CB_RESULT` (un numero, 4 byte), `CB_COLS`, `CB_ROWS`, `CB_GRID` (dw), `CB_BANK`, `CB_AT`. Le celle sono una griglia del programma: `CB_COLS` × `CB_ROWS` numeri di 4 byte, riga dopo riga, a `CB_GRID`, nel suo banco dati quando `CB_BANK` = `VOS_DATA`. Una cella `CALC_NONE` non ha un numero (vuota, o testo: 0 in `+ - * /`, le funzioni la saltano); `CALC_BAD` ha un errore.

| Chiamata | Ingresso → uscita |
|---|---|
| `CALC_EVAL` | HL → formula, 0 (con `=` davanti o no) → `CB_RESULT` e DE:HL (DE la parte alta) |
| `CALC_NUMBER` | HL → testo: solo un numero? → come `CALC_EVAL` |
| `CALC_TEXT` | `CB_RESULT` → testo in HL (spazio per 13 byte: `-12.5`), A = la sua lunghezza |
| `CALC_CELL` | HL → testo: una cella (`b12`) all'inizio? → D = colonna, E = riga (da 0), A = i suoi caratteri |

Errori: carry e A (`CALC_ERR_*`: 30 formula sbagliata, 31 divisione per zero, 32 numero troppo grande, 33 cella fuori dalla griglia, 34 una cella usata ha un errore, 29 `CALC.SYS` non è su A:), che `VOS_ERROR` mostra; allora `CB_RESULT` = `CALC_BAD` e `CB_AT` = il punto nel testo. L'esempio è SHEET (`myapps/sheet`), un foglio di calcolo che tiene i suoi valori nel suo banco dati e ricalcola le formule dopo ogni modifica.

I dettagli completi, ad es. sul background, sull'accessorio e su `VOS_SPLIT`, sono in `src/api/vos_api.inc`. Per esempi, vedi `apps/demo/demo.asm` (modo 0, movimento), `apps/clock/clock.asm` (accessorio) e `apps/mixed/mixed.asm` (schermo misto). Un gioco intero con sprite, un livello letto da file e suono è `myapps/vrouves/`.

Un assistente IA che scrive un programma deve leggere [`AI.md`](AI.md) (in inglese): le stesse regole, più brevi, con le trappole di RASM e del banco dati.

## Test

`make test-sdk` costruisce il modello come TEMPLATE.BIN e lo apre dal Launcher in Caprice32, con pressioni di tasti definite da `src/kernel/test_script.asm` (script 15). Cattura schermate in `build/shots`: la sua schermata, il riquadro dopo che si è mosso, il suo menu, il dialogo ABOUT e il ritorno al Launcher.

Per un tuo test automatico, copia lo script 15 e il target `test-sdk` del Makefile.
