# Manual de V-OS

V-OS es un sistema operativo gráfico para el Amstrad CPC 6128, escrito desde cero en ensamblador Z80. Tiene:

- una barra de menús, ventanas que se pueden arrastrar, diálogos y botones, que se usan con el teclado o con un ratón AMX
- tres vistas para los archivos y los programas (Escritorio, Programas, Commander) y los ajustes (Ajustes)
- seis idiomas como complementos: inglés, griego, francés, español, alemán e italiano
- programas que funcionan uno al lado del otro y continúan donde se quedaron, un accesorio de escritorio y programas en segundo plano
- Studio, un editor de bloques al estilo de Scratch que funciona en el propio CPC
- una API con 42 llamadas y un SDK para programas en ensamblador

Este manual también está en griego: [00-index.md](../00-index.md), en inglés: [00-index.md](../en/00-index.md), en francés: [00-index.md](../fr/00-index.md), en alemán: [00-index.md](../de/00-index.md) y en italiano: [00-index.md](../it/00-index.md).

## Contenido

| Capítulo | Para quién |
|---|---|
| [1. Primeros pasos](01-getting-started.md): el arranque, la pantalla, las teclas, el ratón | todos |
| [2. Las vistas](02-views.md): Escritorio, Programas, Commander, Ajustes | todos |
| [3. Programas](03-programs.md): ejecución, varios a la vez, accesorio, segundo plano, los programas del disquete | todos |
| [4. Idiomas](04-languages.md) | todos |
| [5. Studio](05-studio.md): programas de bloques en el CPC, todos los bloques | quien hace programas |
| [6. Bloques en el ordenador](06-blocks-web.md): el editor web y `vbc.py` | quien hace programas |
| [7. SDK](../../../sdk/README.es.md): programas en ensamblador con la API | programadores |
| [8. Desarrollo de V-OS](08-development.md): compilación, estructura, pruebas, memoria | quien trabaja en el propio V-OS |

El mismo material está también en PDF, en [`docs/V-OS-es.pdf`](../../V-OS-es.pdf). Lo genera `make docs`.

## Otros documentos

- [`MILESTONES.md`](../../../MILESTONES.md): el estado del proyecto, hito a hito, con lo que se probó en cada uno.
- [`docs/REQUIREMENTS.md`](../../REQUIREMENTS.md): los requisitos y el diseño, con los detalles de implementación de cada hito.
- [`src/api/vos_api.inc`](../../../src/api/vos_api.inc): la API, con todas sus reglas en los comentarios.

> Esta documentación cubre V-OS hasta M36 incluido. Se actualiza con cada hito.
