#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <omp.h>

static int minimo(int a, int b) {
    return a < b ? a : b;
}

static int maximo(int a, int b) {
    return a > b ? a : b;
}

static void llenar_imagen(unsigned char *imagen, int ancho, int alto) {
    for (int i = 0; i < alto; ++i) {
        for (int j = 0; j < ancho; ++j) {
            unsigned int valor = (unsigned int)(i * 13u + j * 7u + (i ^ j));
            imagen[(size_t)i * ancho + j] = (unsigned char)(valor & 255u);
        }
    }
}

static uint64_t checksum(const unsigned char *imagen, int ancho, int alto) {
    uint64_t suma = 0;
    size_t total = (size_t)ancho * (size_t)alto;
    for (size_t idx = 0; idx < total; ++idx) {
        suma += imagen[idx];
    }
    return suma;
}

int main(int argc, char **argv) {
    int ancho = 1920;
    int alto = 1080;
    int hilos = 4;

    if (argc >= 2) ancho = atoi(argv[1]);
    if (argc >= 3) alto = atoi(argv[2]);
    if (argc >= 4) hilos = atoi(argv[3]);

    if (ancho <= 0 || alto <= 0 || hilos <= 0) {
        fprintf(stderr, "Uso: %s <ancho> <alto> <hilos>\n", argv[0]);
        return 1;
    }

    size_t total = (size_t)ancho * (size_t)alto;
    unsigned char *entrada = (unsigned char *)malloc(total);
    unsigned char *salida = (unsigned char *)malloc(total);

    if (entrada == NULL || salida == NULL) {
        fprintf(stderr, "No fue posible reservar memoria para una imagen de %d x %d.\n", ancho, alto);
        free(entrada);
        free(salida);
        return 1;
    }

    llenar_imagen(entrada, ancho, alto);

    omp_set_dynamic(0);
    omp_set_num_threads(hilos);

    double inicio = omp_get_wtime();

    /*
     * Las filas de salida se reparten de forma estatica.
     * Cada hilo escribe filas distintas de 'salida'.
     * Para una fila en el limite de su bloque puede leer i-1 o i+1 de 'entrada'.
     * Esa fila vecina funciona como un halo logico y es segura porque entrada es solo lectura.
     */
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < alto; ++i) {
        int r0 = maximo(0, i - 1);
        int r1 = minimo(alto - 1, i + 1);

        int suma = 0;
        int contador = 0;

        int c_fin_inicial = minimo(ancho - 1, 1);
        for (int r = r0; r <= r1; ++r) {
            for (int c = 0; c <= c_fin_inicial; ++c) {
                suma += entrada[(size_t)r * ancho + c];
                ++contador;
            }
        }

        for (int j = 0; j < ancho; ++j) {
            if (j > 0) {
                int columna_sale = j - 2;
                int columna_entra = j + 1;

                if (columna_sale >= 0) {
                    for (int r = r0; r <= r1; ++r) {
                        suma -= entrada[(size_t)r * ancho + columna_sale];
                        --contador;
                    }
                }

                if (columna_entra < ancho) {
                    for (int r = r0; r <= r1; ++r) {
                        suma += entrada[(size_t)r * ancho + columna_entra];
                        ++contador;
                    }
                }
            }

            salida[(size_t)i * ancho + j] = (unsigned char)(suma / contador);
        }
    }

    double fin = omp_get_wtime();

    printf("Blur paralelo con ventana deslizante\n");
    printf("Imagen: %d x %d\n", ancho, alto);
    printf("Hilos: %d\n", hilos);
    printf("Tiempo: %.6f s\n", fin - inicio);
    printf("Checksum: %llu\n", (unsigned long long)checksum(salida, ancho, alto));

    free(entrada);
    free(salida);
    return 0;
}
