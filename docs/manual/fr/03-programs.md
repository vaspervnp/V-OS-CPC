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
- **Programmes qui demandent toute la mémoire :** STUDIO et tout ce que fait Studio (CALC, MINES, FLAP, TICKER et les vôtres). De même MARKDOWN et READER, qui dépassent 12K. Sans extension mémoire, ils tournent seuls. Si l'un d'eux tourne déjà, vous obtenez « FERMEZ D'ABORD UN AUTRE PROGRAMME ».

Quand vous passez à une vue (F1–F4) pendant qu'un programme tourne :

- Un petit programme reste en mémoire. Vous le retrouvez depuis le Lanceur (RETURN dessus) ou avec F6, et il reprend exactement là où il en était.
- Un programme qui occupe toute la mémoire se termine, sauf s'il y a une extension mémoire.

**F6** (AFFICHAGE > PROGRAMMES) montre la liste des programmes en cours. On en choisit un avec les flèches et RETURN. Si aucun ne tourne, vous obtenez « AUCUN PROGRAMME EN COURS ».

**Avec une extension mémoire** (par ex. 512K, que V-OS détecte tout seul au démarrage), chaque programme qui demande toute la mémoire reçoit sa propre banque. Ainsi STUDIO, CALC, DEMO et PONG peuvent tous tourner ensemble. Depuis M43, chaque programme reçoit aussi sa propre banque de données de 16K quand il en a besoin : ce qu'il y garde n'est pas perdu pendant que d'autres programmes ou vues tournent.

## En arrière-plan

Un programme qui se trouve derrière un autre, ou derrière une vue, est normalement **figé** et reprend quand il revient au premier plan.

Certains programmes demandent à **continuer à tourner** en arrière-plan, par ex. TICKER, qui compte le temps. Pendant ce temps, ils ne dessinent pas et ne jouent pas de son. Quand ils reviennent au premier plan, ils ont aussi compté le temps de leur absence.

Dans Studio, vous choisissez cela pour votre programme avec STUDIO > IN BACKGROUND (en arrière-plan).

MUSIC fait exception : sa chanson est jouée depuis l'interruption, 50 fois par seconde, et continue donc sans à-coups derrière tout. Elle ne s'arrête qu'un instant pendant la lecture de la disquette.

## L'accessoire de bureau (ACCESSOIRE)

Un petit programme, comme CLOCK, peut s'ouvrir dans une fenêtre **par-dessus tout le reste** : une vue ou un programme.

1. Dans le Lanceur, sélectionnez CLOCK et choisissez FICHIER > COMME ACCESSOIRE (^A).
2. Dès lors, **F5** l'ouvre et le ferme, où que vous soyez. ESC le ferme aussi.

Tant qu'il est ouvert, il reçoit les touches et les clics. Sa fenêtre se déplace par son titre. Quand il se ferme, ce qui était dessous est redessiné.

## La page (mode 2)

NOTEPAD, MARKDOWN, READER et SHEET ont PAGE (MODE 2) dans leur menu, ^M. L'écran passe en mode 2 : texte noir sur papier blanc, 768 pixels de large, avec menus et dialogues noirs sur blanc aussi. Les éditeurs (NOTEPAD et MARKDOWN) montrent 80 colonnes entre les bords de la page, une ligne là où finit chaque page de 60 lignes, et PAGE n sur la dernière ligne. L'aperçu de MARKDOWN et READER montrent la page en 80 colonnes avec ses styles. SHEET montre 10 colonnes (A–J) avec des lignes entre elles. ^M à nouveau revient au mode 1.

## Les programmes de la disquette

Une disquette du CPC contient 180K, alors V-OS vient sur deux. `vos.dsk` (A:) a le système, DEMO, MIXED, STUDIO et CLOCK, et les sources `.VBS` des programmes VB, que Studio ouvre depuis A:. `apps.dsk` (B:) a les autres, de PONG à WEBGET : dans le Lanceur, TAB montre B:. Certains programmes ont leur propre disquette, comme le dit le tableau.

