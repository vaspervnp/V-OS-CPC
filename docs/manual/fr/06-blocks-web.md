# 6. Les blocs sur le PC : l'éditeur web et `vbc.py`

En plus de Studio, qui tourne sur le CPC, il existe aussi un éditeur de blocs pour le PC. Le langage est le même, avec quelques blocs en plus : listes, bruit, taille des sprites, texte en couleur.

## L'éditeur

Ouvrez `blocks/editor.html` dans un navigateur. Il est basé sur Blockly et existe en grec ou en anglais.

- **Catégories :** événements, contrôle, mouvement, apparence, texte, opérateurs, capteurs, variables, listes et fenêtres.
- **Sprites :** rectangles ou costumes. Ils sont définis dans un tableau, et la scène les montre dans les couleurs du CPC. On peut les déplacer à la souris.
- **Fichiers :** il ouvre et enregistre des fichiers `.vbp`. Ce sont des fichiers JSON contenant tout le programme, ils peuvent donc aussi s'écrire à la main.

## Compilation

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

`vbc.py` écrit `build/NOM.ASM`, avec un commentaire pour chaque bloc. Il l'assemble avec RASM en `NOM.VBN`, avec une table de relocation pour qu'il tourne à côté d'autres programmes, et avec `--dsk` il le place sur la disquette.

| Option | Ce qu'elle fait |
|---|---|
| `-o build` | dossier de sortie |
| `--asm-only` | seulement le `.ASM` |
| `--dsk build/vos.dsk` | aussi sur la disquette |

## Le format `.vbp`

La description complète se trouve en tête de `blocks/vbc.py` : événements, commandes, valeurs, costumes, icône. En bref :

```json
{"name": "PONG", "mode": 0, "background": 0,
 "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
              "colour": 8, "vx": 2, "vy": 2, "visible": true}],
 "variables": {"score": 0},
 "scripts": [{"sprite": "ball", "when": {"event": "start"},
              "do": [{"block": "forever", "do": [{"block": "move"}, {"block": "bounce"}]}]}]}
```

- **Variables et listes :** elles ont des noms, pas des lettres. Les listes ont une longueur maximale fixe.
- **Icône :** `"icon"` donne une icône pour le Lanceur.
- **Un programme avec beaucoup de parties semblables :** un script Python peut l'écrire. Voir `tools/mkbricks.py`, qui écrit `bricks.vbp` avec 32 briques.

## Exemples

Dans `blocks/examples/` :

| Fichier | Programme |
|---|---|
| `pong.vbp` | PONG |
| `catch.vbp` | CATCH |
| `starcat.vbp` | STARCAT : costumes, un air tiré d'une liste |
| `counter.vbp` | COUNTER : une fenêtre et des boutons |
| `bricks.vbp` | BRICKS (écrit par `tools/mkbricks.py`) |

Les fichiers `*.vbt` sont des programmes Studio sous forme de texte, pour `tools/mkvbs.py`. Voir le [chapitre 5](05-studio.md).

## Studio ou éditeur web ?

| | Studio | éditeur web |
|---|---|---|
| Où | sur le CPC | sur le PC |
| Fichier | `.VBS` | `.vbp` |
| Variables | 128, A–H15 | avec des noms |
| Listes, bruit, taille des sprites | non | oui |
| SAVE/LOAD VARS | oui | non |
| Le programme | demande toute la mémoire | petit, tourne à côté d'autres |
