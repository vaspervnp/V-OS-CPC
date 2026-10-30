# Manuale di V-OS

V-OS è un sistema operativo grafico per l'Amstrad CPC 6128, scritto da zero in assembly Z80. Offre:

- una barra dei menu, finestre trascinabili, dialoghi e pulsanti, che si usano con la tastiera o con un mouse AMX
- tre viste per file e programmi (Scrivania, Launcher, Commander) e le impostazioni (Impostazioni)
- sei lingue come plugin: inglese, greco, francese, spagnolo, tedesco e italiano
- programmi che girano uno accanto all'altro e riprendono da dove si erano fermati, un accessorio di scrivania e programmi in background
- Studio, un editor a blocchi in stile Scratch che gira sul CPC stesso
- un'API con 42 chiamate e un SDK per programmi in assembly

Questo manuale esiste anche in greco ([../00-index.md](../00-index.md)), inglese ([../en/00-index.md](../en/00-index.md)), francese ([../fr/00-index.md](../fr/00-index.md)), spagnolo ([../es/00-index.md](../es/00-index.md)) e tedesco ([../de/00-index.md](../de/00-index.md)).

## Indice

| Capitolo | Per chi |
|---|---|
| [1. Per iniziare](01-getting-started.md): avvio, lo schermo, i tasti, il mouse | tutti |
| [2. Le viste](02-views.md): Scrivania, Launcher, Commander, Impostazioni | tutti |
| [3. I programmi](03-programs.md): avvio, più programmi insieme, accessorio, background, i programmi sul dischetto | tutti |
| [4. Le lingue](04-languages.md) | tutti |
| [5. Studio](05-studio.md): programmi a blocchi sul CPC, tutti i blocchi | chi crea programmi |
| [6. I blocchi sul computer](06-blocks-web.md): l'editor web e `vbc.py` | chi crea programmi |
| [7. SDK](../../../sdk/README.it.md): programmi in assembly con l'API | programmatori |
| [8. Sviluppare V-OS](08-development.md): build, struttura, test, memoria | chi lavora su V-OS stesso |

Lo stesso materiale è disponibile anche in PDF, in [`docs/V-OS-it.pdf`](../../V-OS-it.pdf). Viene creato da `make docs`.

## Altri documenti

- [`MILESTONES.md`](../../../MILESTONES.md): lo stato del progetto, milestone per milestone, con quello che è stato testato in ciascuna.
- [`docs/REQUIREMENTS.md`](../../REQUIREMENTS.md): i requisiti e il progetto, con i dettagli di implementazione di ogni milestone.
- [`src/api/vos_api.inc`](../../../src/api/vos_api.inc): l'API, con tutte le sue regole nei commenti.

> Questa documentazione copre V-OS fino alla M34 compresa. Viene aggiornata a ogni milestone.
