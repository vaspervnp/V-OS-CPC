# 5. Studio: programas con bloques

STUDIO es un editor de bloques al estilo de Scratch que funciona en el propio CPC.

- Se hacen sprites y scripts con bloques.
- El programa se ejecuta al momento con CONTROL+R.
- Se convierte en un programa normal de V-OS (`.VBN`) que también se inicia desde Programas (F2).

## La pantalla

Studio usa una pantalla "dividida", con dos zonas:

- **Arriba, en modo 0 (16 colores):**
  - **a la izquierda, el escenario** a la mitad de tamaño
  - **a la derecha, el panel SPRITES:** los sprites con su color y su posición, el tamaño del seleccionado (W, H), el fondo y el modo del programa (p. ej. `STAGE 2 M1`), y el nombre del archivo
- **Abajo, en modo 1:**
  - **a la izquierda, la paleta** con los bloques de una categoría (`< EVENTS >`)
  - **a la derecha, el script**, una línea por bloque
  - **al final, la línea de estado**, con las teclas que funcionan donde se encuentra

**TAB** pasa del script a la paleta, luego al escenario, y vuelve al script.

## Menús

| STUDIO | | EDIT |
|---|---|---|
| NEW | ^N | DELETE LINE |
| OPEN (`.VBS`) | ^O | + SPRITE (hasta 6) |
| SAVE | ^S | − SPRITE |
| SAVE AS | | BACKGROUND (el color del escenario) |
| RUN | ^R | SCREEN MODE (0 o 1) |
| IN BACKGROUND | | |
| BACK | ^Q | |

- **RUN (^R):** guarda `NOMBRE.VBS`, escribe `NOMBRE.VBN` y lo ejecuta. El programa se detiene desde su propio menú (PROGRAM > STOP, ^Q), y entonces Studio vuelve a arrancar con el mismo programa abierto.
- **IN BACKGROUND (en segundo plano):** pregunta si el programa sigue funcionando cuando está detrás de otro o detrás de una vista, o se pausa, que es lo predeterminado.
- **SCREEN MODE (modo de pantalla):**
  - **Modo 0:** 16 colores, 192 píxeles de ancho.
  - **Modo 1:** 4 colores (tintas 0–3), 384 píxeles de ancho, y más texto.

## La paleta

←/→ cambian la categoría, ↑/↓ eligen un bloque, y RETURN lo añade debajo de la línea del script. Un clic en un bloque de la paleta hace lo mismo.

Un bloque que abre (FOREVER, REPEAT, IF) entra junto con su END, y se borra junto con él. Un bloque con texto pide el texto al momento.

## El script

| Tecla | Qué hace |
|---|---|
| ↑/↓ | línea |
| ←/→ | hueco de la línea (los huecos son los valores dentro del bloque) |
| RETURN | sin hueco seleccionado: añade el bloque de la paleta. En un hueco de texto: cambia el texto. En un hueco de tecla: espera a que pulse la tecla |
| CLR | borra la línea |
| DEL | borra la última cifra de un número |
| ratón | clic en un hueco: lo selecciona. Segundo clic: cambia su clase |

El programa es una lista de líneas:

- Cada `WHEN …` empieza un script, para un sprite o para el escenario. El script llega hasta el siguiente `WHEN`.
- La sangría sale sola de los bloques que abren y cierran.
- Las líneas antes del primer `WHEN` se ignoran.
- Lo que quede abierto se cierra al final del script.

### Qué va en un hueco

La línea de estado siempre dice qué acepta el hueco.

**Hueco de valor:**

| Tecla | Valor |
|---|---|
| 0–9, − | número, un entero de −32768 a 32767 |
| A–H | variable. La misma letra otra vez: A1, A2 … A15, y vuelta a A |
| X, Y | la posición del sprite del script |
| R y cifras | RANDOM: un número de 1 a n |
| K y una tecla | KEY: 1 mientras se mantiene pulsada, si no 0 |
| T y una cifra | TOUCHING: 1 cuando el sprite toca el sprite n |
| Z | AT EDGE: 1 cuando el sprite está en el borde del escenario |
| P | BUTTON: el número del último botón pulsado |
| U | COSTUME: el número del disfraz del sprite (0: sin disfraz) |

