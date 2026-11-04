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
| TAB | la siguiente unidad: A:, B:, DISK (con una tarjeta M4) |
| RETURN, ENTER | abrir: un programa se ejecuta, un archivo de un tipo conocido se abre en su programa, los demás muestran su información |
| ^C | copiar a la siguiente unidad (desde DISK: a A:) |
| ^D | borrar (pregunta antes) |
| ^N | renombrar |
| ^R | releer los discos |
| ratón | clic en un archivo: lo selecciona, otra vez: lo abre. Clic en una unidad: la abre |

- **Menú ARCHIVO:** ABRIR, INFO DEL ARCHIVO (^I), COPIAR A LA SIGUIENTE, BORRAR, RENOMBRAR, RELEER LOS DISCOS, GUARDAR EL ESCRITORIO (^S), SALIR AL BASIC.
- **GUARDAR EL ESCRITORIO** (^S) escribe la ventana de archivos tal como está (dónde, su tamaño, su unidad, o cerrada) en `A:SETUP.CFG`: en el siguiente arranque el Escritorio la abre así enseguida. El ^S de Setup también la guarda.
- **La ventana ARCHIVOS** se puede arrastrar por su título y se queda ahí, incluso al cambiar de vista.
- **Al principio no hay ventana ni unidad elegida:** se ve el fondo (y su imagen). Una unidad (un clic en su icono, o TAB) abre su ventana; la X de su título la cierra, igual que un clic en la unidad abierta. El cuadradito de la esquina inferior derecha agranda o reduce la ventana en iconos enteros (2 a 5 por fila, 1 a 5 filas; cuatro por cinco al principio), y la barra de la derecha muestra qué parte de la lista se ve: un clic encima o debajo de su parte oscura desplaza una ventana. El tamaño se guarda, como el sitio.
- **Abrir según el tipo** (también en el Commander): los `.TXT` se abren en NOTEPAD, los `.MD` en MARKDOWN, los `.PIC` y `.LYR` en PAINT, los `.VDB` en DATABASE, los `.VSH` en SHEET, los `.MUS` en MUSIC, que empieza a tocarlos. El programa se busca en la unidad del archivo, luego en A: y luego en B:. Si no se encuentra, aparece "NINGÚN PROGRAMA PARA ESTE ARCHIVO". Si el programa tiene cambios sin guardar, pregunta primero.

## Programas, F2

Modo 0, 16 colores. Muestra solo los programas de una unidad (`.BIN`, `.VBN`, `.BAS`), al principio A:, como baldosas en una cuadrícula de 3×3, con las páginas siguientes debajo. La línea de página empieza con la unidad (`A:`, `B:`). Cada programa que tiene icono lo muestra en su baldosa. La baldosa seleccionada es blanca.

| Tecla | Qué hace |
|---|---|
| flechas | eligen (↑/↓ una fila. Más allá del borde, la página siguiente o la anterior) |
| RETURN, ENTER | ejecuta el programa. Si ya está en marcha, continúa donde estaba |
| ^A | lo carga como accesorio de escritorio (COMO ACCESORIO). Después F5 lo abre |
| ^R | releer el disco |
| TAB | la siguiente unidad (UNIDAD SIGUIENTE): A:, B:, DISK. Un programa iniciado desde B: vuelve a B: |
| ratón | clic: selecciona, otra vez: ejecuta |

**Menú ARCHIVO:** EJECUTAR, COMO ACCESORIO, UNIDAD SIGUIENTE, RELEER LOS DISCOS, SALIR AL BASIC.

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
| ^G | la siguiente unidad para el panel activo: A:, B:, DISK (también con un clic en su título) |
| ^F | buscar archivos: un nombre con `*` y `?` (`*.TXT`, `README.*`, `NOTE?AD.BIN`; sin punto, cualquier extensión), que se busca en A:, B: y DISK (la carpeta donde está). El panel activo lista lo encontrado, hasta 64 archivos, cada uno con su unidad (`B:README.TXT`). RETURN va al archivo en su unidad; ^C, ^D, ^N y ^V funcionan sobre los archivos encontrados tal como están; ^R o ^G termina la lista |
| ^V | ver el texto: las primeras líneas del archivo elegido en el otro panel, hasta que se vuelva a dibujar. Una imagen (`.SCR`, como las guardan PAINT y el CHART de SHEET) se ve en toda la pantalla en modo 0 con sus propias tintas; una tecla o un clic vuelve al Commander |
| ^E | copiar el disco: todo el disco del panel activo en el del otro panel (A: y B:), pista por pista, cada pista formateada antes como la del origen (DATA o SYSTEM). Pregunta antes: los archivos del otro disco se pierden |
| ratón | clic: selecciona, otra vez: abre |

