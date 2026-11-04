# V-OS Manual

V-OS is a graphical operating system for the Amstrad CPC 6128, written from scratch in Z80 assembly. It has:

- a menu bar, draggable windows, dialogs and buttons, used with the keyboard or an AMX mouse
- three views for files and programs (Desktop, Launcher, Commander) and the settings (Setup)
- six languages as plugins: English, Greek, French, Spanish, German and Italian
- programs that run side by side and resume where they left off, a desk accessory and programs in the background
- Studio, a Scratch-style block editor that runs on the CPC itself
- an API with 42 calls and an SDK for programs in assembly

This manual is also in Greek ([../00-index.md](../00-index.md)), French ([../fr/00-index.md](../fr/00-index.md)), Spanish ([../es/00-index.md](../es/00-index.md)), German ([../de/00-index.md](../de/00-index.md)) and Italian ([../it/00-index.md](../it/00-index.md)).

## Contents

| Chapter | For whom |
|---|---|
| [1. Getting started](01-getting-started.md): starting up, the screen, keys, mouse | everyone |
| [2. The views](02-views.md): Desktop, Launcher, Commander, Setup | everyone |
| [3. Programs](03-programs.md): running, several at once, accessory, background, the programs on the disc | everyone |
| [4. Languages](04-languages.md) | everyone |
| [5. Studio](05-studio.md): block programs on the CPC, all the blocks | anyone who makes programs |
| [6. Blocks on the computer](06-blocks-web.md): the web editor and `vbc.py` | anyone who makes programs |
| [7. SDK](../../../sdk/README.en.md): programs in assembly with the API | programmers |
| [8. Developing V-OS](08-development.md): build, structure, tests, memory | anyone working on V-OS itself |
| [9. On a real CPC](09-real-cpc.md): what to try, and how to report | anyone with a real CPC |

The same material is also available as a PDF, in [`docs/V-OS-en.pdf`](../../V-OS-en.pdf). It is made by `make docs`.

## Other documents

- [`MILESTONES.md`](../../../MILESTONES.md): the state of the project, milestone by milestone, with what was tested in each.
- [`docs/REQUIREMENTS.md`](../../REQUIREMENTS.md): the requirements and the design, with the implementation details of each milestone.
- [`src/api/vos_api.inc`](../../../src/api/vos_api.inc): the API, with all its rules in comments.

> This documentation covers V-OS up to and including M64. It is updated with every milestone.
