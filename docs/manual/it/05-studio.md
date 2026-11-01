# 5. Studio: programmi con i blocchi

STUDIO è un editor a blocchi in stile Scratch che gira sul CPC stesso.

- Crei sprite e script con i blocchi.
- Il programma parte subito con CONTROL+R.
- Diventa un normale programma V-OS (`.VBN`) che si avvia anche dal Launcher.

## Lo schermo

Studio usa uno schermo "diviso", con due zone:

- **In alto, in modo 0 (16 colori):**
  - **a sinistra, lo stage** (il palcoscenico) a metà dimensione
  - **a destra, il pannello SPRITES:** gli sprite con il loro colore e la loro posizione, la dimensione di quello selezionato (W, H), lo sfondo e il modo del programma (ad es. `STAGE 2 M1`), e il nome del file
- **In basso, in modo 1:**
  - **a sinistra, la palette** con i blocchi di una categoria (`< EVENTS >`)
  - **a destra, lo script**, una riga per blocco
  - **in fondo, la riga di stato**, con i tasti che funzionano dove ti trovi

**TAB** va dallo script alla palette, poi allo stage, e di nuovo allo script.

## Menu

| STUDIO | | EDIT |
|---|---|---|
| NEW | ^N | DELETE LINE |
| OPEN (`.VBS`) | ^O | + SPRITE (fino a 6) |
| SAVE | ^S | − SPRITE |
| SAVE AS | | BACKGROUND (il colore dello stage) |
| RUN | ^R | SCREEN MODE (0 o 1) |
| IN BACKGROUND | | TEXT LANGUAGE (^T) |
| BACK | ^Q | |

- **RUN (^R):** salva `NAME.VBS`, scrive `NAME.VBN` e lo avvia. Il programma si ferma dal proprio menu (PROGRAM > STOP, ^Q), e poi Studio riparte con lo stesso programma aperto.
- **IN BACKGROUND:** chiede se il programma continua a girare quando è dietro un altro o dietro una vista, oppure si mette in pausa, che è il comportamento predefinito.
- **SCREEN MODE:**
  - **Modo 0:** 16 colori, 192 pixel di larghezza.
  - **Modo 1:** 4 colori (penne 0–3), 384 pixel di larghezza, e più testo.

## La palette

←/→ cambiano la categoria, ↑/↓ scelgono un blocco, e RETURN lo aggiunge sotto la riga dello script. Un clic su un blocco della palette fa lo stesso.

Un blocco che si apre (FOREVER, REPEAT, IF) entra insieme al suo END, e viene cancellato insieme a esso. Un blocco con un testo chiede subito il testo.

## Lo script

| Tasto | Cosa fa |
|---|---|
| ↑/↓ | riga |
| ←/→ | casella della riga (le caselle sono i valori dentro il blocco) |
| RETURN | senza casella selezionata: aggiunge il blocco della palette. Su una casella di testo: cambia il testo. Su una casella di tasto: aspetta che tu prema il tasto |
| CLR | cancella la riga |
| DEL | cancella l'ultima cifra di un numero |
| mouse | clic su una casella: la seleziona. Secondo clic: ne cambia il tipo |

Il programma è un elenco di righe:

- Ogni `WHEN …` inizia uno script, per uno sprite o per lo stage. Lo script arriva fino al `WHEN` successivo.
- Il rientro viene da solo dai blocchi che si aprono e si chiudono.
- Le righe prima del primo `WHEN` vengono ignorate.
- Tutto quello che resta aperto viene chiuso alla fine dello script.

### Cosa va in una casella

La riga di stato dice sempre che cosa accetta la casella.

**Casella di valore:**

| Tasto | Valore |
|---|---|
| 0–9, − | numero, un intero da −32768 a 32767 |
| A–H | variabile. Di nuovo la stessa lettera: A1, A2 … A15, e di nuovo A |
| X, Y | la posizione dello sprite dello script |
| R e cifre | RANDOM: un numero da 1 a n |
| K e un tasto | KEY: 1 mentre è tenuto premuto, altrimenti 0 |
| T e una cifra | TOUCHING: 1 quando lo sprite tocca lo sprite n |
| Z | AT EDGE: 1 quando lo sprite è al bordo dello stage |
| P | BUTTON: il numero dell'ultimo pulsante premuto |
| U | COSTUME: il numero del costume dello sprite (0: nessun costume) |

**Altri tipi di casella:**

- **Variabile:** A–H, e di nuovo la stessa lettera per A1…A15.
- **Confronto:** `<`, `=`, `>`. SPAZIO dà "nessuno" (NONE), e allora IF controlla solo che il primo valore non sia 0.
- **Sprite** (nei blocchi `WHEN`): 0 lo stage, 1–6 uno sprite.
- **Tasto** (in `WHEN KEY`): RETURN e poi il tasto.
- **Testo:** RETURN, e scrivi fino a 14 caratteri.
- **Gruppo di variabili** (SAVE/LOAD VARS): A–H passa al gruppo di otto successivo (A-H, A1-H1 … A15-H15), e SPAZIO dà ALL.

