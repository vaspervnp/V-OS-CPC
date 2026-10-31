# 2. Las vistas

V-OS tiene cuatro "vistas": maneras de ver los archivos y los programas, y los ajustes. Se cambia de vista con F1–F4 o desde el menú VER. Cada vista recuerda qué archivo estaba seleccionado, y la siguiente selecciona el mismo archivo.

## Los menús comunes

Los dos últimos menús son iguales en todas las vistas y en los programas:

| VER | | AYUDA | |
|---|---|---|---|
| ESCRITORIO | F1 | TECLAS | ^K |
| PROGRAMAS | F2 | ACERCA DE V-OS | |
| COMMANDER | F3 | | |
| AJUSTES | F4 | | |
| PROGRAMAS (en marcha) | F6 | | |
| CAMBIAR DE IDIOMA | ^L | | |

AYUDA > ACERCA DE V-OS muestra la versión (0.15 beta; cada hito suma 0.01), la fecha de compilación, el autor (Revive8bit, 2026) y el arquitecto (Vasper).

## Escritorio, F1

Modo 1. Una ventana ARCHIVOS muestra los archivos de una unidad como iconos, cuatro por fila. El tipo va escrito dentro del icono y el nombre debajo, y un `.VBN` lleva al lado una marca de "play". A la derecha, dos iconos eligen A: o B:. La barra de título muestra el formato del disquete y el número de archivos, y el espacio libre se muestra abajo.

| Tecla | Qué hace |
|---|---|
| flechas | eligen un archivo (↑/↓ una fila) |
| TAB | la otra unidad |
| RETURN, ENTER | abrir: un programa se ejecuta, un archivo de un tipo conocido se abre en su programa, los demás muestran su información |
| ^C | copiar a la otra unidad |
| ^D | borrar (pregunta antes) |
| ^N | renombrar |
| ^R | releer los discos |
| ratón | clic en un archivo: lo selecciona, otra vez: lo abre. Clic en una unidad: la abre |

- **Menú ARCHIVO:** ABRIR, INFO DEL ARCHIVO (^I), COPIAR A LA OTRA UNIDAD, BORRAR, RENOMBRAR, RELEER LOS DISCOS, SALIR AL BASIC.
- **La ventana ARCHIVOS** se puede arrastrar por su título y se queda ahí, incluso al cambiar de vista.
- **Abrir según el tipo** (también en el Commander): los `.TXT` se abren en NOTEPAD, los `.MD` en MARKDOWN, los `.PIC` y `.LYR` en PAINT, los `.MUS` en MUSIC, que empieza a tocarlos. El programa se busca en la unidad del archivo, luego en A: y luego en B:. Si no se encuentra, aparece "NINGÚN PROGRAMA PARA ESTE ARCHIVO". Si el programa tiene cambios sin guardar, pregunta primero.

## Programas, F2

Modo 0, 16 colores. Muestra solo los programas de una unidad (`.BIN`, `.VBN`, `.BAS`), al principio A:, como baldosas en una cuadrícula de 3×3, con las páginas siguientes debajo. La línea de página empieza con la unidad (`A:`, `B:`). Cada programa que tiene icono lo muestra en su baldosa. La baldosa seleccionada es blanca.

| Tecla | Qué hace |
|---|---|
| flechas | eligen (↑/↓ una fila. Más allá del borde, la página siguiente o la anterior) |
| RETURN, ENTER | ejecuta el programa. Si ya está en marcha, continúa donde estaba |
| ^A | lo carga como accesorio de escritorio (COMO ACCESORIO). Después F5 lo abre |
| ^R | releer el disco |
| TAB | la otra unidad (OTRA UNIDAD). Un programa iniciado desde B: vuelve a B: |
| ratón | clic: selecciona, otra vez: ejecuta |

**Menú ARCHIVO:** EJECUTAR, COMO ACCESORIO, OTRA UNIDAD, RELEER LOS DISCOS, SALIR AL BASIC.

## Commander, F3

Modo 1, dos paneles con listas de archivos: A: a la izquierda, B: a la derecha. Cada panel muestra el formato y el número de archivos en su título, y el espacio libre abajo. El panel activo tiene el título oscuro y una selección.

| Tecla | Qué hace |
|---|---|
| ↑/↓ | eligen (con SHIFT: una página) |
| TAB, ←/→ | el otro panel |
| RETURN, ENTER | abrir, como en el Escritorio. La información (tamaño, tipo, dirección de carga, los primeros bytes) con ^I |
| ^C | copiar al otro panel, de cualquier tamaño. Si hay un archivo con el mismo nombre, pregunta antes |
| ^D | borrar |
| ^N | renombrar |
| ^R | releer los dos discos |
| ratón | clic: selecciona, otra vez: abre |

**Menú ARCHIVO:** ABRIR, INFO DEL ARCHIVO (^I), COPIAR AL OTRO PANEL, BORRAR, RENOMBRAR, RELEER LOS DISCOS, FORMATEAR DISCO (DATA), SALIR AL BASIC.

> FORMATEAR borra todos los archivos del disquete del panel activo. Pregunta antes.

## Ajustes, F4

Modo 1. Una línea para cada ajuste. Los cambios se aplican al momento. Al guardarlos (RETURN o ^S) se escriben en `A:SETUP.CFG` y valen también en el siguiente arranque.

| Ajuste | Valores |
|---|---|
| VISTA INICIAL | ESCRITORIO, PROGRAMAS, COMMANDER |
| IDIOMA | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| RETARDO REPETICIÓN | cuánto tiempo se mantiene pulsada una tecla antes de que empiece a repetirse: CORTO, MEDIO, LARGO |
| VELOC. REPETICIÓN | LENTA, MEDIO, RÁPIDA |
| RATÓN AMX | SÍ, NO |
| LECTURA AMX | PULSOS o NIVELES: cómo se lee el ratón. Si el puntero no se mueve bien, pruebe el otro |
| COLOR DEL FONDO | AZUL, NEGRO, VERDE, ROJO |
| TECLADOS | EN + IDIOMA, LOS SEIS (los que recorre CONTROL+SHIFT) |

| Tecla | Qué hace |
|---|---|
| ↑/↓ | eligen un ajuste |
| ←/→ | cambian el valor (también un clic en la línea) |
| RETURN, ^S | guardar |

Al cambiar el IDIOMA se carga al momento el paquete de idioma desde A:. Véase el [capítulo 4](04-languages.md).
