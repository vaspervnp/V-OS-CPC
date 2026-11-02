# 3. Programas

## Empezar y terminar

Un programa se inicia de una de estas maneras:

- desde Programas (F2): se selecciona y se pulsa RETURN, o se hace doble clic
- desde el Escritorio o el Commander: ARCHIVO > EJECUTAR
- desde otro programa, como Studio, que ejecuta lo que usted haga

Cada programa tiene su propio menú junto a los comunes VER y AYUDA. Termina desde su menú (normalmente BACK o STOP, CONTROL+Q) y vuelve a la vista desde la que se inició.

## Varios programas a la vez

Los programas de V-OS son de dos clases:

- **Pequeños, con tabla de reubicación:** DEMO, MIXED y CLOCK, los ejemplos del editor web (PONG, CATCH, STARCAT, COUNTER), y lo que haga el [SDK](../../../sdk/README.es.md). Comparten 12K de memoria, y funcionan juntos tantos como quepan.
- **Programas que necesitan toda la memoria:** STUDIO y lo que hace Studio (CALC, MINES, FLAP, TICKER y los suyos). También MARKDOWN y READER, que pasan de 12K. Sin ampliación de memoria funcionan solos. Si ya hay uno en marcha, aparece "CIERRE PRIMERO OTRO PROGRAMA".

Cuando se va a una vista (F1–F4) mientras un programa está en marcha:

- Un programa pequeño se queda en memoria. Se retoma desde Programas (RETURN sobre él) o con F6, y continúa exactamente donde estaba.
- Un programa que tiene toda la memoria termina, a menos que haya una ampliación de memoria.

**F6** (VER > PROGRAMAS) muestra la lista de los programas en marcha. Se elige uno con las flechas y RETURN. Si no hay ninguno en marcha, aparece "NINGÚN PROGRAMA EN MARCHA".

**Con una ampliación de memoria** (p. ej. 512K, que V-OS encuentra por sí solo al arrancar), cada programa que necesita toda la memoria recibe su propio banco. Así, STUDIO, CALC, DEMO y PONG pueden funcionar todos juntos. Desde M43 cada programa recibe también su propio banco de datos de 16K cuando lo necesita: lo que guarda allí no se pierde mientras corren otros programas o vistas.

## En segundo plano

Un programa que está detrás de otro, o detrás de una vista, normalmente **se congela** y continúa cuando vuelve al frente.

Algunos programas piden **seguir funcionando** también en segundo plano, p. ej. TICKER, que cuenta el tiempo. Mientras están ahí no dibujan ni suenan. Cuando vuelven al frente, también han contado el tiempo que estuvieron fuera.

En Studio esto se elige para su programa con STUDIO > IN BACKGROUND.

MUSIC es la excepción: su canción suena desde la interrupción, 50 veces por segundo, así que sigue sin cortes detrás de todo. Solo se para un momento mientras se lee el disquete.

## El accesorio de escritorio (ACCESORIO)

Un programa pequeño, como CLOCK, puede abrirse en una ventana **encima de cualquier cosa**: una vista o un programa.

1. En Programas, seleccione CLOCK y elija ARCHIVO > COMO ACCESORIO (^A).
2. A partir de entonces, **F5** lo abre y lo cierra, esté donde esté. ESC también lo cierra.

Mientras está abierto, recibe las teclas y los clics. Su ventana se puede arrastrar por su título. Cuando se cierra, se vuelve a dibujar lo que había debajo.

## La página (modo 2)

NOTEPAD, MARKDOWN, READER y SHEET tienen PAGE (MODE 2) en su menú, ^M. La pantalla pasa al modo 2: texto negro sobre papel blanco, 768 píxeles de ancho, con los menús y diálogos también negros sobre blanco. Los editores (NOTEPAD y MARKDOWN) muestran 80 columnas entre los bordes de la página, una línea donde termina cada página de 60 líneas, y PAGE n en la última línea. La vista previa de MARKDOWN y READER muestran la página en 80 columnas con sus estilos. SHEET muestra 10 columnas (A–J) con líneas entre ellas. ^M de nuevo vuelve al modo 1.

## Los programas del disquete

Un disquete del CPC tiene 180K, así que V-OS viene en dos. `vos.dsk` (A:) tiene el sistema, DEMO, MIXED, STUDIO y CLOCK, y las fuentes `.VBS` de los programas VB, que Studio abre desde A:. `apps.dsk` (B:) tiene los demás, de PONG a WEBGET: en el Launcher, TAB muestra B:. Algunos programas tienen su propio disquete, como dice la tabla.

