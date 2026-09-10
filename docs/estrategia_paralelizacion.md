# Estrategia de Paralelización

## Problema 3: Multiplicación de Matrices Densas

### División del trabajo

La matriz resultado `C` se divide en bloques cuadrados. Cada bloque representa una parte independiente del resultado y puede ser calculado por un hilo diferente.

En las pruebas se utiliza un tamaño de bloque de `32 x 32`, aunque este valor puede cambiarse desde la línea de comandos.

La directiva principal utilizada es:

```c
#pragma omp parallel for collapse(2) schedule(static)
```

- `parallel for` reparte las iteraciones entre varios hilos.
- `collapse(2)` combina los ciclos que recorren los bloques por filas y columnas, permitiendo que OpenMP tenga más trabajo para distribuir.
- `schedule(static)` asigna los bloques desde el inicio porque todos tienen un costo de cálculo parecido.

### Acceso a memoria

Las matrices `A` y `B` son compartidas entre los hilos, pero únicamente se utilizan para lectura.

La matriz `C` también se encuentra en memoria compartida, pero cada hilo recibe un bloque diferente y solo escribe dentro de esa región.

De esta forma, dos hilos no escriben al mismo tiempo sobre una misma posición de `C`.

### Prevención de condiciones de carrera

No fue necesario utilizar `critical`, `atomic` o bloqueos.

Cada combinación de bloques `(bi, bj)` corresponde a una región exclusiva de `C`, por lo que un solo hilo es responsable de actualizar todas las posiciones de ese bloque.

Las variables utilizadas para recorrer los ciclos y realizar los cálculos dentro de cada iteración pertenecen al hilo que está ejecutando ese bloque.

### Balance de carga

Se utiliza `schedule(static)` porque el trabajo necesario para calcular los bloques es muy similar. Así se evita el costo adicional de estar reasignando trabajo mientras el programa se está ejecutando.

---

## Problema 5: Filtro de Desenfoque de Imagen

### División del trabajo

Para el filtro blur, el trabajo se divide por filas de la imagen de salida.

La directiva utilizada es:

```c
#pragma omp parallel for schedule(static)
```

Cada hilo recibe un grupo de filas y procesa todos los píxeles de esas filas.

Se utiliza `schedule(static)` porque cada fila requiere aproximadamente la misma cantidad de trabajo.

### Manejo de los bordes entre hilos

Para calcular un píxel se necesitan los valores de su fila y de las filas vecinas.

Un hilo puede necesitar leer una fila que está siendo procesada como salida por otro hilo. Esto no genera conflicto porque todos los cálculos leen los datos desde `entrada`, y esa matriz nunca se modifica durante el blur.

Por ejemplo:

```text
Hilo 0 -> filas de salida 0 a 269
Hilo 1 -> filas de salida 270 a 539
```

Para calcular la fila `270`, el segundo hilo puede leer la fila `269` de `entrada`.

Esta fila vecina funciona como un **halo lógico**: el hilo puede consultarla aunque esté fuera de su grupo de filas, sin necesidad de copiarla.

### Prevención de condiciones de carrera

La matriz `entrada` es compartida y de solo lectura.

Cada hilo escribe únicamente las filas que le fueron asignadas en la matriz `salida`. Por esta razón, dos hilos no escriben sobre el mismo píxel.

Las variables usadas para la suma, el contador y los índices son independientes para cada iteración.

No fue necesario utilizar `critical`, `atomic` ni bloqueos.

### Ventana deslizante

Dentro de cada fila se utiliza una ventana deslizante.

En lugar de volver a sumar todos los vecinos para cada píxel, al avanzar una columna se eliminan de la suma los valores que dejan de pertenecer a la ventana y se agregan los nuevos valores que entran.

Esto reduce operaciones repetidas y mantiene la misma lógica tanto en la versión secuencial como en la paralela.

---