Le lettere vengono lette come tasti, quindi funzionano anche con la tastiera greca.

## Lo stage e gli sprite

| Tasto | Cosa fa |
|---|---|
| frecce | muovono lo sprite selezionato |
| 1–6 | selezionano uno sprite |
| C | colore successivo |
| W, H | larghezza, altezza |
| K | quale costume indossa (nessuno, 1, 2, …) |
| E | disegna il suo costume (uno nuovo, se non ne ha) |
| clic sullo stage | mette lì lo sprite |

Uno sprite senza costume è un rettangolo colorato.

### Costumi

**E** apre l'editor dei costumi al posto dello stage. Ha una griglia 16×16 con le 16 penne sotto.

| Tasto | Cosa fa |
|---|---|
| frecce | casella |
| SPAZIO, RETURN | colora la casella |
| 0–9, A–F | penna |
| `.` | trasparente |
| E, TAB | fatto |
| clic | su una casella: colora. Sulla riga delle penne: sceglie una penna |

Un programma ha fino a 8 costumi, condivisi da tutti gli sprite. La dimensione di uno sprite con un costume è 16×16. Sullo stage, x viene arrotondata a un byte intero (2 pixel in modo 0, 4 in modo 1).

## Tutti i blocchi

Nella colonna "Blocco", le caselle appaiono come nello script.

### EVENTS

| Blocco | Cosa fa |
|---|---|
| WHEN START *sprite* | lo script parte insieme al programma |
| WHEN KEY *tasto* *sprite* | parte quando si preme il tasto |
| WHEN CLICKED *sprite* | parte con un clic sullo sprite (o sullo stage) |
| WHEN I RECEIVE *n* *sprite* | parte quando viene inviato il messaggio n |
| SEND *n* | invia il messaggio n (n può essere anche una variabile) |

> Un messaggio fa ripartire **dall'inizio** ogni script che lo aspetta, anche se era già in esecuzione. Per questo uno script non dovrebbe inviare un messaggio a se stesso.

### CONTROL

| Blocco | Cosa fa |
|---|---|
| FOREVER … END | ripete per sempre |
| REPEAT *n* … END | n volte |
| IF *a* *confronto* *b* … [ELSE …] END | esegue le righe solo se il confronto è vero |
| WAIT *n* | aspetta n frame (50 = un secondo) |
| WAIT UNTIL *a* *confronto* *b* | aspetta finché il confronto è vero |
| STOP | termina questo script |

### MOTION

| Blocco | Cosa fa |
|---|---|
| GO TO *x* *y* | lo sprite va in x, y |
| CHANGE X *n*, CHANGE Y *n* | si sposta di n |
| SPEED *vx* *vy* | imposta la sua velocità |
| MOVE | un passo alla sua velocità |
| BOUNCE | al bordo dello stage, inverte la velocità |

### LOOKS/SOUND

| Blocco | Cosa fa |
|---|---|
| COLOUR *n* | la penna del rettangolo |
| COSTUME *n* | indossa il costume n (1–8. 0 non cambia nulla) |
| NEXT COSTUME | il successivo, e dopo l'ultimo di nuovo il primo |
| SHOW, HIDE | |
| PRINT *valore* AT *x* *y* | stampa un numero |
| STYLE *n* | lo stile di PRINT e TEXT che seguono: 1 grassetto, 2 corsivo, 4 sottolineato, sommati (7: tutti), 0 normale |
| NOTE *n* FOR *frame* | suona una nota (numero MIDI: 60 = do, 69 = la 440 Hz) e aspetta che finisca |
| MUSIC *"nome"* | suona la canzone *nome*`.MUS` dal dischetto del programma, dietro di esso, con il programma MUSIC (su A: o B:). Continua anche dopo la fine del programma, fino allo STOP di MUSIC (F6). Serve un'espansione di memoria; senza: "CHIUDI PRIMA UN ALTRO PROGRAMMA". Un nome che non c'è (o vuoto) ferma la musica |

### VARIABLES

| Blocco | Cosa fa |
|---|---|
| SET *variabile* TO *valore* | |
| CHANGE *variabile* BY *valore* | addizione |
| DECREASE *variabile* BY *valore* | sottrazione |
| MULTIPLY *variabile* BY *valore* | |
| DIVIDE *variabile* BY *valore* | divisione intera |
| REMAINDER *variabile* BY *valore* | il resto della divisione |
| SAVE VARS *gruppo* TO *"nome"* | scrive le variabili in un file di testo (vedi sotto) |
| LOAD VARS *gruppo* FROM *"nome"* | le rilegge |

### WINDOWS