| Programa | Qué es |
|---|---|
| **STUDIO** | el editor de bloques: se hacen programas en el CPC ([capítulo 5](05-studio.md)) |
| **DEMO** | el primer programa de V-OS: un cuadrado que se mueve solo. Las flechas lo dirigen y SPACE cambia su color |
| **MIXED** | la "pantalla mixta": una franja de 16 colores (modo 0) entre franjas de modo 1. Un clic muestra las coordenadas |
| **CLOCK** | el tiempo desde que arrancó V-OS. También funciona como accesorio de escritorio |
| **CALC** | una calculadora en una ventana con botones, hecha en Studio (también existe `CALC.VBS`) |
| **MINES** | un buscaminas de 8×6 con 8 minas, hecho en Studio. Un clic abre una casilla, y NEW empieza una partida nueva |
| **BRICKS** | romper ladrillos: una pala con ←/→, 32 ladrillos, 3 vidas, niveles con una pelota cada vez más rápida. En GAME OVER, SPACE para una partida nueva |
| **VROUVES** | tower defence, del juego de CPC LET'S GO FOR VROUVES: 7 pantallas, del Kafenio al cementerio, con 10 oleadas cada una. Está en su propio disquete, `vrouves.dsk`: en B:, y TAB en el Launcher. Las flechas mueven el cursor, 1–6 elige un defensor, SPACE construye, S vende, N trae la oleada siguiente, P hace pausa. Puntos por cada invasor y por los aldeanos que quedan al final de una pantalla. El disquete guarda `VROUVES.SAV`: CONTINUE empieza desde la pantalla alcanzada, HIGH SCORES muestra las cinco mejores con sus nombres. Escrito con el SDK (`myapps/vrouves`) |
| **NOTEPAD** | un editor de texto en modo 1, 48×22, para archivos de hasta 4K, o de hasta 16K con una ampliación de memoria: entonces guarda unos 2,5K alrededor del cursor en su memoria y el resto en su propio banco de datos, y SELECT ALL toma esa parte. NEW, OPEN (solo archivos `.TXT`), SAVE, SAVE AS, OTHER DRIVE. Flechas, DEL, CLR y RETURN; un clic coloca el cursor. La línea de abajo muestra la línea y la columna. Menú EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT y las flechas seleccionan. El portapapeles (hasta 1K) es común a todos los programas (`myapps/notepad`) |
| **PAINT** | dibujo en modo 0 con 16 colores: una imagen de toda la pantalla del CPC, 160×200 sin el overscan (`.SCR`, 16K, que también cargan el BASIC y otros programas del CPC; sin ampliación de memoria 128×128, `.PIC`), o de 64×64 con zoom 2× en 3 capas (`.LYR`, NEW LAYERS). Herramientas: P lápiz, B pincel, L línea, X rectángulo, F relleno; TAB cambia el color. Las flechas y COPY dibujan sin ratón. La ventana muestra 128×128 de la imagen: las barras a su derecha y debajo muestran qué parte, y un clic o un arrastre sobre ellas la mueve. Bajo los colores: dónde está el puntero en la imagen, y VIEW, la esquina superior izquierda de la ventana. Capas: 1–3 eligen una, H la oculta o la muestra, U y D la suben y la bajan, E es la goma. EXPORT .SCR (para la imagen de 128×128 y las capas; toda la pantalla ya es un `.SCR`): la imagen (las capas tal como se ven) como pantalla del CPC, un `NOMBRE.SCR` de 16K (modo 0, en el centro, con la paleta), para BASIC u otros programas. En BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | reproduce canciones de Arkos Tracker 3 (`.MUS`, hechas con `make songs`), con tres barras de volumen. Está en su propio disquete, `music.dsk`, en B:. OPEN, SPACE reproduce y para. La música sigue detrás de otras vistas y programas, sin cortes, incluso mientras otro programa carga o dibuja: suena desde la interrupción. El bloque MUSIC de Studio lo inicia detrás de un programa con una canción (`myapps/music`) |
| **MARKDOWN** | un editor de archivos Markdown (`.MD`, hasta 6K), como NOTEPAD. ^P muestra la página: títulos `#`, **negrita**, *cursiva*, `código`, listas, citas, líneas, bloques de código y enlaces subrayados, sin las marcas. Las líneas seguidas forman un párrafo (dos espacios al final cortan la línea). Las flechas desplazan la página, RETURN o ^P vuelven al texto. Está en su propio disquete, `markdown.dsk`, con un `README.MD`. Menú EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT y las flechas seleccionan. El portapapeles (hasta 1K) es común a todos los programas (`myapps/markdown`) |
| **SYSINFO** | muestra las versiones de V-OS y de la API, la memoria (toda y la libre para programas) y el espacio libre en los disquetes de A: y B: (^R otra vez). Un ejemplo de `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | descarga archivos de la web con la tarjeta M4: GET A FILE (^G) pide una dirección (HTTP, p. ej. `example.com/index.html`) y un nombre, y el archivo (hasta 16K) se guarda en la unidad que muestra (OTHER DRIVE). También muestra el estado de la red. Sin tarjeta M4: "NO M4 BOARD" (`myapps/webget`) |
| **READER** | lee páginas Markdown (`.MD`, hasta 6K) del disquete o de la web con la tarjeta M4, mostradas como la vista previa de MARKDOWN. TAB elige el enlace siguiente (invertido), RETURN lo abre, DEL vuelve a la página anterior (guarda 4). Un enlace sin `http://` se abre junto a la página, en el disquete o en el mismo sitio. OPEN A FILE y OPEN AN ADDRESS (^U, HTTP, p. ej. `example.com/README.md`). Las direcciones `https://` no se abren. Está en su propio disquete, `reader.dsk`, con `INDEX.MD` y `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | un callejero en una base de datos de V-OS: escribe las primeras letras de una calle y ve las calles que empiezan así, con su zona y código postal; DEL borra una letra. ^A añade una calle, ^D borra la primera de la lista. Las calles están en `STREETS.VDB` en su disco, `streets.dsk`, en B:; la primera vez lo crea con calles de Atenas. Un ejemplo de la API de bases de datos (`myapps/streets`) La búsqueda no distingue mayúsculas, minúsculas ni acentos. |
| **DATABASE** | bases de datos, como un pequeño Access: ^N una base nueva (`NOMBRE.VDB`), ^O abrir una, ^T una tabla nueva (su nombre, y campos: un nombre, TEXTO hasta 40 caracteres o NÚMERO 0–65535, y si se ordena por el primero). La lista muestra un registro por línea y los campos en columnas; las flechas eligen y desplazan, TAB pasa a la tabla siguiente, y si la tabla tiene clave, lo que escribes va a los registros que empiezan así (sin mayúsculas ni acentos). RETURN abre el formulario: un campo por línea, RETURN lo cambia, ^S guarda, ^B vuelve a la lista. ^A un registro nuevo, ^D borrar, ^W la otra unidad. También abre los `.VDB` de STREETS (`myapps/database`) |
| **SHEET** | una hoja de cálculo: 16 columnas (A–P) y 64 filas, 5 columnas y 19 filas en la pantalla. Una celda tiene, hasta 40 caracteres, un número (`12`, `-3.5`; el separador decimal es un punto), texto, o una fórmula después de `=`: `+ - * /`, paréntesis, celdas (`B3`), SUM, AVG, MIN, MAX y COUNT de celdas y rangos (`=SUM(B2:B9)`), ABS, INT, ROUND(x, 0–2). Los números tienen dos decimales, hasta ±21474836.46. Las flechas mueven el cursor, RETURN cambia la celda, al escribir empieza un texto nuevo, DEL (o CLR) la vacía; después de cada cambio se vuelven a calcular todas las fórmulas. La primera línea muestra el texto de la celda. Una celda con error muestra `#ERR`, un número que no cabe `########`. ^N nueva, ^O abrir, ^S guardar, ^A guardar como (`NOMBRE.VSH`, un archivo de texto, una línea por celda: `B3 =B1*2`), ^W la otra unidad. Las fórmulas las calcula `CALC.SYS` en A:, que cualquier programa puede usar (`VX_CALC`). Está en su propio disco, `sheet.dsk`, con el ejemplo `BUDGET.VSH` (`myapps/sheet`) |
| **PONG** | una pelota y una pala con las flechas, puntuación y vidas |
| **CATCH** | atrapar las estrellas que caen |
| **STARCAT** | un gato con disfraces que camina, una estrella, una melodía a partir de una lista |
| **COUNTER** | un contador con botones +1, −1 y 0, en modo 1 |
| **FLAP** | un pájaro que bate las alas (disfraces), y una estrella que cambia de disfraz cada segundo |
| **TICKER** | cuenta segundos y sigue en segundo plano |

- Los programas de bloques son archivos `.VBN`. Tienen un menú PROGRAM > STOP (CONTROL+Q).
- Los que tienen también un `.VBS` (CALC, MINES, FLAP, TICKER) se abren en Studio para verlos o cambiarlos.
- `VBRUN.SYS` no es un programa: es el "reproductor" que necesita Studio.
