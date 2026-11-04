# 3. I programmi

## Avvio e chiusura

Un programma si avvia in uno di questi modi:

- dal Launcher: selezionalo e premi RETURN, oppure fai clic due volte
- dalla Scrivania o dal Commander: FILE > AVVIA
- da un altro programma, come Studio, che avvia quello che crei

Ogni programma ha il proprio menu accanto ai comuni VISTA e AIUTO. Si chiude dal suo menu (di solito BACK o STOP, CONTROL+Q) e torna alla vista da cui era stato avviato.

## Più programmi insieme

I programmi V-OS sono di due tipi:

- **Piccoli, con una tabella di rilocazione:** DEMO, MIXED e CLOCK, gli esempi dell'editor web (PONG, CATCH, STARCAT, COUNTER) e tutto quello che crea l'[SDK](../../../sdk/README.it.md). Condividono 12K di memoria, e ne girano insieme quanti ce ne stanno.
- **Programmi che hanno bisogno di tutta la memoria:** STUDIO e quello che crea Studio (CALC, MINES, FLAP, TICKER e i tuoi). Così anche MARKDOWN e READER, che superano i 12K. Senza un'espansione di memoria girano da soli. Se uno è già in esecuzione, compare "CHIUDI PRIMA UN ALTRO PROGRAMMA".

Quando passi a una vista (F1–F4) mentre un programma è in esecuzione:

- Un programma piccolo resta in memoria. Lo riprendi dal Launcher (RETURN su di esso) o con F6, e riprende esattamente da dove era.
- Un programma che ha tutta la memoria si chiude, a meno che non ci sia un'espansione di memoria.

**F6** (VISTA > PROGRAMMI) mostra l'elenco dei programmi in esecuzione. Ne scegli uno con le frecce e RETURN. Se non ce n'è nessuno, compare "NESSUN PROGRAMMA IN ESECUZIONE".

**Con un'espansione di memoria** (ad es. 512K, che V-OS trova da solo all'avvio), ogni programma che ha bisogno di tutta la memoria riceve un proprio banco. Così STUDIO, CALC, DEMO e PONG possono girare tutti insieme. Dalla M43 ogni programma riceve anche un proprio banco dati di 16K quando gli serve: ciò che vi tiene non si perde mentre girano altri programmi o viste.

## In background

Un programma dietro un altro, o dietro una vista, normalmente **si blocca** e riprende quando torna in primo piano.

Alcuni programmi chiedono di **continuare a girare** anche in background, ad es. TICKER, che conta il tempo. Mentre sono lì non disegnano e non suonano. Quando tornano in primo piano, hanno contato anche il tempo in cui erano via.

In Studio lo scegli per il tuo programma con STUDIO > IN BACKGROUND.

MUSIC è l'eccezione: la sua canzone suona dall'interrupt, 50 volte al secondo, e quindi continua senza interruzioni dietro a tutto. Si ferma solo un attimo mentre si legge il dischetto.

## L'accessorio di scrivania (ACCESSORIO)

Un programma piccolo, come CLOCK, può aprirsi in una finestra **sopra qualsiasi cosa**: una vista o un programma.

1. Nel Launcher, seleziona CLOCK e scegli FILE > COME ACCESSORIO (^A).
2. Da quel momento, **F5** lo apre e lo chiude, ovunque tu sia. Anche ESC lo chiude.

Mentre è aperto, riceve i tasti e i clic. La sua finestra si può trascinare per il titolo. Quando si chiude, quello che c'era sotto viene ridisegnato.

## La pagina (modo 2)

NOTEPAD, MARKDOWN, READER e SHEET hanno PAGE (MODE 2) nel loro menu, ^M. Lo schermo passa al modo 2: testo nero su carta bianca, 768 pixel di larghezza, con menu e dialoghi anch'essi neri su bianco. Gli editor (NOTEPAD e MARKDOWN) mostrano 80 colonne tra i bordi della pagina, una riga dove finisce ogni pagina di 60 righe, e PAGE n nell'ultima riga. L'anteprima di MARKDOWN e READER mostrano la pagina in 80 colonne con i suoi stili. SHEET mostra 10 colonne (A–J) con righe tra loro. ^M di nuovo torna al modo 1.

