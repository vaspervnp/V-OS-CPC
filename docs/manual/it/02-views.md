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

AIUTO > INFORMAZIONI SU V-OS mostra la versione (0.1 beta), la data della compilazione, l'autore (Revive8bit, 2026) e l'architetto (Vasper).

## Scrivania, F1

Modo 1. Una finestra FILE mostra i file di un'unità come icone, quattro per riga. Il tipo è scritto dentro l'icona e il nome sotto, e un `.VBN` ha accanto un segno di "play". A destra, due icone scelgono A: o B:. La barra del titolo mostra il formato del disco e il numero di file, e lo spazio libero è mostrato in basso.

| Tasto | Cosa fa |
|---|---|
| frecce | scelgono un file (↑/↓ una riga) |
| TAB | l'altra unità |
| RETURN, ENTER | apri: un programma si avvia, un file di un tipo noto si apre nel suo programma, gli altri mostrano le loro informazioni |
| ^C | copia sull'altra unità |
| ^D | elimina (chiede prima) |
| ^N | rinomina |
| ^R | rilegge i dischi |
| mouse | clic su un file: selezione, di nuovo: apertura. Clic su un'unità: la apre |

- **Menu FILE:** APRI, INFO SUL FILE (^I), COPIA SULL'ALTRA UNITÀ, ELIMINA, RINOMINA, RILEGGI I DISCHI, ESCI IN BASIC.
- **La finestra FILE** si può trascinare per il suo titolo e resta lì, anche quando cambi vista.
- **Apertura per tipo** (anche nel Commander): i `.TXT` si aprono in NOTEPAD, i `.MD` in MARKDOWN, i `.PIC` e `.LYR` in PAINT, i `.MUS` in MUSIC, che comincia a suonarli. Il programma si cerca sull'unità del file, poi su A:, poi su B:. Se non si trova, appare "NESSUN PROGRAMMA PER QUESTO FILE". Se il programma ha modifiche non salvate, chiede prima.

## Launcher (PROGRAMMI), F2

Modo 0, 16 colori. Mostra solo i programmi di un'unità (`.BIN`, `.VBN`, `.BAS`), all'inizio A:, come riquadri in una griglia 3×3, con le pagine successive sotto. La riga della pagina comincia con l'unità (`A:`, `B:`). Ogni programma che ha un'icona la mostra sul suo riquadro. Il riquadro selezionato è bianco.

| Tasto | Cosa fa |
|---|---|
| frecce | scelgono (↑/↓ una riga. Oltre il bordo, la pagina successiva o precedente) |
| RETURN, ENTER | avvia il programma. Se è già in esecuzione, riprende da dove era |
| ^A | lo carica come accessorio di scrivania (COME ACCESSORIO). Poi F5 lo apre |
| ^R | rilegge il dischetto |
| TAB | l'altra unità (ALTRA UNITÀ). Un programma avviato da B: torna a B: |
| mouse | clic: selezione, di nuovo: avvio |

**Menu FILE:** AVVIA, COME ACCESSORIO, ALTRA UNITÀ, RILEGGI I DISCHI, ESCI IN BASIC.

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
| mouse | clic: selezione, di nuovo: apertura |

**Menu FILE:** APRI, INFO SUL FILE (^I), COPIA DI FRONTE, ELIMINA, RINOMINA, RILEGGI I DISCHI, FORMATTA IL DISCO (DATA), ESCI IN BASIC.

> FORMATTA IL DISCO cancella tutti i file sul dischetto del pannello attivo. Chiede prima.

## Impostazioni, F4

Modo 1. Una riga per ogni impostazione. Le modifiche hanno effetto subito. Quando vengono salvate (RETURN o ^S) sono scritte in `A:SETUP.CFG` e valgono anche al prossimo avvio.

| Impostazione | Valori |
|---|---|
| VISTA INIZIALE | SCRIVANIA, PROGRAMMI, COMMANDER |
| LINGUA | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| RITARDO RIPETIZ. | quanto a lungo tieni premuto un tasto prima che inizi a ripetersi: BREVE, MEDIO, LUNGO |
| VELOC. RIPETIZ. | LENTA, MEDIO, VELOCE |
| MOUSE AMX | SÌ, NO |
| LETTURA AMX | IMPULSI o LIVELLI: come viene letto il mouse. Se il puntatore non si muove bene, prova l'altro |
| COLORE SFONDO | BLU, NERO, VERDE, ROSSO |

| Tasto | Cosa fa |
|---|---|
| ↑/↓ | scelgono un'impostazione |
| ←/→ | cambiano il valore (anche un clic sulla riga) |
| RETURN, ^S | salvano |

Cambiare la LINGUA carica subito il pacchetto di lingua da A:. Vedi il [capitolo 4](04-languages.md).
