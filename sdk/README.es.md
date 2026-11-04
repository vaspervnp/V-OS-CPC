# El SDK de V-OS: programas en ensamblador

Con este SDK se escriben programas propios en ensamblador Z80. Funcionan dentro de V-OS como DEMO o CLOCK: aparecen en Programas (F2), en el Escritorio y en el Commander, y tienen su propio menú, botones, diálogos, sonido y archivos. También funcionan junto a otros programas.

## Inicio rápido

```bash
make new-app NAME=hello
```

Esto crea la carpeta `myapps/hello/` a partir de `sdk/template/`. Contiene tres archivos:

- `hello.asm`: el programa. Las flechas mueven un recuadro, hay un botón BEEP, un contador de segundos y su propio menú (ABOUT, BACK) junto a VER y AYUDA.
- `texts.txt`: sus textos, en inglés y en griego.
- `icon.txt`: su icono, de 16×16, para Programas (F2).

```bash
make app NAME=hello
```

Esto compila `build/HELLO.BIN` y lo pone en el disquete de los programas, `build/apps.dsk`. `make run` lo pone en B:; en el Launcher, TAB muestra B:.

```bash
make run
```

Esto abre el disquete en Caprice32. HELLO está en Programas (F2), en la última página.

- Un `make` a secas compila todos los programas de `myapps/` y los pone en el disquete, junto con V-OS.
- El nombre tiene de 1 a 8 letras minúsculas o cifras y empieza por una letra. No puede ser el nombre de un programa de V-OS (p. ej. demo).
- Se necesitan RASM, Python 3 e iDSK, como para todo V-OS.
- En Caprice32 el programa se ejecuta a mano, desde Programas (F2).

Un programa más grande:

- Ponga más archivos `.asm` en su carpeta (p. ej. `art.asm` con sprites) e inclúyalos con `include "art.asm"`. El build los encuentra y vuelve a compilar el programa cuando cambian.
- Lo que ponga en la subcarpeta `disc/` (p. ej. `disc/LEVEL1.DAT`) va tal cual al disquete, para `VOS_LOAD`.
- Con una subcarpeta `owndisc/`, el programa tiene además su propio disquete, `build/<nombre>.dsk`, con el `.BIN` y los archivos de `owndisc/`. No va en `apps.dsk`. Se pone en B: y se ejecuta desde el Launcher (TAB, la otra unidad). La unidad desde la que se inició, para cargar de allí sus archivos, está en `VOS_SELF`: `db unidad`, y luego su nombre (11 bytes).
- **Un archivo para abrir (versión 14):** cuando RETURN en el Escritorio o el Commander abre un archivo en su programa, `VOS_OPEN` (`#B000`) contiene `db 1, unidad, nombre de 11 bytes` (0: ninguno). Léalo en `init`, con A = 0 y también con A = 2 (el programa ya estaba en marcha), y luego escriba 0 allí. Los tipos y sus programas están en la tabla `ft_open` del núcleo (`src/kernel/files_ext.asm`).
- Un programa con tabla de reubicación (como los del SDK) funciona junto a otros hasta 12K; uno mayor (hasta 16K) funciona solo sin ampliación de memoria, como uno sin tabla (MARKDOWN, READER). Para lo demás, cargue archivos en el banco de datos.

## Cómo funciona un programa

Un programa es un `.BIN`, compilado para `VOS_APP_ADDR` (`#4000`). Empieza así:

```
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0
        jp event                ; +3  HL -> el evento
        jp redraw               ; +6
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12 el icono (opcional)
```

- **`init`** fija el modo, la paleta, el menú y los botones, activa `VE_FRAME` si hace falta, y lo dibuja todo.
  - A = 0: un arranque nuevo.
  - A = 2: el programa vuelve de una vista o de otro programa. Su estado es tal como lo dejó; vuelve a fijar lo anterior y dibuja.
- **`event`** se llama para cada evento y vuelve al momento. Un programa nunca espera por su cuenta (sin bucle de espera). Para movimiento o tiempo, `VOS_TICKS` con A = 1, y entonces llega un `VE_FRAME` 50 veces por segundo.
- **`redraw`** lo vuelve a dibujar todo, p. ej. cuando cambia el idioma o se cierra el accesorio de escritorio.
- **Salida:** `VOS_EXIT`, que vuelve a la vista que lo inició.

### El orden dentro de `event`

