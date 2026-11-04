# 2. Le viste

V-OS ha quattro "viste": modi di vedere i file e i programmi, e le impostazioni. Si cambia vista con F1–F4 o dal menu VISTA. Ogni vista ricorda quale file era selezionato, e la successiva seleziona lo stesso file.

## I menu comuni

Gli ultimi due menu sono uguali in tutte le viste e nei programmi:

| VISTA | | AIUTO | |
|---|---|---|---|
| SCRIVANIA | F1 | TASTI | ^K |
| PROGRAMMI | F2 | INFORMAZIONI SU V-OS | |
| COMMANDER | F3 | | |
| IMPOSTAZIONI | F4 | | |
| PROGRAMMI (in esecuzione) | F6 | | |
| CAMBIA LINGUA | ^L | | |

AIUTO > INFORMAZIONI SU V-OS mostra la versione (0.15 beta; ogni milestone aggiunge 0.01), la data della compilazione, l'autore (Revive8bit, 2026) e l'architetto (Vasper).

## Scrivania, F1

Modo 1. Una finestra FILE mostra i file di un'unità come icone, quattro per riga. Il tipo è scritto dentro l'icona e il nome sotto, e un `.VBN` ha accanto un segno di "play". A destra, due icone scelgono A: o B:. La barra del titolo mostra il formato del disco e il numero di file, e lo spazio libero è mostrato in basso.

| Tasto | Cosa fa |
|---|---|
| frecce | scelgono un file (↑/↓ una riga) |
| TAB | l'unità seguente: A:, B:, DISK (con una scheda M4) |
| RETURN, ENTER | apri: un programma si avvia, un file di un tipo noto si apre nel suo programma, gli altri mostrano le loro informazioni |
| ^C | copia sull'unità seguente (da DISK: su A:) |
| ^D | elimina (chiede prima) |
| ^N | rinomina |
| ^R | rilegge i dischi |
| mouse | clic su un file: selezione, di nuovo: apertura. Clic su un'unità: la apre |

- **Menu FILE:** APRI, INFO SUL FILE (^I), COPIA SULL'UNITÀ SEGUENTE, ELIMINA, RINOMINA, RILEGGI I DISCHI, ESCI IN BASIC.
- **La finestra FILE** si può trascinare per il suo titolo e resta lì, anche quando cambi vista.
- **All'inizio non c'è finestra né unità scelta:** si vede lo sfondo (e la sua immagine). Un'unità (un clic sulla sua icona, o TAB) apre la sua finestra; la X del titolo la chiude, come un clic sull'unità aperta. Il quadratino nell'angolo in basso a destra ingrandisce o rimpicciolisce la finestra a icone intere (2–5 per riga, 1–5 righe; quattro per cinque all'inizio), e la barra a destra mostra quale parte della lista si vede: un clic sopra o sotto la sua parte scura scorre di una finestra. La dimensione resta, come il posto.
- **Apertura per tipo** (anche nel Commander): i `.TXT` si aprono in NOTEPAD, i `.MD` in MARKDOWN, i `.PIC` e `.LYR` in PAINT, i `.VDB` in DATABASE, i `.VSH` in SHEET, i `.MUS` in MUSIC, che comincia a suonarli. Il programma si cerca sull'unità del file, poi su A:, poi su B:. Se non si trova, appare "NESSUN PROGRAMMA PER QUESTO FILE". Se il programma ha modifiche non salvate, chiede prima.

## Launcher (PROGRAMMI), F2

Modo 0, 16 colori. Mostra solo i programmi di un'unità (`.BIN`, `.VBN`, `.BAS`), all'inizio A:, come riquadri in una griglia 3×3, con le pagine successive sotto. La riga della pagina comincia con l'unità (`A:`, `B:`). Ogni programma che ha un'icona la mostra sul suo riquadro. Il riquadro selezionato è bianco.

| Tasto | Cosa fa |
|---|---|
| frecce | scelgono (↑/↓ una riga. Oltre il bordo, la pagina successiva o precedente) |
| RETURN, ENTER | avvia il programma. Se è già in esecuzione, riprende da dove era |
| ^A | lo carica come accessorio di scrivania (COME ACCESSORIO). Poi F5 lo apre |
| ^R | rilegge il dischetto |
| TAB | l'unità seguente (UNITÀ SEGUENTE): A:, B:, DISK. Un programma avviato da B: torna a B: |
| mouse | clic: selezione, di nuovo: avvio |

**Menu FILE:** AVVIA, COME ACCESSORIO, UNITÀ SEGUENTE, RILEGGI I DISCHI, ESCI IN BASIC.

## Commander, F3

Modo 1, due pannelli con elenchi di file: A: a sinistra, B: a destra. Ogni pannello mostra nel titolo il formato e il numero di file, e in basso lo spazio libero. Il pannello attivo ha il titolo scuro e una selezione.

