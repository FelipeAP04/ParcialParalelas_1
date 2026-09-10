#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <omp.h>

static int minimo(int a, int b) {
    return a < b ? a : b;
}

static void llenar_matrices(int *A, int *B, int n) {
    size_t total = (size_t)n * (size_t)n;
    for (size_t idx = 0; idx < total; ++idx) {
        A[idx] = (int)((idx * 17u + 13u) % 10u);
        B[idx] = (int)((idx * 29u + 7u) % 10u);
    }
}

static uint64_t checksum(const int *C, int n) {
    uint64_t suma = 0;
    size_t total = (size_t)n * (size_t)n;
    for (size_t idx = 0; idx < total; ++idx) {
        suma += (uint64_t)C[idx];
    }
    return suma;
}

int main(int argc, char **argv) {
    int n = 1024;
    int hilos = 4;
    int bloque = 32;

    if (argc >= 2) n = atoi(argv[1]);
    if (argc >= 3) hilos = atoi(argv[2]);
    if (argc >= 4) bloque = atoi(argv[3]);

    if (n <= 0 || hilos <= 0 || bloque <= 0) {
        fprintf(stderr, "Uso: %s <tamano> <hilos> [bloque]\n", argv[0]);
        return 1;
    }

    size_t total = (size_t)n * (size_t)n;
    size_t bytes = total * sizeof(int);

    int *A = (int *)malloc(bytes);
    int *B = (int *)malloc(bytes);
    int *C = (int *)calloc(total, sizeof(int));

    if (A == NULL || B == NULL || C == NULL) {
        fprintf(stderr, "No fue posible reservar memoria para matrices de %d x %d.\n", n, n);
        free(A);
        free(B);
        free(C);
        return 1;
    }

    llenar_matrices(A, B, n);

    omp_set_dynamic(0);
    omp_set_num_threads(hilos);

    int bloques = (n + bloque - 1) / bloque;

    double inicio = omp_get_wtime();

    /*
     * Cada iteracion (bi, bj) representa un bloque exclusivo de C.
     * Por eso dos hilos nunca escriben la misma celda de C.
     * El tercer indice bk recorre los bloques necesarios de A y B.
     */
    #pragma omp parallel for collapse(2) schedule(static)
    for (int bi = 0; bi < bloques; ++bi) {
        for (int bj = 0; bj < bloques; ++bj) {
            int i_inicio = bi * bloque;
            int j_inicio = bj * bloque;
            int i_fin = minimo(i_inicio + bloque, n);
            int j_fin = minimo(j_inicio + bloque, n);

            for (int bk = 0; bk < bloques; ++bk) {
                int k_inicio = bk * bloque;
                int k_fin = minimo(k_inicio + bloque, n);

                for (int i = i_inicio; i < i_fin; ++i) {
                    int *fila_c = &C[(size_t)i * n];
                    const int *fila_a = &A[(size_t)i * n];

                    for (int k = k_inicio; k < k_fin; ++k) {
                        int valor_a = fila_a[k];
                        const int *fila_b = &B[(size_t)k * n];

                        for (int j = j_inicio; j < j_fin; ++j) {
                            fila_c[j] += valor_a * fila_b[j];
                        }
                    }
                }
            }
        }
    }

    double fin = omp_get_wtime();

    printf("Multiplicacion paralela por bloques\n");
    printf("Tamano: %d x %d\n", n, n);
    printf("Hilos: %d\n", hilos);
    printf("Bloque: %d x %d\n", bloque, bloque);
    printf("Tiempo: %.6f s\n", fin - inicio);
    printf("Checksum: %llu\n", (unsigned long long)checksum(C, n));

    free(A);
    free(B);
    free(C);
    return 0;
}