```
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame        ; los fotogramas
        push hl
        call VOS_UI_EVENT               ; menús, botones, CONTROL+letra
        pop hl
        or a : jr nz,command            ; A = la orden
        call VOS_MENU_OPEN : ret nz     ; menú abierto: las teclas son suyas
        ...                             ; sus propias teclas y clics
command: ...
        jp VOS_COMMAND                  ; lo que no es suyo (VER, AYUDA)
```

**Mientras hay un menú abierto, no dibuje.** Si no, dibujará encima de él. En `VE_FRAME`, actualice el estado, pero dibuje solo si `VOS_MENU_OPEN` da Z. Los diálogos (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) tienen su propio bucle, así que no llega ningún evento mientras están abiertos.

### Los eventos

`HL` → 8 bytes: `db type, code, char, mods; dw x, y`.

| type | qué | code / char / x, y |
|---|---|---|
| `VE_KEY_DOWN` 1, `VE_KEY_REPEAT` 3, `VE_KEY_UP` 2 | tecla | code = número de tecla (`VK_*`, fila del teclado·8 + bit), char = el carácter en el idioma del paquete |
| `VE_PTR_DOWN` 5, `VE_PTR_UP` 6, `VE_PTR_MOVE` 4 | puntero | x, y en píxeles del modo |
| `VE_FRAME` 8 | fotograma (con `VOS_TICKS`) | — |
| `VE_LANG` 7 | cambió el idioma del teclado | — |

### Tres clases de programa

- **Con tabla de reubicación (lo predeterminado del SDK):** `make app` lo compila dos veces, en `#4000` y en `#4100`. `tools/mkreloc.py` añade la tabla a partir de la diferencia.
  - Funciona junto a otros programas, en los 12K desde `#5000`, y continúa donde se detuvo (F6 muestra los programas en marcha).
  - Sus datos deben estar dentro de sus propios bytes (etiquetas, `ds`), nunca en direcciones fijas.
  - Si `mkreloc.py` da un error, en algún sitio se usa una dirección de una manera que no sobrevive a la reubicación. P. ej. `ld a,label & 255`, o solo el byte bajo de una dirección.
- **Sin tabla:** ocupa todo el banco (hasta 16K, código y datos), pero solo funciona solo, a menos que haya una ampliación de memoria. Necesita su propia regla en el Makefile (véase `STUDIO.BIN`).
- **Accesorio de escritorio:** hasta 4K, con tabla. Se abre con F5 encima de cualquier cosa, e `init` recibe A = 1. Véanse `apps/clock/clock.asm` y la descripción en `src/api/vos_api.inc`.

### Reglas

- **Registros:** las llamadas alteran todos los registros excepto IX. Los argumentos van en A, BC, DE, HL (IX para `VOS_RECT` y `VOS_BLIT`). Los resultados vuelven en A o HL. Si hay fallo, se activa el acarreo (carry) y A = número de error, que `VOS_ERROR` muestra.
- **Memoria:** no ponga otro banco en `#4000`, porque el programa desaparecerá bajo sus pies. Para 16K más está el banco de datos (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). Se comparte con las vistas y otros programas, y conserva sus datos solo mientras el programa está en marcha. Con una ampliación de memoria (API 21) cada programa recibe uno propio, que guarda lo que tiene hasta que el programa termina, corra lo que corra mientras tanto; `VX_DATA` dice cuál (A = 1: el suyo).
- **Coordenadas:** x en píxeles del modo (modo 0: 0–191, modo 1: 0–383, modo 2: 0–767), y de 0 a 258. La barra de menús ocupa y 0–11.
- **RASM:** las etiquetas no distinguen mayúsculas de minúsculas (`BOX` y `box` son lo mismo). El hexadecimal se escribe con `#` y no con `&`.

## Los formatos de datos

- **Barra de menús** (`VOS_SET_BAR`): `db count; dw menu, ...`. Los menús comunes VER y AYUDA vienen de `VOS_MENU_VIEW` y `VOS_MENU_HELP`.
- **Menú:** `db title, count` y para cada opción `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` para una línea
  - command: 1.., lo que devuelve `VOS_UI_EVENT`
  - letter: atajo CONTROL+letra, o 0