## I programmi sul dischetto

Un dischetto del CPC contiene 180K, così V-OS arriva su due. `vos.dsk` (A:) ha il sistema, DEMO, MIXED, STUDIO e CLOCK, e i sorgenti `.VBS` dei programmi VB, che Studio apre da A:. `apps.dsk` (B:) ha gli altri, da PONG a WEBGET: nel Launcher, TAB mostra B:. Alcuni programmi hanno un dischetto proprio, come dice la tabella.

| Programma | Cos'è |
|---|---|
| **STUDIO** | l'editor a blocchi: crei programmi sul CPC ([capitolo 5](05-studio.md)) |
| **DEMO** | il primo programma V-OS: un quadrato che si muove da solo. Le frecce lo guidano e SPAZIO ne cambia il colore |
| **MIXED** | lo "schermo misto": una fascia a 16 colori (modo 0) tra fasce in modo 1. Un clic mostra le coordinate |
| **CLOCK** | il tempo trascorso dall'avvio di V-OS; con una scheda M4 l'ora reale e, come programma, la data (dal server dell'ora della M4, impostato con `NETSET` sul CPC). Gira anche come accessorio di scrivania |
| **CALC** | una calcolatrice in una finestra con pulsanti, fatta in Studio (c'è anche `CALC.VBS`) |
| **MINES** | un campo minato 8×6 con 8 mine, fatto in Studio. Un clic apre una casella, e NEW inizia una nuova partita |
| **BRICKS** | rompi-mattoni: una racchetta con ←/→, 32 mattoni, 3 vite, livelli con una palla sempre più veloce. A GAME OVER, SPAZIO per una nuova partita |
| **VROUVES** | tower defence, dal gioco per CPC LET'S GO FOR VROUVES: 7 livelli, dal Kafenio al cimitero, con 10 ondate ciascuno. È sul suo dischetto, `vrouves.dsk`: in B:, e TAB nel Launcher. Le frecce muovono il cursore, 1–6 sceglie un difensore, SPAZIO costruisce, S vende, N chiama l'ondata successiva, P mette in pausa. Punti per ogni invasore e per gli abitanti rimasti alla fine di un livello. Il dischetto conserva `VROUVES.SAV`: CONTINUE riparte dal livello raggiunto, HIGH SCORES mostra i cinque migliori con i nomi. Scritto con l'SDK (`myapps/vrouves`) |
| **NOTEPAD** | un editor di testo in modo 1, 48×22, per file fino a 4K, o fino a 16K con un'espansione di memoria: allora tiene circa 2,5K intorno al cursore nella sua memoria e il resto nel suo banco dati, e SELECT ALL prende quella parte. NEW, OPEN (solo file `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Frecce, DEL, CLR e RETURN; un clic posiziona il cursore. La riga in basso mostra riga e colonna. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi. PRINT ^P stampa il testo su una stampante. UNDO ^Z (menu EDIT) annulla l'ultima modifica: ciò che è stato digitato o incollato, o ciò che hanno tolto DEL, CLR, CUT o la digitazione sopra una selezione (fino a 256 caratteri); ^Z di nuovo la rifà (`myapps/notepad`) |
| **PAINT** | disegno in modo 0 con 16 colori: un'immagine di tutto lo schermo del CPC, 160×200 senza l'overscan (`.SCR`, 16K, che caricano anche il BASIC e gli altri programmi del CPC; senza espansione di memoria 128×128, `.PIC`), o 64×64 con zoom 2× in 3 livelli (`.LYR`, NEW LAYERS). Strumenti: P matita, B pennello, L linea, X rettangolo, F riempimento; TAB cambia il colore. Frecce e COPY disegnano senza mouse. La finestra mostra 128×128 dell'immagine: le barre alla sua destra e sotto mostrano quale parte, e un clic o un trascinamento su di esse la sposta. Sotto i colori: dov'è il puntatore nell'immagine, e VIEW, l'angolo in alto a sinistra della finestra. Livelli: 1–3 ne sceglie uno, H lo nasconde o lo mostra, U e D lo spostano su e giù, E è la gomma. UNDO ^Z annulla l'ultimo strumento, e ^Z di nuovo lo ripristina (un riempimento di tutto lo schermo non si può annullare; dopo che è stato eseguito un altro programma non c'è niente da annullare). EXPORT .SCR (per l'immagine 128×128 e i livelli; tutto lo schermo è già un `.SCR`): l'immagine (i livelli come si vedono) come schermo del CPC, un `NOME.SCR` di 16K (modo 0, al centro, con la palette), per il BASIC o altri programmi. In BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | suona brani di Arkos Tracker 3 (`.MUS`, fatti con `make songs`), con tre barre del volume. È sul suo dischetto, `music.dsk`, in B:. OPEN, SPAZIO suona e ferma. La musica continua dietro altre viste e programmi, senza interruzioni, anche mentre un altro programma carica o disegna: suona dall'interrupt. Il blocco MUSIC di Studio lo avvia dietro un programma con una canzone (`myapps/music`) |
| **MARKDOWN** | un editor di file Markdown (`.MD`, fino a 6K), come NOTEPAD. ^P mostra la pagina: titoli `#`, **grassetto**, *corsivo*, `codice`, elenchi, citazioni, linee, blocchi di codice e link sottolineati, senza i segni. Le righe una dopo l'altra formano un paragrafo (due spazi alla fine spezzano la riga). Le frecce scorrono la pagina, RETURN o ^P tornano al testo. È sul suo dischetto, `markdown.dsk`, con un `README.MD`. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi (`myapps/markdown`) |
| **SHOW** | le immagini `.SCR` di un'unità una dopo l'altra, in modo 0, con i loro colori (quelli di PAINT): la seguente ogni cinque secondi, → e ← a mano, SPACE ferma e riprende, ^W l'altra unità (A:, B:, DISK). Fino a 48 immagini (`myapps/show`) |
| **SYSINFO** | mostra le versioni di V-OS e dell'API, la memoria (tutta e quella libera per i programmi) e lo spazio libero sui dischetti in A: e B: (^R di nuovo). Un esempio di `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | scarica file dal web con la scheda M4: GET A FILE (^G) chiede un indirizzo (HTTP, p. es. `example.com/index.html`) e un nome, e il file (fino a 16K) si salva sull'unità mostrata (OTHER DRIVE). Mostra anche lo stato della rete. Senza scheda M4: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | legge pagine Markdown (`.MD`, fino a 6K) dal dischetto o dal web con la scheda M4, mostrate come l'anteprima di MARKDOWN. TAB sceglie il collegamento successivo (invertito), RETURN lo apre, DEL torna alla pagina precedente (ne tiene 4). Un collegamento senza `http://` si apre accanto alla pagina, sul dischetto o sullo stesso sito. OPEN A FILE e OPEN AN ADDRESS (^U, HTTP, p. es. `example.com/README.md`). Gli indirizzi `https://` non si aprono. È sul suo dischetto, `reader.dsk`, con `INDEX.MD` e `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | uno stradario in un database di V-OS: scrivi le prime lettere di una via e vedi le vie che iniziano così, con zona e CAP; DEL cancella una lettera. ^A aggiunge una via, ^D cancella la prima della lista. Le vie sono in `STREETS.VDB` sul suo disco, `streets.dsk`, in B:; la prima volta lo crea con vie di Atene. Un esempio dell'API dei database (`myapps/streets`) La ricerca ignora maiuscole, minuscole e accenti. |
| **DATABASE** | database, come un piccolo Access: ^N un database nuovo (`NOME.VDB`), ^O aprirne uno, ^T una tabella nuova (il suo nome, e campi: un nome, TESTO fino a 40 caratteri o NUMERO 0–65535, e se è ordinata per il primo). La lista mostra un record per riga e i campi in colonne; le frecce scelgono e scorrono, TAB passa alla tabella seguente, e se la tabella ha una chiave, ciò che scrivi va ai record che iniziano così (senza maiuscole né accenti). RETURN apre il modulo: un campo per riga, RETURN lo cambia, ^S salva, ^B torna alla lista. ^A un record nuovo, ^D cancella, ^W l'altra unità, ^P stampa la tabella come la mostra la lista, tutti i record. IMPORT CSV aggiunge un record per ogni riga di un `.CSV` alla tabella in uso: i campi in ordine, separati da virgole o da punti e virgola, i testi tagliati alla loro lunghezza, i numeri dalle loro cifre; una prima riga che inizia col nome del primo campo (le intestazioni) viene saltata. Apre anche i `.VDB` di STREETS (`myapps/database`) |
| **SHEET** | un foglio di calcolo: 16 colonne (A–P) e 64 righe, 5 colonne e 19 righe sullo schermo. Una cella contiene, fino a 40 caratteri, un numero (`12`, `-3.5`; il separatore decimale è un punto), testo, o una formula dopo `=`: `+ - * /`, parentesi, celle (`B3`), SUM, AVG, MIN, MAX e COUNT di celle e intervalli (`=SUM(B2:B9)`), ABS, INT, ROUND(x, 0–2). I numeri hanno due decimali, fino a ±21474836.46. Le frecce muovono il cursore, RETURN cambia la cella, digitando si comincia un testo nuovo, DEL (o CLR) la svuota; dopo ogni modifica tutte le formule si ricalcolano. La prima riga mostra il testo della cella. Una cella con un errore mostra `#ERR`, un numero che non ci sta `########`. ^N nuovo, ^O apri, ^S salva, ^A salva come (`NOME.VSH`, un file di testo, una riga per cella: `B3 =B1*2`), ^W l'altra unità, ^P stampa il foglio come lo mostra la pagina, le colonne A–H e poi I–P, fino all'ultima riga usata. ^G CHART: un intervallo di una colonna o di una riga (`B2:B9`, fino a 16 celle; all'inizio la colonna del cursore fino al suo ultimo numero) come barre in modo 0, ognuna alta quanto la cella rispetto alla più grande, con i testi della colonna A (o della riga 1) sotto; ^S salva il grafico come `.SCR` (le barre, senza i testi), che PAINT e il BASIC aprono, ogni altro tasto torna indietro. OPEN CSV legge un `.CSV` (da un foglio di calcolo del PC, o da un database): una riga del file per riga, i campi dalla colonna A, separati da virgole o da punti e virgola (la prima riga mostra quali); i campi tra virgolette possono contenerli, e con i punti e virgola `1,5` è il numero 1.5. Salvato, diventa un `.VSH` con lo stesso nome. Le formule le calcola `CALC.SYS` su A:, che ogni programma può usare (`VX_CALC`). È su un suo dischetto, `sheet.dsk`, con l'esempio `BUDGET.VSH` (`myapps/sheet`) |
| **PONG** | una palla e una racchetta con le frecce, punteggio e vite |
| **CATCH** | prendi le stelle che cadono |
| **STARCAT** | un gatto con costumi che cammina, una stella, una melodia da una lista |
| **COUNTER** | un contatore con i pulsanti +1, −1 e 0, in modo 1 |
| **FLAP** | un uccello che batte le ali (costumi), e una stella che cambia costume ogni secondo |
| **TICKER** | conta i secondi e continua in background |

- I programmi a blocchi sono file `.VBN`. Hanno un menu PROGRAM > STOP (CONTROL+Q).
- Quelli che hanno anche un `.VBS` (CALC, MINES, FLAP, TICKER) si aprono in Studio, così puoi guardarli o modificarli.
- `VBRUN.SYS` non è un programma: è il "player" di cui Studio ha bisogno.

## Stampa

NOTEPAD, SHEET e DATABASE stampano con ^P (PRINT nel loro menu) su una stampante collegata alla porta stampante del CPC (Centronics), come la Amstrad DMP2000 o una compatibile Epson.

- **Sette bit:** la porta del CPC invia 7 bit, quindi le lettere sopra 127 escono come lettere semplici: gli accenti vengono tolti (É → E, ñ → n, ß → s) e il greco è scritto in Greeklish, lettera per lettera (Α → A, Θ → 8, Ξ → 3, Ψ → 4, Ω → W).
- **La fine:** ogni stampa termina con una pagina nuova.
- **Nessuna stampante:** se la stampante resta occupata per due secondi (nessuna collegata, fuori linea, senza carta), appare LA STAMPANTE NON È PRONTA e la stampa si ferma.
- I programmi stampano con la chiamata `VX_PRINT` (capitolo 7).

