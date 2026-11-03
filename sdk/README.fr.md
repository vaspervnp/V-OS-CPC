# Le SDK de V-OS : des programmes en assembleur

Avec ce SDK, vous écrivez vos propres programmes en assembleur Z80. Ils tournent dans V-OS comme DEMO ou CLOCK : ils apparaissent dans le Lanceur, le Bureau et le Commander, et ils ont leur propre menu, des boutons, des dialogues, du son et des fichiers. Ils tournent aussi à côté d'autres programmes.

## Démarrage rapide

```bash
make new-app NAME=hello
```

Cela crée le dossier `myapps/hello/` à partir de `sdk/template/`. Il contient trois fichiers :

- `hello.asm` : le programme. Les flèches déplacent une boîte, il y a un bouton BEEP, un compteur de secondes, et son propre menu (ABOUT, BACK) à côté d'AFFICHAGE et AIDE.
- `texts.txt` : ses textes, en anglais et en grec.
- `icon.txt` : son icône, 16×16, pour le Lanceur.

```bash
make app NAME=hello
```

Cela construit `build/HELLO.BIN` et le place sur la disquette des programmes, `build/apps.dsk`. `make run` la met en B: ; dans le Lanceur, TAB montre B:.

```bash
make run
```

Cela ouvre la disquette dans Caprice32. HELLO se trouve dans le Lanceur, à la dernière page.

- Un simple `make` construit tous les programmes de `myapps/` et les place sur la disquette, avec V-OS.
- Le nom a 1 à 8 lettres minuscules ou chiffres et commence par une lettre. Ce ne peut pas être le nom d'un programme de V-OS (par ex. demo).
- Il vous faut RASM, Python 3 et iDSK, comme pour tout V-OS.
- Dans Caprice32, vous lancez le programme vous-même, depuis le Lanceur.

Un programme plus grand :

