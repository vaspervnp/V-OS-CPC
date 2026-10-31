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

## Un alphabet pour toutes

Toutes les langues écrivent avec le même jeu de caractères, le **jeu de V-OS**, et chaque module a toutes ses lettres. Ainsi un texte ou une base peut mêler grec, français, allemand, espagnol et italien, et tout s'affiche bien quelle que soit la langue active : dans Setup, LANGUAGE montre ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL avec leurs propres lettres.

Les codes 128 à 255 sont ceux du grec en ISO 8859-7, tels quels, et les codes qu'il laisse libres reçoivent À Á Â Ä Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Ö Ù Ú Û Ü, leurs minuscules, ß et ¡ ¿. L'accent ´ s'écrit comme le tonos grec (΄) et µ comme μ. Il n'y a pas de ÿ, Œ ni œ. La table est dans `tools/voscs.py`. Un fichier texte grec d'un PC (ISO 8859-7) se lit tel quel ; un fichier français ou allemand en Latin-1 doit être converti.

Avec le clavier anglais, SHIFT et `^` donne £.

## Créer une nouvelle langue

Les sources des langues se trouvent dans `lang/<code>/` :

- `messages.txt` : les textes du système. La liste de base est définie par `lang/en/messages.txt`, et tout ce qui manque dans un module apparaît en anglais.
- `keymap.txt` : les touches qui diffèrent du clavier anglais.
- `pack.txt` : le code, le nom, le jeu de caractères et la police.

`tools/mklng.py` les transforme en `.LNG`, et le Makefile le place sur la disquette. Tous les modules ont la même police, `lang/vos/font.txt`, et `charset vos`.