- **Botones** (`VOS_SET_WIDGETS`, luego `VOS_DRAW_WIDGETS`): `db count`, y para cada botón `dw x, y; db ancho en caracteres, text, command, 0`.
- **Diálogo** (`VOS_DIALOG` → A = botón, 0 el primero, ESC da el último): `db title, text, número de botones (1–3), button, ...`. Para los botones, `VM_OK`, `VM_YES` y `VM_NO`.
- **Textos** (`VOS_TEXTS`): los genera `tools/mktexts.py` a partir de `texts.txt`, con líneas `NAME | English | Greek`. Las dos columnas se escriben en UTF-8 y se convierten en bytes del juego de caracteres de V-OS (`tools/voscs.py`), que contiene el griego y las letras latinas del francés, el español, el alemán y el italiano.
  - Da `T_NAME` (`VT_FIRST` = `#C0` en adelante) y la tabla `texts:`. Hasta 64 textos.
  - Un `|` sin espacios alrededor empieza una línea nueva en los diálogos.
  - Los textos van donde se pide un "texto" (menús, botones, diálogos). Con `VOS_MSG` se obtiene su dirección para `VOS_PRINT`.
- **Paleta** (`VOS_PALETTE`): 17 colores del firmware (0–26): 16 tintas y el borde. En modo 1 cuentan las tintas 0–3.
- **Rectángulo** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icono:** 16 líneas de 16 caracteres en `icon.txt`. Cada carácter es una tinta en hexadecimal (modo 0, paleta de Programas) o `.` para transparente. Programas lo lee del disco: mientras el programa corre, los 256 bytes después de "IC" quedan libres para búferes (PAINT guarda allí sus filas).
- **Nombres de archivo** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 bytes, `"NAME    EXT"`. Unidad 0 = A:, 1 = B:.

## La API (versión 22)

