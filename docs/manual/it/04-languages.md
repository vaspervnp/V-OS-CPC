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
- **Solo la tastiera:** CONTROL+SHIFT cambia la tastiera. La barra dei menu mostra a destra quale è attiva (EN, ΕΛ, FR, …). Con TASTIERE di Setup su EN + LINGUA va tra quella inglese e quella del pacchetto; su TUTTE SEI passa per tutte: EN, quella del pacchetto, le altre quattro, e di nuovo EN. Così puoi scrivere in francese con la tastiera francese mentre il sistema è in greco. Ogni pacchetto contiene le tastiere di tutti.

I simboli `@ # [ ] { } \ |` non sono sulle tastiere dei pacchetti, perché il CPC non ha AltGr. Scrivili con la tastiera inglese.

## I testi dei programmi

I programmi hanno i propri testi in **due lingue**: l'inglese e, facoltativamente, un'altra (oggi il greco). Un programma appare nella sua seconda lingua solo quando il pacchetto è in quella lingua. Altrimenti appare in inglese. Quindi, con il francese, Studio appare in inglese.

## Un alfabeto per tutte

Tutte le lingue scrivono con lo stesso set di caratteri, il **set di V-OS**, e ogni pacchetto ha tutte le sue lettere. Così un testo o un database può mescolare greco, francese, tedesco, spagnolo e italiano, e tutto si vede bene qualunque sia la lingua attiva: in Setup, LANGUAGE mostra ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL con le loro lettere.

I codici da 128 a 255 sono quelli del greco in ISO 8859-7, così come erano, e i codici che lascia liberi contengono À Á Â Ä Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Ö Ù Ú Û Ü, le loro minuscole, ß e ¡ ¿. L'accento ´ si scrive come il tonos greco (΄) e µ come μ. Non ci sono ÿ, Œ né œ. La tabella è in `tools/voscs.py`. Un file di testo greco da un PC (ISO 8859-7) si legge così com'è; uno francese o tedesco in Latin-1 va convertito.

Con la tastiera inglese, SHIFT e `^` dà £.

I file in **UTF-8**, da un PC o dal web, li aprono NOTEPAD e READER, che li portano nel set di V-OS; ciò che non ha (il cinese, per esempio) diventa `?`. Sul PC, `tools/voscv.py` converte file da e verso V-OS (UTF-8, Latin-1 e altri) e dice che cos'è un file (`check`).

## Creare una nuova lingua

I sorgenti delle lingue sono in `lang/<code>/`:

- `messages.txt`: i testi di sistema. L'elenco di base è definito da `lang/en/messages.txt`, e quello che manca in un pacchetto appare in inglese.
- `keymap.txt`: i tasti diversi dalla tastiera inglese.
- `pack.txt`: il codice, il nome, il set di caratteri e il font.

`tools/mklng.py` li trasforma in un `.LNG`, e il Makefile lo mette sul dischetto. Tutti i pacchetti hanno lo stesso font, `lang/vos/font.txt`, e `charset vos`.
