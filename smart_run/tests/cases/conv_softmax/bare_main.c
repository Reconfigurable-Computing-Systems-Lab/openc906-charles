/* Bare-metal main for conv_softmax model test on C906 */
#include <string.h>
#include <stdint.h>
#include <csi_nn.h>
#include <shl_ref.h>
#include "test_data.h"

void *csinn_(char *params_base);
void csinn_update_input_and_run(struct csinn_tensor **input_tensors, void *sess);

/* Float32 input data loaded by tb.v at this address from input.pat */
#define INPUT_F32_ADDR  0x00080000

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

int main(void)
{
    install_trap_handler();

    /* Build the model graph */
    void *sess = csinn_((char *)model_params);
    if (!sess) return -1;

    /* Quantize float32 input (loaded by tb.v from input.0.bin) to int8 */
    float *input_f32 = (float *)INPUT_F32_ADDR;
    uint8_t *input_q = shl_ref_f32_to_input_dtype(0, input_f32, sess);

    /* Run inference with real input */
    struct csinn_tensor *input_tensor = csinn_alloc_tensor(NULL);
    input_tensor->dim_count = 4;
    input_tensor->dim[0] = 1; input_tensor->dim[1] = 16;
    input_tensor->dim[2] = 28; input_tensor->dim[3] = 28;
    input_tensor->data = input_q;
    struct csinn_tensor *inputs[] = {input_tensor};
    csinn_update_input_and_run(inputs, sess);

    /* Cleanup */
    shl_mem_free(input_q);
    csinn_free_tensor(input_tensor);
    csinn_session_deinit(sess);
    csinn_free_session(sess);
    return 0;
}