**Otras clases de hueco:**

- **Variable:** A–H, y la misma letra otra vez para A1…A15.
- **Comparación:** `<`, `=`, `>`. SPACE da NONE ("ninguna"), y entonces IF solo comprueba que el primer valor no sea 0.
- **Sprite** (en los bloques `WHEN`): 0 el escenario, 1–6 un sprite.
- **Tecla** (en `WHEN KEY`): RETURN y luego la tecla.
- **Texto:** RETURN, y se escriben hasta 14 caracteres.
- **Grupo de variables** (SAVE/LOAD VARS): A–H pasa al siguiente grupo de ocho (A-H, A1-H1 … A15-H15), y SPACE da ALL.

Las letras se leen como teclas, así que también funcionan con el teclado griego.

## El escenario y los sprites

| Tecla | Qué hace |
|---|---|
| flechas | mueven el sprite seleccionado |
| 1–6 | seleccionan un sprite |
| C | color siguiente |
| W, H | ancho, alto |
| K | qué disfraz lleva (ninguno, 1, 2, …) |
| E | dibujar su disfraz (uno nuevo, si no tiene) |
| clic en el escenario | pone el sprite ahí |

Un sprite sin disfraz es un rectángulo de color.

### Disfraces

**E** abre el editor de disfraces en lugar del escenario. Tiene una cuadrícula de 16×16 con las 16 tintas debajo.

| Tecla | Qué hace |
|---|---|
| flechas | casilla |
| SPACE, RETURN | pinta la casilla |
| 0–9, A–F | tinta |
| `.` | transparente |
| E, TAB | terminado |
| clic | en una casilla: pinta. En la fila de tintas: selecciona una tinta |

Un programa tiene hasta 8 disfraces, compartidos por todos los sprites. El tamaño de un sprite con disfraz es 16×16. En el escenario, x se redondea a un byte entero (2 píxeles en modo 0, 4 en modo 1).

## Todos los bloques

En la columna "Bloque", los huecos aparecen como en el script.

### EVENTS

| Bloque | Qué hace |
|---|---|
| WHEN START *sprite* | el script empieza junto con el programa |
| WHEN KEY *tecla* *sprite* | empieza cuando se pulsa la tecla |
| WHEN CLICKED *sprite* | empieza con un clic en el sprite (o en el escenario) |
| WHEN I RECEIVE *n* *sprite* | empieza cuando se envía el mensaje n |
| SEND *n* | envía el mensaje n (n también puede ser una variable) |

> Un mensaje inicia **desde el principio** todos los scripts que lo esperan, aunque ya estuvieran en marcha. Por eso un script no debe enviarse un mensaje a sí mismo.

### CONTROL

| Bloque | Qué hace |
|---|---|
| FOREVER … END | repite para siempre |
| REPEAT *n* … END | n veces |
| IF *a* *comparación* *b* … [ELSE …] END | ejecuta las líneas solo si se cumple la comparación |
| WAIT *n* | espera n fotogramas (50 = un segundo) |
| WAIT UNTIL *a* *comparación* *b* | espera hasta que se cumpla la comparación |
| STOP | termina este script |

### MOTION

| Bloque | Qué hace |
|---|---|
| GO TO *x* *y* | el sprite va a x, y |
| CHANGE X *n*, CHANGE Y *n* | se desplaza n |
| SPEED *vx* *vy* | fija su velocidad |
| MOVE | un paso a su velocidad |
| BOUNCE | en el borde del escenario, invierte la velocidad |

### LOOKS/SOUND

| Bloque | Qué hace |
|---|---|
| COLOUR *n* | la tinta del rectángulo |
| COSTUME *n* | se pone el disfraz n (1–8. 0 no cambia nada) |
| NEXT COSTUME | el siguiente, y después del último otra vez el primero |
| SHOW, HIDE | |
| PRINT *valor* AT *x* *y* | escribe un número |
| NOTE *n* FOR *fotogramas* | toca una nota (número MIDI: 60 = do, 69 = la 440 Hz) y espera a que termine |

### VARIABLES

