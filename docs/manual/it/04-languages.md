# 4. Le lingue

V-OS parla sei lingue. L'inglese è integrato. Le altre cinque sono **pacchetti di lingua**, file sul dischetto che portano tre cose: tutti i testi di sistema, la tastiera e le lettere (il font) della lingua.

| Lingua | File | Tastiera |
|---|---|---|
| English | integrato (`ENGLISH.MSG`) | quella inglese del CPC |
| Ελληνικά | `GREEK.LNG` | greca, con gli accenti |
| Français | `FRENCH.LNG` | AZERTY, cifre con SHIFT, tasti morti ^ e ¨ |
| Español | `SPANISH.LNG` | Ñ sul tasto `:`, tasti morti ´ ¨ ` ^, e ¡ ¿ |
| Deutsch | `GERMAN.LNG` | QWERTZ, Ü Ö Ä ß, tasti morti ´ e ` |
| Italiano | `ITALIAN.LNG` | è é ò à ù ì su tasti propri |

## Cambiare lingua

- **In modo permanente:** nelle Impostazioni (F4), la riga LINGUA passa ciclicamente per tutte le lingue. Ognuna si carica subito da A:, e tutto lo schermo viene ridisegnato in quella lingua. Salvando (^S) resta anche per il prossimo avvio.
- **Rapidamente:** CONTROL+L (VISTA > CAMBIA LINGUA) passa dall'inglese alla lingua del pacchetto caricato e viceversa.
- **Solo la tastiera:** CONTROL+SHIFT passa la tastiera da quella inglese a quella del pacchetto e viceversa. La barra dei menu mostra a destra quale è attiva (EN, ΕΛ, FR, …).

I simboli `@ # [ ] { } \ |` non sono sulle tastiere dei pacchetti, perché il CPC non ha AltGr. Scrivili con la tastiera inglese.

## I testi dei programmi

I programmi hanno i propri testi in **due lingue**: l'inglese e, facoltativamente, un'altra (oggi il greco). Un programma appare nella sua seconda lingua solo quando il pacchetto è in quella lingua. Altrimenti appare in inglese. Quindi, con il francese, Studio appare in inglese.

## Creare una nuova lingua

I sorgenti delle lingue sono in `lang/<code>/`:

- `messages.txt`: i testi di sistema. L'elenco di base è definito da `lang/en/messages.txt`, e quello che manca in un pacchetto appare in inglese.
- `keymap.txt`: i tasti diversi dalla tastiera inglese.
- `pack.txt`: il codice, il nome, il set di caratteri e il font.

`tools/mklng.py` li trasforma in un `.LNG`, e il Makefile lo mette sul dischetto. I pacchetti latini condividono il font `lang/latin1/font.txt`.
