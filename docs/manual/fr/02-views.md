# 2. Les vues

V-OS a quatre « vues » : des façons de voir les fichiers et les programmes, et les réglages. On change de vue avec F1–F4 ou depuis le menu AFFICHAGE. Chaque vue retient le fichier sélectionné, et la suivante sélectionne le même.

## Les menus communs

Les deux derniers menus sont les mêmes dans toutes les vues et dans les programmes :

| AFFICHAGE | | AIDE | |
|---|---|---|---|
| BUREAU | F1 | TOUCHES | ^K |
| PROGRAMMES (le Lanceur) | F2 | À PROPOS DE V-OS | |
| COMMANDER | F3 | | |
| RÉGLAGES | F4 | | |
| PROGRAMMES (en cours) | F6 | | |
| CHANGER DE LANGUE | ^L | | |

AIDE > À PROPOS DE V-OS montre la version (0.14 bêta ; chaque étape ajoute 0.01), la date de compilation, l'auteur (Revive8bit, 2026) et l'architecte (Vasper).

## Bureau, F1

Mode 1. Une fenêtre FICHIERS montre les fichiers d'un lecteur sous forme d'icônes, quatre par rangée. Le type est écrit dans l'icône et le nom en dessous, et un `.VBN` porte une marque « lecture » à côté. À droite, deux icônes choisissent A: ou B:. La barre de titre indique le format de la disquette et le nombre de fichiers, et l'espace libre s'affiche en bas.

| Touche | Ce qu'elle fait |
|---|---|
| flèches | choisir un fichier (↑/↓ une rangée) |
| TAB | l'autre lecteur |
| RETURN, ENTER | ouvrir : un programme se lance, un fichier d'un type connu s'ouvre dans son programme, les autres montrent leurs infos |
| ^C | copier sur l'autre lecteur |
| ^D | supprimer (demande d'abord) |
| ^N | renommer |
| ^R | relire les disques |
| souris | clic sur un fichier : sélection, encore : ouverture. Clic sur un lecteur : l'ouvre |

- **Menu FICHIER :** OUVRIR, INFOS DU FICHIER (^I), COPIER SUR L'AUTRE LECTEUR, SUPPRIMER, RENOMMER, RELIRE LES DISQUES, QUITTER VERS LE BASIC.
- **La fenêtre FICHIERS** se déplace par son titre et reste là où vous la mettez, même quand vous changez de vue.
- **Ouverture selon le type** (aussi dans le Commander) : les `.TXT` s'ouvrent dans NOTEPAD, les `.MD` dans MARKDOWN, les `.PIC` et `.LYR` dans PAINT, les `.MUS` dans MUSIC, qui commence à les jouer. Le programme est cherché sur le lecteur du fichier, puis sur A:, puis sur B:. S'il n'est pas trouvé, « AUCUN PROGRAMME POUR CE FICHIER » s'affiche. Si le programme a des modifications non enregistrées, il demande d'abord.

## Lanceur (PROGRAMMES), F2

Mode 0, 16 couleurs. Il ne montre que les programmes d'un lecteur (`.BIN`, `.VBN`, `.BAS`), A: au départ, sous forme de tuiles dans une grille de 3×3, avec les pages suivantes en dessous. La ligne de page commence par le lecteur (`A:`, `B:`). Chaque programme qui a une icône l'affiche sur sa tuile. La tuile sélectionnée est blanche.

| Touche | Ce qu'elle fait |
|---|---|
| flèches | choisir (↑/↓ une rangée. Au-delà du bord, la page suivante ou précédente) |
| RETURN, ENTER | lance le programme. S'il tourne déjà, il reprend là où il en était |
| ^A | le charge comme accessoire de bureau (COMME ACCESSOIRE). F5 l'ouvre ensuite |
| ^R | relire la disquette |
| TAB | l'autre lecteur (AUTRE LECTEUR). Un programme lancé depuis B: revient sur B: |
| souris | clic : sélection, encore : lancement |

**Menu FICHIER :** LANCER, COMME ACCESSOIRE, AUTRE LECTEUR, RELIRE LES DISQUES, QUITTER VERS LE BASIC.

## Commander, F3

Mode 1, deux panneaux avec des listes de fichiers : A: à gauche, B: à droite. Chaque panneau indique le format et le nombre de fichiers dans son titre, et l'espace libre en bas. Le panneau actif a un titre foncé et une sélection.

| Touche | Ce qu'elle fait |
|---|---|
| ↑/↓ | choisir (avec SHIFT : une page) |
| TAB, ←/→ | l'autre panneau |
| RETURN, ENTER | ouvrir, comme dans le Bureau. Les infos (taille, type, adresse de chargement, les premiers octets) avec ^I |
| ^C | copier vers l'autre panneau, quelle que soit la taille. S'il existe un fichier du même nom, demande d'abord |
| ^D | supprimer |
| ^N | renommer |
| ^R | relire les deux disquettes |
| souris | clic : sélection, encore : ouverture |

**Menu FICHIER :** OUVRIR, INFOS DU FICHIER (^I), COPIER EN FACE, SUPPRIMER, RENOMMER, RELIRE LES DISQUES, FORMATER LE DISQUE (DATA), QUITTER VERS LE BASIC.

> FORMATER efface tous les fichiers de la disquette du panneau actif. Une confirmation est demandée.

## Réglages, F4

Mode 1. Une ligne par réglage. Les changements prennent effet tout de suite. Une fois enregistrés (RETURN ou ^S), ils sont écrits dans `A:SETUP.CFG` et s'appliquent aussi au démarrage suivant.

| Réglage | Valeurs |
|---|---|
| VUE AU DÉMARRAGE | BUREAU, PROGRAMMES, COMMANDER |
| LANGUE | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| DÉLAI RÉPÉTITION | combien de temps on tient une touche avant qu'elle se répète : COURT, MOYEN, LONG |
| VITESSE RÉPÉTITION | LENTE, MOYEN, RAPIDE |
| SOURIS AMX | OUI, NON |
| LECTURE AMX | IMPULSIONS ou NIVEAUX : la façon de lire la souris. Si le pointeur ne bouge pas correctement, essayez l'autre |
| COULEUR DU BUREAU | BLEU, NOIR, VERT, ROUGE |

| Touche | Ce qu'elle fait |
|---|---|
| ↑/↓ | choisir un réglage |
| ←/→ | changer la valeur (un clic sur la ligne aussi) |
| RETURN, ^S | enregistrer |

Changer la LANGUE charge aussitôt le module de langue depuis A:. Voir le [chapitre 4](04-languages.md).
