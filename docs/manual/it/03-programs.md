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

## Finestre

Con un'**espansione di memoria**, CLOCK, SYSINFO, DIARY, TELNET, MAIL, FTP, WEBGET e DATABASE si aprono in una **finestra** sulla scrivania, sopra le finestre degli altri programmi in esecuzione. Così anche un programma di Studio in modo 1 che apre una finestra propria (come CALC): la finestra ne mostra l'interno, con i suoi pulsanti. DIARY, TELNET, MAIL, FTP, WEBGET e DATABASE mostrano nella finestra il loro schermo com'era; rimpicciolita, ne mostra la parte in alto a sinistra. Anche NOTEPAD, MARKDOWN, READER e SHEET si aprono in una finestra e vi dispongono il loro testo: tante colonne e righe quante ne entrano, la riga di stato sotto, e di nuovo ogni volta che la ridimensioni. La loro pagina (^M), e il grafico di SHEET, vanno a schermo intero; ^M di nuovo riporta la finestra dov'era, grande com'era. Ogni finestra tiene una copia di sé in memoria, così quando sposti una finestra sopra le altre queste ricompaiono subito, senza che i loro programmi le ridisegnino. Sotto le finestre si vede l'immagine della scrivania (BACKGROUND in Setup). Anche la finestra dei file e le icone delle unità della scrivania sono tra le finestre: si vedono dietro i programmi, e sulla scrivania (F1) le finestre dei programmi si vedono sulla sua superficie. Un clic su una finestra la porta davanti, e un clic sulla finestra o sulle icone della scrivania riporta la scrivania. La X di una finestra chiede al suo programma di chiudersi come ^Q, così NOTEPAD, per esempio, chiede prima delle modifiche non salvate. Un programma in una finestra non cambia i colori dello schermo. TELNET, MAIL e FTP in una finestra continuano a ricevere quando sono dietro, se nessun'altra finestra li copre. L'accessorio (F5) e l'elenco dei programmi (F6) si aprono sopra le finestre. Gli altri programmi si aprono ancora a schermo intero.

