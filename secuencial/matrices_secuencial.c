#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <omp.h>

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

    if (argc >= 2) {
        n = atoi(argv[1]);
    }

    if (n <= 0) {
        fprintf(stderr, "El tamano de la matriz debe ser mayor que 0.\n");
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

    double inicio = omp_get_wtime();

    /*
     * Recorrido i-k-j.
     * A[i][k] se lee una vez y se reutiliza para actualizar toda la fila i de C.
     * Ademas, B[k][j] se recorre por filas, que son contiguas en memoria.
     */
    for (int i = 0; i < n; ++i) {
        int *fila_c = &C[(size_t)i * n];
        const int *fila_a = &A[(size_t)i * n];

        for (int k = 0; k < n; ++k) {
            int valor_a = fila_a[k];
            const int *fila_b = &B[(size_t)k * n];

            for (int j = 0; j < n; ++j) {
                fila_c[j] += valor_a * fila_b[j];
            }
        }
    }

    double fin = omp_get_wtime();

    printf("Multiplicacion secuencial\n");
    printf("Tamano: %d x %d\n", n, n);
    printf("Tiempo: %.6f s\n", fin - inicio);
    printf("Checksum: %llu\n", (unsigned long long)checksum(C, n));

    free(A);
    free(B);
    free(C);
    return 0;
}
