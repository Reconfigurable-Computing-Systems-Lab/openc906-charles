/* Bare-metal main for conv_softmax model test on C906 */
#include <string.h>
#include <csi_nn.h>
#include "test_data.h"

void *csinn_(char *params_base);
void csinn_update_input_and_run(struct csinn_tensor **input_tensors, void *sess);

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

    /* Run inference with dummy input */
    struct csinn_tensor *input_tensor = csinn_alloc_tensor(NULL);
    input_tensor->dim_count = 4;
    input_tensor->dim[0] = 1; input_tensor->dim[1] = 16;
    input_tensor->dim[2] = 28; input_tensor->dim[3] = 28;
    input_tensor->data = (void *)input_data;
    struct csinn_tensor *inputs[] = {input_tensor};
    csinn_update_input_and_run(inputs, sess);

    /* Cleanup */
    csinn_free_tensor(input_tensor);
    csinn_session_deinit(sess);
    csinn_free_session(sess);
    return 0;
}