| Tasto | Cosa fa |
|---|---|
| ↑/↓ | scelgono (con SHIFT: una pagina) |
| TAB, ←/→ | l'altro pannello |
| RETURN, ENTER | apri, come nella Scrivania. Le informazioni (dimensione, tipo, indirizzo di caricamento, i primi byte) con ^I |
| ^C | copia nell'altro pannello, di qualsiasi dimensione. Se c'è un file con lo stesso nome, chiede prima |
| ^D | elimina |
| ^N | rinomina |
| ^R | rilegge entrambi i dischi |
| ^G | l'unità seguente per il pannello attivo: A:, B:, DISK (anche con un clic sul suo titolo) |
| ^F | cerca file: un nome con `*` e `?` (`*.TXT`, `README.*`, `NOTE?AD.BIN`; senza punto, qualsiasi estensione), cercato su A:, B: e DISK (la cartella in cui è). Il pannello attivo elenca ciò che è stato trovato, fino a 64 file, ognuno con la sua unità (`B:README.TXT`). RETURN va al file sulla sua unità; ^C, ^D, ^N e ^V agiscono sui file trovati così come sono; ^R o ^G chiude l'elenco |
| ^V | mostra il testo: le prime righe del file scelto nell'altro pannello, finché non viene ridisegnato |
| ^E | copia il disco: tutto il disco del pannello attivo su quello dell'altro pannello (A: e B:), traccia per traccia, ogni traccia prima formattata come quella di origine (DATA o SYSTEM). Chiede prima: i file dell'altro disco si perdono |
| mouse | clic: selezione, di nuovo: apertura |

**Menu FILE:** APRI, INFO SUL FILE (^I), MOSTRA IL TESTO (^V), CERCA (^F), COPIA IL DISCO (^E), COPIA DI FRONTE, ELIMINA, RINOMINA, RILEGGI I DISCHI, UNITÀ SEGUENTE (^G), FORMATTA IL DISCO (DATA), ESCI IN BASIC.

> FORMATTA IL DISCO cancella tutti i file sul dischetto del pannello attivo. Chiede prima.

## DISK: la scheda SD della M4

Con una scheda M4, la Scrivania ha una terza icona di unità, DISK, sotto A: e B:, e TAB passa da A: a B: e a DISK. Ci arrivano anche il Launcher e i pannelli del Commander (^G). Il titolo mostra la cartella in cui sei, ad es. `DISK:/GAMES/`.

- **Le cartelle** appaiono come cartelle (un'icona con linguetta, o DIR nel Commander). RETURN su una ci entra, e `..`, la prima voce, risale. Nel Launcher ci sono anche loro, per arrivare ai programmi che contengono.
- **Tutto come su un dischetto:** i programmi si avviano da lì, i file si aprono nei loro programmi, e ^C, ^D e ^N copiano, eliminano e rinominano. Le copie tra DISK e un dischetto arrivano fino a 16K. Cartelle e file hanno nomi come sul CPC (8.3: `NOME.EXT`); i nomi più lunghi non appaiono.
- **M4.SYS** (su `vos.dsk`) viene caricato da A: la prima volta che si usa DISK.
- **Nei programmi:** OTHER DRIVE (^W in SHEET) passa da A: a B: e a DISK, e la riga in basso dice `DISK:NOME.TXT`. La lista di OPEN mostra anche le cartelle: RETURN su una (o su `..`) mostra quella cartella, e SAVE scrive nella cartella da cui hai aperto. READER scrive la scheda come `C:` nei suoi indirizzi.
- **I database** vanno anche su DISK: il ^W di DATABASE ci arriva, e STREETS avviato dalla scheda tiene lì il suo STREETS.VDB.
- **Non ancora:** la scheda SD non si formatta da V-OS. V-OS stesso parte ancora da un dischetto in A: (scrivi `|DISC` prima di `RUN"VOS"`: con una scheda M4, il CPC parte sulla scheda SD).

## Impostazioni, F4

Modo 1. Una riga per ogni impostazione. Le modifiche hanno effetto subito. Quando vengono salvate (RETURN o ^S) sono scritte in `A:SETUP.CFG` e valgono anche al prossimo avvio.

| Impostazione | Valori |
|---|---|
| VISTA INIZIALE | SCRIVANIA, PROGRAMMI, COMMANDER |
| LINGUA | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| RITARDO RIPETIZ. | quanto a lungo tieni premuto un tasto prima che inizi a ripetersi: BREVE, MEDIO, LUNGO |
| VELOC. RIPETIZ. | LENTA, MEDIO, VELOCE |
| MOUSE AMX | SÌ, NO |
| LETTURA AMX | LIVELLI (all'inizio) o IMPULSI: come viene letto il mouse. LIVELLI conta ogni lettura con movimento, IMPULSI solo l'inizio degli impulsi. Se il puntatore si muove troppo veloce o troppo lento, prova l'altro |
| COLORE SFONDO | BLU, NERO, VERDE, ROSSO |
| TASTIERE | EN + LINGUA, TUTTE SEI (quelle che CONTROL+SHIFT percorre) |
| TEMA | CHIARO, SCURO (barre, menu, dialoghi, finestre e liste in nero con testo bianco; nei programmi, i loro menu e dialoghi) |
| SFONDO | NESSUNO, o un'immagine `.SCR`: SINISTRA/DESTRA passano per NESSUNO, A:, B: e DISK, e su un'unità si elencano i suoi `.SCR` per sceglierne uno. La Scrivania la mostra al centro dello sfondo, col colore dello sfondo intorno; un'immagine di PAINT (modo 0, 16 colori) nei quattro colori della Scrivania. Serve un'espansione di memoria (il suo ultimo banco da 16K tiene l'immagine); senza: SERVE UN'ESPANSIONE DI MEMORIA. Dopo tre minuti senza far nulla sulla Scrivania, l'immagine si mostra da sola (un salvaschermo); un tasto qualsiasi o il mouse riportano la Scrivania |

| Tasto | Cosa fa |
|---|---|
| ↑/↓ | scelgono un'impostazione |
| ←/→ | cambiano il valore (anche un clic sulla riga) |
| RETURN, ^S | salvano |

Cambiare la LINGUA carica subito il pacchetto di lingua da A:. Vedi il [capitolo 4](04-languages.md).
