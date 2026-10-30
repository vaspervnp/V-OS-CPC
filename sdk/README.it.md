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

Questo costruisce `build/HELLO.BIN` e lo mette sul dischetto `build/vos.dsk`.

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
- Con una sottocartella `owndisc/`, il programma ha anche un dischetto suo, `build/<nome>.dsk`, con il `.BIN` e i file di `owndisc/`. Lo metti in B: e lo avvii dal Commander (FILE > AVVIA). Il drive da cui è partito, per caricare da lì i suoi file, è in `VOS_SELF`: `db drive`, poi il suo nome (11 byte).
- Un programma con tabella di rilocazione (come quelli dell'SDK) può arrivare a 12K. Per il resto, carica file nel banco dati.

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
- **Memoria:** non mappare un altro banco a `#4000`, perché il programma ti sparirebbe da sotto. Per altri 16K c'è il banco dati (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). È condiviso con le viste e con altri programmi, e conserva i suoi dati solo mentre il programma è in esecuzione.
- **Coordinate:** x in pixel del modo (modo 0: 0–191, modo 1: 0–383), y da 0 a 258. La barra dei menu occupa y 0–11.
- **RASM:** le etichette non distinguono maiuscole e minuscole (`BOX` e `box` sono la stessa). L'esadecimale si scrive con `#` e non con `&`.

## I formati dei dati

- **Barra dei menu** (`VOS_SET_BAR`): `db count; dw menu, ...`. I comuni VISTA e AIUTO vengono da `VOS_MENU_VIEW` e `VOS_MENU_HELP`.
- **Menu:** `db title, count` e per ogni voce `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` per una linea
  - command: 1.., quello che restituisce `VOS_UI_EVENT`
  - letter: scorciatoia CONTROL+lettera, o 0
- **Pulsanti** (`VOS_SET_WIDGETS`, poi `VOS_DRAW_WIDGETS`): `db count`, e per ogni pulsante `dw x, y; db larghezza in caratteri, text, command, 0`.
- **Dialogo** (`VOS_DIALOG` → A = pulsante, 0 il primo, ESC dà l'ultimo): `db title, text, numero di pulsanti (1–3), pulsante, ...`. Per i pulsanti, `VM_OK`, `VM_YES` e `VM_NO`.
- **Testi** (`VOS_TEXTS`): creati da `tools/mktexts.py` a partire da `texts.txt`, con righe `NAME | English | Greek`.
  - Dà `T_NAME` (`VT_FIRST` = `#C0` e oltre) e la tabella `texts:`. Fino a 64 testi.
  - Un `|` senza spazi intorno inizia una nuova riga nei dialoghi.
  - I testi vanno dove viene chiesto un "testo" (menu, pulsanti, dialoghi). Con `VOS_MSG` ottieni il loro indirizzo per `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`): 17 colori del firmware (0–26): 16 penne e il bordo. In modo 1 contano le penne 0–3.
- **Rettangolo** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icona:** 16 righe di 16 caratteri in `icon.txt`. Ogni carattere è una penna in esadecimale (modo 0, palette del Launcher) o `.` per trasparente.
- **Nomi di file** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 byte, `"NAME    EXT"`. Unità 0 = A:, 1 = B:.

## L'API (versione 11)

| Chiamata | Ingresso → uscita | Cosa fa |
|---|---|---|
| `VOS_EXIT` | — | fine, ritorno alla vista che l'ha avviato |
| `VOS_TICKS` | A = 1 / 0 | `VE_FRAME` 50 volte al secondo, o nessuno |
| `VOS_FRAMES` | → HL (e A bit 16–23) | frame dall'avvio |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = comando | i comandi comuni di VISTA e AIUTO |
| `VOS_ERROR` | A = errore | dialogo di errore |
| `VOS_MODE` | A = 0 / 1 | modo 0 (192×259, 16 penne) o 1 (384×259, 4 penne) |
| `VOS_PALETTE` | HL → 17 colori | |
| `VOS_CLS` | A = penna | cancella lo schermo |
| `VOS_PLOT` | HL = x, DE = y, A = penna | un pixel |
| `VOS_RECT` | IX → rettangolo | rettangolo pieno |
| `VOS_COLOURS` | A = penna del testo, C = sfondo | per `VOS_PRINT` e `VOS_CHAR` |
| `VOS_PRINT` | HL = x, DE = y, BC → testo, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = carattere | |
| `VOS_MSG` | A = testo → HL | l'indirizzo di un testo (`T_*` o uno di sistema) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → barra dei menu | |
| `VOS_UI_EVENT` | (l'evento corrente) → A | comando di menu, pulsante o scorciatoia, 0 per nessuno |
| `VOS_DIALOG` | HL → dialogo → A | |
| `VOS_INPUT` | A = titolo, HL → testo, C = massimo → carry se annullato | inserimento di testo (servono C + 2 byte) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → pulsanti | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | i menu comuni |
| `VOS_CATALOG` | A = unità → A = file, HL → elenco | 16 byte ciascuno: 11 il nome, a +12 la dimensione in K |
| `VOS_FILE_PICK` | A = titolo → A = file, carry se annullato | dialogo di scelta, dopo `VOS_CATALOG` |
| `VOS_LOAD` | A = unità, HL → nome, DE = dove → BC = lunghezza | |
| `VOS_SAVE` | A = unità, HL → nome, DE = da, BC = lunghezza | file binario, che sostituisce il vecchio |
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

I dettagli completi, ad es. sul background, sull'accessorio e su `VOS_SPLIT`, sono in `src/api/vos_api.inc`. Per esempi, vedi `apps/demo/demo.asm` (modo 0, movimento), `apps/clock/clock.asm` (accessorio) e `apps/mixed/mixed.asm` (schermo misto). Un gioco intero con sprite, un livello letto da file e suono è `myapps/vrouves/`.

## Test

`make test-sdk` costruisce il modello come TEMPLATE.BIN e lo apre dal Launcher in Caprice32, con pressioni di tasti definite da `src/kernel/test_script.asm` (script 15). Cattura schermate in `build/shots`: la sua schermata, il riquadro dopo che si è mosso, il suo menu, il dialogo ABOUT e il ritorno al Launcher.

Per un tuo test automatico, copia lo script 15 e il target `test-sdk` del Makefile.
