# 8. Développer V-OS

Pour ceux qui travaillent sur V-OS lui-même. Les programmes *pour* V-OS sont décrits dans le [SDK](../../../sdk/README.fr.md).

## Ce qu'il vous faut

- [RASM](https://github.com/EdouardBERGE/rasm), l'assembleur
- [iDSK](https://github.com/cpcsdk/idsk), pour les images de disquette
- Python 3, pour les outils. `make docs` demande aussi `markdown` et `pymupdf`.
- GNU make 4.3 ou plus récent
- pour les tests, Caprice32 (snap `caprice32`)

## Compilation

| Commande | Ce qu'elle fait |
|---|---|
| `make` | `build/vos.dsk` (A:) : le noyau, les vues, les langues, DEMO, MIXED, STUDIO, CLOCK et les sources `.VBS` ; `build/apps.dsk` (B:) : les autres programmes et `myapps/*` ; et la disquette de chaque programme avec `owndisc/`. Si un fichier ne tient pas sur une vraie disquette (180K), il s'arrête avec une erreur |
| `make run` | ouvre la disquette dans Caprice32 (`RUN"VOS"`) |
| `make shot` | démarre sans fenêtre et prend une capture d'écran |
| `make docs` | le manuel en PDF : `docs/V-OS.pdf` (grec) et `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip` : `V-OS.exe` pour Windows, avec CPCEMU 3.0.2 (CPC 6128, 576K, souris AMX, carte M4), `vos.dsk` en A:, `apps.dsk` en B: et les disquettes des programmes à côté. V-OS démarre tout seul. Il faut WSL et le zip portable de CPCEMU (`CPCEMU_ZIP=…`) |
| `make linux` | `build/V-OS-linux.tar.gz` : le script `V-OS` pour Linux (x86_64), avec CPCEMU 2.5 (la 3.0.2 n'existe pas pour Linux) et les mêmes réglages et disquettes. Il faut SDL2 sur le système et le tar.gz Linux de CPCEMU (`CPCEMU_TGZ=…`) |
| `make songs` | les morceaux d'Arkos Tracker 3 en fichiers `.MUS` dans `myapps/music/owndisc` (`tools/mkmusic.py` ; il faut Arkos Tracker 3, `ARKOS=…`) |
| `make new-app NAME=x`, `make app NAME=x` | votre propre programme (SDK) |
| `make clean` | efface `build/` |

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `src/vos.asm` | la racine de la compilation : chargeur et noyau, écriture sur la disquette |
| `src/boot/` | le chargeur qu'AMSDOS lance en `#4000`, détection de l'extension RAM |
| `src/kernel/` | vecteurs, interruptions, système de fichiers, vues, API (`api.asm`), réglages, extension du noyau (`ext.asm`), scripts de test (`test_script.asm`) |
| `src/drivers/` | Gate Array, CRTC, clavier, souris AMX, FDC, AY |
| `src/gfx/` | graphismes overscan, texte, écran mixte |
| `src/ui/` | menus, boutons, dialogues, saisie de texte, sélecteur de fichiers |
| `src/shell/` | les vues sous forme d'overlays : Bureau, Lanceur, Commander, Réglages |
| `src/api/vos_api.inc` | l'API pour les programmes |
| `lang/` | les langues (textes, claviers, polices) |
| `apps/` | les programmes en assembleur : DEMO, MIXED, STUDIO, CLOCK, et leurs icônes |
| `blocks/` | l'éditeur web, `vbc.py`, `runtime.asm`, le lecteur de Studio (`player.asm`), des exemples |
| `sdk/` | le SDK : guide et modèle de programme |
| `tools/` | outils : polices, langues, textes, icônes, relocation, `.VBS` à partir de texte, captures d'écran, PDF |
| `docs/` | ce manuel en grec (`manual/`) et en anglais, français, espagnol, allemand et italien (`manual/en/`, `fr/`, `es/`, `de/`, `it/`), les PDF, les exigences (`REQUIREMENTS.md`) |

## La mémoire, en bref

| Zone | Ce qu'elle contient |
|---|---|
| `#0000–#3DFF` | le noyau. En page zéro, après les vecteurs de restart, la table de l'API en `#0108` |
| jusqu'à `#4000` | la pile du noyau |
| `#4000–#7FFF` | la « fenêtre » des banques |
| `#8000–#FFFF` | l'écran overscan de 32K. Dans ses trous, des tampons du noyau |

Les banques qui passent dans la fenêtre :

| Banque | Ce qu'elle contient |
|---|---|
| 4 | tampon de fichiers et de chargement, et la banque de données du programme en cours |
| 5 | la vue en `#4000–#4FFF`, et à partir de `#5000` les programmes avec table de relocation (ou un programme sans table dans toute la banque) |
| 6 | ce que cachent les menus et les dialogues, et à partir de `#7000` l'accessoire de bureau |
| 7 | le module de langue, les listes du Commander, les textes anglais, et à partir de `#7000` l'extension du noyau |

Avec une extension mémoire, ses banques accueillent des programmes. Les détails, adresse par adresse, sont dans `docs/REQUIREMENTS.md` (§4.2 et dans chaque section « Υλοποίηση M… » (réalisation)).

## Conventions

- **RASM :** l'hexadécimal s'écrit `#C000` et non `&C000`, car RASM lit `&` comme un ET. Les étiquettes ne sont pas sensibles à la casse.
- **Commentaires :** en anglais, courts, comme dans le code existant. Chaque fichier commence par un bloc qui dit ce qu'il fait.
- **Documentation :** en grec. `MILESTONES.md` (anglais), `MILESTONES.el.md` (grec) et `docs/REQUIREMENTS.md` ont une section par étape. Le manuel est écrit en grec et traduit dans les cinq autres langues de V-OS.
- **Textes :** les textes du système sont dans `lang/*/messages.txt`, et ceux des programmes dans `texts.txt` (pour `tools/mktexts.py`).

## Les tests

Les tests lancent V-OS dans Caprice32 sans fenêtre et prennent des captures d'écran dans `build/shots/<délai>/`.

**Comment ils fonctionnent :**

- Caprice32 sans fenêtre ne peut pas appuyer sur les flèches, COPY ou les touches f. C'est pourquoi les appuis de touches sont faits par une compilation spéciale : un `-DTEST_SCRIPT=n` place le script n dans `src/kernel/test_script.asm`, une table de touches par trame.
- Chaque cible `make test-…` construit une disquette avec son script et prend une capture à chaque délai de `…_SHOTS`.
- Le délai se mesure en appuis sur « Z » : environ 2,5–3,5 trames chacun. La correspondance n'est pas fixe, on saisit donc un moment avec deux ou trois délais autour.
- Dès que V-OS écrit sur la disquette, Caprice32 ne se ferme plus tout seul, et le test se termine par un dépassement de délai. C'est normal dans test-vars, test-costume et d'autres.
- Vous regardez les captures vous-même, par ex. réunies en une image avec `ffmpeg … hstack/vstack`.

| Cible | Ce qu'elle teste |
|---|---|
| `test-input` | touches, Studio : blocs, fichiers, exécution |
| `test-calc` | CALC avec des clics, puis `CALC.VBS` dans Studio et son titre en anglais et en français (^T) |
| `test-costume` | costume dans Studio, exécution, réouverture |
| `test-acc` | l'horloge comme accessoire de bureau |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | plusieurs programmes, F6, extension mémoire, arrière-plan |
| `test-drag` | déplacement des fenêtres |
| `test-langs`, `test-lang` | les langues, l'enregistrement de la langue |
| `test-mines`, `test-bricks` | les jeux |
| `test-vars` | les 128 variables, SAVE/LOAD VARS |
| `test-sdk` | le modèle du SDK |
| `test-apps` | les deux disquettes telles qu'elles sont données, `vos.dsk` (avec les touches du test) en A: et `apps.dsk` en B: : le Lanceur montre B: et PONG s'y lance |
| `test-vrouves` | VROUVES depuis sa disquette en B:, par le Lanceur (TAB) : construction, la vague 1, l'argent, HIGH SCORES |
| `test-notepad` | NOTEPAD : saisie, DEL, le dialogue d'enregistrement, OPEN avec seulement les fichiers `.TXT` ; puis ^M : la page (mode 2) |
| `test-notepad-big` | la fenêtre de texte de NOTEPAD dans un émulateur Z80 (`tools/notepad_check.py`) : un fichier de 12K avec sa propre banque de données, déplacements, saisie et SAVE, texte jusqu'à 16K, et 4K sur un 6128 |
| `test-data` | (576K) NOTEPAD avec un texte de 15K jusqu'à la ligne 33, MARKDOWN entre-temps, puis NOTEPAD de retour au début : les lignes depuis sa propre banque de données |
| `test-paint` | PAINT : ligne, rectangle, remplissage, les menus, puis les calques (en cacher un), OTHER DRIVE et EXPORT .SCR vers B: ("SAVED AS .SCR") |
| `test-paint-big` | PAINT sur tout l'écran (576K) : des lignes, la fenêtre déplacée par ses barres (un clic et un glissement), sa position, enregistrée en `B:NONAME.SCR` et rouverte |
| `test-scr` | l'EXPORT .SCR de PAINT (son code dans un émulateur Z80, `tools/scr_check.py`) chargé en BASIC depuis une disquette, avec la palette ; chaque pixel de l'écran est vérifié |
| `test-about` | AIDE > À PROPOS DE V-OS |
| `test-music` | MUSIC depuis `music.dsk` en B: : un morceau joue, et continue derrière le Lanceur |
| `test-markdown` | MARKDOWN depuis `markdown.dsk` en B: : `README.MD` ouvert, la page avec ^P, un écran plus bas, retour au texte ; puis ^M : la page (mode 2) |
| `test-open` | ouverture selon le type dans le Commander : `README.MD` dans MARKDOWN depuis B:, un `.TXT` dans NOTEPAD depuis A: |
| `test-sysinfo` | SYSINFO depuis le Commander : version, API, mémoire, K libres en A: et B:, ^R, ^Q. Avec `SYSINFO_RAM=576`, avec une extension de 512K |
| `test-clip` | le presse-papiers : sélection avec SHIFT, ^C et ^V dans NOTEPAD, ^A, ^X, ^V, puis ^V dans MARKDOWN |
| `test-webget` | à la main, dans le CPCEMU de `make linux` (carte M4 ; il faut un écran et internet) : WEBGET télécharge `example.com/index.html`. Fermez CPCEMU avec F12 quand SAVED s'affiche, et `INDEX.HTM` est cherché sur la disquette |
| `test-reader` | READER depuis `reader.dsk` en B: ouvre `INDEX.MD`, TAB choisit un lien, RETURN ouvre `ABOUT.MD`, DEL revient, et un lien `https://` donne un message ; puis ^M : la page (mode 2) |
| `test-db` | le moteur de bases de données dans un émulateur Z80 (`tools/db_check.py`) : des milliers d'appels au hasard sur quatre tables, vérifiés par un modèle, le fichier page par page (`tools/vdb.py`), jusqu'à remplir la disquette |
| `test-db-disc` | `DB.SYS` avec le système de fichiers du noyau sur une image DSK (`tools/db_disc_check.py`) |
| `test-streets` | STREETS depuis `streets.dsk` en B: : un nouveau `STREETS.VDB` avec 24 rues, recherche, une nouvelle rue |
| `test-database-z80` | DATABASE dans un émulateur Z80, la base en Python et l'écran en texte : deux tables, 47 enregistrements par le formulaire, l'ordre sans casse ni accents, la recherche, un changement, une suppression, le défilement |
| `test-database` | DATABASE dans Caprice32 : une nouvelle base en B:, une table, trois enregistrements par le formulaire, la liste, la recherche, un changement |
| `test-calc-sys` | le moteur de formules `CALC.SYS` dans un émulateur Z80 (`tools/calc_check.py`) : des formules fixes et 40 000 aléatoires, des nombres et des textes, comparés à un modèle en Python |
| `test-sheet-z80` | SHEET dans un émulateur Z80 avec `CALC.SYS` lui-même et l'écran en texte : valeurs, `#ERR`, cellules qui s'utilisent l'une l'autre, défilement, SAVE et OPEN, un fichier UTF-8, `BUDGET.VSH`, une feuille pleine ; puis ^M : la page (mode 2) |
| `test-sheet` | SHEET dans Caprice32 : des nombres et une formule tapés, `CALC.SYS` depuis A:, la feuille enregistrée en B: ; puis ^M : la page (mode 2) |
| `test-kbds` | CLAVIERS : LES SIX dans Setup, puis dans NOTEPAD les touches `:` et Z avec chaque clavier : `:z`, `:ζ`, `mw`, `ñz`, `öy`, `òz` |
| `test-charset`, `test-reader-utf8` | des fichiers UTF-8 en grec, français, espagnol, allemand et italien dans NOTEPAD et dans READER |
| `test-utf8` | le code de `VX_UTF8` dans un émulateur Z80, face à `tools/voscs.py` |
| `test-view` | `VX_VIEW` : VIEWT (`apps/viewt`) dessine à travers une vue de 160 × 96, vérifiée pixel par pixel (`tools/view_check.py`) : la vue remplie, un rectangle coupé, 19 caractères sur 20, le dernier pixel, une image dedans et une dehors ; avec 128K : NO EXPANSION |
| `test-wm` | `VX_WINDOW` et `WM.SYS` (576K) : WINA et WINB (`apps/wint`) dans des fenêtres ; sept captures vérifiées (`tools/wm_check.py`) : l'une devant l'autre, passée devant par un clic avec sa barre, un clic dedans depuis son coin, déplacée par son titre, plein écran avec F7 et retour, fermées avec X jusqu'au Commander |
| `test-wm-apps` | CLOCK, SYSINFO et WINA dans des fenêtres à la fois (576K) ; cinq captures vérifiées (`tools/wm_apps_check.py`) : les trois l'une sur l'autre, CLOCK passé devant par un clic et déplacé, SYSINFO devant et CLOCK qui tourne derrière, à découvert, SYSINFO réduit par son coin |
| `test-wm-apps2` | DIARY, TELNET et CALC dans des fenêtres (576K, API 36 : la fenêtre montre une partie de l'écran du programme) ; quatre captures vérifiées (`tools/wm_apps2_check.py`) : DIARY, TELNET par-dessus, CALC avec ses boutons dans sa fenêtre, et 1 + 2 = 3 cliqués là |
| `test-wm-notepad` | NOTEPAD dans une fenêtre avec un NOTES.TXT (576K) : réduite par son coin, ses colonnes et lignes coupées à la fenêtre, la ligne d'état dessous ; la page (^M) en plein écran et la fenêtre revenue où elle était (`tools/wm_notepad_check.py`) |
| `test-wm-pages` | MARKDOWN avec INDEX.MD et son aperçu, READER (replié à la largeur de la fenêtre) et SHEET (4 colonnes, 18 lignes) dans des fenêtres (576K) ; la page de SHEET et le retour (`tools/wm_pages_check.py`) |
| `test-wm-copies` | copies des fenêtres (576K) : WINB déplacée loin de SYSINFO et WINA, par-dessus et de nouveau loin ; WINA et WINB écrivent combien de fois elles se sont dessinées et affichent toujours 001, l'image du bureau dessous (`tools/wm_copies_check.py`) |
| `test-wm-desktop` | le bureau parmi les fenêtres (576K, SETUP.CFG avec la fenêtre de A:) : WINA avec la fenêtre et les icônes du bureau derrière ; le bureau (F1) avec WINA sur sa surface ; chacun devant par un clic (`tools/wm_desktop_check.py`) |
| `test-wm-keys` | F5, F6, X et la palette parmi les fenêtres (576K) : CLOCK comme accessoire, WINA et WINB ; la liste des programmes (F6) et l'accessoire par-dessus les fenêtres, les fenêtres de nouveau à leur fermeture ; les rouges de WINA (P) laissent les couleurs ; le X de WINA : ^Q, WINB devant (`tools/wm_keys_check.py`) |
| `test-styles` | STYLES.VBN (`blocks/examples/styles.vbt`) depuis le Commander : normal, gras, italique, souligné et les trois, avec le bloc STYLE |
| `test-music-block` | avec 576K : TUNE.VBN (`blocks/examples/tune.vbt`) lance MUSIC (depuis B:) derrière lui avec AGANAMEM.MUS ; F6 montre « > TUNE » et MUSIC, et RETURN met MUSIC devant : A:AGANAMEM, PLAYING. Avec `MBLOCK_RAM=128` : « FERMEZ D'ABORD UN AUTRE PROGRAMME » |
| `test-amsdos`, `test-reboot`, `test-system` | les fichiers V-OS en BASIC, redémarrage, disquette SYSTEM |

**Nouveau script :**

1. Ajoutez un `IF TEST_SCRIPT == n` au début de la chaîne dans `test_script.asm`, avec `ELSE` avant le suivant et un `ENDIF` de plus à la fin.
2. Ajoutez une cible au Makefile, comme `test-sdk`.

Chaque touche s'écrit `dw from, to : db row, bit` du clavier. Le numéro de touche vaut rangée·8 + bit, par ex. RETURN = 18 = rangée 2, bit 2.

**Sans émulateur :** le code d'un programme tourne aussi sur un Z80 dans Python (le paquet `z80`). Vous chargez le `.BIN` en `#4000` et faites revenir immédiatement les appels de l'API (ou leur faites faire ce qu'il faut, par ex. des fichiers dans un dictionnaire). Ensuite vous appelez init et event et lisez la mémoire. C'est bien plus rapide que les captures pour les erreurs de nombres, de fichiers et de sauts. Les adresses des étiquettes viennent de `rasm … -s -sl` (un fichier `.sym`).

## À chaque étape

1. Le code, et un test dans Caprice32 : nouveau ou existant, avec captures d'écran.
2. Les tests que le changement touche.
3. Une section dans `MILESTONES.md` et `MILESTONES.el.md`, et une section « Υλοποίηση M… » (réalisation) dans `docs/REQUIREMENTS.md`.
4. **Mettre à jour le manuel dans les six langues** (`docs/manual/` en grec, `docs/manual/<code>/` pour en, fr, es, de, it, et `sdk/README.md`, `sdk/README.<code>.md` si l'API change), puis `make docs` pour tous les PDF.
5. Commit et push.
