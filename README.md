# ParcialParalelas_1

## Estructura

```text
/secuencial
  matrices_secuencial.c
  blur_secuencial.c
/paralelo
  matrices_paralelo.c
  blur_paralelo.c
/docs
  contexto_y_datos.md
```

## Compilación

Desde la raíz del proyecto:

```bash
gcc -O2 -fopenmp secuencial/matrices_secuencial.c -o matrices_secuencial
gcc -O2 -fopenmp paralelo/matrices_paralelo.c -o matrices_paralelo
gcc -O2 -fopenmp secuencial/blur_secuencial.c -o blur_secuencial
gcc -O2 -fopenmp paralelo/blur_paralelo.c -o blur_paralelo
```

## Pruebas rápidas

### Multiplicación de matrices

```bash
./matrices_secuencial 512
./matrices_paralelo 512 4 32
```

El `Checksum` de ambas ejecuciones debe ser el mismo.

Para pruebas de rendimiento:

```bash
./matrices_secuencial 1024
./matrices_paralelo 1024 2 32
./matrices_paralelo 1024 4 32
./matrices_paralelo 1024 8 32
```

### Blur

```bash
./blur_secuencial 1920 1080
./blur_paralelo 1920 1080 4
```

El `Checksum` de ambas ejecuciones debe ser el mismo.

Para acercarse al caso 8K:

```bash
./blur_secuencial 7680 4320
./blur_paralelo 7680 4320 2
./blur_paralelo 7680 4320 4
./blur_paralelo 7680 4320 8
```

## Qué validar antes de medir

1. La versión secuencial y paralela deben producir el mismo `Checksum` para la misma entrada.
2. Hacer varias corridas de cada configuración y no quedarse con una sola medición.
3. Medir con 1, 2, 4 y 8 hilos si el equipo lo permite.
4. No incluir impresión de matrices o imágenes dentro de la región medida.

## Fórmulas para la siguiente sección

```text
Speedup = tiempo_secuencial / tiempo_paralelo
Eficiencia = speedup / numero_de_hilos
```
