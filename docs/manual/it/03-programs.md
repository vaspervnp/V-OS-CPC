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
- **Programmi che hanno bisogno di tutta la memoria:** STUDIO e quello che crea Studio (CALC, MINES, FLAP, TICKER e i tuoi). Senza un'espansione di memoria girano da soli. Se uno è già in esecuzione, compare "CHIUDI PRIMA UN ALTRO PROGRAMMA".

Quando passi a una vista (F1–F4) mentre un programma è in esecuzione:

- Un programma piccolo resta in memoria. Lo riprendi dal Launcher (RETURN su di esso) o con F6, e riprende esattamente da dove era.
- Un programma che ha tutta la memoria si chiude, a meno che non ci sia un'espansione di memoria.

**F6** (VISTA > PROGRAMMI) mostra l'elenco dei programmi in esecuzione. Ne scegli uno con le frecce e RETURN. Se non ce n'è nessuno, compare "NESSUN PROGRAMMA IN ESECUZIONE".

**Con un'espansione di memoria** (ad es. 512K, che V-OS trova da solo all'avvio), ogni programma che ha bisogno di tutta la memoria riceve un proprio banco. Così STUDIO, CALC, DEMO e PONG possono girare tutti insieme.

## In background

Un programma dietro un altro, o dietro una vista, normalmente **si blocca** e riprende quando torna in primo piano.

Alcuni programmi chiedono di **continuare a girare** anche in background, ad es. TICKER, che conta il tempo. Mentre sono lì non disegnano e non suonano. Quando tornano in primo piano, hanno contato anche il tempo in cui erano via.

In Studio lo scegli per il tuo programma con STUDIO > IN BACKGROUND.

## L'accessorio di scrivania (ACCESSORIO)

Un programma piccolo, come CLOCK, può aprirsi in una finestra **sopra qualsiasi cosa**: una vista o un programma.

1. Nel Launcher, seleziona CLOCK e scegli FILE > COME ACCESSORIO (^A).
2. Da quel momento, **F5** lo apre e lo chiude, ovunque tu sia. Anche ESC lo chiude.

Mentre è aperto, riceve i tasti e i clic. La sua finestra si può trascinare per il titolo. Quando si chiude, quello che c'era sotto viene ridisegnato.

## I programmi sul dischetto

| Programma | Cos'è |
|---|---|
| **STUDIO** | l'editor a blocchi: crei programmi sul CPC ([capitolo 5](05-studio.md)) |
| **DEMO** | il primo programma V-OS: un quadrato che si muove da solo. Le frecce lo guidano e SPAZIO ne cambia il colore |
| **MIXED** | lo "schermo misto": una fascia a 16 colori (modo 0) tra fasce in modo 1. Un clic mostra le coordinate |
| **CLOCK** | il tempo trascorso dall'avvio di V-OS. Gira anche come accessorio di scrivania |
| **CALC** | una calcolatrice in una finestra con pulsanti, fatta in Studio (c'è anche `CALC.VBS`) |
| **MINES** | un campo minato 8×6 con 8 mine, fatto in Studio. Un clic apre una casella, e NEW inizia una nuova partita |
| **BRICKS** | rompi-mattoni: una racchetta con ←/→, 32 mattoni, 3 vite, livelli con una palla sempre più veloce. A GAME OVER, SPAZIO per una nuova partita |
| **VROUVES** | tower defence, dal gioco per CPC LET'S GO FOR VROUVES: 7 livelli, dal Kafenio al cimitero, con 10 ondate ciascuno. È sul suo dischetto, `vrouves.dsk`: in B:, e TAB nel Launcher. Le frecce muovono il cursore, 1–6 sceglie un difensore, SPAZIO costruisce, S vende, N chiama l'ondata successiva, P mette in pausa. Punti per ogni invasore e per gli abitanti rimasti alla fine di un livello. Il dischetto conserva `VROUVES.SAV`: CONTINUE riparte dal livello raggiunto, HIGH SCORES mostra i cinque migliori con i nomi. Scritto con l'SDK (`myapps/vrouves`) |
| **NOTEPAD** | un editor di testo in modo 1, 48×22, per file fino a 4K. NEW, OPEN (solo file `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Frecce, DEL, CLR e RETURN; un clic posiziona il cursore. La riga in basso mostra riga e colonna. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi (`myapps/notepad`) |
| **PAINT** | disegno in modo 0 con 16 colori: un'immagine 128×128 (`.PIC`), o 64×64 con zoom 2× in 3 livelli (`.LYR`, NEW LAYERS). Strumenti: P matita, B pennello, L linea, X rettangolo, F riempimento; TAB cambia il colore. Frecce e COPY disegnano senza mouse. Livelli: 1–3 ne sceglie uno, H lo nasconde o lo mostra, U e D lo spostano su e giù, E è la gomma (`myapps/paint`) |
| **MUSIC** | suona brani di Arkos Tracker 3 (`.MUS`, fatti con `make songs`), con tre barre del volume. È sul suo dischetto, `music.dsk`, in B:. OPEN, SPAZIO suona e ferma. La musica continua dietro altre viste e programmi (`myapps/music`) |
| **MARKDOWN** | un editor di file Markdown (`.MD`, fino a 6K), come NOTEPAD. ^P mostra la pagina: titoli `#`, **grassetto**, *corsivo*, `codice`, elenchi, citazioni, linee, blocchi di codice e link sottolineati, senza i segni. Le frecce scorrono la pagina, RETURN o ^P tornano al testo. È sul suo dischetto, `markdown.dsk`, con un `README.MD`. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi (`myapps/markdown`) |
| **SYSINFO** | mostra le versioni di V-OS e dell'API, la memoria (tutta e quella libera per i programmi) e lo spazio libero sui dischetti in A: e B: (^R di nuovo). Un esempio di `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | scarica file dal web con la scheda M4: GET A FILE (^G) chiede un indirizzo (HTTP, p. es. `example.com/index.html`) e un nome, e il file (fino a 16K) si salva sull'unità mostrata (OTHER DRIVE). Mostra anche lo stato della rete. Senza scheda M4: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | legge pagine Markdown (`.MD`, fino a 6K) dal dischetto o dal web con la scheda M4, mostrate come l'anteprima di MARKDOWN. TAB sceglie il collegamento successivo (invertito), RETURN lo apre, DEL torna alla pagina precedente (ne tiene 4). Un collegamento senza `http://` si apre accanto alla pagina, sul dischetto o sullo stesso sito. OPEN A FILE e OPEN AN ADDRESS (^U, HTTP, p. es. `example.com/README.md`). Gli indirizzi `https://` non si aprono. È sul suo dischetto, `reader.dsk`, con `INDEX.MD` e `ABOUT.MD` (`myapps/reader`) |
| **PONG** | una palla e una racchetta con le frecce, punteggio e vite |
| **CATCH** | prendi le stelle che cadono |
| **STARCAT** | un gatto con costumi che cammina, una stella, una melodia da una lista |
| **COUNTER** | un contatore con i pulsanti +1, −1 e 0, in modo 1 |
| **FLAP** | un uccello che batte le ali (costumi), e una stella che cambia costume ogni secondo |
| **TICKER** | conta i secondi e continua in background |

- I programmi a blocchi sono file `.VBN`. Hanno un menu PROGRAM > STOP (CONTROL+Q).
- Quelli che hanno anche un `.VBS` (CALC, MINES, FLAP, TICKER) si aprono in Studio, così puoi guardarli o modificarli.
- `VBRUN.SYS` non è un programma: è il "player" di cui Studio ha bisogno.
