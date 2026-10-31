# 3. Les programmes

## Lancer et quitter

Un programme se lance de l'une de ces façons :

- depuis le Lanceur : sélectionnez-le et appuyez sur RETURN, ou cliquez deux fois
- depuis le Bureau ou le Commander : FICHIER > LANCER
- depuis un autre programme, comme Studio, qui lance ce que vous créez

Chaque programme a son propre menu à côté des menus communs AFFICHAGE et AIDE. Il se termine depuis son menu (en général BACK ou STOP, CONTROL+Q) et revient à la vue d'où il a été lancé.

## Plusieurs programmes à la fois

Les programmes V-OS sont de deux sortes :

- **Petits, avec une table de relocation :** DEMO, MIXED et CLOCK, les exemples de l'éditeur web (PONG, CATCH, STARCAT, COUNTER), et tout ce que produit le [SDK](../../../sdk/README.fr.md). Ils se partagent 12K de mémoire, et tous ceux qui y tiennent tournent ensemble.
- **Programmes qui demandent toute la mémoire :** STUDIO et tout ce que fait Studio (CALC, MINES, FLAP, TICKER et les vôtres). Sans extension mémoire, ils tournent seuls. Si l'un d'eux tourne déjà, vous obtenez « FERMEZ D'ABORD UN AUTRE PROGRAMME ».

Quand vous passez à une vue (F1–F4) pendant qu'un programme tourne :

- Un petit programme reste en mémoire. Vous le retrouvez depuis le Lanceur (RETURN dessus) ou avec F6, et il reprend exactement là où il en était.
- Un programme qui occupe toute la mémoire se termine, sauf s'il y a une extension mémoire.

**F6** (AFFICHAGE > PROGRAMMES) montre la liste des programmes en cours. On en choisit un avec les flèches et RETURN. Si aucun ne tourne, vous obtenez « AUCUN PROGRAMME EN COURS ».

**Avec une extension mémoire** (par ex. 512K, que V-OS détecte tout seul au démarrage), chaque programme qui demande toute la mémoire reçoit sa propre banque. Ainsi STUDIO, CALC, DEMO et PONG peuvent tous tourner ensemble.

## En arrière-plan

Un programme qui se trouve derrière un autre, ou derrière une vue, est normalement **figé** et reprend quand il revient au premier plan.

Certains programmes demandent à **continuer à tourner** en arrière-plan, par ex. TICKER, qui compte le temps. Pendant ce temps, ils ne dessinent pas et ne jouent pas de son. Quand ils reviennent au premier plan, ils ont aussi compté le temps de leur absence.

Dans Studio, vous choisissez cela pour votre programme avec STUDIO > IN BACKGROUND (en arrière-plan).

## L'accessoire de bureau (ACCESSOIRE)

Un petit programme, comme CLOCK, peut s'ouvrir dans une fenêtre **par-dessus tout le reste** : une vue ou un programme.

1. Dans le Lanceur, sélectionnez CLOCK et choisissez FICHIER > COMME ACCESSOIRE (^A).
2. Dès lors, **F5** l'ouvre et le ferme, où que vous soyez. ESC le ferme aussi.

Tant qu'il est ouvert, il reçoit les touches et les clics. Sa fenêtre se déplace par son titre. Quand il se ferme, ce qui était dessous est redessiné.

## Les programmes de la disquette