| Bloque | Qué hace |
|---|---|
| SET *variable* TO *valor* | |
| CHANGE *variable* BY *valor* | suma |
| DECREASE *variable* BY *valor* | resta |
| MULTIPLY *variable* BY *valor* | |
| DIVIDE *variable* BY *valor* | división entera |
| REMAINDER *variable* BY *valor* | el resto de la división |
| SAVE VARS *grupo* TO *"nombre"* | escribe las variables en un archivo de texto (véase más abajo) |
| LOAD VARS *grupo* FROM *"nombre"* | las vuelve a leer |

### WINDOWS

| Bloque | Qué hace |
|---|---|
| WINDOW *"título"* *ancho* *alto* | una ventana en el centro del escenario, como los diálogos de V-OS. Una ventana nueva ocupa el lugar de la anterior y de sus botones |
| BUTTON *"texto"* AT *x* *y* | un botón del sistema. Se pulsa con un clic o con TAB y RETURN. Los botones se numeran desde 0, en el orden en que aparecen |
| WHEN BUTTON *sprite* | empieza cuando se pulsa cualquier botón. El valor BUTTON (P) dice cuál |
| TEXT *"texto"* AT *x* *y* | escribe un texto |
| LABEL *botón* TO *"texto"* | cambia el texto de un botón |

Con una ventana abierta, TEXT, BUTTON y PRINT cuentan desde la esquina superior izquierda de su interior. La ventana se arrastra por su título, junto con sus botones.

## Variables

Hay 128 variables, compartidas por todos los scripts, llamadas A–H, A1–H1, …, A15–H15. Al principio todas valen 0, y contienen enteros de −32768 a 32767.

### Guardar y recuperar (SAVE VARS, LOAD VARS)

- `SAVE VARS ALL TO "GAME"` escribe las 128 en el archivo `GAME.TXT`. El `.TXT` se añade cuando el nombre no tiene tipo.
- Con un grupo (`A-H`, `A1-H1`, …) escribe solo esas 8.
- El archivo es de texto, una línea por variable:

  ```
  A=12
  B=0
  A1=-5
  ```

- `LOAD VARS ALL FROM "GAME"` cambia las variables que menciona el archivo. Con un grupo, cambia solo las que también están en el grupo. Las líneas que no entiende se ignoran, y si falta el archivo no cambia nada.
- Así, un archivo puede recuperar todas las variables o solo un grupo de ocho, p. ej. las posiciones guardadas de un juego.

## Archivos

- **`NOMBRE.VBS`:** el programa tal como se edita. OPEN lo abre, y se leen hasta 5K.
- **`NOMBRE.VBN`:** el programa listo para ejecutarse. RUN lo escribe, y también se inicia desde Programas (F2). Es el reproductor (`VBRUN.SYS`) junto con el programa. El reproductor compila los bloques a código Z80 al arrancar, así que los programas van rápido.

Un `.VBS` también se puede hacer a partir de texto en el PC, con `tools/mkvbs.py`. La sintaxis se describe al principio del archivo, y hay ejemplos en `blocks/examples/*.vbt` (CALC, MINES, FLAP, TICKER, VARS).

## Límites

| | |
|---|---|
| Líneas (bloques) | 240 |
| Sprites | 6 |
| Scripts (`WHEN …`) | 16 |
| Variables | 128 |
| REPEAT en un programa | 64 (a partir de ahí comparten un contador) |
| Bloques abiertos anidados unos dentro de otros | 16 |
| Textos | 32, de hasta 14 caracteres cada uno |
| Disfraces | 8, de 16×16 |
| Botones | 64 |
| Código | al menos 4.000 bytes, incluso para el programa más grande. Lo que no cabe se ignora |

## Consejos

- **Scripts del escenario:** los bloques de movimiento y de apariencia no hacen nada, y X, Y, TOUCHING y AT EDGE dan 0.
- **TOUCHING:** solo se cumple cuando los dos sprites son visibles.
- **Sincronización:** los scripts funcionan "a la vez". Cada script cede su turno al final de cada bucle y en cada WAIT. Para que un script espere a otro, use una variable y `WAIT UNTIL` (véase MINES).
- **Ejemplos ya hechos:** CALC, MINES, FLAP y TICKER se abren en Studio (OPEN).
