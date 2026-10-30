# 4. Les langues

V-OS parle six langues. L'anglais est intégré. Les cinq autres sont des **modules de langue**, des fichiers sur la disquette qui apportent trois choses : tous les textes du système, le clavier et les lettres (la police) de la langue.

| Langue | Fichier | Clavier |
|---|---|---|
| English | intégré (`ENGLISH.MSG`) | celui, anglais, du CPC |
| Ελληνικά | `GREEK.LNG` | grec, avec accents |
| Français | `FRENCH.LNG` | AZERTY, chiffres avec SHIFT, touches mortes ^ et ¨ |
| Español | `SPANISH.LNG` | Ñ sur la touche `:`, touches mortes ´ ¨ ` ^, et ¡ ¿ |
| Deutsch | `GERMAN.LNG` | QWERTZ, Ü Ö Ä ß, touches mortes ´ et ` |
| Italiano | `ITALIAN.LNG` | è é ò à ù ì sur leurs propres touches |

## Changer de langue

- **Durablement :** dans les Réglages (F4), la ligne LANGUE fait défiler toutes les langues. Chacune se charge aussitôt depuis A:, et tout l'écran est redessiné dans cette langue. Enregistrer (^S) la conserve aussi pour le démarrage suivant.
- **Rapidement :** CONTROL+L (AFFICHAGE > CHANGER DE LANGUE) bascule entre l'anglais et la langue du module chargé.
- **Clavier seul :** CONTROL+SHIFT bascule le clavier entre l'anglais et celui du module. La barre de menus indique à droite lequel est actif (EN, ΕΛ, FR, …).

Les symboles `@ # [ ] { } \ |` ne sont pas sur les claviers des modules, car le CPC n'a pas de touche AltGr. Tapez-les avec le clavier anglais.

## Les textes des programmes

Les programmes ont leurs propres textes en **deux langues** : l'anglais et, en option, une autre (aujourd'hui, le grec). Un programme n'apparaît dans sa seconde langue que si le module est dans cette langue. Sinon, il apparaît en anglais. Ainsi, en français, Studio apparaît en anglais.

## Créer une nouvelle langue

Les sources des langues se trouvent dans `lang/<code>/` :

- `messages.txt` : les textes du système. La liste de base est définie par `lang/en/messages.txt`, et tout ce qui manque dans un module apparaît en anglais.
- `keymap.txt` : les touches qui diffèrent du clavier anglais.
- `pack.txt` : le code, le nom, le jeu de caractères et la police.

`tools/mklng.py` les transforme en `.LNG`, et le Makefile le place sur la disquette. Les modules latins partagent la police `lang/latin1/font.txt`.
