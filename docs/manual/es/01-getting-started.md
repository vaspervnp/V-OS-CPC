# 1. Primeros pasos

## Qué se necesita

- Un Amstrad CPC 6128 o un emulador. V-OS se prueba en Caprice32.
- El disquete de V-OS en la unidad A:, es decir, el `build/vos.dsk` que genera `make`, y el disquete de los programas, `build/apps.dsk`, en B:.
- De forma opcional:
  - un ratón AMX
  - una segunda unidad (B:)
  - una ampliación de memoria (p. ej. 512K), para más programas a la vez

## El arranque

Desde el BASIC:

```
RUN"VOS
```

V-OS carga el núcleo, desactiva las ROM y toma el control de toda la máquina. Detecta por sí solo la ampliación de memoria.

- **Primera vista:** el Escritorio. Se puede cambiar en Ajustes, en la línea VISTA INICIAL.
- **Idioma:** inglés. Si hay un `SETUP.CFG` en el disquete, arranca con el idioma y los ajustes guardados en él.
- **Salir:** ARCHIVO > SALIR AL BASIC (CONTROL+Q en las vistas). Pide confirmación y reinicia el CPC.

## La pantalla

V-OS usa toda la pantalla (overscan): 384×272 píxeles en modo 1 (4 colores) o 192×272 en modo 0 (16 colores).

- **Barra de menús** (arriba): los menús de la vista o del programa, normalmente ARCHIVO o el menú del programa, VER y AYUDA. A la derecha está el idioma del teclado (EN, ΕΛ, …).
- **Línea inferior:** en cada vista, las teclas que funcionan en ella.

## Teclas que funcionan en todas partes

| Tecla | Qué hace |
|---|---|
| F1 | Escritorio |
| F2 | Programas |
| F3 | Commander |
| F4 | Ajustes |
| F5 | abre y cierra el accesorio de escritorio (ACCESORIO) |
| F6 | los programas en marcha, para elegir uno |
| ESC | abre el primer menú. En los menús, ←/→ cambian de menú, ↑/↓ eligen una opción, RETURN la ejecuta, ESC cierra |
| CONTROL+letra | los atajos de los menús (p. ej. ^Q, ^L) |
| CONTROL+L | cambio de idioma (VER > CAMBIAR DE IDIOMA) |
| CONTROL+K | el diálogo con las teclas (AYUDA > TECLAS) |
| CONTROL+SHIFT | cambia el teclado: inglés, el del paquete y, con TECLADOS: LOS SEIS en Setup, los de los otros idiomas |
| TAB, SHIFT+TAB | mueven el foco entre los botones. RETURN, ENTER o SPACE pulsan el botón que tiene el foco |

F1–F6 son las teclas f1–f6 del teclado numérico del CPC.

## El puntero y el ratón

- **Con un ratón AMX:** el puntero se mueve con el ratón, y su botón hace clic. El ratón se activa y se configura en Ajustes (RATÓN AMX, LECTURA AMX).
- **Sin ratón:** el puntero se mueve con las flechas, y COPY hace clic. En las vistas que usan las flechas para elegir (Escritorio, Programas, Commander), las flechas eligen archivos y programas en lugar de mover el puntero.

Casi todo funciona de las dos maneras: un clic en un archivo o programa lo selecciona, y un segundo clic lo abre.

## Ventanas y diálogos

- **Arrastrar:** todas las ventanas se pueden arrastrar por su barra de título: los diálogos, la ventana ARCHIVOS del Escritorio, el accesorio de escritorio y las ventanas de los programas de bloques. Mientras se mantiene pulsado el botón se ve un contorno discontinuo, y la ventana se vuelve a dibujar donde se suelta.
- **Diálogos:** esperan una respuesta. TAB y ←/→ cambian de botón, RETURN lo pulsa, y ESC elige el último (normalmente NO o CANCELAR).
- **Introducción de texto** (p. ej. al renombrar): se escribe al final, DEL borra, RETURN acepta y ESC cancela. También se puede escribir en el idioma del paquete.

## Disquetes y archivos

- **Formato:** V-OS lee y escribe disquetes AMSDOS (formato DATA o SYSTEM) en A: y B:. El BASIC también puede leer sus archivos.
- **Nombres:** 8 caracteres más 3 para el tipo (`NOMBRE.TIP`).

Tipos que se encontrará:

| Tipo | Qué es |
|---|---|
| `.BIN` | un programa de V-OS (o un archivo binario) |
| `.VBN` | un programa de V-OS hecho con bloques |
| `.VBS` | un programa de Studio (su código fuente) |
| `.OVL`, `.MSG`, `.LNG` | partes del propio V-OS: vistas, textos, idiomas |
| `.SYS` | archivos del sistema (p. ej. `VBRUN.SYS`, el reproductor de Studio) |
| `SETUP.CFG` | los ajustes |

Los ajustes, los idiomas y las vistas se leen de A:, así que el disquete de V-OS debe quedarse ahí.

## Mensajes de error

Los errores de disco se muestran en un diálogo: UNIDAD NO LISTA, DISCO PROTEGIDO, NO SE ENCUENTRA, DISCO LLENO, DIRECTORIO LLENO, EL NOMBRE YA EXISTE, NOMBRE NO VÁLIDO y otros.

Dos más tienen que ver con los programas:

- **NO ES PROGRAMA V-OS:** el archivo no tiene la cabecera de un programa.
- **CIERRE PRIMERO OTRO PROGRAMA:** no hay sitio. Véase el [capítulo 3](03-programs.md).
