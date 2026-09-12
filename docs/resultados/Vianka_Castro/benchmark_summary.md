# Resumen de Benchmark

## Informacion del equipo

- Integrante: Vianka Castro
- Fecha/hora: 2026-09-11 21:13:51
- Procesador: 11th Gen Intel(R) Core(TM) i7-1165G7 @ 2.80GHz
- Nucleos fisicos: 4
- Procesadores logicos: 8
- GCC: gcc.exe (Rev6, Built by MSYS2 project) 16.1.0
- Sistema operativo: Microsoft Windows 11 Pro 10.0.26200

## Matrices

| Tamano | Hilos | Tiempo secuencial (s) | Tiempo promedio (s) | Speedup | Eficiencia % |
|---|---:|---:|---:|---:|---:|
| 1024x1024 | 1 | 0.664600 | 1.860600 | 0.357197 | 35.72 |
| 1024x1024 | 2 | 0.664600 | 0.947400 | 0.701499 | 35.07 |
| 1024x1024 | 4 | 0.664600 | 0.906000 | 0.733554 | 18.34 |
| 1024x1024 | 8 | 0.664600 | 0.512400 | 1.297034 | 16.21 |
| 1536x1536 | 1 | 3.236200 | 6.223000 | 0.520039 | 52.00 |
| 1536x1536 | 2 | 3.236200 | 2.855400 | 1.133361 | 56.67 |
| 1536x1536 | 4 | 3.236200 | 2.336600 | 1.385004 | 34.63 |
| 1536x1536 | 8 | 3.236200 | 1.438400 | 2.249861 | 28.12 |
| 2048x2048 | 1 | 7.723000 | 13.113200 | 0.588949 | 58.89 |
| 2048x2048 | 2 | 7.723000 | 5.851200 | 1.319900 | 66.00 |
| 2048x2048 | 4 | 7.723000 | 3.670800 | 2.103901 | 52.60 |
| 2048x2048 | 8 | 7.723000 | 2.730000 | 2.828938 | 35.36 |

### Evidencia visual de matrices

Las capturas siguientes documentan las corridas medidas de los tres tamaños de matriz y la validación automática de sus checksums.

![Inicio del benchmark de matrices 1024x1024: corridas secuenciales y OpenMP con un hilo](<screenshots/image.png>)

![Cierre de matrices 1024x1024 con checksum correcto e inicio de matrices 1536x1536](<screenshots/image copy.png>)

![Cierre de matrices 1536x1536 con checksum correcto e inicio de matrices 2048x2048](<screenshots/image copy 2.png>)

## Blur

| Tamano | Hilos | Tiempo secuencial (s) | Tiempo promedio (s) | Speedup | Eficiencia % |
|---|---:|---:|---:|---:|---:|
| 3840x2160 | 1 | 0.080200 | 0.078200 | 1.025575 | 102.56 |
| 3840x2160 | 2 | 0.080200 | 0.053000 | 1.513208 | 75.66 |
| 3840x2160 | 4 | 0.080200 | 0.048800 | 1.643443 | 41.09 |
| 3840x2160 | 8 | 0.080200 | 0.022800 | 3.517544 | 43.97 |
| 7680x4320 | 1 | 0.229400 | 0.420600 | 0.545411 | 54.54 |
| 7680x4320 | 2 | 0.229400 | 0.257800 | 0.889837 | 44.49 |
| 7680x4320 | 4 | 0.229400 | 0.143400 | 1.599721 | 39.99 |
| 7680x4320 | 8 | 0.229400 | 0.091200 | 2.515351 | 31.44 |

### Evidencia visual de blur

Estas capturas muestran el cierre de las pruebas 4K y 8K, incluyendo la confirmación `Checksum: OK` de las versiones secuencial y OpenMP.

![Cierre del blur 3840x2160 con checksum correcto e inicio de las pruebas 7680x4320](<screenshots/image copy 3.png>)

![Corridas OpenMP de blur 7680x4320 con cuatro y ocho hilos y checksum correcto](<screenshots/image copy 4.png>)
