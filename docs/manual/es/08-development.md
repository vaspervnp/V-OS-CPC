# 8. Desarrollo de V-OS

Para quienes trabajan en el propio V-OS. Los programas *para* V-OS se describen en el [SDK](../../../sdk/README.es.md).

## Qué se necesita

- [RASM](https://github.com/EdouardBERGE/rasm), el ensamblador
- [iDSK](https://github.com/cpcsdk/idsk), para las imágenes de disquete
- Python 3, para las herramientas. `make docs` necesita además `markdown` y `pymupdf`.
- GNU make 4.3 o posterior
- para las pruebas, Caprice32 (snap `caprice32`)

## Compilación

| Orden | Qué hace |
|---|---|
| `make` | `build/vos.dsk` (A:): el núcleo, las vistas, los idiomas, DEMO, MIXED, STUDIO, CLOCK y las fuentes `.VBS`; `build/apps.dsk` (B:): los demás programas y `myapps/*`; y el disquete de cada programa con `owndisc/`. Si un archivo no cabe en un disquete real (180K), se detiene con un error |
| `make run` | abre el disquete en Caprice32 (`RUN"VOS"`) |
| `make shot` | arranca sin ventana y hace una captura de pantalla |
| `make docs` | el manual en PDF: `docs/V-OS.pdf` (griego) y `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip`: `V-OS.exe` para Windows, con CPCEMU 3.0.2 (CPC 6128, 576K, ratón AMX, tarjeta M4), `vos.dsk` en A:, `apps.dsk` en B: y los disquetes de los programas al lado. V-OS arranca solo. Hace falta WSL y el zip portable de CPCEMU (`CPCEMU_ZIP=…`) |
| `make linux` | `build/V-OS-linux.tar.gz`: el script `V-OS` para Linux (x86_64), con CPCEMU 2.5 (la 3.0.2 no ha salido para Linux) y los mismos ajustes y disquetes. Hace falta SDL2 en el sistema y el tar.gz de CPCEMU para Linux (`CPCEMU_TGZ=…`) |
| `make songs` | las canciones de Arkos Tracker 3 como archivos `.MUS` en `myapps/music/owndisc` (`tools/mkmusic.py`; hace falta Arkos Tracker 3, `ARKOS=…`) |
| `make new-app NAME=x`, `make app NAME=x` | su propio programa (SDK) |
| `make clean` | borra `build/` |

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `src/vos.asm` | la raíz de la compilación: cargador y núcleo, escritura en el disquete |
| `src/boot/` | el cargador que AMSDOS ejecuta en `#4000`, detección de la ampliación de RAM |
| `src/kernel/` | vectores, interrupciones, sistema de archivos, vistas, API (`api.asm`), ajustes, extensión del núcleo (`ext.asm`), scripts de prueba (`test_script.asm`) |
| `src/drivers/` | Gate Array, CRTC, teclado, ratón AMX, FDC, AY |
| `src/gfx/` | gráficos overscan, texto, pantalla mixta |
| `src/ui/` | menús, botones, diálogos, introducción de texto, selector de archivos |
| `src/shell/` | las vistas como overlays: Escritorio, Programas, Commander, Ajustes |
| `src/api/vos_api.inc` | la API para los programas |
| `lang/` | los idiomas (textos, teclados, fuentes) |
| `apps/` | los programas en ensamblador: DEMO, MIXED, STUDIO, CLOCK, y sus iconos |
| `blocks/` | el editor web, `vbc.py`, `runtime.asm`, el reproductor de Studio (`player.asm`), ejemplos |
| `sdk/` | el SDK: guía y plantilla de programa |
| `tools/` | herramientas: fuentes, idiomas, textos, iconos, reubicación, `.VBS` a partir de texto, capturas de pantalla, PDF |
| `docs/` | este manual en griego (`manual/`) y en inglés, francés, español, alemán e italiano (`manual/en/`, `fr/`, `es/`, `de/`, `it/`), los PDF, los requisitos (`REQUIREMENTS.md`) |

## La memoria, en resumen

| Zona | Qué contiene |
|---|---|
| `#0000–#3DFF` | el núcleo. En la página cero, después de los vectores de reinicio, la tabla de la API en `#0108` |
| hasta `#4000` | la pila del núcleo |
| `#4000–#7FFF` | la "ventana" de bancos |
| `#8000–#FFFF` | la pantalla overscan de 32K. En sus huecos, búferes del núcleo |

Los bancos que entran en la ventana:

| Banco | Qué contiene |
|---|---|
| 4 | búfer de archivos y de carga, y el banco de datos del programa en marcha |
| 5 | la vista en `#4000–#4FFF`, y desde `#5000` los programas con tabla de reubicación (o un programa sin tabla en todo el banco) |
| 6 | lo que tapan los menús y los diálogos, y desde `#7000` el accesorio de escritorio |
| 7 | el paquete de idioma, las listas del Commander, los textos ingleses, y desde `#7000` la extensión del núcleo |

Con una ampliación de memoria, sus bancos acogen programas. Los detalles, dirección por dirección, están en `docs/REQUIREMENTS.md` (§4.2 y en cada sección "Υλοποίηση M…" (implementación)).

## Convenciones

- **RASM:** el hexadecimal se escribe `#C000` y no `&C000`, porque RASM lee `&` como AND. Las etiquetas no distinguen mayúsculas de minúsculas.
- **Comentarios:** en inglés, breves, como en el código existente. Cada archivo empieza con un bloque que dice qué hace.
- **Documentación:** en griego. `MILESTONES.md` (inglés), `MILESTONES.el.md` (griego) y `docs/REQUIREMENTS.md` tienen una sección para cada hito. El manual se escribe en griego y se traduce a los otros cinco idiomas de V-OS.
- **Textos:** los textos del sistema están en `lang/*/messages.txt`, y los textos de los programas en `texts.txt` (para `tools/mktexts.py`).

## Pruebas

Las pruebas ejecutan V-OS en Caprice32 sin ventana y hacen capturas de pantalla en `build/shots/<retardo>/`.

**Cómo funcionan:**

- Caprice32 sin ventana no puede pulsar flechas, COPY ni teclas f. Por eso las pulsaciones las hace una compilación especial: un `-DTEST_SCRIPT=n` pone el script n en `src/kernel/test_script.asm`, una tabla de teclas por fotograma.
- Cada objetivo `make test-…` compila un disquete con su script y hace una captura en cada retardo de `…_SHOTS`.
- El retardo se mide en pulsaciones de "Z": unos 2,5–3,5 fotogramas cada una. La correspondencia no es fija, así que un momento se captura con dos o tres retardos a su alrededor.
- Una vez que V-OS escribe en el disquete, Caprice32 no se cierra solo, y la prueba termina por tiempo agotado. Esto es lo esperado en test-vars, test-costume y otras.
- Las capturas se miran a mano, p. ej. combinadas en una sola imagen con `ffmpeg … hstack/vstack`.

| Objetivo | Qué prueba |
|---|---|
| `test-input` | teclas, Studio: bloques, archivos, ejecución |
| `test-calc` | CALC con clics, luego `CALC.VBS` en Studio y su título en inglés y en francés (^T) |
| `test-costume` | disfraz en Studio, ejecución, reapertura |
| `test-acc` | el reloj como accesorio de escritorio |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | varios programas, F6, ampliación de memoria, segundo plano |
| `test-drag` | arrastrar ventanas |
| `test-langs`, `test-lang` | los idiomas, guardar el idioma |
| `test-mines`, `test-bricks` | los juegos |
| `test-vars` | las 128 variables, SAVE/LOAD VARS |
| `test-sdk` | la plantilla del SDK |
| `test-apps` | los dos disquetes tal como se entregan, `vos.dsk` (con las teclas del test) en A: y `apps.dsk` en B:: el Launcher muestra B: y PONG se ejecuta desde allí |
| `test-vrouves` | VROUVES desde su disquete en B:, por el Launcher (TAB): construir, la oleada 1, el dinero, HIGH SCORES |
| `test-notepad` | NOTEPAD: escribir, DEL, el diálogo de guardar, OPEN solo con archivos `.TXT`; luego ^M: la página (modo 2) |
| `test-notepad-big` | la ventana de texto de NOTEPAD en un emulador Z80 (`tools/notepad_check.py`): un archivo de 12K con su propio banco de datos, mover, escribir y SAVE, texto hasta 16K, y 4K en un 6128 |
| `test-data` | (576K) NOTEPAD con un texto de 15K hasta la línea 33, MARKDOWN mientras tanto, y NOTEPAD de vuelta al principio: las líneas desde su propio banco de datos |
| `test-paint` | PAINT: línea, rectángulo, relleno, los menús, y luego las capas (ocultar una), OTHER DRIVE y EXPORT .SCR a B: ("SAVED AS .SCR") |
| `test-paint-big` | PAINT en toda la pantalla (576K): líneas, la ventana movida por sus barras (un clic y un arrastre), su posición, guardada como `B:NONAME.SCR` y abierta de nuevo |
| `test-scr` | el EXPORT .SCR de PAINT (su código en un emulador Z80, `tools/scr_check.py`) cargado en BASIC desde un disco, con la paleta; se comprueba cada píxel de la pantalla |
| `test-about` | AYUDA > ACERCA DE V-OS |
| `test-music` | MUSIC desde `music.dsk` en B:: una canción suena y sigue detrás del Launcher |
| `test-markdown` | MARKDOWN desde `markdown.dsk` en B:: abre `README.MD`, la página con ^P, una pantalla más abajo, vuelta al texto; luego ^M: la página (modo 2) |
| `test-open` | abrir según el tipo en el Commander: `README.MD` en MARKDOWN desde B:, un `.TXT` en NOTEPAD desde A: |
| `test-sysinfo` | SYSINFO desde el Commander: versión, API, memoria, K libres en A: y B:, ^R, ^Q. Con `SYSINFO_RAM=576`, con una ampliación de 512K |
| `test-clip` | el portapapeles: seleccionar con SHIFT, ^C y ^V en NOTEPAD, ^A, ^X, ^V, y luego ^V en MARKDOWN |
| `test-webget` | a mano, en el CPCEMU de `make linux` (tarjeta M4; hacen falta una pantalla e internet): WEBGET descarga `example.com/index.html`. Cierre CPCEMU con F12 cuando aparezca SAVED, y se busca `INDEX.HTM` en el disquete |
| `test-reader` | READER desde `reader.dsk` en B: abre `INDEX.MD`, TAB elige un enlace, RETURN abre `ABOUT.MD`, DEL vuelve, y un enlace `https://` da un mensaje; luego ^M: la página (modo 2) |
| `test-db` | el motor de bases de datos en un emulador Z80 (`tools/db_check.py`): miles de llamadas al azar en cuatro tablas, comprobadas con un modelo, el archivo página a página (`tools/vdb.py`), hasta llenar el disco |
| `test-db-disc` | `DB.SYS` con el sistema de archivos del kernel en una imagen DSK (`tools/db_disc_check.py`) |
| `test-streets` | STREETS desde `streets.dsk` en B:: un `STREETS.VDB` nuevo con 24 calles, búsqueda, una calle nueva |
| `test-database-z80` | DATABASE en un emulador Z80, con la base en Python y la pantalla como texto: dos tablas, 47 registros desde el formulario, el orden sin mayúsculas ni acentos, la búsqueda, un cambio, un borrado, el desplazamiento |
| `test-database` | DATABASE en Caprice32: una base nueva en B:, una tabla, tres registros desde el formulario, la lista, la búsqueda, un cambio |
| `test-calc-sys` | el motor de fórmulas `CALC.SYS` en un emulador Z80 (`tools/calc_check.py`): fórmulas fijas y 40.000 aleatorias, números y textos, comparados con un modelo en Python |
| `test-sheet-z80` | SHEET en un emulador Z80 con el propio `CALC.SYS` y la pantalla como texto: valores, `#ERR`, celdas que se usan entre sí, desplazamiento, SAVE y OPEN, un archivo UTF-8, `BUDGET.VSH`, una hoja llena; luego ^M: la página (modo 2) |
| `test-sheet` | SHEET en Caprice32: números y una fórmula tecleados, `CALC.SYS` desde A:, la hoja guardada en B:; luego ^M: la página (modo 2) |
| `test-kbds` | TECLADOS: LOS SEIS en Setup, luego en NOTEPAD las teclas `:` y Z con cada teclado: `:z`, `:ζ`, `mw`, `ñz`, `öy`, `òz` |
| `test-charset`, `test-reader-utf8` | archivos UTF-8 en griego, francés, español, alemán e italiano en NOTEPAD y en READER |
| `test-utf8` | el código de `VX_UTF8` en un emulador Z80, frente a `tools/voscs.py` |
| `test-view` | `VX_VIEW`: VIEWT (`apps/viewt`) dibuja a través de una vista de 160 × 96, comprobada píxel a píxel (`tools/view_check.py`): la vista llena, un rectángulo cortado, 19 de 20 caracteres, el último píxel, una imagen dentro y otra fuera; con 128K: NO EXPANSION |
| `test-wm` | `VX_WINDOW` y `WM.SYS` (576K): WINA y WINB (`apps/wint`) en ventanas; siete capturas comprobadas (`tools/wm_check.py`): una delante de la otra, traída delante con un clic y su barra, un clic dentro desde su esquina, movida por su título, pantalla completa con F7 y de vuelta, cerradas con X hasta el Commander |
| `test-wm-apps` | CLOCK, SYSINFO y WINA en ventanas a la vez (576K); cinco capturas comprobadas (`tools/wm_apps_check.py`): las tres unas sobre otras, CLOCK traído delante con un clic y movido, SYSINFO delante y CLOCK en marcha detrás, sin tapar, SYSINFO reducido por su esquina |
| `test-wm-apps2` | DIARY, TELNET y CALC en ventanas (576K, API 36: la ventana muestra una parte de la pantalla del programa); cuatro capturas comprobadas (`tools/wm_apps2_check.py`): DIARY, TELNET encima, CALC con sus botones en su ventana, y 1 + 2 = 3 pulsados allí |
| `test-wm-notepad` | NOTEPAD en una ventana con un NOTES.TXT (576K): reducida por su esquina, sus columnas y filas cortadas a la ventana, la línea de estado debajo; la página (^M) a pantalla completa y la ventana de vuelta donde estaba (`tools/wm_notepad_check.py`) |
| `test-wm-pages` | MARKDOWN con INDEX.MD y su vista previa, READER (ajustado al ancho de la ventana) y SHEET (4 columnas, 18 filas) en ventanas (576K); la página de SHEET y la vuelta (`tools/wm_pages_check.py`) |
| `test-wm-copies` | copias de las ventanas (576K): WINB movida lejos de SYSINFO y WINA, sobre ellas y lejos otra vez; WINA y WINB escriben cuántas veces se han dibujado y siguen diciendo 001, con la imagen del escritorio debajo (`tools/wm_copies_check.py`) |
| `test-styles` | STYLES.VBN (`blocks/examples/styles.vbt`) desde el Commander: normal, negrita, cursiva, subrayado y los tres, con el bloque STYLE |
| `test-music-block` | con 576K: TUNE.VBN (`blocks/examples/tune.vbt`) inicia MUSIC (desde B:) detrás de él con AGANAMEM.MUS; F6 muestra "> TUNE" y MUSIC, y RETURN trae MUSIC al frente: A:AGANAMEM, PLAYING. Con `MBLOCK_RAM=128`: "CIERRE PRIMERO OTRO PROGRAMA" |
| `test-amsdos`, `test-reboot`, `test-system` | archivos de V-OS en el BASIC, reinicio, disquete SYSTEM |

**Script nuevo:**

1. Añada un `IF TEST_SCRIPT == n` al principio de la cadena en `test_script.asm`, con `ELSE` antes del siguiente y un `ENDIF` más al final.
2. Añada un objetivo al Makefile, como `test-sdk`.

Cada tecla se escribe como `dw desde, hasta : db fila, bit` del teclado. El número de tecla es fila·8 + bit, p. ej. RETURN = 18 = fila 2, bit 2.

**Sin emulador:** el código de un programa también funciona en un Z80 dentro de Python (el paquete `z80`). Se carga el `.BIN` en `#4000` y se hace que las llamadas a la API vuelvan al momento (o hagan lo necesario, p. ej. archivos en un diccionario). Luego se llama a init y event y se lee la memoria. Es mucho más rápido que las capturas para errores en números, archivos y saltos. Las direcciones de las etiquetas salen de `rasm … -s -sl` (un archivo `.sym`).

## En cada hito

1. Código, y una prueba en Caprice32: nueva o existente, con capturas de pantalla.
2. Las pruebas a las que afecta el cambio.
3. Una sección en `MILESTONES.md` y `MILESTONES.el.md`, y una sección "Υλοποίηση M…" (implementación) en `docs/REQUIREMENTS.md`.
4. **Actualizar el manual en los seis idiomas** (`docs/manual/` en griego, `docs/manual/<código>/` para en, fr, es, de, it, y `sdk/README.md`, `sdk/README.<código>.md` si cambia la API), y luego `make docs` para todos los PDF.
5. Commit y push.