**Menú ARCHIVO:** ABRIR, INFO DEL ARCHIVO (^I), VER EL TEXTO (^V), BUSCAR (^F), COPIAR EL DISCO (^E), COPIAR AL OTRO PANEL, BORRAR, RENOMBRAR, RELEER LOS DISCOS, UNIDAD SIGUIENTE (^G), FORMATEAR DISCO (DATA), SALIR AL BASIC.

> FORMATEAR borra todos los archivos del disquete del panel activo. Pregunta antes.

## DISK: la tarjeta SD de la M4

Con una tarjeta M4, el Escritorio tiene un tercer icono de unidad, DISK, debajo de A: y B:, y TAB pasa de A: a B: y a DISK. También llegan a ella Programas y los paneles del Commander (^G). El título muestra la carpeta donde está, p. ej. `DISK:/GAMES/`.

- **Las carpetas** se ven como carpetas (un icono con pestaña, o DIR en el Commander). RETURN sobre una entra en ella, y `..`, la primera entrada, sube. En Programas también aparecen, para llegar a los programas que contienen.
- **Todo como en un disquete:** los programas se ejecutan desde ella, los archivos se abren en sus programas, y ^C, ^D y ^N copian, borran y renombran. Las copias entre DISK y un disquete llegan hasta 16K. Carpetas y archivos tienen nombres como en el CPC (8.3: `NOMBRE.EXT`); los nombres más largos no aparecen.
- **M4.SYS** (en `vos.dsk`) se carga desde A: la primera vez que se usa DISK.
- **La hora y las fechas:** la barra de menús muestra la hora de la M4 («09:25», a la izquierda del idioma del teclado) en cada vista y programa donde cabe, e INFO DEL ARCHIVO (^I) da la fecha y la hora de un archivo de la tarjeta bajo su tamaño. La hora viene del servidor de hora de la M4 (puesto con `NETSET` en el CPC).
- **En los programas:** OTHER DRIVE (^W en SHEET) pasa de A: a B: y a DISK, y la línea de abajo dice `DISK:NOMBRE.TXT`. La lista de OPEN muestra también las carpetas: RETURN en una (o en `..`) muestra esa carpeta, y SAVE escribe en la carpeta desde donde abrió. READER escribe la tarjeta como `C:` en sus direcciones.
- **Las bases de datos** van también en DISK: el ^W de DATABASE llega allí, y STREETS ejecutado desde la tarjeta guarda allí su STREETS.VDB.
- **Aún no:** la tarjeta SD no se formatea desde V-OS. V-OS sigue arrancando desde un disquete en A: (escriba `|DISC` antes de `RUN"VOS"`: con una tarjeta M4, el CPC arranca en la tarjeta SD).

## Ajustes, F4

Modo 1. Una línea para cada ajuste. Los cambios se aplican al momento. Al guardarlos (RETURN o ^S) se escriben en `A:SETUP.CFG` y valen también en el siguiente arranque.

| Ajuste | Valores |
|---|---|
| VISTA INICIAL | ESCRITORIO, PROGRAMAS, COMMANDER |
| IDIOMA | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| RETARDO REPETICIÓN | cuánto tiempo se mantiene pulsada una tecla antes de que empiece a repetirse: CORTO, MEDIO, LARGO |
| VELOC. REPETICIÓN | LENTA, MEDIO, RÁPIDA |
| RATÓN AMX | SÍ, NO |
| LECTURA AMX | NIVELES (al principio) o PULSOS: cómo se lee el ratón. NIVELES cuenta cada lectura con movimiento, PULSOS solo el comienzo de los pulsos. Si el puntero se mueve demasiado rápido o demasiado despacio, pruebe el otro |
| COLOR DEL FONDO | AZUL, NEGRO, VERDE, ROJO |
| TECLADOS | EN + IDIOMA, LOS SEIS (los que recorre CONTROL+SHIFT) |
| TEMA | CLARO, OSCURO (barras, menús, diálogos, ventanas y listas en negro con texto blanco; en los programas, sus menús y diálogos) |
| IMAGEN DE FONDO | NINGUNA, o una imagen `.SCR`: IZQ./DER. pasan por NINGUNA, A:, B: y DISK, y en una unidad se listan sus `.SCR` para elegir uno. El Escritorio la muestra en el centro del fondo, con el color del fondo alrededor; una imagen de PAINT (modo 0, 16 colores) en los cuatro colores del Escritorio. Necesita una ampliación de memoria (su último banco de 16K guarda la imagen); sin ella: NECESITA UNA AMPLIACIÓN DE MEMORIA. Tras tres minutos sin hacer nada en el Escritorio, la imagen se muestra sola (un salvapantallas); cualquier tecla o el ratón devuelven el Escritorio |

| Tecla | Qué hace |
|---|---|
| ↑/↓ | eligen un ajuste |
| ←/→ | cambian el valor (también un clic en la línea) |
| RETURN, ^S | guardar |

Al cambiar el IDIOMA se carga al momento el paquete de idioma desde A:. Véase el [capítulo 4](04-languages.md).
