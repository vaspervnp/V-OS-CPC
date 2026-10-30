# 4. Idiomas

V-OS habla seis idiomas. El inglés viene incorporado. Los otros cinco son **paquetes de idioma**, archivos del disquete que traen tres cosas: todos los textos del sistema, el teclado y las letras (la fuente) del idioma.

| Idioma | Archivo | Teclado |
|---|---|---|
| English | incorporado (`ENGLISH.MSG`) | el inglés del CPC |
| Ελληνικά | `GREEK.LNG` | griego, con acentos |
| Français | `FRENCH.LNG` | AZERTY, cifras con SHIFT, teclas muertas ^ y ¨ |
| Español | `SPANISH.LNG` | Ñ en la tecla `:`, teclas muertas ´ ¨ ` ^, y ¡ ¿ |
| Deutsch | `GERMAN.LNG` | QWERTZ, Ü Ö Ä ß, teclas muertas ´ y ` |
| Italiano | `ITALIAN.LNG` | è é ò à ù ì en sus propias teclas |

## Cambiar de idioma

- **De forma permanente:** en Ajustes (F4), la línea IDIOMA recorre todos los idiomas. Cada uno se carga al momento desde A:, y toda la pantalla se vuelve a dibujar en él. Al guardar (^S) se mantiene también para el siguiente arranque.
- **Rápidamente:** CONTROL+L (VER > CAMBIAR DE IDIOMA) cambia entre el inglés y el idioma del paquete cargado.
- **Solo el teclado:** CONTROL+SHIFT cambia el teclado entre el inglés y el del paquete. La barra de menús muestra a la derecha cuál está activo (EN, ΕΛ, FR, …).

Los símbolos `@ # [ ] { } \ |` no están en los teclados de los paquetes, porque el CPC no tiene AltGr. Escríbalos con el teclado inglés.

## Los textos de los programas

Los programas tienen sus propios textos en **dos idiomas**: inglés y, de forma opcional, uno más (hoy, griego). Un programa aparece en su segundo idioma solo cuando el paquete está en ese idioma. Si no, aparece en inglés. Así, con el francés, Studio aparece en inglés.

## Crear un idioma nuevo

Las fuentes de los idiomas están en `lang/<código>/`:

- `messages.txt`: los textos del sistema. La lista base la define `lang/en/messages.txt`, y lo que falte en un paquete aparece en inglés.
- `keymap.txt`: las teclas que difieren del teclado inglés.
- `pack.txt`: el código, el nombre, el juego de caracteres y la fuente.

`tools/mklng.py` los convierte en un `.LNG`, y el Makefile lo pone en el disquete. Los paquetes latinos comparten la fuente `lang/latin1/font.txt`.
