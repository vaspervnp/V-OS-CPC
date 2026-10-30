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
- **Programas que necesitan toda la memoria:** STUDIO y lo que hace Studio (CALC, MINES, FLAP, TICKER y los suyos). Sin ampliación de memoria funcionan solos. Si ya hay uno en marcha, aparece "CIERRE PRIMERO OTRO PROGRAMA".

Cuando se va a una vista (F1–F4) mientras un programa está en marcha:

- Un programa pequeño se queda en memoria. Se retoma desde Programas (RETURN sobre él) o con F6, y continúa exactamente donde estaba.
- Un programa que tiene toda la memoria termina, a menos que haya una ampliación de memoria.

**F6** (VER > PROGRAMAS) muestra la lista de los programas en marcha. Se elige uno con las flechas y RETURN. Si no hay ninguno en marcha, aparece "NINGÚN PROGRAMA EN MARCHA".

**Con una ampliación de memoria** (p. ej. 512K, que V-OS encuentra por sí solo al arrancar), cada programa que necesita toda la memoria recibe su propio banco. Así, STUDIO, CALC, DEMO y PONG pueden funcionar todos juntos.

## En segundo plano

Un programa que está detrás de otro, o detrás de una vista, normalmente **se congela** y continúa cuando vuelve al frente.

Algunos programas piden **seguir funcionando** también en segundo plano, p. ej. TICKER, que cuenta el tiempo. Mientras están ahí no dibujan ni suenan. Cuando vuelven al frente, también han contado el tiempo que estuvieron fuera.

En Studio esto se elige para su programa con STUDIO > IN BACKGROUND.

## El accesorio de escritorio (ACCESORIO)

Un programa pequeño, como CLOCK, puede abrirse en una ventana **encima de cualquier cosa**: una vista o un programa.

1. En Programas, seleccione CLOCK y elija ARCHIVO > COMO ACCESORIO (^A).
2. A partir de entonces, **F5** lo abre y lo cierra, esté donde esté. ESC también lo cierra.

Mientras está abierto, recibe las teclas y los clics. Su ventana se puede arrastrar por su título. Cuando se cierra, se vuelve a dibujar lo que había debajo.

## Los programas del disquete

| Programa | Qué es |
|---|---|
| **STUDIO** | el editor de bloques: se hacen programas en el CPC ([capítulo 5](05-studio.md)) |
| **DEMO** | el primer programa de V-OS: un cuadrado que se mueve solo. Las flechas lo dirigen y SPACE cambia su color |
| **MIXED** | la "pantalla mixta": una franja de 16 colores (modo 0) entre franjas de modo 1. Un clic muestra las coordenadas |
| **CLOCK** | el tiempo desde que arrancó V-OS. También funciona como accesorio de escritorio |
| **CALC** | una calculadora en una ventana con botones, hecha en Studio (también existe `CALC.VBS`) |
| **MINES** | un buscaminas de 8×6 con 8 minas, hecho en Studio. Un clic abre una casilla, y NEW empieza una partida nueva |
| **BRICKS** | romper ladrillos: una pala con ←/→, 32 ladrillos, 3 vidas, niveles con una pelota cada vez más rápida. En GAME OVER, SPACE para una partida nueva |
| **PONG** | una pelota y una pala con las flechas, puntuación y vidas |
| **CATCH** | atrapar las estrellas que caen |
| **STARCAT** | un gato con disfraces que camina, una estrella, una melodía a partir de una lista |
| **COUNTER** | un contador con botones +1, −1 y 0, en modo 1 |
| **FLAP** | un pájaro que bate las alas (disfraces), y una estrella que cambia de disfraz cada segundo |
| **TICKER** | cuenta segundos y sigue en segundo plano |

- Los programas de bloques son archivos `.VBN`. Tienen un menú PROGRAM > STOP (CONTROL+Q).
- Los que tienen también un `.VBS` (CALC, MINES, FLAP, TICKER) se abren en Studio para verlos o cambiarlos.
- `VBRUN.SYS` no es un programa: es el "reproductor" que necesita Studio.