- Mettez d'autres fichiers `.asm` dans son dossier (par ex. `art.asm` avec des sprites) et intégrez-les avec `include "art.asm"`. Le build les trouve, et reconstruit le programme quand ils changent.
- Ce que vous mettez dans le sous-dossier `disc/` (par ex. `disc/LEVEL1.DAT`) va tel quel sur la disquette, pour `VOS_LOAD`.
- Avec un sous-dossier `owndisc/`, le programme a aussi sa propre disquette, `build/<nom>.dsk`, avec le `.BIN` et les fichiers de `owndisc/`. Il ne va pas sur `apps.dsk`. Vous la mettez en B: et le lancez depuis le Lanceur (TAB, l'autre lecteur). Le lecteur d'où il a été lancé, pour y charger ses fichiers, est dans `VOS_SELF` : `db lecteur`, puis son nom (11 octets).
- **Un fichier à ouvrir (version 14) :** quand RETURN dans le Bureau ou le Commander ouvre un fichier dans votre programme, `VOS_OPEN` (`#B000`) contient `db 1, lecteur, nom de 11 octets` (0 : aucun). Lisez-le dans `init`, avec A = 0 et aussi avec A = 2 (le programme tournait déjà), puis écrivez-y 0. Les types et leurs programmes sont dans la table `ft_open` du noyau (`src/kernel/files_ext.asm`).
- Un programme avec une table de relocation (comme ceux du SDK) tourne à côté d'autres jusqu'à 12K ; un plus grand (jusqu'à 16K) tourne seul sans extension mémoire, comme un programme sans table (MARKDOWN, READER). Pour le reste, chargez des fichiers dans la banque de données.

## Comment fonctionne un programme

Un programme est un `.BIN`, construit pour `VOS_APP_ADDR` (`#4000`). Il commence ainsi :

```
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0
        jp event                ; +3  HL -> l'événement
        jp redraw               ; +6
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12 l'icône (facultative)
```

- **`init`** fixe le mode, la palette, le menu et les boutons, active `VE_FRAME` si besoin, et dessine tout.
  - A = 0 : un démarrage à neuf.
  - A = 2 : le programme revient d'une vue ou d'un autre programme. Son état est tel qu'il l'a laissé ; il refixe ce qui précède et dessine.
- **`event`** est appelé pour chaque événement et revient immédiatement. Un programme n'attend jamais de lui-même (pas de boucle d'attente). Pour le mouvement ou le temps, `VOS_TICKS` avec A = 1, et alors un `VE_FRAME` arrive 50 fois par seconde.
- **`redraw`** redessine tout, par ex. quand la langue change ou que l'accessoire de bureau se ferme.
- **Sortie :** `VOS_EXIT`, qui revient à la vue qui l'a lancé.

### L'ordre dans `event`

```
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame        ; les trames
        push hl
        call VOS_UI_EVENT               ; menus, boutons, CONTROL+lettre
        pop hl
        or a : jr nz,command            ; A = la commande
        call VOS_MENU_OPEN : ret nz     ; menu ouvert : les touches sont à lui
        ...                             ; vos propres touches et clics
command: ...
        jp VOS_COMMAND                  ; ce qui n'est pas à vous (AFFICHAGE, AIDE)
```

**Tant qu'un menu est ouvert, ne dessinez pas.** Sinon vous dessinerez par-dessus. Sur `VE_FRAME`, mettez l'état à jour, mais ne dessinez que si `VOS_MENU_OPEN` donne Z. Les dialogues (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) ont leur propre boucle, donc aucun événement n'arrive tant qu'ils sont ouverts.

### Les événements

`HL` → 8 octets : `db type, code, char, mods; dw x, y`.

| type | quoi | code / char / x, y |
|---|---|---|
| `VE_KEY_DOWN` 1, `VE_KEY_REPEAT` 3, `VE_KEY_UP` 2 | touche | code = numéro de touche (`VK_*`, rangée du clavier·8 + bit), char = le caractère dans la langue du module |
| `VE_PTR_DOWN` 5, `VE_PTR_UP` 6, `VE_PTR_MOVE` 4 | pointeur | x, y en pixels du mode |
| `VE_FRAME` 8 | trame (avec `VOS_TICKS`) | — |
| `VE_LANG` 7 | la langue du clavier a changé | — |

### Trois sortes de programme

- **Avec une table de relocation (le choix par défaut du SDK) :** `make app` le construit deux fois, en `#4000` et en `#4100`. `tools/mkreloc.py` ajoute la table d'après la différence.
  - Il tourne à côté d'autres programmes, dans les 12K à partir de `#5000`, et reprend là où il s'était arrêté (F6 montre les programmes en cours).
  - Ses données doivent être dans ses propres octets (étiquettes, `ds`), jamais à des adresses fixes.
  - Si `mkreloc.py` donne une erreur, une adresse est utilisée quelque part d'une façon qui ne survit pas à la relocation. Par ex. `ld a,label & 255`, ou seulement l'octet bas d'une adresse.
- **Sans table :** il prend toute la banque (jusqu'à 16K, code et données), mais ne tourne que seul, sauf s'il y a une extension mémoire. Il faut alors votre propre règle dans le Makefile (voir `STUDIO.BIN`).
- **Accessoire de bureau :** jusqu'à 4K, avec une table. Il s'ouvre avec F5 par-dessus tout le reste, et `init` reçoit A = 1. Voir `apps/clock/clock.asm` et la description dans `src/api/vos_api.inc`.

### Règles

- **Registres :** les appels altèrent tous les registres sauf IX. Les arguments vont dans A, BC, DE, HL (IX pour `VOS_RECT` et `VOS_BLIT`). Les résultats reviennent dans A ou HL. En cas d'échec, la retenue (carry) est mise et A = numéro d'erreur, que `VOS_ERROR` affiche.
- **Mémoire :** ne mettez pas une autre banque en `#4000`, car le programme disparaîtrait sous vos pieds. Pour 16K de plus, il y a la banque de données (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). Elle est partagée avec les vues et les autres programmes, et ne garde ses données que tant que le programme tourne. Avec une extension mémoire (API 21), chaque programme reçoit la sienne, qui garde son contenu jusqu'à la fin du programme, quoi qu'il tourne entre-temps ; `VX_DATA` dit laquelle (A = 1 : la sienne).
- **Coordonnées :** x en pixels du mode (mode 0 : 0–191, mode 1 : 0–383, mode 2 : 0–767), y de 0 à 258. La barre de menus occupe y 0–11.
- **RASM :** les étiquettes ne sont pas sensibles à la casse (`BOX` et `box` sont identiques). L'hexadécimal s'écrit avec `#` et non avec `&`.

## Les formats de données

- **Barre de menus** (`VOS_SET_BAR`) : `db count; dw menu, ...`. Les menus communs AFFICHAGE et AIDE viennent de `VOS_MENU_VIEW` et `VOS_MENU_HELP`.
- **Menu :** `db title, count` et pour chaque élément `db text, command, letter, 0`.
  - text : `VOS_SEPARATOR` pour une ligne
  - command : 1.., ce que renvoie `VOS_UI_EVENT`
  - letter : raccourci CONTROL+lettre, ou 0
- **Boutons** (`VOS_SET_WIDGETS`, puis `VOS_DRAW_WIDGETS`) : `db count`, et pour chaque bouton `dw x, y; db width in characters, text, command, 0`.
- **Dialogue** (`VOS_DIALOG` → A = bouton, 0 le premier, ESC donne le dernier) : `db title, text, number of buttons (1–3), button, ...`. Pour les boutons, `VM_OK`, `VM_YES` et `VM_NO`.
- **Textes** (`VOS_TEXTS`) : produits par `tools/mktexts.py` à partir de `texts.txt`, avec des lignes `NAME | English | Greek`. Les deux colonnes sont écrites en UTF-8 et deviennent des octets du jeu de caractères de V-OS (`tools/voscs.py`), qui contient le grec et les lettres latines du français, de l'espagnol, de l'allemand et de l'italien.
  - Il donne `T_NAME` (`VT_FIRST` = `#C0` et au-delà) et la table `texts:`. Jusqu'à 64 textes.
  - Un `|` sans espaces autour commence une nouvelle ligne dans les dialogues.
  - Les textes vont partout où un « texte » est demandé (menus, boutons, dialogues). Avec `VOS_MSG`, vous obtenez leur adresse pour `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`) : 17 couleurs du firmware (0–26) : 16 encres et la bordure. En mode 1, seules les encres 0–3 comptent.
- **Rectangle** (`VOS_RECT`, IX →) : `dw x, y, w, h; db pen`.
- **Icône :** 16 lignes de 16 caractères dans `icon.txt`. Chaque caractère est une encre en hexadécimal (mode 0, palette du Lanceur) ou `.` pour transparent. Le Lanceur la lit sur la disquette : tant que le programme tourne, les 256 octets après "IC" sont libres pour des tampons (PAINT y garde ses lignes).
- **Noms de fichiers** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`) : 11 octets, `"NAME    EXT"`. Lecteur 0 = A:, 1 = B:.

## L'API (version 22)

| Appel | Entrée → sortie | Ce qu'il fait |
|---|---|---|
| `VOS_EXIT` | — | fin, retour à la vue qui l'a lancé |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 fois par seconde, ou aucun. Avec `VOS_PTR_KEYS` (2), les flèches et COPY déplacent aussi le pointeur et cliquent |
| `VOS_FRAMES` | → HL (et A bits 16–23) | trames depuis le démarrage |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = commande | les commandes communes d'AFFICHAGE et AIDE (6–19). Numérotez vos propres commandes à partir de `VC_APP` (32), sinon un élément d'AFFICHAGE ou d'AIDE lance l'une des vôtres |
| `VOS_ERROR` | A = erreur | dialogue d'erreur |
| `VOS_MODE` | A = 0 / 1 / 2 | mode 0 (192×259, 16 encres), 1 (384×259, 4 encres) ou 2 (768×259, 2 encres, 96 colonnes de texte ; version 25). En mode 2, menus et dialogues se dessinent à l'encre 1 sur l'encre 0 : encre 0 blanche et 1 noire donnent du texte noir sur papier blanc (NOTEPAD, MARKDOWN, READER, SHEET avec ^M) |
| `VOS_PALETTE` | HL → 17 couleurs | |
| `VOS_CLS` | A = encre | efface l'écran |
| `VOS_PLOT` | HL = x, DE = y, A = encre | un pixel |
| `VOS_RECT` | IX → rectangle | rectangle plein |
| `VOS_COLOURS` | A = encre du texte (+ `VOS_BOLD`, `VOS_ITALIC`, `VOS_UNDERLINE`), C = fond | pour `VOS_PRINT` et `VOS_CHAR`. Les styles sont faits à partir de la même police, pour toutes les langues |
| `VOS_PRINT` | HL = x, DE = y, BC → texte, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = caractère | |
| `VOS_MSG` | A = texte → HL | l'adresse d'un texte (`T_*` ou un texte du système) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → barre de menus | |
| `VOS_UI_EVENT` | (l'événement en cours) → A | commande de menu, de bouton ou de raccourci, 0 pour aucune |
| `VOS_DIALOG` | HL → dialogue → A | |
| `VOS_INPUT` | A = titre, HL → texte, C = maximum → carry si annulé | saisie de texte (demande C + 2 octets) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → boutons | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | les menus communs |
| `VOS_CATALOG` | A = lecteur → A = fichiers, HL → liste | 16 octets chacun : 11 pour le nom, en +12 la taille en K. Avec A = lecteur + `VOS_CAT_EXT` et HL → `"EXT"`, seulement les fichiers de cette extension |
| `VOS_FILE_PICK` | A = titre → A = fichier, carry si annulé | dialogue de sélection, après `VOS_CATALOG` |
| `VOS_LOAD` | A = lecteur, HL → nom, DE = où → BC = longueur | |
| `VOS_SAVE` | A = lecteur, HL → nom, DE = depuis, BC = longueur | fichier binaire, qui remplace l'ancien. Avec A + `VOS_LOAD_IX` (#40, version 20), son en-tête dit qu'il se charge à IX, pas à DE (un `.SCR` : IX = #C000) |
| `VOS_DELETE` | A = lecteur, HL → nom | |
| `VOS_TEXTS` | HL → table de textes | les textes du programme |
| `VOS_MENU_OPEN` | → NZ si un menu est ouvert | |
| `VOS_KEY_HELD` | A = touche → NZ tant qu'elle est enfoncée | pour les jeux |
| `VOS_BLIT` | IX → `dw x, y; db bytes, lines; dw source; db source stride` | image : paires (masque, pixels) |
| `VOS_SOUND` | A = canal 0–2, HL = période (bit 15 : bruit), C = volume 0–15, B = trames | une note ; 440 Hz correspond à la période 142 |
| `VOS_SPLIT` | HL → `dw y1, y2; db 8 colors` (0 = désactive) | écran mixte : mode 0 entre y1 et y2 |
| `VOS_RUN` | A = lecteur, HL → nom | lance un autre programme, puis celui-ci redémarre |
| `VOS_KEEP` | → HL → 16 octets | mémoire qui reste entre les programmes |
| `VOS_BANK_GET`, `VOS_BANK_PUT` | HL = depuis, DE = vers, BC = octets | copie depuis et vers la banque de données |
| `VOS_BACKGROUND` | A = 1 / 0 | continue à tourner ou se fige quand il est derrière un autre |
| `VOS_DRAG` | HL = x, DE = y, BC = w, A = h → carry : nouveaux HL, DE | déplacement d'une fenêtre par son titre |
| `VOS_FIT` | idem → HL, DE | ramène une fenêtre dans l'écran |
| `VOS_EXT` | A = un appel `VX_*`, BC, DE, HL selon l'appel → A, HL, C, DE, retenue | les appels après la table (version 15), ci-dessous |

**Lecteurs :** 0 = A:, 1 = B:, 2 = DISK, la carte SD d'une carte M4 (version 28), dans le dossier où le Bureau ou le Commander est entré en dernier. Les appels de fichiers et `VX_FREE` y marchent comme sur une disquette (noms 8.3 ; sans carte M4 : retenue, A = 35), et le catalogue a aussi les dossiers (à +13, 1). Les bases de données seulement sur disquette.

**Les appels de `VOS_EXT`:** `VX_VERSION` → A = API, HL = version de V-OS (BCD). `VX_FREE` C = lecteur → A = K libres. Inconnu : retenue `VX_CLIP_PUT` HL = texte, BC = octets → le presse-papiers (jusqu'à 1K). `VX_CLIP_GET` DE = où, BC = place → HL = taille (version 16). `VX_M4` HL → une commande pour la carte M4 (db taille, dw commande, données), DE → la réponse, BC = octets ; retenue : pas de carte M4 (version 17). `VX_MEM` → HL = la RAM en K, DE = les K libres pour les programmes (version 18). `VX_BEHIND` DE → db lecteur, nom de 11 octets d'un fichier : son programme (selon le type) démarre derrière celui-ci, avec `init` A = 3 et le fichier dans `VOS_OPEN` (version 19 ; MUSIC le connaît). `VX_DATA` → A = 1 si la banque de données est celle du programme (extension mémoire), 0 si c'est la banque 4 partagée (version 21 ; NOTEPAD garde ainsi du texte jusqu'à 16K). `VX_DB` C = un appel `DB_*`, DE, HL → une base de données (version 22, plus bas). `VX_UTF8` HL → un texte, BC = octets, E = 0 dans la mémoire du programme ou `VOS_DATA` dans sa banque de données : s'il est en UTF-8 (d'un PC ou du web), il passe là dans le jeu de caractères de V-OS → BC = octets maintenant, A = 1 ; A = 0 : ce n'était pas de l'UTF-8 et il reste tel quel (version 23 ; NOTEPAD et READER le font). `VX_CALC` C = un appel `CALC_*`, DE → un bloc, HL → texte → formules et nombres (version 24, ci-dessous). `VX_LANG` → HL = le code de la langue que montre V-OS (`"EN"`, `"EL"`, `"FR"`… ; L la première lettre) (version 26 ; VBRUN montre ainsi les traductions des programmes de Studio). `VX_IRQ` HL = une routine du programme → le noyau l'appelle une fois par image depuis l'interruption, devant ou derrière, avec sa banque en place et les interruptions coupées ; 0 l'arrête, comme la fin du programme ; retenue : pas pour un accessoire ni pour un programme seul dans la banque 5 (version 27 ; MUSIC joue ainsi ses chansons, qui ne s'arrêtent plus quand un autre programme se charge ou dessine). Elle doit être courte, garder IY, EXX et AF', n'écrire que sa propre mémoire et l'AY, et n'appeler rien de V-OS.

### Bases de données (version 22)

`VOS_EXT` avec A = `VX_DB` et C = un appel `DB_*` travaille sur une base de données : un fichier `NOM.VDB` de pages de 1K, aussi grand que la disquette le permet (jusqu'à 255K). Elle a jusqu'à 8 tables ; une table a jusqu'à 10 champs, du texte (jusqu'à 255 caractères) ou un nombre (2 octets), et peut avoir un champ clé (texte jusqu'à 64 caractères, ou un nombre) avec un index, pour que FIND soit rapide. Un enregistrement est ses champs les uns après les autres ; son identifiant (rid) est un nombre de 16 bits. Une base est ouverte à la fois, pour le programme qui l'a ouverte. Chaque appel écrit ses changements sur la disquette avant de revenir. Le noyau charge le moteur, `DB.SYS`, depuis le lecteur A: la première fois.

| Appel | Entrée → sortie |
|---|---|
| `DB_CREATE`, `DB_OPEN` | DE → db lecteur, nom de 11 octets (`"STREETS VDB"`) ; OPEN → A = 1 : Latin-1 (de V-OS 0.15) |
| `DB_CLOSE` | |
| `DB_TABLE` | DE → nom (8), champs, champ clé (0 : aucun), puis chaque champ : nom (8), type, longueur → A = table |
| `DB_USE` | E = la table qu'utilisent les appels ci-dessous |
| `DB_INFO` | E = table, HL → 124 octets : sa description → A = tables |
| `DB_ADD` | HL → enregistrement → DE = rid |
| `DB_GET`, `DB_PUT` | DE = rid, HL → l'enregistrement |
| `DB_DEL` | DE = rid |
| `DB_FIND` | HL → clé comme dans un enregistrement (place pour un enregistrement), E = octets qui comptent (0 : tous) → DE = le premier enregistrement avec cette clé ou après |
| `DB_FIRST`, `DB_LAST`, `DB_NEXT`, `DB_PREV` | HL → place pour l'enregistrement, ou 0 → DE = rid, dans l'ordre de la clé ; retenue à la fin |
| `DB_COUNT` | → HL = enregistrements |

Erreurs : retenue et A (`DB_ERR_*`, et les erreurs de la disquette), que `VOS_ERROR` montre. Le texte est gardé tel qu'il est tapé, dans le jeu de caractères de V-OS, le même dans toutes les langues : une base peut contenir du grec, du français et de l'allemand ensemble. Seule une base de V-OS 0.15 avec des lettres latines (Latin-1) est différente : `DB_OPEN` donne alors A = 1 ; montrez `DB_ERR_ALPHABET` avec `VOS_ERROR`. Le tri et FIND comparent des octets : dans une clé `DB_TEXT`, majuscules et minuscules, et lettres accentuées, sont différentes. Un champ `DB_ALPHA` (type 2, depuis la version 23) est du texte comme `DB_TEXT`, mais comme clé il est trié et trouvé sans casse ni accents : ΕΛΕΝΗ, Ελένη et ελένη, ou Élodie et ELODIE, sont pareils ; l'enregistrement garde le texte tel qu'il a été tapé. Des exemples sont STREETS (`myapps/streets`), un index des rues, et DATABASE (`myapps/database`), tout un programme de bases avec tables, liste et formulaire ; `tools/vdb.py` montre et vérifie un fichier `.VDB` sur le PC.

### Formules (version 24)

`VOS_EXT` avec A = `VX_CALC` et C = un appel `CALC_*` calcule des formules, comme un tableur. Le noyau charge le moteur, `CALC.SYS`, depuis le lecteur A: la première fois. Un nombre fait 32 bits, en centièmes (1234 vaut 12.34), de -21474836.46 à 21474836.46. Une formule a `+ - * /`, des parenthèses, des nombres (`12`, `3.5`, `.25` ; une troisième décimale arrondit), des cellules (`A1` à `Z255`) et les fonctions SUM, AVG, MIN, MAX, COUNT (de valeurs, de cellules et de plages comme `B2:D9`, séparées par `,` ou `;`), ABS(x), INT(x) (vers le bas, en entier) et ROUND(x) ou ROUND(x, 0–2), en majuscules ou non. Les produits et les quotients sont arrondis au centième.

DE → le bloc du programme, `CB_SIZE` (10) octets : `CB_RESULT` (un nombre, 4 octets), `CB_COLS`, `CB_ROWS`, `CB_GRID` (dw), `CB_BANK`, `CB_AT`. Les cellules sont une grille du programme : `CB_COLS` × `CB_ROWS` nombres de 4 octets, ligne après ligne, à `CB_GRID`, dans sa banque de données quand `CB_BANK` = `VOS_DATA`. Une cellule `CALC_NONE` n'a pas de nombre (vide, ou du texte : 0 dans `+ - * /`, ignorée par les fonctions) ; `CALC_BAD` a une erreur.

| Appel | Entrée → sortie |
|---|---|
| `CALC_EVAL` | HL → formule, 0 (avec `=` devant ou non) → `CB_RESULT` et DE:HL (DE le haut) |
| `CALC_NUMBER` | HL → texte : seulement un nombre ? → comme `CALC_EVAL` |
| `CALC_TEXT` | `CB_RESULT` → texte en HL (13 octets de place : `-12.5`), A = sa longueur |
| `CALC_CELL` | HL → texte : une cellule (`b12`) au début ? → D = colonne, E = ligne (depuis 0), A = ses caractères |

Erreurs : carry et A (`CALC_ERR_*` : 30 formule fausse, 31 division par zéro, 32 nombre trop grand, 33 cellule hors de la grille, 34 une cellule utilisée a une erreur, 29 `CALC.SYS` n'est pas sur A:), que `VOS_ERROR` affiche ; alors `CB_RESULT` = `CALC_BAD` et `CB_AT` = l'endroit dans le texte. L'exemple est SHEET (`myapps/sheet`), un tableur qui garde ses valeurs dans sa banque de données et recalcule les formules après chaque changement.

Tous les détails, par ex. sur l'arrière-plan, l'accessoire et `VOS_SPLIT`, sont dans `src/api/vos_api.inc`. Pour des exemples, voir `apps/demo/demo.asm` (mode 0, mouvement), `apps/clock/clock.asm` (accessoire) et `apps/mixed/mixed.asm` (écran mixte). Un jeu complet avec des sprites, un niveau lu dans un fichier et du son : `myapps/vrouves/`.

Un assistant IA qui écrit un programme doit lire [`AI.md`](AI.md) (en anglais) : les mêmes règles, plus courtes, avec les pièges de RASM et de la banque de données.

## Les tests

`make test-sdk` construit le modèle sous le nom TEMPLATE.BIN et l'ouvre depuis le Lanceur dans Caprice32, avec des appuis de touches définis par `src/kernel/test_script.asm` (script 15). Il prend des captures dans `build/shots` : son écran, la boîte après son déplacement, son menu, le dialogue ABOUT, et le retour au Lanceur.

Pour votre propre test automatique, copiez le script 15 et la cible `test-sdk` du Makefile.
