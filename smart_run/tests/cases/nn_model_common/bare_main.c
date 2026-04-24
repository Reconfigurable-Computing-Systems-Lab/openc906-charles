/*
 * Generic bare-metal main for CSI-NN2 model tests on C906.
 *
 * Works with any HHB-generated model.c by querying the csinn_session
 * at runtime for input count, shapes, and dtypes.  Float32 input data
 * is loaded by the testbench (tb.v) from input.pat at INPUT_BASE_ADDR.
 */
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include <csi_nn.h>
#include <shl_ref.h>
#include <shl_memory.h>

#include "test_data.h"
#include "model_config.h"

/* Provided by model.c (HHB-generated, patched to use CSINN_REF) */
void *csinn_(char *params_base);

extern void __fail(void);

static void __attribute__((naked, aligned(4))) trap_handler(void)
{
    __asm__ volatile(
        ".option push\n"
        ".option norelax\n"
        "la t0, __fail\n"
        "jr t0\n"
        ".option pop\n"
    );
}

static void install_trap_handler(void)
{
    __asm__ volatile("csrw mtvec, %0" :: "r"(trap_handler));
}

static int tensor_elem_count(struct csinn_tensor *t)
{
    int n = 1;
    for (int d = 0; d < t->dim_count; d++)
        n *= t->dim[d];
    return n;
}

int main(void)
{
    install_trap_handler();

    /* Build the compute graph */
    struct csinn_session *sess =
        (struct csinn_session *)csinn_((char *)model_params);
    if (!sess) return -1;

    int input_num = sess->input_num;
    float *float_ptr = (float *)INPUT_BASE_ADDR;

    /* Per-input arrays (freed after session_run) */
    uint8_t **conv_bufs =
        (uint8_t **)malloc(input_num * sizeof(uint8_t *));
    struct csinn_tensor **inputs =
        (struct csinn_tensor **)malloc(input_num * sizeof(void *));

    for (int i = 0; i < input_num; i++) {
        struct csinn_tensor *ref = sess->input[i];
        int elem_count = tensor_elem_count(ref);

        /* Convert float32 data (from testbench memory) to model's dtype */
        conv_bufs[i] = shl_ref_f32_to_input_dtype(i, float_ptr, sess);
        float_ptr += elem_count;

        /* Build an input tensor matching the session's expected shape */
        inputs[i] = csinn_alloc_tensor(NULL);
        inputs[i]->dim_count = ref->dim_count;
        memcpy(inputs[i]->dim, ref->dim, sizeof(int32_t) * ref->dim_count);
        inputs[i]->data = conv_bufs[i];

        csinn_update_input(i, inputs[i], sess);
    }

    /* Execute the graph */
    csinn_session_run(sess);

    /* Cleanup */
    for (int i = 0; i < input_num; i++) {
        shl_mem_free(conv_bufs[i]);
        csinn_free_tensor(inputs[i]);
    }
    free(conv_bufs);
    free(inputs);

    csinn_session_deinit(sess);
    csinn_free_session(sess);
    return 0;
}