| Programme | Ce que c'est |
|---|---|
| **STUDIO** | l'éditeur de blocs : vous créez des programmes sur le CPC ([chapitre 5](05-studio.md)) |
| **DEMO** | le premier programme V-OS : un carré qui se déplace tout seul. Les flèches le dirigent et ESPACE change sa couleur |
| **MIXED** | l'« écran mixte » : une bande en 16 couleurs (mode 0) entre des bandes en mode 1. Un clic affiche les coordonnées |
| **CLOCK** | le temps écoulé depuis le démarrage de V-OS ; avec une carte M4, l'heure réelle et, comme programme, la date (depuis le serveur de temps de la M4, réglé avec `NETSET` sur le CPC). Il tourne aussi comme accessoire de bureau |
| **CALC** | une calculatrice dans une fenêtre avec des boutons, faite dans Studio (il existe aussi `CALC.VBS`) |
| **MINES** | un démineur de 8×6 avec 8 mines, fait dans Studio. Un clic ouvre une case, et NEW commence une nouvelle partie |
| **BRICKS** | un casse-briques : une raquette avec ←/→, 32 briques, 3 vies, des niveaux avec une balle toujours plus rapide. À GAME OVER, ESPACE pour une nouvelle partie |
| **VROUVES** | tower defence, d'après le jeu CPC LET'S GO FOR VROUVES : 7 niveaux, du Kafenio au cimetière, avec 10 vagues chacun. Il est sur sa propre disquette, `vrouves.dsk` : en B:, et TAB dans le Lanceur. Les flèches déplacent le curseur, 1–6 choisit un défenseur, ESPACE construit, S vend, N appelle la vague suivante, P met en pause. Des points pour chaque envahisseur et pour les villageois restants à la fin d'un niveau. La disquette garde `VROUVES.SAV` : CONTINUE reprend au niveau atteint, HIGH SCORES montre les cinq meilleurs avec leurs noms. Écrit avec le SDK (`myapps/vrouves`) |
| **NOTEPAD** | un éditeur de texte en mode 1, 48×22, pour des fichiers jusqu'à 4K, ou jusqu'à 16K avec une extension mémoire : il garde alors environ 2,5K autour du curseur dans sa mémoire et le reste dans sa propre banque de données, et SELECT ALL prend cette partie. NEW, OPEN (seulement les fichiers `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Flèches, DEL, CLR et RETURN ; un clic place le curseur. La ligne du bas montre la ligne et la colonne. Menu EDIT : COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A ; SHIFT et les flèches sélectionnent. Le presse-papiers (jusqu'à 1K) est commun à tous les programmes. PRINT ^P imprime le texte sur une imprimante. UNDO ^Z (menu EDIT) annule le dernier changement : ce qui a été tapé ou collé, ou ce que DEL, CLR, CUT ou la frappe sur une sélection ont enlevé (jusqu'à 256 caractères) ; ^Z encore le refait (`myapps/notepad`) |
| **PAINT** | dessin en mode 0 avec 16 couleurs : une image de tout l'écran du CPC, 160×200 sans l'overscan (`.SCR`, 16K, que le BASIC et les autres programmes du CPC chargent aussi ; sans extension mémoire 128×128, `.PIC`), ou 64×64 avec un zoom 2× en 3 calques (`.LYR`, NEW LAYERS). Outils : P crayon, B pinceau, L ligne, X rectangle, F remplissage ; TAB change la couleur. Les flèches et COPY dessinent sans souris. La fenêtre montre 128×128 de l'image : les barres à sa droite et en dessous montrent quelle partie, et un clic ou un glissement sur elles la déplace. Sous les couleurs : où est le pointeur dans l'image, et VIEW, le coin en haut à gauche de la fenêtre. Calques : 1–3 en choisit un, H le cache ou le montre, U et D le montent et le descendent, E est la gomme. UNDO ^Z annule le dernier outil, et ^Z encore le rétablit (un remplissage de tout l'écran ne peut pas être annulé ; après qu'un autre programme a tourné, il n'y a plus rien à annuler). EXPORT .SCR (pour l'image de 128×128 et les calques ; tout l'écran est déjà un `.SCR`) : l'image (les calques tels qu'ils s'affichent) comme écran du CPC, un `NOM.SCR` de 16K (mode 0, au milieu, avec la palette), pour le BASIC ou d'autres programmes. En BASIC : `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | joue des morceaux d'Arkos Tracker 3 (`.MUS`, faits par `make songs`), avec trois barres de volume. Il est sur sa propre disquette, `music.dsk`, en B:. OPEN, ESPACE joue et arrête. La musique continue derrière les autres vues et programmes, sans à-coups, même pendant qu'un autre programme se charge ou dessine : elle est jouée depuis l'interruption. Le bloc MUSIC de Studio le lance derrière un programme avec une chanson (`myapps/music`) |
| **MARKDOWN** | un éditeur de fichiers Markdown (`.MD`, jusqu'à 6K), comme NOTEPAD. ^P montre la page : titres `#`, **gras**, *italique*, `code`, listes, citations, lignes, blocs de code et liens soulignés, sans les marques. Les lignes qui se suivent forment un paragraphe (deux espaces à la fin coupent la ligne). Les flèches font défiler la page, RETURN ou ^P reviennent au texte. Il est sur sa propre disquette, `markdown.dsk`, avec un `README.MD`. Menu EDIT : COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A ; SHIFT et les flèches sélectionnent. Le presse-papiers (jusqu'à 1K) est commun à tous les programmes (`myapps/markdown`) |
| **SHOW** | les images `.SCR` d'un lecteur l'une après l'autre, en mode 0, avec leurs propres couleurs (celles de PAINT) : la suivante toutes les cinq secondes, → et ← à la main, SPACE arrête et reprend, ^W l'autre lecteur (A:, B:, DISK). Jusqu'à 48 images (`myapps/show`) |
| **SYSINFO** | montre les versions de V-OS et de l'API, la mémoire (toute et celle libre pour les programmes) et la place libre sur les disquettes en A: et B: (^R à nouveau). Un exemple de `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | télécharge des fichiers du web avec la carte M4 : GET A FILE (^G) demande une adresse (HTTP, p. ex. `example.com/index.html`) et un nom, et le fichier (jusqu'à 16K) est enregistré sur le lecteur affiché (OTHER DRIVE). Il montre aussi l'état du réseau. Sans carte M4 : « NO M4 BOARD » (`myapps/webget`) |
| **READER** | lit des pages Markdown (`.MD`, jusqu'à 6K) depuis la disquette ou le web avec la carte M4, affichées comme l'aperçu de MARKDOWN. TAB choisit le lien suivant (inversé), RETURN l'ouvre, DEL revient à la page précédente (il en garde 4). Un lien sans `http://` s'ouvre à côté de la page, sur la disquette ou sur le même site. OPEN A FILE et OPEN AN ADDRESS (^U, HTTP, p. ex. `example.com/README.md`). Les adresses `https://` ne s'ouvrent pas. Il est sur sa propre disquette, `reader.dsk`, avec `INDEX.MD` et `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | un index des rues dans une base de données de V-OS : tapez les premières lettres d'une rue et voyez les rues qui commencent ainsi, avec leur quartier et code postal ; DEL efface une lettre. ^A ajoute une rue, ^D efface la première de la liste. Les rues sont dans `STREETS.VDB` sur sa disquette, `streets.dsk`, en B: ; la première fois il le crée avec des rues d'Athènes. Un exemple de l'API des bases de données (`myapps/streets`) La recherche ignore majuscules, minuscules et accents. |
| **DATABASE** | des bases de données, comme un petit Access : ^N une nouvelle base (`NOM.VDB`), ^O en ouvrir une, ^T une nouvelle table (son nom, et des champs : un nom, TEXTE jusqu'à 40 caractères ou NOMBRE 0–65535, et si elle est triée par le premier). La liste montre un enregistrement par ligne et les champs en colonnes ; les flèches choisissent et font défiler, TAB passe à la table suivante, et si la table a une clé, ce que vous tapez va aux enregistrements qui commencent ainsi (sans casse ni accents). RETURN ouvre le formulaire : un champ par ligne, RETURN le change, ^S enregistre, ^B retour à la liste. ^A un nouvel enregistrement, ^D supprimer, ^W l'autre lecteur, ^P imprime la table comme la liste la montre, tous les enregistrements. IMPORT CSV ajoute un enregistrement pour chaque ligne d'un `.CSV` à la table en cours : les champs dans l'ordre, séparés par des virgules ou des points-virgules, les textes coupés à leur longueur, les nombres d'après leurs chiffres ; une première ligne qui commence par le nom du premier champ (les en-têtes) est ignorée. Il ouvre aussi les `.VDB` de STREETS (`myapps/database`) |
| **SHEET** | un tableur : 16 colonnes (A–P) et 64 lignes, 5 colonnes et 19 lignes à l'écran. Une cellule contient (40 caractères au plus) un nombre (`12`, `-3.5` ; la virgule décimale est un point), du texte, ou une formule après `=` : `+ - * /`, des parenthèses, des cellules (`B3`), SUM, AVG, MIN, MAX et COUNT de cellules et de plages (`=SUM(B2:B9)`), ABS, INT, ROUND(x, 0–2). Les nombres ont deux décimales, jusqu'à ±21474836.46. Les flèches déplacent le curseur, RETURN modifie la cellule, la frappe commence un nouveau texte, DEL (ou CLR) la vide  ; tout est recalculé après chaque changement. Une cellule en erreur montre `#ERR`, un nombre trop large `########`. ^N nouveau, ^O ouvrir, ^S enregistrer, ^A enregistrer sous (`NOM.VSH`, du texte, une ligne par cellule : `B3 =B1*2`), ^W l'autre lecteur, ^P imprime la feuille comme la page la montre, les colonnes A–H puis I–P, jusqu'à la dernière ligne utilisée. ^G CHART : une plage d'une colonne ou d'une ligne (`B2:B9`, jusqu'à 16 cellules ; au début la colonne du curseur jusqu'à son dernier nombre) en barres en mode 0, chacune aussi haute que la cellule l'est par rapport à la plus grande, avec les textes de la colonne A (ou de la ligne 1) en dessous ; ^S enregistre le graphique comme `.SCR` (les barres, sans les textes), que PAINT et le BASIC ouvrent, toute autre touche revient. OPEN CSV lit un `.CSV` (d'un tableur de PC, ou d'une base de données) : une ligne par ligne de la feuille, les champs à partir de la colonne A, séparés par des virgules ou des points-virgules (la première ligne montre lesquels) ; les champs entre guillemets peuvent en contenir, et avec des points-virgules `1,5` est le nombre 1.5. Enregistré, il devient un `.VSH` du même nom. Les formules sont calculées par `CALC.SYS` sur A:, que tout programme peut utiliser (`VX_CALC`). Il est sur sa propre disquette, `sheet.dsk`, avec l'exemple `BUDGET.VSH` (`myapps/sheet`) |
| **PONG** | une balle et une raquette avec les flèches, score et vies |
| **CATCH** | attrapez les étoiles qui tombent |
| **STARCAT** | un chat avec des costumes qui marche, une étoile, une mélodie tirée d'une liste |
| **COUNTER** | un compteur avec des boutons +1, −1 et 0, en mode 1 |
| **FLAP** | un oiseau qui bat des ailes (costumes), et une étoile qui change de costume chaque seconde |
| **TICKER** | compte les secondes et continue en arrière-plan |

- Les programmes en blocs sont des fichiers `.VBN`. Ils ont un menu PROGRAM > STOP (CONTROL+Q).
- Ceux qui ont aussi un `.VBS` (CALC, MINES, FLAP, TICKER) s'ouvrent dans Studio pour que vous puissiez les regarder ou les modifier.
- `VBRUN.SYS` n'est pas un programme : c'est le « lecteur » dont Studio a besoin.

## Impression

NOTEPAD, SHEET et DATABASE impriment avec ^P (PRINT dans leur menu) sur une imprimante branchée sur le port imprimante du CPC (Centronics), comme l'Amstrad DMP2000 ou une compatible Epson.

- **Sept bits :** le port du CPC envoie 7 bits, donc les lettres au-dessus de 127 sortent en lettres simples : les accents sont omis (É → E, ñ → n, ß → s) et le grec est écrit en Greeklish, lettre pour lettre (Α → A, Θ → 8, Ξ → 3, Ψ → 4, Ω → W).
- **La fin :** chaque impression se termine par une nouvelle page.
- **Pas d'imprimante :** si l'imprimante reste occupée deux secondes (aucune branchée, hors ligne, plus de papier), L'IMPRIMANTE N'EST PAS PRÊTE apparaît et l'impression s'arrête.
- Les programmes impriment avec l'appel `VX_PRINT` (chapitre 7).

