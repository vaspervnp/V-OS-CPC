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

## Bureau, F1

Mode 1. Une fenêtre FICHIERS montre les fichiers d'un lecteur sous forme d'icônes, quatre par rangée. Le type est écrit dans l'icône et le nom en dessous, et un `.VBN` porte une marque « lecture » à côté. À droite, deux icônes choisissent A: ou B:. La barre de titre indique le format de la disquette et le nombre de fichiers, et l'espace libre s'affiche en bas.

| Touche | Ce qu'elle fait |
|---|---|
| flèches | choisir un fichier (↑/↓ une rangée) |
| TAB | l'autre lecteur |
| RETURN, ENTER | infos du fichier |
| ^C | copier sur l'autre lecteur |
| ^D | supprimer (demande d'abord) |
| ^N | renommer |
| ^R | relire les disques |
| souris | clic sur un fichier : sélection, encore : infos. Clic sur un lecteur : l'ouvre |

- **Menu FICHIER :** LANCER (lance le programme sélectionné), INFOS DU FICHIER, COPIER SUR L'AUTRE LECTEUR, SUPPRIMER, RENOMMER, RELIRE LES DISQUES, QUITTER VERS LE BASIC.
- **La fenêtre FICHIERS** se déplace par son titre et reste là où vous la mettez, même quand vous changez de vue.

## Lanceur (PROGRAMMES), F2

Mode 0, 16 couleurs. Il ne montre que les programmes de A: (`.BIN`, `.VBN`, `.BAS`), sous forme de tuiles dans une grille de 3×3, avec les pages suivantes en dessous. Chaque programme qui a une icône l'affiche sur sa tuile. La tuile sélectionnée est blanche.

| Touche | Ce qu'elle fait |
|---|---|
| flèches | choisir (↑/↓ une rangée. Au-delà du bord, la page suivante ou précédente) |
| RETURN, ENTER | lance le programme. S'il tourne déjà, il reprend là où il en était |
| ^A | le charge comme accessoire de bureau (COMME ACCESSOIRE). F5 l'ouvre ensuite |
| ^R | relire la disquette |
| souris | clic : sélection, encore : lancement |

**Menu FICHIER :** LANCER, COMME ACCESSOIRE, RELIRE LES DISQUES, QUITTER VERS LE BASIC.

## Commander, F3

Mode 1, deux panneaux avec des listes de fichiers : A: à gauche, B: à droite. Chaque panneau indique le format et le nombre de fichiers dans son titre, et l'espace libre en bas. Le panneau actif a un titre foncé et une sélection.

| Touche | Ce qu'elle fait |
|---|---|
| ↑/↓ | choisir (avec SHIFT : une page) |
| TAB, ←/→ | l'autre panneau |
| RETURN, ENTER | infos : taille, type, adresse de chargement, les premiers octets |
| ^C | copier vers l'autre panneau, quelle que soit la taille. S'il existe un fichier du même nom, demande d'abord |
| ^D | supprimer |
| ^N | renommer |
| ^R | relire les deux disquettes |
| souris | clic : sélection, encore : infos |

**Menu FICHIER :** LANCER, INFOS DU FICHIER, COPIER EN FACE, SUPPRIMER, RENOMMER, RELIRE LES DISQUES, FORMATER LE DISQUE (DATA), QUITTER VERS LE BASIC.

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