- La barra dei menu resta in alto ed è quella della finestra **davanti**. Un clic su un'altra finestra la porta davanti, con la sua barra.
- Trascina il **titolo** di una finestra per spostarla, e il suo **angolo in basso a destra** per cambiarne la dimensione. Il programma dispone ciò che mostra per la nuova dimensione.
- Il **+** nel titolo, o **F7**, dà al programma tutto lo schermo (sotto la barra), e di nuovo una finestra. **X** chiude il programma.
- L'orologio **continua a scorrere** mentre un'altra finestra è davanti, purché nessuna lo copra.

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
| **NOTEPAD** | un editor di testo in modo 1, 48×22, per file fino a 4K, o fino a 16K con un'espansione di memoria: allora tiene circa 2,5K intorno al cursore nella sua memoria e il resto nel suo banco dati, e SELECT ALL prende quella parte. NEW, OPEN (solo file `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Frecce, DEL, CLR e RETURN; un clic posiziona il cursore. La riga in basso mostra riga e colonna. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi. PRINT ^P stampa il testo su una stampante. UNDO ^Z (menu EDIT) annulla l'ultima modifica: ciò che è stato digitato o incollato, o ciò che hanno tolto DEL, CLR, CUT o la digitazione sopra una selezione (fino a 256 caratteri); ^Z di nuovo la rifà. FIND ^F (menu EDIT) cerca un testo dal cursore in poi, in tutto il testo (A–Z senza maiuscole), e lo seleziona; FIND AGAIN ^G il seguente; REPLACE ^R chiede il testo e cosa mettere al suo posto, e lo cambia in tutto il testo (NOT FOUND se non c'è) (`myapps/notepad`) |
| **PAINT** | disegno in modo 0 con 16 colori: un'immagine di tutto lo schermo del CPC, 160×200 senza l'overscan (`.SCR`, 16K, che caricano anche il BASIC e gli altri programmi del CPC; senza espansione di memoria 128×128, `.PIC`), o 64×64 con zoom 2× in 3 livelli (`.LYR`, NEW LAYERS). Strumenti: P matita, B pennello, L linea, X rettangolo, F riempimento, C cerchio (dal centro a dove si rilascia il pulsante); TAB cambia il colore. Frecce e COPY disegnano senza mouse. La finestra mostra 128×128 dell'immagine: le barre alla sua destra e sotto mostrano quale parte, e un clic o un trascinamento su di esse la sposta. Sotto i colori: dov'è il puntatore nell'immagine, e VIEW, l'angolo in alto a sinistra della finestra. Livelli: 1–3 ne sceglie uno, H lo nasconde o lo mostra, U e D lo spostano su e giù, E è la gomma. UNDO ^Z annulla l'ultimo strumento, e ^Z di nuovo lo ripristina (anche il riempimento, su tutto lo schermo oltre la finestra; dopo che è stato eseguito un altro programma non c'è niente da annullare). EXPORT .SCR (per l'immagine 128×128 e i livelli; tutto lo schermo è già un `.SCR`): l'immagine (i livelli come si vedono) come schermo del CPC, un `NOME.SCR` di 16K (modo 0, al centro, con la palette), per il BASIC o altri programmi. In BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | suona brani di Arkos Tracker 3 (`.MUS`, fatti con `make songs`), con tre barre del volume. È sul suo dischetto, `music.dsk`, in B:. OPEN, SPAZIO suona e ferma. La musica continua dietro altre viste e programmi, senza interruzioni, anche mentre un altro programma carica o disegna: suona dall'interrupt. Il blocco MUSIC di Studio lo avvia dietro un programma con una canzone (`myapps/music`) |
| **MARKDOWN** | un editor di file Markdown (`.MD`, fino a 6K), come NOTEPAD. ^P mostra la pagina: titoli `#`, **grassetto**, *corsivo*, `codice`, elenchi, citazioni, linee, blocchi di codice e link sottolineati, senza i segni. Le righe una dopo l'altra formano un paragrafo (due spazi alla fine spezzano la riga). Le frecce scorrono la pagina, RETURN o ^P tornano al testo. È sul suo dischetto, `markdown.dsk`, con un `README.MD`. Menu EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT e le frecce selezionano. Gli appunti (fino a 1K) sono comuni a tutti i programmi (`myapps/markdown`) |
| **DIARY** | i giorni e cosa c'è in essi: il mese in modo 1, una settimana per riga dal lunedì, il giorno scelto invertito e i giorni con note segnati `*`, e sotto le note del giorno scelto (fino a 10, di 40 caratteri). Le frecce si muovono di un giorno e di una settimana, `<` e `>` di un mese, TAB va alle note (UP/DOWN ne scelgono una, RETURN la cambia, DEL la elimina). ^A aggiunge una nota, ^T va a oggi. Con una scheda M4 parte da oggi; senza dall'ultimo giorno con una nota. Le note sono tenute in `DIARY.VDB` sull'unità da cui è stato avviato (^W l'altra unità), creato la prima volta, tramite `DB.SYS` (`myapps/diary`) |
| **SHOW** | le immagini `.SCR` di un'unità una dopo l'altra, in modo 0, con i loro colori (quelli di PAINT): la seguente ogni cinque secondi, → e ← a mano, SPACE ferma e riprende, ^W l'altra unità (A:, B:, DISK). Fino a 48 immagini (`myapps/show`) |
| **SYSINFO** | mostra le versioni di V-OS e dell'API, la memoria (tutta e quella libera per i programmi) e lo spazio libero sui dischetti in A: e B: (^R di nuovo). Un esempio di `VOS_EXT` (`myapps/sysinfo`) |
| **TELNET** | testo attraverso la rete con la scheda M4: ^O CONNECT chiede `HOST:PORTA` (un nome come `bbs.example.org`, o numeri come `192.168.1.10`; senza porta, 23) e si collega in TCP. Ciò che arriva si scrive nella finestra, che scorre verso l'alto alla fine; i colori e gli altri codici ANSI vengono tralasciati, il greco in ISO 8859-7 appare così com'è, e alle opzioni telnet dice di essere `V-OS` (TTYPE), così che un server come V-OS NET lo riconosca; finché l'altro capo fa l'eco (ECHO, per una password), la riga scritta in basso mostra `*` per ogni carattere; le altre opzioni vengono rifiutate. La riga scritta in basso parte con RETURN. ^D CLOSE chiude la connessione, come può fare l'altro capo; la prima riga mostra lo stato (CONNECTED, NO CONNECTION…). Senza scheda M4: NO M4 BOARD (`myapps/telnet`) |
| **MAIL** | posta elettronica con la scheda M4: ACCOUNT chiede i server POP3 e SMTP (`HOST:PORTA`; senza porta, 110 e 25), l'utente, la password e il tuo indirizzo, e li tiene in `MAIL.CFG` accanto a MAIL. ^G GET MAIL elenca i 20 messaggi più recenti, il più recente per primo (da chi, l'oggetto); RETURN legge quello scelto (UP/DOWN una riga, LEFT/RIGHT una pagina, RETURN o DEL l'elenco): il quoted-printable e il base64 vengono decodificati, l'UTF-8 e gli oggetti codificati diventano greco, e di un messaggio in più parti si vede il testo. ^S SAVE AS TEXT lo scrive come `.TXT`, ^D DELETE lo cancella sul server (quando la connessione finisce). ^W WRITE chiede TO e SUBJECT e invia un `.TXT` dell'unità mostrata (scritto in NOTEPAD; OTHER DRIVE la cambia), e ^R REPLY risponde a quello che leggi con «Re: ». Sotto il testo sono elencati gli allegati, e ^A SAVE ATTACHMENT ne salva uno: su DISK di qualsiasi dimensione, su A: o B: fino a 16K. Un messaggio più grande dello spazio mostra il suo inizio e lo dice. Solo connessioni semplici (niente SSL/TLS), quindi un server tuo o uno che le accetta; la password è tenuta così com'è (`myapps/mail`) |
| **FTP** | file da e verso un server FTP con la scheda M4: ^O CONNECT chiede `HOST:PORTA` (senza porta, 21), l'utente (nessuno: anonymous) e la password, ed elenca la cartella del server: le cartelle come `<DIR>`, i file con la loro dimensione. UP/DOWN scelgono, RETURN apre una cartella o prende un file, DEL (o ^U) sale di una cartella. ^G GET THE FILE lo salva (con un nome 8.3 che chiede) sull'unità mostrata (OTHER DRIVE): su DISK viene scritto sulla scheda man mano che arriva, di qualsiasi dimensione, così com'è; su A: o B: fino a 16K. ^P PUT A FILE invia un file di quell'unità (da DISK di qualsiasi dimensione), e ^D DELETE THE FILE lo cancella sul server. ^K CLOSE chiude la connessione; la prima riga mostra lo stato e la cartella (`myapps/ftp`) |
| **WEBGET** | scarica file dal web con la scheda M4: GET A FILE (^G) chiede un indirizzo (HTTP, p. es. `example.com/index.html`) e un nome, e il file (fino a 16K) si salva sull'unità mostrata (OTHER DRIVE). Mostra anche lo stato della rete. Senza scheda M4: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | legge pagine Markdown (`.MD`, fino a 6K) dal dischetto o dal web con la scheda M4, mostrate come l'anteprima di MARKDOWN. TAB sceglie il collegamento successivo (invertito), RETURN lo apre, DEL torna alla pagina precedente (ne tiene 4). Un collegamento senza `http://` si apre accanto alla pagina, sul dischetto o sullo stesso sito. OPEN A FILE e OPEN AN ADDRESS (^U, HTTP, p. es. `example.com/README.md`). Gli indirizzi `https://` non si aprono. È sul suo dischetto, `reader.dsk`, con `INDEX.MD` e `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | uno stradario in un database di V-OS: scrivi le prime lettere di una via e vedi le vie che iniziano così, con zona e CAP; DEL cancella una lettera. ^A aggiunge una via, ^D cancella la prima della lista. Le vie sono in `STREETS.VDB` sul suo disco, `streets.dsk`, in B:; la prima volta lo crea con vie di Atene. Un esempio dell'API dei database (`myapps/streets`) La ricerca ignora maiuscole, minuscole e accenti. |
| **DATABASE** | database, come un piccolo Access: ^N un database nuovo (`NOME.VDB`), ^O aprirne uno, ^T una tabella nuova (il suo nome, e campi: un nome, TESTO fino a 40 caratteri o NUMERO 0–65535, e se è ordinata per il primo). La lista mostra un record per riga e i campi in colonne; le frecce scelgono e scorrono, TAB passa alla tabella seguente, e se la tabella ha una chiave, ciò che scrivi va ai record che iniziano così (senza maiuscole né accenti). RETURN apre il modulo: un campo per riga, RETURN lo cambia, ^S salva, ^B torna alla lista. ^A un record nuovo, ^D cancella, ^W l'altra unità, ^P stampa la tabella come la mostra la lista, tutti i record. PRINT LETTERS ^L stampa un `.TXT` dell'unità (una lettera scritta in NOTEPAD) una volta per ogni record della tabella, una pagina ciascuna: il nome di un campo tra graffe, `{NAME}`, diventa ciò che il record vi contiene (senza maiuscole; un nome sconosciuto resta com'è). IMPORT CSV aggiunge un record per ogni riga di un `.CSV` alla tabella in uso: i campi in ordine, separati da virgole o da punti e virgola, i testi tagliati alla loro lunghezza, i numeri dalle loro cifre; una prima riga che inizia col nome del primo campo (le intestazioni) viene saltata. Apre anche i `.VDB` di STREETS (`myapps/database`) |
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
- **Le pagine:** ogni pagina inizia con un'intestazione, il nome del file e il numero della pagina (`NOTES.TXT  PAGINA 2`), e dopo 60 righe una pagina nuova inizia da sola.
- **La fine:** ogni stampa termina con una pagina nuova.
- **Nessuna stampante:** se la stampante resta occupata per due secondi (nessuna collegata, fuori linea, senza carta), appare LA STAMPANTE NON È PRONTA e la stampa si ferma.
- I programmi stampano con la chiamata `VX_PRINT` (capitolo 7).

