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
| `make` | `build/vos.dsk` : le noyau, les vues, les langues, tous les programmes et `myapps/*` |
| `make run` | ouvre la disquette dans Caprice32 (`RUN"VOS"`) |
| `make shot` | démarre sans fenêtre et prend une capture d'écran |
| `make docs` | le manuel en PDF : `docs/V-OS.pdf` (grec) et `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip` : `V-OS.exe` pour Windows, avec CPCEMU 3.0.2 (CPC 6128, 576K, souris AMX, carte M4), `vos.dsk` en A: et `vrouves.dsk` en B:. V-OS démarre tout seul. Il faut WSL et le zip portable de CPCEMU (`CPCEMU_ZIP=…`) |
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
- **Documentation :** en grec. `README.md` et `docs/REQUIREMENTS.md` ont une section par étape. Le manuel est écrit en grec et traduit dans les cinq autres langues de V-OS.
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
| `test-calc` | CALC avec des clics, puis `CALC.VBS` dans Studio |
| `test-costume` | costume dans Studio, exécution, réouverture |
| `test-acc` | l'horloge comme accessoire de bureau |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | plusieurs programmes, F6, extension mémoire, arrière-plan |
| `test-drag` | déplacement des fenêtres |
| `test-langs`, `test-lang` | les langues, l'enregistrement de la langue |
| `test-mines`, `test-bricks` | les jeux |
| `test-vars` | les 128 variables, SAVE/LOAD VARS |
| `test-sdk` | le modèle du SDK |
| `test-vrouves` | VROUVES depuis sa disquette en B:, par le Lanceur (TAB) : construction, la vague 1, l'argent, HIGH SCORES |
| `test-notepad` | NOTEPAD : saisie, DEL, le dialogue d'enregistrement, OPEN avec seulement les fichiers `.TXT` |
| `test-paint` | PAINT : ligne, rectangle, remplissage, les menus, puis les calques (en cacher un) |
| `test-about` | AIDE > À PROPOS DE V-OS |
| `test-music` | MUSIC depuis `music.dsk` en B: : un morceau joue, et continue derrière le Lanceur |
| `test-markdown` | MARKDOWN depuis `markdown.dsk` en B: : `README.MD` ouvert, la page avec ^P, un écran plus bas, retour au texte |
| `test-amsdos`, `test-reboot`, `test-system` | les fichiers V-OS en BASIC, redémarrage, disquette SYSTEM |

**Nouveau script :**

1. Ajoutez un `IF TEST_SCRIPT == n` au début de la chaîne dans `test_script.asm`, avec `ELSE` avant le suivant et un `ENDIF` de plus à la fin.
2. Ajoutez une cible au Makefile, comme `test-sdk`.

Chaque touche s'écrit `dw from, to : db row, bit` du clavier. Le numéro de touche vaut rangée·8 + bit, par ex. RETURN = 18 = rangée 2, bit 2.

**Sans émulateur :** le code d'un programme tourne aussi sur un Z80 dans Python (le paquet `z80`). Vous chargez le `.BIN` en `#4000` et faites revenir immédiatement les appels de l'API (ou leur faites faire ce qu'il faut, par ex. des fichiers dans un dictionnaire). Ensuite vous appelez init et event et lisez la mémoire. C'est bien plus rapide que les captures pour les erreurs de nombres, de fichiers et de sauts. Les adresses des étiquettes viennent de `rasm … -s -sl` (un fichier `.sym`).

## À chaque étape

1. Le code, et un test dans Caprice32 : nouveau ou existant, avec captures d'écran.
2. Les tests que le changement touche.
3. Une section dans `README.md` et une section « Υλοποίηση M… » (réalisation) dans `docs/REQUIREMENTS.md`.
4. **Mettre à jour le manuel dans les six langues** (`docs/manual/` en grec, `docs/manual/<code>/` pour en, fr, es, de, it, et `sdk/README.md`, `sdk/README.<code>.md` si l'API change), puis `make docs` pour tous les PDF.
5. Commit et push.
