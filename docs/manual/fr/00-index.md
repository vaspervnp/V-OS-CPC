# Manuel de V-OS

V-OS est un système d'exploitation graphique pour l'Amstrad CPC 6128, écrit entièrement en assembleur Z80. Il offre :

- une barre de menus, des fenêtres déplaçables, des dialogues et des boutons, utilisables au clavier ou avec une souris AMX
- trois vues pour les fichiers et les programmes (Bureau, Lanceur, Commander) et les réglages (Réglages)
- six langues sous forme de modules : anglais, grec, français, espagnol, allemand et italien
- des programmes qui tournent côte à côte et reprennent là où ils s'étaient arrêtés, un accessoire de bureau et des programmes en arrière-plan
- Studio, un éditeur de blocs à la Scratch qui tourne sur le CPC lui-même
- une API de 42 appels et un SDK pour les programmes en assembleur

Ce manuel existe aussi en grec : [00-index.md](../00-index.md), en anglais : [00-index.md](../en/00-index.md), en espagnol : [00-index.md](../es/00-index.md), en allemand : [00-index.md](../de/00-index.md) et en italien : [00-index.md](../it/00-index.md).

## Sommaire

| Chapitre | Pour qui |
|---|---|
| [1. Premiers pas](01-getting-started.md) : démarrage, l'écran, les touches, la souris | tout le monde |
| [2. Les vues](02-views.md) : Bureau, Lanceur, Commander, Réglages | tout le monde |
| [3. Les programmes](03-programs.md) : lancement, plusieurs à la fois, accessoire, arrière-plan, les programmes de la disquette | tout le monde |
| [4. Les langues](04-languages.md) | tout le monde |
| [5. Studio](05-studio.md) : programmes en blocs sur le CPC, tous les blocs | ceux qui créent des programmes |
| [6. Les blocs sur l'ordinateur](06-blocks-web.md) : l'éditeur web et `vbc.py` | ceux qui créent des programmes |
| [7. SDK](../../../sdk/README.fr.md) : programmes en assembleur avec l'API | les programmeurs |
| [8. Développer V-OS](08-development.md) : compilation, structure, tests, mémoire | ceux qui travaillent sur V-OS lui-même |

Le même contenu existe aussi en PDF, dans [`docs/V-OS-fr.pdf`](../../V-OS-fr.pdf). Il est produit par `make docs`.

## Autres documents

- [`MILESTONES.md`](../../../MILESTONES.md) : l'état du projet, étape par étape, avec ce qui a été testé à chacune.
- [`docs/REQUIREMENTS.md`](../../REQUIREMENTS.md) : les exigences et la conception, avec les détails de réalisation de chaque étape.
- [`src/api/vos_api.inc`](../../../src/api/vos_api.inc) : l'API, avec toutes ses règles en commentaires.

> Cette documentation couvre V-OS jusqu'à M37 inclus. Elle est mise à jour à chaque étape.
