# Resultados y métricas

## Metodología de medición

Las pruebas se ejecutaron en el equipo de Vianka Vanessa Castro Ordoñez (carné 23201), equipado con un Intel Core i7-1165G7 de 4 núcleos físicos y 8 procesadores lógicos. Los cuatro programas se compilaron con GCC 16.1.0 usando `-O2 -fopenmp`.

Para cada configuración se realizó una corrida de calentamiento y luego 5 corridas medidas. La corrida de calentamiento no se incluyó en las estadísticas. Los tiempos corresponden únicamente a la región de cálculo del algoritmo; no incluyen la reserva de memoria, generación de datos ni cálculo del checksum.

Las versiones secuencial y paralela recibieron exactamente los mismos datos deterministas. En todas las configuraciones se verificó que sus checksums fueran iguales. El promedio de las 5 corridas se utilizó para calcular:

```text
Speedup(p) = Ts / Tp
Eficiencia(p) = Speedup(p) / p
Eficiencia (%) = Eficiencia(p) x 100
```

## Multiplicación de matrices

### Tamaño 1024x1024

| Hilos | Tiempo promedio (s) | Speedup | Eficiencia (%) |
|---:|---:|---:|---:|
| Secuencial | 0.607800 | 1.000 | 100.00 |
| 1 | 1.313000 | 0.463 | 46.29 |
| 2 | 0.738400 | 0.823 | 41.16 |
| 4 | 0.447600 | 1.358 | 33.95 |
| 8 | 0.354200 | 1.716 | 21.45 |

### Tamaño 1536x1536

| Hilos | Tiempo promedio (s) | Speedup | Eficiencia (%) |
|---:|---:|---:|---:|
| Secuencial | 1.981800 | 1.000 | 100.00 |
| 1 | 4.190400 | 0.473 | 47.29 |
| 2 | 2.614800 | 0.758 | 37.90 |
| 4 | 1.571200 | 1.261 | 31.53 |
| 8 | 1.251000 | 1.584 | 19.80 |

### Tamaño 2048x2048

| Hilos | Tiempo promedio (s) | Speedup | Eficiencia (%) |
|---:|---:|---:|---:|
| Secuencial | 4.884000 | 1.000 | 100.00 |
| 1 | 12.331800 | 0.396 | 39.60 |
| 2 | 13.356600 | 0.366 | 18.28 |
| 4 | 7.645400 | 0.639 | 15.97 |
| 8 | 6.089600 | 0.802 | 10.03 |

### Interpretación

- En 1024x1024, la mejor configuración fue 8 hilos: redujo el tiempo de 0.607800 s a 0.354200 s y alcanzó un speedup de 1.716.
- En 1536x1536, 8 hilos también fue la mejor configuración: 1.251000 s y speedup de 1.584.
- En 2048x2048, ninguna configuración OpenMP superó a la versión secuencial. La mejor paralela fue la de 8 hilos con 6.089600 s, todavía 1.205600 s más lenta que la secuencial.
- La corrida de matrices 2048x2048 con 1 hilo presentó alta variabilidad: entre 10.218000 s y 19.272000 s, con desviación estándar de 3.888629 s. Esto sugiere interferencia de otros procesos o cambios de frecuencia/temperatura durante esa configuración; por eso se conservaron el CSV crudo y las estadísticas de dispersión.
- La eficiencia cae al aumentar los hilos. El trabajo por bloques agrega más recorrido y control que el ciclo `i-k-j` secuencial, y la presión sobre caché y memoria limita el escalamiento. Los resultados demuestran que paralelizar no garantiza una mejora para todos los tamaños.

## Filtro blur

### Tamaño 3840x2160

| Hilos | Tiempo promedio (s) | Speedup | Eficiencia (%) |
|---:|---:|---:|---:|
| Secuencial | 0.221600 | 1.000 | 100.00 |
| 1 | 0.193600 | 1.145 | 114.46 |
| 2 | 0.099000 | 2.238 | 111.92 |
| 4 | 0.060400 | 3.669 | 91.72 |
| 8 | 0.047000 | 4.715 | 58.94 |

### Tamaño 7680x4320

| Hilos | Tiempo promedio (s) | Speedup | Eficiencia (%) |
|---:|---:|---:|---:|
| Secuencial | 0.707200 | 1.000 | 100.00 |
| 1 | 0.686200 | 1.031 | 103.06 |
| 2 | 0.438000 | 1.615 | 80.73 |
| 4 | 0.223600 | 3.163 | 79.07 |
| 8 | 0.155800 | 4.539 | 56.74 |

### Interpretación

- El blur sí escala de forma clara. En 3840x2160, 8 hilos redujeron el tiempo de 0.221600 s a 0.047000 s, un speedup de 4.715.
- En 8K (7680x4320), 8 hilos redujeron el tiempo de 0.707200 s a 0.155800 s, un speedup de 4.539.
- `schedule(static)` funciona bien porque todas las filas tienen un costo muy parecido y evita el gasto de redistribuir trabajo durante la ejecución.
- Los valores superiores a 100 % de eficiencia con 1 y 2 hilos en 3840x2160 no representan rendimiento ilimitado. Son un efecto de comparar dos binarios distintos en una tarea muy corta, junto con caché, turbo y resolución/variación temporal. Conviene interpretarlos como ruido experimental o mejora de disposición del código, no como escalamiento ideal sostenido.
- Al pasar de 4 a 8 hilos el tiempo sigue bajando, pero la eficiencia desciende a cerca de 57-59 %. La causa probable es que el blur comienza a estar limitado por el ancho de banda de memoria y usa los 8 hilos lógicos sobre solo 4 núcleos físicos.

## Conclusión individual

Los datos apoyan la decisión de paralelizar el filtro blur: divide el trabajo en filas independientes, no requiere sincronización y logró más de 4.5 veces de aceleración con 8 hilos. La multiplicación por bloques obtuvo mejoras moderadas en 1024 y 1536, pero no en 2048 durante estas pruebas. Por lo tanto, la recomendación de consultoría no es simplemente “usar más hilos”: para blur sí conviene OpenMP, mientras que para matrices se debe revisar el tamaño de bloque, el orden de recorrido y las condiciones del equipo antes de elegir la versión paralela.

## Archivos de respaldo

- `benchmark_raw.csv`: las 125 mediciones individuales y sus checksums.
- `benchmark_summary.csv`: promedio, mediana, mínimo, máximo y desviación estándar de cada configuración.
- `benchmark_summary.md`: resumen reproducible del equipo y las métricas.
- `evidencia_corridas.txt`: comandos y salidas de ejecuciones secuenciales/paralelas representativas.
- `graficas/`: curvas de speedup y eficiencia para ambos problemas.
