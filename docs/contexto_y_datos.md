# Contexto y Datos

## Problema 3: Multiplicación de Matrices Densas

El problema consiste en multiplicar dos matrices cuadradas `A` y `B` para obtener una tercera matriz `C`. Cada posición de `C` se calcula combinando una fila de `A` con una columna de `B`.

### Propuesta secuencial

Para la versión secuencial proponemos recorrer la multiplicación en el orden `i-k-j`.

La idea es tomar un valor `A[i][k]` y reutilizarlo para actualizar varias posiciones de la fila `i` de `C`. De esta forma se evita estar buscando repetidamente el mismo dato de `A` para cada celda.

Flujo general:

1. Inicializar la matriz `C` en cero.
2. Recorrer una fila de `A`.
3. Tomar cada valor `A[i][k]`.
4. Multiplicarlo por los elementos de la fila `k` de `B`.
5. Acumular los resultados en la fila correspondiente de `C`.

Esta sigue siendo una solución secuencial, pero cambia el orden tradicional de los ciclos para aprovechar mejor los datos que ya están siendo utilizados.

### Datos de prueba

No se utilizará directamente una matriz de un millón por un millón porque su tamaño supera la memoria disponible en una computadora normal.

Se propone trabajar con matrices cuadradas de:

- `256 x 256`
- `512 x 512`
- `1024 x 1024`
- `2048 x 2048`

Los valores serán generados por el programa usando números enteros pequeños entre `0` y `9`. Para poder comparar varias ejecuciones se puede usar una semilla fija, de modo que las matrices sean iguales en todas las pruebas.

### Estructuras en memoria

Se utilizarán tres matrices:

- `A`: primera matriz de entrada.
- `B`: segunda matriz de entrada.
- `C`: matriz donde se guarda el resultado.

Los datos pueden almacenarse como enteros (`int`) en arreglos continuos de memoria.

---

## Problema 5: Filtro de Desenfoque de Imagen

El problema consiste en aplicar un filtro blur sobre una imagen representada como una matriz de píxeles. Para obtener el nuevo valor de un píxel se calcula el promedio entre ese píxel y los vecinos que lo rodean.

### Propuesta secuencial

Para la versión secuencial proponemos procesar la imagen fila por fila usando una ventana deslizante de tres filas.

Mientras se procesa una fila, solo se necesitan:

- la fila anterior,
- la fila actual,
- la fila siguiente.

Para cada píxel se toman los valores disponibles dentro de su vecindad `3 x 3`, se suman y luego se calcula el promedio. En los bordes no se intenta acceder fuera de la imagen; simplemente se promedian los vecinos que realmente existen.

Esta forma permite recorrer la imagen de manera ordenada y evita tratar cada píxel como un caso completamente independiente.

### Datos de prueba

Para las pruebas se utilizarán imágenes en escala de grises representadas como matrices de valores entre `0` y `255`.

Se proponen los siguientes tamaños:

- `1024 x 1024`
- `1920 x 1080`
- `3840 x 2160`
- `7680 x 4320` (8K)

El origen de los datos puede ser una imagen convertida a escala de grises o una matriz generada por el programa. Para las pruebas de rendimiento conviene mantener la misma entrada entre la versión secuencial y la paralela.

### Estructuras en memoria

Se utilizarán dos matrices principales:

- `imagen_original`: contiene los píxeles de entrada.
- `imagen_resultado`: guarda los píxeles después de aplicar el blur.

Cada píxel puede almacenarse como `unsigned char`, ya que sus valores están entre `0` y `255`.

---

