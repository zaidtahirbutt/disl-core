#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include "utils.h"
#include <riscv_vector.h>

#define VECTOR_SIZE 4

int main() {
    // Initialize input vectors
    int32_t a[VECTOR_SIZE] = {1, 2, 3, 4};
    int32_t b[VECTOR_SIZE] = {5, 6, 7, 8};
    int32_t c[VECTOR_SIZE];

    // Set the vector length to VECTOR_SIZE elements
    size_t vl = __riscv_vsetvl_e32m1(VECTOR_SIZE);

    // Load the input vectors into vector registers
    vint32m1_t va = __riscv_vle32_v_i32m1(a, vl);
    vint32m1_t vb = __riscv_vle32_v_i32m1(b, vl);

    // Perform vector addition
    vint32m1_t vc = __riscv_vadd_vv_i32m1(va, vb, vl);

    // Store the result back to memory
    __riscv_vse32_v_i32m1(c, vc, vl);

    // Print the result
    for (size_t i = 0; i < VECTOR_SIZE; i++) {
        printf("c[%d] = %d\n", i, c[i]);
    }

    return 0;
}