| Blocco | Cosa fa |
|---|---|
| WINDOW *"titolo"* *larghezza* *altezza* | una finestra al centro dello stage, come i dialoghi di V-OS. Una nuova finestra prende il posto della precedente e dei suoi pulsanti |
| BUTTON *"testo"* AT *x* *y* | un pulsante di sistema. Si preme con un clic o con TAB e RETURN. I pulsanti sono numerati da 0, nell'ordine in cui appaiono |
| WHEN BUTTON *sprite* | parte quando viene premuto un pulsante qualsiasi. Il valore BUTTON (P) dice quale |
| TEXT *"testo"* AT *x* *y* | scrive un testo |
| LABEL *pulsante* TO *"testo"* | cambia il testo di un pulsante |

Con una finestra aperta, TEXT, BUTTON e PRINT contano dall'angolo in alto a sinistra del suo interno. La finestra si trascina per il titolo, insieme ai suoi pulsanti.

## Le variabili

Ci sono 128 variabili, condivise da tutti gli script, chiamate A–H, A1–H1, …, A15–H15. All'inizio valgono tutte 0, e contengono interi da −32768 a 32767.

### Salvare e ripristinare (SAVE VARS, LOAD VARS)

- `SAVE VARS ALL TO "GAME"` scrive tutte le 128 nel file `GAME.TXT`. Il `.TXT` viene aggiunto quando il nome non ha un tipo.
- Con un gruppo (`A-H`, `A1-H1`, …) scrive solo quelle 8.
- Il file è di testo, una riga per variabile:

  ```
  A=12
  B=0
  A1=-5
  ```

- `LOAD VARS ALL FROM "GAME"` cambia le variabili che il file nomina. Con un gruppo, cambia solo quelle che sono anche nel gruppo. Le righe che non capisce vengono ignorate, e se il file manca non cambia nulla.
- Così un file può ripristinare tutte le variabili o solo un gruppo di otto, ad es. le posizioni salvate di un gioco.

## I testi in altre lingue

I testi di un programma (finestre, pulsanti, TEXT, LABEL) possono avere una traduzione in ogni lingua di V-OS. Il programma li mostra nella lingua in cui è V-OS quando parte. Così CALC si chiama «ΑΡΙΘΜΟΜΗΧΑΝΗ» in greco, «CALCULATOR» in inglese, «CALCOLATRICE» in italiano.

- **EDIT > TEXT LANGUAGE (^T):** passa per le lingue EN, EL, FR, ES, DE, IT e torna ai testi del programma stesso. Sotto gli sprite, accanto al nome, si vede il codice della lingua (es. `CALC IT`).
- In una lingua, le caselle di testo mostrano e cambiano i testi in quella lingua. Un testo senza traduzione mostra il suo, e quando lo cambi diventa la sua traduzione. Un testo nuovo scritto in una lingua diventa anche il suo.
- Le traduzioni si salvano dentro il `.VBS` (e il `.VBN`), tutte e sei insieme, circa 3K.
- In un `.vbt` si scrivono con `LANG IT` seguito da righe `"testo" "traduzione"`.

## I file

- **`NAME.VBS`:** il programma come lo modifichi. OPEN lo apre, e vengono letti fino a 9K.
- **`NAME.VBN`:** il programma pronto da eseguire. RUN lo scrive, e si avvia anche dal Launcher. È il player (`VBRUN.SYS`) insieme al programma. Il player compila i blocchi in codice Z80 all'avvio, quindi i programmi sono veloci.

Un `.VBS` si può creare anche da un testo sul PC, con `tools/mkvbs.py`. La sintassi è descritta all'inizio del file, e gli esempi sono `blocks/examples/*.vbt` (CALC, MINES, FLAP, TICKER, VARS). CALC e MINES hanno anche le traduzioni (`LANG`).

## Limiti

| | |
|---|---|
| Righe (blocchi) | 240 |
| Sprite | 6 |
| Script (`WHEN …`) | 16 |
| Variabili | 128 |
| REPEAT in un programma | 64 (oltre, condividono un contatore) |
| Blocchi aperti annidati uno dentro l'altro | 16 |
| Testi | 32, fino a 14 caratteri ciascuno, e in 6 lingue |
| Costumi | 8, 16×16 |
| Pulsanti | 64 |
| Codice | almeno 4.000 byte, anche per il programma più grande. Quello che non ci sta viene ignorato |

## Consigli

- **Script dello stage:** i blocchi di movimento e di aspetto non fanno nulla, e X, Y, TOUCHING e AT EDGE danno 0.
- **TOUCHING:** vale solo quando entrambi gli sprite sono visibili.
- **Tempi:** gli script girano "insieme". Ogni script cede il turno alla fine di ogni ciclo e a ogni WAIT. Per far aspettare uno script un altro, usa una variabile e `WAIT UNTIL` (vedi MINES).
- **Esempi pronti:** CALC, MINES, FLAP e TICKER si aprono in Studio (OPEN).
