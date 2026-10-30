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

Esto compila `build/HELLO.BIN` y lo pone en el disquete `build/vos.dsk`.

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
- Con una subcarpeta `owndisc/`, el programa tiene además su propio disquete, `build/<nombre>.dsk`, con el `.BIN` y los archivos de `owndisc/`. No va en `vos.dsk`. Se pone en B: y se ejecuta desde el Launcher (TAB, la otra unidad). La unidad desde la que se inició, para cargar de allí sus archivos, está en `VOS_SELF`: `db unidad`, y luego su nombre (11 bytes).
- Un programa con tabla de reubicación (como los del SDK) puede ocupar hasta 12K. Para lo demás, cargue archivos en el banco de datos.

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
- **Memoria:** no ponga otro banco en `#4000`, porque el programa desaparecerá bajo sus pies. Para 16K más está el banco de datos (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). Se comparte con las vistas y otros programas, y conserva sus datos solo mientras el programa está en marcha.
- **Coordenadas:** x en píxeles del modo (modo 0: 0–191, modo 1: 0–383), y de 0 a 258. La barra de menús ocupa y 0–11.
- **RASM:** las etiquetas no distinguen mayúsculas de minúsculas (`BOX` y `box` son lo mismo). El hexadecimal se escribe con `#` y no con `&`.

## Los formatos de datos

- **Barra de menús** (`VOS_SET_BAR`): `db count; dw menu, ...`. Los menús comunes VER y AYUDA vienen de `VOS_MENU_VIEW` y `VOS_MENU_HELP`.
- **Menú:** `db title, count` y para cada opción `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` para una línea
  - command: 1.., lo que devuelve `VOS_UI_EVENT`
  - letter: atajo CONTROL+letra, o 0
- **Botones** (`VOS_SET_WIDGETS`, luego `VOS_DRAW_WIDGETS`): `db count`, y para cada botón `dw x, y; db ancho en caracteres, text, command, 0`.
- **Diálogo** (`VOS_DIALOG` → A = botón, 0 el primero, ESC da el último): `db title, text, número de botones (1–3), button, ...`. Para los botones, `VM_OK`, `VM_YES` y `VM_NO`.
- **Textos** (`VOS_TEXTS`): los genera `tools/mktexts.py` a partir de `texts.txt`, con líneas `NAME | English | Greek`.
  - Da `T_NAME` (`VT_FIRST` = `#C0` en adelante) y la tabla `texts:`. Hasta 64 textos.
  - Un `|` sin espacios alrededor empieza una línea nueva en los diálogos.
  - Los textos van donde se pide un "texto" (menús, botones, diálogos). Con `VOS_MSG` se obtiene su dirección para `VOS_PRINT`.
- **Paleta** (`VOS_PALETTE`): 17 colores del firmware (0–26): 16 tintas y el borde. En modo 1 cuentan las tintas 0–3.
- **Rectángulo** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icono:** 16 líneas de 16 caracteres en `icon.txt`. Cada carácter es una tinta en hexadecimal (modo 0, paleta de Programas) o `.` para transparente.
- **Nombres de archivo** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 bytes, `"NAME    EXT"`. Unidad 0 = A:, 1 = B:.

## La API (versión 12)

| Llamada | Entrada → salida | Qué hace |
|---|---|---|
| `VOS_EXIT` | — | fin, vuelta a la vista que lo inició |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 veces por segundo, o ninguno. Con `VOS_PTR_KEYS` (2) las flechas y COPY también mueven el puntero y hacen clic |
| `VOS_FRAMES` | → HL (y A bits 16–23) | fotogramas desde el arranque |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = orden | las órdenes comunes de VER y AYUDA |
| `VOS_ERROR` | A = error | diálogo de error |
| `VOS_MODE` | A = 0 / 1 | modo 0 (192×259, 16 tintas) o 1 (384×259, 4 tintas) |
| `VOS_PALETTE` | HL → 17 colores | |
| `VOS_CLS` | A = tinta | borra la pantalla |
| `VOS_PLOT` | HL = x, DE = y, A = tinta | un píxel |
| `VOS_RECT` | IX → rectángulo | rectángulo relleno |
| `VOS_COLOURS` | A = tinta del texto, C = fondo | para `VOS_PRINT` y `VOS_CHAR` |
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
| `VOS_SAVE` | A = unidad, HL → nombre, DE = desde, BC = longitud | archivo binario, que sustituye al anterior |
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

Todos los detalles, p. ej. sobre el segundo plano, el accesorio y `VOS_SPLIT`, están en `src/api/vos_api.inc`. Como ejemplos, véanse `apps/demo/demo.asm` (modo 0, movimiento), `apps/clock/clock.asm` (accesorio) y `apps/mixed/mixed.asm` (pantalla mixta). Un juego completo con sprites, una pantalla leída de un archivo y sonido es `myapps/vrouves/`.

Un asistente de IA que escribe un programa debe leer [`AI.md`](AI.md) (en inglés): las mismas reglas, más cortas, con las trampas de RASM y del banco de datos.

## Pruebas

`make test-sdk` compila la plantilla como TEMPLATE.BIN y la abre desde Programas (F2) en Caprice32, con pulsaciones de teclas definidas por `src/kernel/test_script.asm` (script 15). Hace capturas de pantalla en `build/shots`: su pantalla, el recuadro después de moverse, su menú, el diálogo ABOUT y la vuelta a Programas.

Para su propia prueba automática, copie el script 15 y el objetivo `test-sdk` del Makefile.