| Programme | Ce que c'est |
|---|---|
| **STUDIO** | l'éditeur de blocs : vous créez des programmes sur le CPC ([chapitre 5](05-studio.md)) |
| **DEMO** | le premier programme V-OS : un carré qui se déplace tout seul. Les flèches le dirigent et ESPACE change sa couleur |
| **MIXED** | l'« écran mixte » : une bande en 16 couleurs (mode 0) entre des bandes en mode 1. Un clic affiche les coordonnées |
| **CLOCK** | le temps écoulé depuis le démarrage de V-OS. Il tourne aussi comme accessoire de bureau |
| **CALC** | une calculatrice dans une fenêtre avec des boutons, faite dans Studio (il existe aussi `CALC.VBS`) |
| **MINES** | un démineur de 8×6 avec 8 mines, fait dans Studio. Un clic ouvre une case, et NEW commence une nouvelle partie |
| **BRICKS** | un casse-briques : une raquette avec ←/→, 32 briques, 3 vies, des niveaux avec une balle toujours plus rapide. À GAME OVER, ESPACE pour une nouvelle partie |
| **VROUVES** | tower defence, d'après le jeu CPC LET'S GO FOR VROUVES : 7 niveaux, du Kafenio au cimetière, avec 10 vagues chacun. Il est sur sa propre disquette, `vrouves.dsk` : en B:, et TAB dans le Lanceur. Les flèches déplacent le curseur, 1–6 choisit un défenseur, ESPACE construit, S vend, N appelle la vague suivante, P met en pause. Des points pour chaque envahisseur et pour les villageois restants à la fin d'un niveau. La disquette garde `VROUVES.SAV` : CONTINUE reprend au niveau atteint, HIGH SCORES montre les cinq meilleurs avec leurs noms. Écrit avec le SDK (`myapps/vrouves`) |
| **NOTEPAD** | un éditeur de texte en mode 1, 48×22, pour des fichiers jusqu'à 4K. NEW, OPEN (seulement les fichiers `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Flèches, DEL, CLR et RETURN ; un clic place le curseur. La ligne du bas montre la ligne et la colonne. Menu EDIT : COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A ; SHIFT et les flèches sélectionnent. Le presse-papiers (jusqu'à 1K) est commun à tous les programmes (`myapps/notepad`) |
| **PAINT** | dessin en mode 0 avec 16 couleurs : une image de 128×128 (`.PIC`), ou 64×64 avec un zoom 2× en 3 calques (`.LYR`, NEW LAYERS). Outils : P crayon, B pinceau, L ligne, X rectangle, F remplissage ; TAB change la couleur. Les flèches et COPY dessinent sans souris. Calques : 1–3 en choisit un, H le cache ou le montre, U et D le montent et le descendent, E est la gomme. EXPORT .SCR : l'image (les calques tels qu'ils s'affichent) comme écran du CPC, un `NOM.SCR` de 16K (mode 0, au milieu, avec la palette), pour le BASIC ou d'autres programmes (`myapps/paint`) |
| **MUSIC** | joue des morceaux d'Arkos Tracker 3 (`.MUS`, faits par `make songs`), avec trois barres de volume. Il est sur sa propre disquette, `music.dsk`, en B:. OPEN, ESPACE joue et arrête. La musique continue derrière les autres vues et programmes. Le bloc MUSIC de Studio le lance derrière un programme avec une chanson (`myapps/music`) |
| **MARKDOWN** | un éditeur de fichiers Markdown (`.MD`, jusqu'à 6K), comme NOTEPAD. ^P montre la page : titres `#`, **gras**, *italique*, `code`, listes, citations, lignes, blocs de code et liens soulignés, sans les marques. Les lignes qui se suivent forment un paragraphe (deux espaces à la fin coupent la ligne). Les flèches font défiler la page, RETURN ou ^P reviennent au texte. Il est sur sa propre disquette, `markdown.dsk`, avec un `README.MD`. Menu EDIT : COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A ; SHIFT et les flèches sélectionnent. Le presse-papiers (jusqu'à 1K) est commun à tous les programmes (`myapps/markdown`) |
| **SYSINFO** | montre les versions de V-OS et de l'API, la mémoire (toute et celle libre pour les programmes) et la place libre sur les disquettes en A: et B: (^R à nouveau). Un exemple de `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | télécharge des fichiers du web avec la carte M4 : GET A FILE (^G) demande une adresse (HTTP, p. ex. `example.com/index.html`) et un nom, et le fichier (jusqu'à 16K) est enregistré sur le lecteur affiché (OTHER DRIVE). Il montre aussi l'état du réseau. Sans carte M4 : « NO M4 BOARD » (`myapps/webget`) |
| **READER** | lit des pages Markdown (`.MD`, jusqu'à 6K) depuis la disquette ou le web avec la carte M4, affichées comme l'aperçu de MARKDOWN. TAB choisit le lien suivant (inversé), RETURN l'ouvre, DEL revient à la page précédente (il en garde 4). Un lien sans `http://` s'ouvre à côté de la page, sur la disquette ou sur le même site. OPEN A FILE et OPEN AN ADDRESS (^U, HTTP, p. ex. `example.com/README.md`). Les adresses `https://` ne s'ouvrent pas. Il est sur sa propre disquette, `reader.dsk`, avec `INDEX.MD` et `ABOUT.MD` (`myapps/reader`) |
| **PONG** | une balle et une raquette avec les flèches, score et vies |
| **CATCH** | attrapez les étoiles qui tombent |
| **STARCAT** | un chat avec des costumes qui marche, une étoile, une mélodie tirée d'une liste |
| **COUNTER** | un compteur avec des boutons +1, −1 et 0, en mode 1 |
| **FLAP** | un oiseau qui bat des ailes (costumes), et une étoile qui change de costume chaque seconde |
| **TICKER** | compte les secondes et continue en arrière-plan |

- Les programmes en blocs sont des fichiers `.VBN`. Ils ont un menu PROGRAM > STOP (CONTROL+Q).
- Ceux qui ont aussi un `.VBS` (CALC, MINES, FLAP, TICKER) s'ouvrent dans Studio pour que vous puissiez les regarder ou les modifier.
- `VBRUN.SYS` n'est pas un programme : c'est le « lecteur » dont Studio a besoin.
