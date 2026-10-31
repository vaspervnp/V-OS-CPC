# 1. Premiers pas

## Ce qu'il vous faut

- Un Amstrad CPC 6128 ou un émulateur. V-OS est testé sur Caprice32.
- La disquette de V-OS dans le lecteur A:, c'est-à-dire le `build/vos.dsk` que produit `make`.
- En option :
  - une souris AMX
  - un second lecteur (B:)
  - une extension mémoire (par ex. 512K), pour plus de programmes à la fois

## Démarrage

Depuis le BASIC :

```
RUN"VOS
```

V-OS charge le noyau, coupe les ROM et prend le contrôle de toute la machine. Il détecte l'extension mémoire tout seul.

- **Première vue :** le Bureau. Vous pouvez la changer dans les Réglages, à la ligne VUE AU DÉMARRAGE.
- **Langue :** l'anglais. S'il y a un `SETUP.CFG` sur la disquette, V-OS démarre avec la langue et les réglages qui y sont enregistrés.
- **Sortie :** FICHIER > QUITTER VERS LE BASIC (CONTROL+Q dans les vues). Une confirmation est demandée, puis le CPC redémarre.

## L'écran

V-OS utilise tout l'écran (overscan) : 384×272 pixels en mode 1 (4 couleurs) ou 192×272 en mode 0 (16 couleurs).

- **Barre de menus** (en haut) : les menus de la vue ou du programme, en général FICHIER ou le menu du programme, AFFICHAGE et AIDE. À droite, la langue du clavier (EN, ΕΛ, FR, …).
- **Ligne du bas :** dans chaque vue, les touches qui y fonctionnent.

## Les touches valables partout

| Touche | Ce qu'elle fait |
|---|---|
| F1 | Bureau |
| F2 | Lanceur |
| F3 | Commander |
| F4 | Réglages |
| F5 | ouvre et ferme l'accessoire de bureau (ACCESSOIRE) |
| F6 | les programmes en cours, pour en choisir un |
| ESC | ouvre le premier menu. Dans les menus, ←/→ changent de menu, ↑/↓ choisissent un élément, RETURN l'exécute, ESC ferme |
| CONTROL+lettre | les raccourcis des menus (par ex. ^Q, ^L) |
| CONTROL+L | changer de langue (AFFICHAGE > CHANGER DE LANGUE) |
| CONTROL+K | le dialogue des touches (AIDE > TOUCHES) |
| CONTROL+SHIFT | change le clavier : anglais, celui du module et, avec CLAVIERS : LES SIX dans Setup, ceux des autres langues |
| TAB, SHIFT+TAB | déplacent le focus entre les boutons. RETURN, ENTER ou ESPACE appuient sur le bouton qui a le focus |

F1–F6 sont les touches f1–f6 du pavé numérique du CPC.

## Le pointeur et la souris

- **Avec une souris AMX :** le pointeur suit la souris, et son bouton sert à cliquer. La souris s'active et se règle dans les Réglages (SOURIS AMX, LECTURE AMX).
- **Sans souris :** le pointeur se déplace avec les flèches, et COPY sert à cliquer. Dans les vues qui utilisent les flèches pour choisir (Bureau, Lanceur, Commander), les flèches choisissent les fichiers et les programmes au lieu de déplacer le pointeur.

La plupart des choses fonctionnent des deux façons : un clic sur un fichier ou un programme le sélectionne, un second clic l'ouvre.

## Fenêtres et dialogues

- **Déplacement :** toute fenêtre peut être déplacée par sa barre de titre : les dialogues, la fenêtre FICHIERS du Bureau, l'accessoire de bureau et les fenêtres des programmes en blocs. Tant que vous tenez le bouton, un contour en pointillés s'affiche, et la fenêtre est redessinée là où vous le relâchez.
- **Dialogues :** ils attendent une réponse. TAB et ←/→ changent de bouton, RETURN l'actionne, et ESC choisit le dernier (en général NON ou ANNULER).
- **Saisie de texte** (par ex. pour renommer) : vous tapez à la fin, DEL efface, RETURN valide et ESC annule. Vous pouvez aussi taper dans la langue du module.

## Disquettes et fichiers

- **Format :** V-OS lit et écrit les disquettes AMSDOS (format DATA ou SYSTEM) dans A: et B:. Le BASIC peut lui aussi lire ses fichiers.
- **Noms :** 8 caractères plus 3 pour le type (`NOM.TYP`).

Les types que vous rencontrerez :

| Type | Ce que c'est |
|---|---|
| `.BIN` | un programme V-OS (ou un fichier binaire) |
| `.VBN` | un programme V-OS fait avec des blocs |
| `.VBS` | un programme Studio (sa source) |
| `.OVL`, `.MSG`, `.LNG` | des parties de V-OS lui-même : vues, textes, langues |
| `.SYS` | des fichiers système (par ex. `VBRUN.SYS`, le lecteur de Studio) |
| `SETUP.CFG` | les réglages |

Les réglages, les langues et les vues sont lus depuis A:, la disquette de V-OS doit donc y rester.

## Messages d'erreur

Les erreurs de disquette s'affichent dans un dialogue : LECTEUR PAS PRÊT, PROTÉGÉ EN ÉCRITURE, FICHIER INTROUVABLE, DISQUE PLEIN, RÉPERTOIRE PLEIN, NOM DÉJÀ PRIS, NOM INVALIDE et d'autres.

Deux autres concernent les programmes :

- **PROGRAMME NON V-OS :** le fichier n'a pas l'en-tête d'un programme.
- **FERMEZ D'ABORD UN AUTRE PROGRAMME :** il n'y a plus de place. Voir le [chapitre 3](03-programs.md).
