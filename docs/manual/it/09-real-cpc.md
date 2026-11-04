# 9. Su un CPC vero

V-OS è stato provato solo su emulatori: Caprice32, 1984 e CPCEMU. Un CPC vero può comportarsi in modo diverso con l'unità a dischi, la tastiera, il CRTC, il monitor o con un mouse AMX. Questo capitolo è una lista di cose da provare, con quello che ciascuna deve fare. Se qualcosa fa altro, faccelo sapere. Anche "ha funzionato tutto" aiuta.

## Portare V-OS sul CPC

La versione pubblicata ha due immagini di dischetto, `vos.dsk` (A:) e `apps.dsk` (B:). Ognuna sta su un dischetto da 3" (180K). Alcuni modi per usarle:

- **Un Gotek o un HxC** al posto di un'unità: copia i file `.dsk` sulla sua chiavetta USB.
- **Un'unità da 3,5" di un PC** collegata al CPC come unità B:: scrivi le immagini su dischetti (per esempio con SAMdisk o DiskImager su Windows).
- **Una scheda M4:** copia le immagini sulla sua scheda SD e montale dal suo menu.

Poi, in BASIC: `RUN"VOS`.

## Cosa annotare prima

- Il modello (CPC 6128 o 6128 Plus) e, se lo sai, il tipo di CRTC (da 0 a 4).
- L'espansione di memoria (nessuna, 64K, 512K…), le unità, il mouse, una scheda M4.
- Il monitor (CTM644 a colori, GT65 verde, un televisore con un adattatore…).

## La lista

Ogni riga: cosa fare, e cosa dovresti vedere.

**L'avvio**
- [ ] `RUN"VOS` da A:. In pochi secondi: la Scrivania, la barra dei menu in alto, le icone delle unità a destra. Niente sfarfalla o salta.
- [ ] L'immagine riempie tutto lo schermo (overscan, 384×272), senza nulla di tagliato ai lati o in basso.
- [ ] AIUTO > INFORMAZIONI SU V-OS mostra il numero della versione pubblicata.
- [ ] SYSINFO (nel Launcher, F2) mostra la memoria che hai.

**L'unità a dischi**
- [ ] TAB sulla Scrivania apre la finestra di A:, con i suoi file come icone. Un secondo TAB: B:.
- [ ] Nel Commander (F3), copia un file da A: a B: (^C). Poi esci da V-OS (CONTROL+Q) e, in BASIC, `CAT` su B: lo mostra e `LOAD` lo legge.
- [ ] Rinomina (^N) ed elimina (^D) un file su B:.
- [ ] FORMATTA IL DISCO (DATA) nel menu FILE del Commander, su un dischetto che non ti serve. Poi `CAT` in BASIC: un dischetto vuoto.
- [ ] Si legge anche un dischetto in formato SYSTEM (quello di CP/M).
- [ ] Impostazioni (F4): cambia la LINGUA, ^S. Riparti con `RUN"VOS`: V-OS parte in quella lingua.
- [ ] Senza dischetto in B:, il Commander lo dice, e V-OS non si blocca.

**La tastiera**
- [ ] Ogni tasto in NOTEPAD: lettere, cifre, simboli, SHIFT, CAPS LOCK, le frecce, DEL, CLR, COPY.
- [ ] CONTROL+SHIFT cambia la lingua della tastiera (EN, ΕΛ, …, a destra nella barra dei menu). Le lettere greche e accentate escono giuste.
- [ ] Un tasto tenuto premuto si ripete alla velocità di RITARDO RIPETIZ. e VELOC. RIPETIZ. delle Impostazioni.
- [ ] I tasti funzione: F1 Scrivania, F2 Launcher, F3 Commander, F4 Impostazioni, F6 i programmi in esecuzione.

**Il mouse AMX**
- [ ] Impostazioni: MOUSE AMX su SÌ. Il puntatore segue il mouse alla stessa velocità in orizzontale e in verticale, in modo 1 (la Scrivania) e in modo 0 (il Launcher).
- [ ] Se salta o va nella direzione sbagliata, prova l'altro valore di LETTURA AMX.
- [ ] Pulsante sinistro: un clic; sul titolo di una finestra, la trascina; nell'angolo in basso a destra, la ridimensiona.

**La memoria**
- [ ] Senza espansione: NOTEPAD e PONG insieme, F6 per passare dall'uno all'altro; STUDIO gira da solo.
- [ ] Con un'espansione: quattro programmi insieme, ognuno dove l'hai lasciato. PAINT con un'immagine grande. Un'immagine sulla Scrivania (Impostazioni, SFONDO).

**Lo schermo**
- [ ] PAINT e il Launcher in modo 0 (16 colori): i colori sono giusti.
- [ ] READER o NOTEPAD con una pagina in modo 2 (80 colonne): leggibile, anche su un monitor a colori.
- [ ] Lo schermo misto di Studio (modo 0 sopra, modo 1 sotto): la linea di divisione resta ferma, niente sfarfalla.
- [ ] Il tema scuro (Impostazioni, TEMA).

**Il suono**
- [ ] MUSIC suona una canzone; continua a suonare mentre vai sulla Scrivania e avvii un altro programma.
- [ ] I giochi (VROUVES, BRICKS, PONG) hanno i loro suoni.

**La scheda M4** (se ne hai una)
- [ ] TAB sulla Scrivania passa da B: a DISK, la scheda SD, con le sue cartelle.
- [ ] NOTEPAD salva un file su DISK, e lo riapre.
- [ ] La barra dei menu mostra l'ora della M4; INFO SUL FILE di un file su DISK dà la sua data.
- [ ] WEBGET scarica un file; READER apre una pagina dal web.
- [ ] TELNET si collega a un server (una BBS) e mostra ciò che invia.

**La velocità** (quanto tempo, con un orologio)
- [ ] Da `RUN"VOS` alla Scrivania.
- [ ] Da F2 al Launcher, e dall'icona di un programma al programma.
- [ ] SHEET: BUDGET.VSH aperto e calcolato.

## Farcelo sapere

Apri una issue su <https://github.com/vaspervnp/V-OS-CPC/issues> con:

- quello che hai annotato prima (il modello, la memoria, il monitor…);
- le righe che hanno fatto altro, e cosa hanno fatto;
- una foto dello schermo, se qualcosa sembra sbagliato.
