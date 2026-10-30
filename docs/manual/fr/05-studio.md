# 5. Studio : des programmes avec des blocs

STUDIO est un éditeur de blocs à la Scratch qui tourne sur le CPC lui-même.

- Vous créez des sprites et des scripts à partir de blocs.
- Le programme se lance aussitôt avec CONTROL+R.
- Il devient un programme V-OS normal (`.VBN`) qui se lance aussi depuis le Lanceur.

## L'écran

Studio utilise un écran « partagé », en deux zones :

- **En haut, en mode 0 (16 couleurs) :**
  - **à gauche, la scène** à demi-taille
  - **à droite, le panneau SPRITES :** les sprites avec leur couleur et leur position, la taille du sprite sélectionné (W, H), le fond et le mode du programme (par ex. `STAGE 2 M1`), et le nom du fichier
- **En bas, en mode 1 :**
  - **à gauche, la palette** avec les blocs d'une catégorie (`< EVENTS >`)
  - **à droite, le script**, une ligne par bloc
  - **tout en bas, la ligne d'état**, avec les touches qui fonctionnent là où vous êtes

**TAB** passe du script à la palette, puis à la scène, et revient au script.

## Les menus

| STUDIO | | EDIT |
|---|---|---|
| NEW | ^N | DELETE LINE |
| OPEN (`.VBS`) | ^O | + SPRITE (jusqu'à 6) |
| SAVE | ^S | − SPRITE |
| SAVE AS | | BACKGROUND (la couleur de la scène) |
| RUN | ^R | SCREEN MODE (0 ou 1) |
| IN BACKGROUND | | |
| BACK | ^Q | |

- **RUN (^R) :** enregistre `NOM.VBS`, écrit `NOM.VBN` et le lance. Le programme s'arrête depuis son propre menu (PROGRAM > STOP, ^Q), puis Studio redémarre avec le même programme ouvert.
- **IN BACKGROUND (en arrière-plan) :** demande si le programme continue à tourner quand il est derrière un autre ou derrière une vue, ou s'il se met en pause, ce qui est le comportement par défaut.
- **SCREEN MODE (mode d'écran) :**
  - **Mode 0 :** 16 couleurs, 192 pixels de large.
  - **Mode 1 :** 4 couleurs (encres 0–3), 384 pixels de large, et plus de texte.

## La palette

←/→ changent de catégorie, ↑/↓ choisissent un bloc, et RETURN l'ajoute sous la ligne du script. Un clic sur un bloc de la palette fait de même.

Un bloc qui s'ouvre (FOREVER, REPEAT, IF) entre avec son END, et s'efface avec lui. Un bloc avec du texte demande le texte tout de suite.

## Le script

| Touche | Ce qu'elle fait |
|---|---|
| ↑/↓ | ligne |
| ←/→ | case de la ligne (les cases sont les valeurs à l'intérieur du bloc) |
| RETURN | sans case sélectionnée : ajoute le bloc de la palette. Sur une case de texte : changer le texte. Sur une case de touche : attend que vous appuyiez sur la touche |
| CLR | efface la ligne |
| DEL | efface le dernier chiffre d'un nombre |
| souris | clic sur une case : la sélectionne. Second clic : change sa sorte |

Le programme est une liste de lignes :

- Chaque `WHEN …` commence un script, pour un sprite ou pour la scène. Le script va jusqu'au `WHEN` suivant.
- L'indentation se fait toute seule, d'après les blocs qui s'ouvrent et se ferment.
- Les lignes avant le premier `WHEN` sont ignorées.
- Tout ce qui reste ouvert est fermé à la fin du script.

### Ce qui va dans une case

La ligne d'état dit toujours ce que la case accepte.

**Case de valeur :**

| Touche | Valeur |
|---|---|
| 0–9, − | nombre, un entier de −32768 à 32767 |
| A–H | variable. La même lettre encore : A1, A2 … A15, puis retour à A |
| X, Y | la position du sprite du script |
| R et des chiffres | RANDOM : un nombre de 1 à n |
| K et une touche | KEY : 1 tant qu'elle est enfoncée, sinon 0 |
| T et un chiffre | TOUCHING : 1 quand le sprite touche le sprite n |
| Z | AT EDGE : 1 quand le sprite est au bord de la scène |
| P | BUTTON : le numéro du dernier bouton actionné |
| U | COSTUME : le numéro du costume du sprite (0 : aucun costume) |

**Autres sortes de case :**

- **Variable :** A–H, et la même lettre encore pour A1…A15.
- **Comparaison :** `<`, `=`, `>`. ESPACE donne « aucune », et alors IF vérifie seulement que la première valeur n'est pas 0.
- **Sprite** (dans les blocs `WHEN`) : 0 la scène, 1–6 un sprite.
- **Touche** (dans `WHEN KEY`) : RETURN puis la touche.
- **Texte :** RETURN, et vous tapez jusqu'à 14 caractères.
- **Groupe de variables** (SAVE/LOAD VARS) : A–H passe au groupe de huit suivant (A-H, A1-H1 … A15-H15), et ESPACE donne ALL.

Les lettres sont lues comme des touches, elles fonctionnent donc aussi avec le clavier grec.

## La scène et les sprites

| Touche | Ce qu'elle fait |
|---|---|
| flèches | déplacent le sprite sélectionné |
| 1–6 | sélectionner un sprite |
| C | couleur suivante |
| W, H | largeur, hauteur |
| K | le costume qu'il porte (aucun, 1, 2, …) |
| E | dessiner son costume (un nouveau, s'il n'en a pas) |
| clic sur la scène | place le sprite à cet endroit |

Un sprite sans costume est un rectangle de couleur.

### Les costumes

**E** ouvre l'éditeur de costumes à la place de la scène. Il a une grille de 16×16 avec les 16 encres en dessous.

| Touche | Ce qu'elle fait |
|---|---|
| flèches | case |
| ESPACE, RETURN | peint la case |
| 0–9, A–F | encre |
| `.` | transparent |
| E, TAB | terminé |
| clic | sur une case : la peint. Sur la rangée d'encres : choisit une encre |

Un programme a jusqu'à 8 costumes, partagés par tous les sprites. Un sprite avec costume mesure 16×16. Sur la scène, x est arrondi à un octet entier (2 pixels en mode 0, 4 en mode 1).

## Tous les blocs

Dans la colonne « Bloc », les cases apparaissent comme dans le script.

### EVENTS (événements)

| Bloc | Ce qu'il fait |
|---|---|
| WHEN START *sprite* | le script démarre avec le programme |
| WHEN KEY *touche* *sprite* | démarre quand on appuie sur la touche |
| WHEN CLICKED *sprite* | démarre sur un clic sur le sprite (ou sur la scène) |
| WHEN I RECEIVE *n* *sprite* | démarre quand le message n est envoyé |
| SEND *n* | envoie le message n (n peut aussi être une variable) |

> Un message relance **depuis le début** tout script qui l'attend, même s'il tournait déjà. C'est pourquoi un script ne devrait pas s'envoyer un message à lui-même.

### CONTROL (contrôle)

| Bloc | Ce qu'il fait |
|---|---|
| FOREVER … END | répète indéfiniment |
| REPEAT *n* … END | n fois |
| IF *a* *comparaison* *b* … [ELSE …] END | exécute les lignes seulement si la comparaison est vraie |
| WAIT *n* | attend n trames (50 = une seconde) |
| WAIT UNTIL *a* *comparaison* *b* | attend que la comparaison soit vraie |
| STOP | termine ce script |

### MOTION (mouvement)

| Bloc | Ce qu'il fait |
|---|---|
| GO TO *x* *y* | le sprite va en x, y |
| CHANGE X *n*, CHANGE Y *n* | déplace de n |
| SPEED *vx* *vy* | fixe sa vitesse |
| MOVE | un pas à sa vitesse |
| BOUNCE | au bord de la scène, inverse la vitesse |

### LOOKS/SOUND (apparence et son)

| Bloc | Ce qu'il fait |
|---|---|
| COLOUR *n* | l'encre du rectangle |
| COSTUME *n* | porte le costume n (1–8. 0 ne change rien) |
| NEXT COSTUME | le suivant, et après le dernier, de nouveau le premier |
| SHOW, HIDE | |
| PRINT *valeur* AT *x* *y* | affiche un nombre |
| STYLE *n* | le style des PRINT et TEXT qui suivent : 1 gras, 2 italique, 4 souligné, additionnés (7 : tous), 0 normal |
| NOTE *n* FOR *trames* | joue une note (numéro MIDI : 60 = do, 69 = la 440 Hz) et attend qu'elle se termine |
| MUSIC *"nom"* | joue la chanson *nom*`.MUS` de la disquette du programme, derrière lui, avec le programme MUSIC (sur A: ou B:). Elle continue après la fin du programme, jusqu'au STOP de MUSIC (F6). Il faut une extension mémoire ; sans elle : « FERMEZ D'ABORD UN AUTRE PROGRAMME ». Un nom absent (ou vide) arrête la musique |

### VARIABLES

| Bloc | Ce qu'il fait |
|---|---|
| SET *variable* TO *valeur* | |
| CHANGE *variable* BY *valeur* | addition |
| DECREASE *variable* BY *valeur* | soustraction |
| MULTIPLY *variable* BY *valeur* | |
| DIVIDE *variable* BY *valeur* | division entière |
| REMAINDER *variable* BY *valeur* | le reste de la division |
| SAVE VARS *groupe* TO *"nom"* | écrit les variables dans un fichier texte (voir plus bas) |
| LOAD VARS *groupe* FROM *"nom"* | les relit |

### WINDOWS (fenêtres)

| Bloc | Ce qu'il fait |
|---|---|
| WINDOW *"titre"* *largeur* *hauteur* | une fenêtre au milieu de la scène, comme les dialogues de V-OS. Une nouvelle fenêtre remplace la précédente et ses boutons |
| BUTTON *"texte"* AT *x* *y* | un bouton du système. Il s'actionne d'un clic ou avec TAB et RETURN. Les boutons sont numérotés à partir de 0, dans l'ordre où ils apparaissent |
| WHEN BUTTON *sprite* | démarre quand un bouton quelconque est actionné. La valeur BUTTON (P) dit lequel |
| TEXT *"texte"* AT *x* *y* | écrit du texte |
| LABEL *bouton* TO *"texte"* | change le texte d'un bouton |

Avec une fenêtre ouverte, TEXT, BUTTON et PRINT comptent à partir du coin supérieur gauche de son intérieur. La fenêtre se déplace par son titre, avec ses boutons.

## Les variables

Il y a 128 variables, partagées par tous les scripts, nommées A–H, A1–H1, …, A15–H15. Au départ, elles valent toutes 0, et elles contiennent des entiers de −32768 à 32767.

### Enregistrer et restaurer (SAVE VARS, LOAD VARS)

- `SAVE VARS ALL TO "GAME"` écrit les 128 dans le fichier `GAME.TXT`. Le `.TXT` est ajouté quand le nom n'a pas de type.
- Avec un groupe (`A-H`, `A1-H1`, …), seules ces 8 sont écrites.
- Le fichier est un texte, une ligne par variable :

  ```
  A=12
  B=0
  A1=-5
  ```

- `LOAD VARS ALL FROM "GAME"` modifie les variables que le fichier mentionne. Avec un groupe, il ne modifie que celles qui sont aussi dans le groupe. Les lignes qu'il ne comprend pas sont ignorées, et si le fichier manque, rien ne change.
- Un fichier peut donc restaurer toutes les variables ou un seul groupe de huit, par ex. les positions sauvegardées d'un jeu.

## Les fichiers

- **`NOM.VBS` :** le programme tel que vous l'éditez. OPEN l'ouvre, et jusqu'à 5K sont lus.
- **`NOM.VBN` :** le programme prêt à tourner. RUN l'écrit, et il se lance aussi depuis le Lanceur. C'est le lecteur (`VBRUN.SYS`) avec le programme. Le lecteur compile les blocs en code Z80 au démarrage, si bien que les programmes tournent vite.

Un `.VBS` peut aussi être fabriqué à partir de texte sur le PC, avec `tools/mkvbs.py`. La syntaxe est décrite en tête du fichier, et les exemples sont `blocks/examples/*.vbt` (CALC, MINES, FLAP, TICKER, VARS).

## Les limites

| | |
|---|---|
| Lignes (blocs) | 240 |
| Sprites | 6 |
| Scripts (`WHEN …`) | 16 |
| Variables | 128 |
| REPEAT dans un programme | 64 (au-delà, ils partagent un compteur) |
| Blocs ouverts imbriqués les uns dans les autres | 16 |
| Textes | 32, jusqu'à 14 caractères chacun |
| Costumes | 8, de 16×16 |
| Boutons | 64 |
| Code | au moins 4 000 octets, même pour le plus gros programme. Ce qui ne tient pas est ignoré |

## Conseils

- **Scripts de la scène :** les blocs de mouvement et d'apparence ne font rien, et X, Y, TOUCHING et AT EDGE donnent 0.
- **TOUCHING :** n'est vrai que si les deux sprites sont visibles.
- **Synchronisation :** les scripts tournent « ensemble ». Chaque script cède son tour à la fin de chaque boucle et à chaque WAIT. Pour qu'un script en attende un autre, utilisez une variable et `WAIT UNTIL` (voir MINES).
- **Exemples tout prêts :** CALC, MINES, FLAP et TICKER s'ouvrent dans Studio (OPEN).
