# 6. Bloques en el PC: el editor web y `vbc.py`

Además de Studio, que funciona en el CPC, existe también un editor de bloques para el PC. El lenguaje es el mismo, con algunos bloques más: listas, ruido, tamaño del sprite, texto de color.

## El editor

Abra `blocks/editor.html` en un navegador. Está basado en Blockly y viene en griego o en inglés.

- **Categorías:** eventos, control, movimiento, apariencia, texto, operadores, sensores, variables, listas y ventanas.
- **Sprites:** rectángulos o disfraces. Se definen en una tabla, y el escenario los muestra con los colores del CPC. Se pueden arrastrar con el ratón.
- **Archivos:** abre y guarda archivos `.vbp`. Son JSON con todo el programa, así que también se pueden escribir a mano.

## Compilar

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

`vbc.py` escribe `build/NOMBRE.ASM`, con un comentario para cada bloque. Lo ensambla con RASM en `NOMBRE.VBN`, con una tabla de reubicación para que funcione junto a otros programas, y con `--dsk` lo pone en el disquete.

| Opción | Qué hace |
|---|---|
| `-o build` | carpeta de salida |
| `--asm-only` | solo el `.ASM` |
| `--dsk build/vos.dsk` | también en el disquete |

## El formato `.vbp`

La descripción completa está al principio de `blocks/vbc.py`: eventos, órdenes, valores, disfraces, icono. En resumen:

```json
{"name": "PONG", "mode": 0, "background": 0,
 "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
              "colour": 8, "vx": 2, "vy": 2, "visible": true}],
 "variables": {"score": 0},
 "scripts": [{"sprite": "ball", "when": {"event": "start"},
              "do": [{"block": "forever", "do": [{"block": "move"}, {"block": "bounce"}]}]}]}
```

- **Variables y listas:** tienen nombres, no letras. Las listas tienen una longitud máxima fija.
- **Icono:** `"icon"` da un icono para Programas (F2).
- **Un programa con muchas partes parecidas:** lo puede escribir un script de Python. Véase `tools/mkbricks.py`, que escribe `bricks.vbp` con 32 ladrillos.

## Ejemplos

En `blocks/examples/`:

| Archivo | Programa |
|---|---|
| `pong.vbp` | PONG |
| `catch.vbp` | CATCH |
| `starcat.vbp` | STARCAT: disfraces, una melodía a partir de una lista |
| `counter.vbp` | COUNTER: una ventana y botones |
| `bricks.vbp` | BRICKS (escrito por `tools/mkbricks.py`) |

Los archivos `*.vbt` son programas de Studio en forma de texto, para `tools/mkvbs.py`. Véase el [capítulo 5](05-studio.md).

## ¿Studio o editor web?

| | Studio | editor web |
|---|---|---|
| Dónde | en el CPC | en el PC |
| Archivo | `.VBS` | `.vbp` |
| Variables | 128, A–H15 | con nombres |
| Listas, ruido, tamaño del sprite | no | sí |
| SAVE/LOAD VARS | sí | no |
| El programa | necesita toda la memoria | pequeño, funciona junto a otros |
