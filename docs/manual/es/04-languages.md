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
- **Solo el teclado:** CONTROL+SHIFT cambia el teclado. La barra de menús muestra a la derecha cuál está activo (EN, ΕΛ, FR, …). Con TECLADOS de Setup en EN + IDIOMA va entre el inglés y el del paquete; en LOS SEIS pasa por todos: EN, el del paquete, los otros cuatro, y otra vez EN. Así puedes escribir francés con el teclado francés mientras el sistema está en griego. Cada paquete contiene los teclados de todos.

Los símbolos `@ # [ ] { } \ |` no están en los teclados de los paquetes, porque el CPC no tiene AltGr. Escríbalos con el teclado inglés.

## Los textos de los programas

Los programas tienen sus propios textos en **dos idiomas**: inglés y, de forma opcional, uno más (hoy, griego). Un programa aparece en su segundo idioma solo cuando el paquete está en ese idioma. Si no, aparece en inglés. Así, con el francés, Studio aparece en inglés. Los programas de Studio, en cambio, pueden tener sus textos en los seis idiomas ([capítulo 5](05-studio.md)): CALC se llama «CALCULADORA» en español.

## Un alfabeto para todos

Todos los idiomas escriben con el mismo juego de caracteres, el **juego de V-OS**, y cada paquete tiene todas sus letras. Así un texto o una base puede mezclar griego, francés, alemán, español e italiano, y todo se ve bien sea cual sea el idioma activo: en Setup, LANGUAGE muestra ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL con sus propias letras.

Los códigos 128 a 255 son los del griego en ISO 8859-7, tal cual, y los códigos que deja libres llevan À Á Â Ä Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Ö Ù Ú Û Ü, sus minúsculas, ß y ¡ ¿. El acento ´ se escribe como el tonos griego (΄) y µ como μ. No hay ÿ, Œ ni œ. La tabla está en `tools/voscs.py`. Un archivo de texto griego de un PC (ISO 8859-7) se lee tal cual; uno francés o alemán en Latin-1 hay que convertirlo.

Con el teclado inglés, SHIFT y `^` da £.

Los archivos en **UTF-8**, de un PC o de la web, los abren NOTEPAD y READER, que los pasan al juego de V-OS; lo que no tiene (chino, por ejemplo) se vuelve `?`. En el PC, `tools/voscv.py` convierte archivos desde y hacia V-OS (UTF-8, Latin-1 y otros) y dice qué es un archivo (`check`).

## Crear un idioma nuevo

Las fuentes de los idiomas están en `lang/<código>/`:

- `messages.txt`: los textos del sistema. La lista base la define `lang/en/messages.txt`, y lo que falte en un paquete aparece en inglés.
- `keymap.txt`: las teclas que difieren del teclado inglés.
- `pack.txt`: el código, el nombre, el juego de caracteres y la fuente.

`tools/mklng.py` los convierte en un `.LNG`, y el Makefile lo pone en el disquete. Todos los paquetes tienen la misma fuente, `lang/vos/font.txt`, y `charset vos`.
