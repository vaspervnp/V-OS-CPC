# 1. Per iniziare

## Cosa serve

- Un Amstrad CPC 6128 o un suo emulatore. V-OS è testato su Caprice32.
- Il dischetto di V-OS nell'unità A:, cioè il `build/vos.dsk` creato da `make`.
- Facoltativamente:
  - un mouse AMX
  - una seconda unità (B:)
  - un'espansione di memoria (ad es. 512K), per più programmi insieme

## Avvio

Dal BASIC:

```
RUN"VOS
```

V-OS carica il kernel, disattiva le ROM e prende il controllo di tutta la macchina. Rileva da solo l'espansione di memoria.

- **Prima vista:** la Scrivania. Si può cambiare nelle Impostazioni, alla riga VISTA INIZIALE.
- **Lingua:** inglese. Se sul dischetto c'è un `SETUP.CFG`, parte con la lingua e le impostazioni salvate lì.
- **Uscita:** FILE > ESCI IN BASIC (CONTROL+Q nelle viste). Chiede conferma e riavvia il CPC.

## Lo schermo

V-OS usa tutto lo schermo (overscan): 384×272 pixel in modo 1 (4 colori) o 192×272 in modo 0 (16 colori).

- **Barra dei menu** (in alto): i menu della vista o del programma, di solito FILE o il menu del programma, VISTA e AIUTO. A destra c'è la lingua della tastiera (EN, ΕΛ, …).
- **Riga in basso:** in ogni vista, i tasti che funzionano lì.

## Tasti che funzionano ovunque

| Tasto | Cosa fa |
|---|---|
| F1 | Scrivania |
| F2 | Launcher |
| F3 | Commander |
| F4 | Impostazioni |
| F5 | apre e chiude l'accessorio di scrivania (ACCESSORIO) |
| F6 | i programmi in esecuzione, per sceglierne uno |
| ESC | apre il primo menu. Nei menu, ←/→ cambiano menu, ↑/↓ scelgono una voce, RETURN la esegue, ESC chiude |
| CONTROL+lettera | le scorciatoie dei menu (ad es. ^Q, ^L) |
| CONTROL+L | cambia lingua (VISTA > CAMBIA LINGUA) |
| CONTROL+K | il dialogo con i tasti (AIUTO > TASTI) |
| CONTROL+SHIFT | passa la tastiera dall'inglese alla lingua del pacchetto e viceversa |
| TAB, SHIFT+TAB | spostano il focus tra i pulsanti. RETURN, ENTER o SPAZIO premono il pulsante che ha il focus |

F1–F6 sono i tasti f1–f6 del tastierino numerico del CPC.

## Il puntatore e il mouse

- **Con un mouse AMX:** il puntatore si muove con il mouse, e il suo pulsante fa clic. Il mouse si attiva e si configura nelle Impostazioni (MOUSE AMX, LETTURA AMX).
- **Senza mouse:** il puntatore si muove con i tasti freccia, e COPY fa clic. Nelle viste che usano le frecce per scegliere (Scrivania, Launcher, Commander), le frecce scelgono file e programmi invece di muovere il puntatore.

Quasi tutto funziona in entrambi i modi: un clic su un file o un programma lo seleziona, e un secondo clic lo apre.

## Finestre e dialoghi

- **Trascinamento:** ogni finestra si può trascinare per la sua barra del titolo: i dialoghi, la finestra FILE della Scrivania, l'accessorio di scrivania e le finestre dei programmi a blocchi. Mentre tieni premuto il pulsante si vede un contorno tratteggiato, e la finestra viene ridisegnata dove lo rilasci.
- **Dialoghi:** aspettano una risposta. TAB e ←/→ cambiano pulsante, RETURN lo preme, ed ESC sceglie l'ultimo (di solito NO o ANNULLA).
- **Inserimento di testo** (ad es. per rinominare): scrivi alla fine, DEL cancella, RETURN accetta ed ESC annulla. Puoi scrivere anche nella lingua del pacchetto.

## Dischetti e file

- **Formato:** V-OS legge e scrive dischetti AMSDOS (formato DATA o SYSTEM) in A: e B:. Anche il BASIC può leggere i suoi file.
- **Nomi:** 8 caratteri più 3 per il tipo (`NAME.TYP`).

Tipi che incontrerai:

| Tipo | Cos'è |
|---|---|
| `.BIN` | un programma V-OS (o un file binario) |
| `.VBN` | un programma V-OS fatto con i blocchi |
| `.VBS` | un programma di Studio (il suo sorgente) |
| `.OVL`, `.MSG`, `.LNG` | parti di V-OS stesso: viste, testi, lingue |
| `.SYS` | file di sistema (ad es. `VBRUN.SYS`, il player di Studio) |
| `SETUP.CFG` | le impostazioni |

Le impostazioni, le lingue e le viste vengono lette da A:, quindi il dischetto di V-OS deve restare lì.

## Messaggi di errore

Gli errori del disco compaiono in un dialogo: UNITÀ NON PRONTA, DISCO PROTETTO, FILE NON TROVATO, DISCO PIENO, DIRECTORY PIENA, NOME GIÀ USATO, NOME NON VALIDO e altri.

Altri due riguardano i programmi:

- **NON È UN PROGRAMMA V-OS:** il file non ha l'intestazione di un programma.
- **CHIUDI PRIMA UN ALTRO PROGRAMMA:** non c'è spazio. Vedi il [capitolo 3](03-programs.md).