| Llamada | Entrada → salida | Qué hace |
|---|---|---|
| `VOS_EXIT` | — | fin, vuelta a la vista que lo inició |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 veces por segundo, o ninguno. Con `VOS_PTR_KEYS` (2) las flechas y COPY también mueven el puntero y hacen clic |
| `VOS_FRAMES` | → HL (y A bits 16–23) | fotogramas desde el arranque |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = orden | las órdenes comunes de VER y AYUDA (6–19). Numere sus propias órdenes desde `VC_APP` (32), o un elemento de VER o AYUDA ejecuta una de las suyas |
| `VOS_ERROR` | A = error | diálogo de error |
| `VOS_MODE` | A = 0 / 1 / 2 | modo 0 (192×259, 16 tintas), 1 (384×259, 4 tintas) o 2 (768×259, 2 tintas, 96 columnas de texto; versión 25). En modo 2 los menús y diálogos se dibujan con la tinta 1 sobre la 0: tinta 0 blanca y 1 negra dan texto negro sobre papel blanco (NOTEPAD, MARKDOWN, READER, SHEET con ^M) |
| `VOS_PALETTE` | HL → 17 colores | |
| `VOS_CLS` | A = tinta | borra la pantalla |
| `VOS_PLOT` | HL = x, DE = y, A = tinta | un píxel |
| `VOS_RECT` | IX → rectángulo | rectángulo relleno |
| `VOS_COLOURS` | A = tinta del texto (+ `VOS_BOLD`, `VOS_ITALIC`, `VOS_UNDERLINE`), C = fondo | para `VOS_PRINT` y `VOS_CHAR`. Los estilos salen de la misma fuente, para todos los idiomas |
| `VOS_PRINT` | HL = x, DE = y, BC → texto, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = carácter | |
| `VOS_MSG` | A = texto → HL | la dirección de un texto (`T_*` o uno del sistema) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → barra de menús | |
| `VOS_UI_EVENT` | (el evento actual) → A | orden de menú, botón o atajo, 0 si no hay |
| `VOS_DIALOG` | HL → diálogo → A | |
| `VOS_INPUT` | A = título, HL → texto, C = máximo → carry si se cancela | introducción de texto (necesita C + 2 bytes) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → botones | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | los menús comunes |
| `VOS_CATALOG` | A = unidad → A = archivos, HL → lista | 16 bytes cada uno: 11 el nombre, en +12 el tamaño en K. Con A = unidad + `VOS_CAT_EXT` y HL → `"EXT"`, solo los archivos con esa extensión |
| `VOS_FILE_PICK` | A = título → A = archivo, carry si se cancela | diálogo selector, después de `VOS_CATALOG` |
| `VOS_LOAD` | A = unidad, HL → nombre, DE = dónde → BC = longitud | |
| `VOS_SAVE` | A = unidad, HL → nombre, DE = desde, BC = longitud | archivo binario, que sustituye al anterior. Con A + `VOS_LOAD_IX` (#40, versión 20) su cabecera dice que se carga en IX, no en DE (un `.SCR`: IX = #C000) |
| `VOS_DELETE` | A = unidad, HL → nombre | |
| `VOS_TEXTS` | HL → tabla de textos | los textos del programa |
| `VOS_MENU_OPEN` | → NZ si hay un menú abierto | |
| `VOS_KEY_HELD` | A = tecla → NZ mientras está pulsada | para juegos |
| `VOS_BLIT` | IX → `dw x, y; db bytes, lines; dw source; db source stride` | imagen: pares (máscara, píxeles) |
| `VOS_SOUND` | A = canal 0–2, HL = periodo (bit 15: ruido), C = volumen 0–15, B = fotogramas | una nota; 440 Hz es el periodo 142 |
| `VOS_SPLIT` | HL → `dw y1, y2; db 8 colores` (0 = la desactiva) | pantalla mixta: modo 0 entre y1 e y2 |
| `VOS_RUN` | A = unidad, HL → nombre | ejecuta otro programa, y después este vuelve a arrancar |
| `VOS_KEEP` | → HL → 16 bytes | memoria que se mantiene entre programas |
| `VOS_BANK_GET`, `VOS_BANK_PUT` | HL = desde, DE = hasta, BC = bytes | copia desde y hacia el banco de datos |
| `VOS_BACKGROUND` | A = 1 / 0 | sigue funcionando o se congela cuando está detrás de otro |
| `VOS_DRAG` | HL = x, DE = y, BC = w, A = h → carry: nuevos HL, DE | arrastrar una ventana por su título |
| `VOS_FIT` | igual → HL, DE | mete una ventana dentro de la pantalla |
| `VOS_EXT` | A = una llamada `VX_*`, BC, DE, HL según la llamada → A, HL, C, DE, acarreo | las llamadas después de la tabla (versión 15), abajo |

**Unidades:** 0 = A:, 1 = B:, 2 = DISK, la tarjeta SD de una M4 (versión 28), en la carpeta donde entró por última vez el Escritorio o el Commander. Las llamadas de archivos y `VX_FREE` funcionan allí como en un disquete (nombres 8.3; sin M4: acarreo, A = 35), y el catálogo tiene también las carpetas (en +13, 1). Las bases de datos (`VX_DB`) funcionan allí también (versión 29). Desde la versión 29, `VOS_CAT_EXT` conserva las carpetas, y `VOS_FILE_PICK` entra en una carpeta elegida (o `..`) y la lista como pidió el último `VOS_CATALOG`: lo que devuelve es siempre un archivo, en la carpeta actual. `VX_DRIVE` C = unidad → A = la siguiente (A: → B: → DISK con una M4 → A:), para una orden OTHER DRIVE; `src/api/vos_drive.inc` tiene `vos_next_drive` (A: ↔ B: en un V-OS anterior) y `vos_drive_text` (`A:`, `B:`, `DISK:`).

**Las llamadas de `VOS_EXT`:** `VX_VERSION` → A = API, HL = versión de V-OS (BCD). `VX_FREE` C = unidad → A = K libres. Desconocida: acarreo `VX_CLIP_PUT` HL = texto, BC = bytes → el portapapeles (hasta 1K). `VX_CLIP_GET` DE = dónde, BC = espacio → HL = tamaño (versión 16). `VX_M4` HL → una orden para la tarjeta M4 (db tamaño, dw orden, datos), DE → la respuesta, BC = bytes; acarreo: no hay tarjeta M4 (versión 17); HL = 0: BC bytes del `sock_info` de la ROM de la M4 a DE, 16 por socket (su estado, su última orden, los bytes recibidos, una ip y un puerto; el socket 0 es el de C_NETHOSTIP, su ip el nombre buscado) (versión 32; TELNET espera así). `VX_MEM` → HL = la RAM en K, DE = los K libres para programas (versión 18). `VX_BEHIND` DE → db unidad, nombre de 11 bytes de un archivo: su programa (por tipo) arranca detrás de este, con `init` A = 3 y el archivo en `VOS_OPEN` (versión 19; MUSIC lo conoce). `VX_DATA` → A = 1 si el banco de datos es del programa (ampliación de memoria), 0 si es el banco 4 compartido (versión 21; NOTEPAD guarda así texto de hasta 16K). `VX_DB` C = una llamada `DB_*`, DE, HL → una base de datos (versión 22, abajo). `VX_UTF8` HL → un texto, BC = bytes, E = 0 en la memoria del programa o `VOS_DATA` en su banco de datos: si está en UTF-8 (de un PC o de la web), pasa allí al juego de caracteres de V-OS → BC = bytes ahora, A = 1; A = 0: no era UTF-8 y queda como estaba (versión 23; así lo hacen NOTEPAD y READER). `VX_CALC` C = una llamada `CALC_*`, DE → un bloque, HL → texto → fórmulas y números (versión 24, más abajo). `VX_LANG` → HL = el código del idioma que muestra V-OS (`"EN"`, `"EL"`, `"FR"`…; L la primera letra) (versión 26; así muestra VBRUN las traducciones de los programas de Studio). `VX_IRQ` HL = una rutina del programa → el núcleo la llama una vez por imagen desde la interrupción, delante o detrás, con su banco puesto y las interrupciones desactivadas; 0 la detiene, igual que el fin del programa; acarreo: no para un accesorio ni para un programa solo en el banco 5 (versión 27; así toca MUSIC sus canciones, que ya no se paran mientras otro programa carga o dibuja). Debe ser corta, conservar IY, EXX y AF', escribir solo su propia memoria y el AY, y no llamar a nada de V-OS. `VX_PRINT` HL → un texto, BC = bytes, E = 0 en la memoria del programa o `VOS_DATA` en su banco de datos → a la impresora (el puerto Centronics del CPC, 7 bits), tal cual: 13, 10 terminan una línea, 12 empieza una página nueva; las letras por encima de 127 salen como ASCII simple (sin acentos, el griego en Greeklish: Θ 8, Ξ 3, Ψ 4); acarreo, A = 41: la impresora siguió ocupada dos segundos (ninguna, fuera de línea, sin papel) (versión 30; así imprimen NOTEPAD, SHEET y DATABASE con ^P). Tras 60 líneas empieza sola una página nueva; BC = 0 con HL → el nombre de 11 bytes de un archivo (como lo da `VOS_CATALOG`) empieza una impresión cuyas páginas llevan un encabezado, `NOTES.TXT  PAGINA 2`; HL = 0: sin encabezados (versión 31). `VX_VIEW` HL → dw x, y, w, h: desde entonces el programa dibuja con (0, 0) en (x, y) y nada fuera de ese rectángulo (cortado a la pantalla): `VOS_CLS` lo llena, `VOS_RECT` se corta a él, un punto, un carácter (cada uno de `VOS_PRINT`) o una imagen de `VOS_BLIT` se dibuja solo si está todo dentro; menús, diálogos y barra no cambian; HL = 0: ninguna; de nuevo tras `VOS_MODE` y en `redraw` (termina cuando otro programa pasa delante); carry: sin ampliación de memoria (versión 33; el primer paso hacia los programas en ventanas, docs/WINDOWS.md). `VX_WINDOW` HL → dw w, h: el programa en una ventana sobre el escritorio, su interior w × h (w múltiplo de 8) como vista y sus eventos del puntero con x, y desde él; llamarlo primero en init, cada vez (también con A = 2: así se redibujan las ventanas de detrás, con su init); su título la mueve, X lo termina, + o F7 la ponen a pantalla completa y de vuelta, un clic en otra la trae delante con su barra; modo 1, los colores del tema; carry: sin ampliación de memoria o sin `WM.SYS` en A: (pantalla completa como antes; versión 34). Desde la versión 35 `VX_WINDOW` escribe en HL el tamaño que tiene ahora su interior (pantalla completa: la pantalla bajo la barra), así init dispone lo que muestra para él; la esquina inferior derecha cambia el tamaño (y init se llama de nuevo con A = 2); con `VOS_BACKGROUND` el programa dibuja en su ventana también desde detrás, mientras ninguna la tape (`VOS_CLS`, `PLOT`, `RECT`, `COLOURS`, `PRINT`, `CHAR`, `BLIT`; no `VOS_MSG`). Ejemplos: `apps/clock`, `myapps/sysinfo`. Desde la versión 36 HL apunta a dw w, h, x0, y0: la ventana muestra la parte de la pantalla del programa desde x0, y0 (0, 0: como antes), así un programa hecho para toda la pantalla dibuja como antes, y sus widgets y eventos lo siguen (p. ej. `dw 376, 232, 0, 12` en `myapps/telnet`); un programa con la versión 36 en su cabecera da siempre los cuatro. Si lo llama fuera de init, dibuja después su barra de nuevo (`VOS_DRAW_BAR`). Desde V-OS 0.49 una ventana de detrás que tiene una copia de sí misma (tomada mientras nada la tapaba) se copia de vuelta en su lugar: su init no se llama entonces, así que un programa no debe contar con que se le llame para dibujar estando detrás; uno que sigue en segundo plano (`VOS_BACKGROUND`) dibuja como antes mientras no está tapado. La ventana de archivos y los iconos de las unidades del escritorio también están entre las ventanas (0.50): hasta ocho ventanas en total. Desde la 0.51 `VOS_PALETTE` no hace nada mientras el programa está delante en una ventana (a pantalla completa funciona); la X de una ventana envía al programa CONTROL+Q, así que su BACK puede preguntar antes; un programa de detrás que nada tapa tiene también `VOS_EXT` (TELNET recibe ahí), y un `VOS_EXT` que no hizo nada mientras estaba tapado deja tus búferes como estaban: márcalos antes, como hace TELNET. Con w = 0 (V-OS 0.48) el programa sale de las ventanas: su ventana se va (carry), y pone su modo y su paleta y dibuja a pantalla completa, como para una página en modo 2; si lo pide de nuevo más tarde, la ventana vuelve donde estaba, del mismo tamaño. Con el tamaño devuelto un programa se dispone para su ventana: NOTEPAD, MARKDOWN, READER y SHEET (`set_mode`) toman w / 8 columnas y tantas filas como caben, de nuevo en cada cambio de tamaño, y salen de las ventanas para su página (^M).

### Bases de datos (versión 22)

`VOS_EXT` con A = `VX_DB` y C = una llamada `DB_*` trabaja con una base de datos: un archivo `NOMBRE.VDB` de páginas de 1K, tan grande como permita el disco (hasta 255K). Tiene hasta 8 tablas; una tabla tiene hasta 10 campos, texto (hasta 255 caracteres) o un número (2 bytes), y puede tener un campo clave (texto de hasta 64 caracteres, o un número) con un índice, para que FIND sea rápido. Un registro son sus campos uno tras otro; su id (rid) es un número de 16 bits. Hay una base abierta a la vez, para el programa que la abrió. Cada llamada escribe sus cambios en el disco antes de volver. El kernel carga el motor, `DB.SYS`, desde la unidad A: la primera vez.

| Llamada | Entrada → salida |
|---|---|
| `DB_CREATE`, `DB_OPEN` | DE → db unidad, nombre de 11 bytes (`"STREETS VDB"`); OPEN → A = 1: Latin-1 (de V-OS 0.15) |
| `DB_CLOSE` | |
| `DB_TABLE` | DE → nombre (8), campos, campo clave (0: ninguno), luego cada campo: nombre (8), tipo, longitud → A = tabla |
| `DB_USE` | E = la tabla que usan las llamadas de abajo |
| `DB_INFO` | E = tabla, HL → 124 bytes: su descripción → A = tablas |
| `DB_ADD` | HL → registro → DE = rid |
| `DB_GET`, `DB_PUT` | DE = rid, HL → el registro |
| `DB_DEL` | DE = rid |
| `DB_FIND` | HL → clave como en un registro (sitio para un registro), E = bytes que cuentan (0: todos) → DE = el primer registro con esa clave o después |
| `DB_FIRST`, `DB_LAST`, `DB_NEXT`, `DB_PREV` | HL → sitio para el registro, o 0 → DE = rid, por la clave; acarreo al final |
| `DB_COUNT` | → HL = registros |

Errores: acarreo y A (`DB_ERR_*`, y los errores del disco), que `VOS_ERROR` muestra. El texto se guarda tal como se escribe, en el juego de caracteres de V-OS, el mismo en todos los idiomas: una base puede tener griego, francés y alemán juntos. Solo una base de V-OS 0.15 con letras latinas (Latin-1) es distinta: `DB_OPEN` da entonces A = 1; muestra `DB_ERR_ALPHABET` con `VOS_ERROR`. El orden y FIND comparan bytes: en una clave `DB_TEXT` mayúsculas y minúsculas, y las acentuadas, son distintas. Un campo `DB_ALPHA` (tipo 2, desde la versión 23) es texto como `DB_TEXT`, pero como clave se ordena y se encuentra sin mayúsculas ni acentos: ΕΛΕΝΗ, Ελένη y ελένη, o Élodie y ELODIE, son lo mismo; el registro guarda el texto tal como se escribió. Ejemplos son STREETS (`myapps/streets`), un callejero, y DATABASE (`myapps/database`), un programa entero de bases con tablas, lista y formulario; `tools/vdb.py` muestra y comprueba un archivo `.VDB` en el PC.

### Fórmulas (versión 24)

`VOS_EXT` con A = `VX_CALC` y C = una llamada `CALC_*` calcula fórmulas, como una hoja de cálculo. El núcleo carga el motor, `CALC.SYS`, desde la unidad A: la primera vez. Un número es de 32 bits, en centésimas (1234 es 12.34), de -21474836.46 a 21474836.46. Una fórmula tiene `+ - * /`, paréntesis, números (`12`, `3.5`, `.25`; un tercer decimal redondea), celdas (`A1` a `Z255`) y las funciones SUM, AVG, MIN, MAX, COUNT (de valores, celdas y rangos como `B2:D9`, separados por `,` o `;`), ABS(x), INT(x) (hacia abajo, a un entero) y ROUND(x) o ROUND(x, 0–2), en mayúsculas o no. Los productos y los cocientes se redondean a la centésima.

DE → el bloque del programa, `CB_SIZE` (10) bytes: `CB_RESULT` (un número, 4 bytes), `CB_COLS`, `CB_ROWS`, `CB_GRID` (dw), `CB_BANK`, `CB_AT`. Las celdas son una cuadrícula del programa: `CB_COLS` × `CB_ROWS` números de 4 bytes, fila tras fila, en `CB_GRID`, en su banco de datos cuando `CB_BANK` = `VOS_DATA`. Una celda `CALC_NONE` no tiene número (vacía, o texto: 0 en `+ - * /`, las funciones la omiten); `CALC_BAD` tiene un error.

| Llamada | Entrada → salida |
|---|---|
| `CALC_EVAL` | HL → fórmula, 0 (con `=` delante o no) → `CB_RESULT` y DE:HL (DE la parte alta) |
| `CALC_NUMBER` | HL → texto: ¿solo un número? → como `CALC_EVAL` |
| `CALC_TEXT` | `CB_RESULT` → texto en HL (sitio para 13 bytes: `-12.5`), A = su longitud |
| `CALC_CELL` | HL → texto: ¿una celda (`b12`) al principio? → D = columna, E = fila (desde 0), A = sus caracteres |

Errores: carry y A (`CALC_ERR_*`: 30 fórmula errónea, 31 división por cero, 32 número demasiado grande, 33 celda fuera de la cuadrícula, 34 una celda que usa tiene un error, 29 `CALC.SYS` no está en A:), que `VOS_ERROR` muestra; entonces `CB_RESULT` = `CALC_BAD` y `CB_AT` = dónde en el texto. El ejemplo es SHEET (`myapps/sheet`), una hoja de cálculo que guarda sus valores en su banco de datos y vuelve a calcular las fórmulas tras cada cambio.

Todos los detalles, p. ej. sobre el segundo plano, el accesorio y `VOS_SPLIT`, están en `src/api/vos_api.inc`. Como ejemplos, véanse `apps/demo/demo.asm` (modo 0, movimiento), `apps/clock/clock.asm` (accesorio) y `apps/mixed/mixed.asm` (pantalla mixta). Un juego completo con sprites, una pantalla leída de un archivo y sonido es `myapps/vrouves/`.

Un asistente de IA que escribe un programa debe leer [`AI.md`](AI.md) (en inglés): las mismas reglas, más cortas, con las trampas de RASM y del banco de datos.

## Pruebas

`make test-sdk` compila la plantilla como TEMPLATE.BIN y la abre desde Programas (F2) en Caprice32, con pulsaciones de teclas definidas por `src/kernel/test_script.asm` (script 15). Hace capturas de pantalla en `build/shots`: su pantalla, el recuadro después de moverse, su menú, el diálogo ABOUT y la vuelta a Programas.

Para su propia prueba automática, copie el script 15 y el objetivo `test-sdk` del Makefile.
