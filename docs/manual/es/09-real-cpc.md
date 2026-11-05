# 9. En un CPC real

V-OS solo se ha probado en emuladores: Caprice32, 1984 y CPCEMU. Un CPC real puede comportarse de otra manera en su unidad de disco, su teclado, su CRTC, su monitor o con un ratón AMX. Este capítulo es una lista de cosas que probar, y lo que cada una debe hacer. Si algo hace otra cosa, díganoslo. Incluso "todo funcionó" ayuda.

## Cómo llevar V-OS al CPC

La versión publicada tiene dos imágenes de disco, `vos.dsk` (A:) y `apps.dsk` (B:). Cada una cabe en un disquete de 3" (180K). Algunas formas de usarlas:

- **Un Gotek o un HxC** en lugar de una unidad: copie los archivos `.dsk` a su memoria USB.
- **Una unidad de 3,5" de PC** conectada al CPC como unidad B:: grabe las imágenes en disquetes (por ejemplo con SAMdisk o DiskImager en Windows).
- **Una tarjeta M4:** copie las imágenes a su tarjeta SD y móntelas desde su menú.

Después, en BASIC: `RUN"VOS`.

## Qué anotar primero

- El modelo (CPC 6128 o 6128 Plus) y, si lo sabe, el tipo de CRTC (0 a 4).
- La ampliación de memoria (ninguna, 64K, 512K…), las unidades, el ratón, una tarjeta M4.
- El monitor (CTM644 en color, GT65 verde, un televisor con un adaptador…).

## La lista

Cada línea: qué hacer, y qué debería ver.

**El arranque**
- [ ] `RUN"VOS` desde A:. En unos segundos: el Escritorio, la barra de menús arriba, los iconos de las unidades a la derecha. Nada parpadea ni salta.
- [ ] La imagen llena toda la pantalla (overscan, 384×272), sin nada cortado a los lados ni abajo.
- [ ] AYUDA > ACERCA DE V-OS muestra el número de la versión publicada.
- [ ] SYSINFO (en Programas, F2) muestra la memoria que tiene.

**La unidad de disco**
- [ ] TAB en el Escritorio abre la ventana de A:, con sus archivos como iconos. Un segundo TAB: B:.
- [ ] En el Commander (F3), copie un archivo de A: a B: (^C). Luego salga de V-OS (CONTROL+Q) y, en BASIC, `CAT` en B: lo muestra y `LOAD` lo lee.
- [ ] Renombre (^N) y borre (^D) un archivo en B:.
- [ ] FORMATEAR DISCO (DATA) en el menú ARCHIVO del Commander, en un disquete que no necesite. Luego `CAT` en BASIC: un disquete vacío.
- [ ] También se lee un disquete en formato SYSTEM (el de CP/M).
- [ ] Ajustes (F4): cambie el IDIOMA, ^S. Arranque de nuevo con `RUN"VOS`: V-OS arranca en ese idioma.
- [ ] Sin disquete en B:, el Commander lo dice, y V-OS no se cuelga.

**El teclado**
- [ ] Cada tecla en NOTEPAD: letras, dígitos, símbolos, SHIFT, CAPS LOCK, las flechas, DEL, CLR, COPY.
- [ ] CONTROL+SHIFT cambia el idioma del teclado (EN, ΕΛ, …, a la derecha de la barra de menús). Las letras griegas y acentuadas salen bien.
- [ ] Una tecla mantenida se repite a la velocidad de RETARDO REPETICIÓN y VELOC. REPETICIÓN de Ajustes.
- [ ] Las teclas de función: F1 Escritorio, F2 Programas, F3 Commander, F4 Ajustes, F6 los programas en marcha.

**El ratón AMX**
- [ ] Ajustes: RATÓN AMX en SÍ. El puntero sigue al ratón a la misma velocidad en horizontal y en vertical, en modo 1 (el Escritorio) y en modo 0 (Programas).
- [ ] Si salta o va en sentido contrario, pruebe el otro valor de LECTURA AMX.
- [ ] Botón izquierdo: un clic; en el título de una ventana, la arrastra; en la esquina de abajo a la derecha, cambia su tamaño.

**La memoria**
- [ ] Sin ampliación: NOTEPAD y PONG a la vez, F6 para pasar de uno a otro; STUDIO funciona solo.
- [ ] Con ampliación: cuatro programas a la vez, cada uno donde se dejó. PAINT con una imagen grande. Una imagen en el Escritorio (Ajustes, IMAGEN DE FONDO).

**La pantalla**
- [ ] PAINT y Programas en modo 0 (16 colores): los colores son correctos.
- [ ] READER o NOTEPAD con una página en modo 2 (80 columnas): legible, también en un monitor en color.
- [ ] La pantalla mixta de Studio (modo 0 arriba, modo 1 abajo): la línea de separación se queda quieta, nada parpadea.
- [ ] El tema oscuro (Ajustes, TEMA).

**El sonido**
- [ ] MUSIC toca una canción; sigue sonando mientras va al Escritorio y arranca otro programa.
- [ ] Los juegos (VROUVES, BRICKS, PONG) tienen sus sonidos.

**La tarjeta M4** (si tiene una)
- [ ] TAB en el Escritorio pasa de B: a DISK, la tarjeta SD, con sus carpetas.
- [ ] NOTEPAD guarda un archivo en DISK, y lo vuelve a abrir.
- [ ] La barra de menús muestra la hora de la M4; INFO DEL ARCHIVO de un archivo en DISK da su fecha.
- [ ] WEBGET descarga un archivo; READER abre una página de la web.
- [ ] TELNET se conecta a un servidor (una BBS) y muestra lo que envía.
- [ ] MAIL trae mensajes de un servidor POP3 y envía uno por SMTP.
- [ ] FTP lista la carpeta de un servidor, trae un archivo y envía uno.

**La velocidad** (cuánto tarda, con un reloj)
- [ ] De `RUN"VOS` al Escritorio.
- [ ] De F2 a Programas, y del icono de un programa al programa.
- [ ] SHEET: BUDGET.VSH abierto y calculado.

## Cómo decírnoslo

Abra un issue en <https://github.com/vaspervnp/V-OS-CPC/issues> con:

- lo que anotó primero (el modelo, la memoria, el monitor…);
- las líneas que hicieron otra cosa, y qué hicieron;
- una foto de la pantalla, si algo se ve mal.
