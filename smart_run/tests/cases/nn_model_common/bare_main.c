/*
 * Generic bare-metal main for CSI-NN2 model tests on C906.
 *
 * Two modes, selected by model_config.h:
 *
 *  - Legacy (no PARAMS_IN_SRAM): weights are baked into the ELF as
 *    model_params[] (test_data.h); float32 input comes from input.pat at
 *    INPUT_BASE_ADDR; success = ran to completion without trapping.
 *
 *  - PARAMS_IN_SRAM (onnx2csinn.py generator): the whole [params|input|golden]
 *    blob is loaded by the testbench into SRAM at PARAMS_BASE_ADDR. csinn_()
 *    reads weights/qinfo through params_base; inputs are pointed directly at the
 *    fp32 INPUTk_ADDR windows; after session_run the outputs are compared
 *    element-wise against the fp32 goldens at OUTPUTk_ADDR (MODEL_VERIFY).
 *    PASS only when every element is within tolerance (and, for a classifier
 *    output, the argmax matches). Otherwise __fail().
 */
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#include <csi_nn.h>
#include <shl_ref.h>
#include <shl_memory.h>

#include "test_data.h"
#include "model_config.h"

/* Provided by model.c (generated / HHB, patched to use CSINN_REF) */
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

/* Minimal UART putchar for best-effort diagnostics (C906 CPU-side UART0 THR).
 * The testbench snoops AXI writes to this address and echoes the byte. */
/* Diagnostics via UART are off by default: crt0 leaves the console region
 * cacheable so byte stores don't reach the bus (nothing prints), and PASS/FAIL
 * is signaled through the GPR magic values instead. Build with -DUART_DBG to
 * emit best-effort markers (tb.v snoops AXI writes to 0x10015000). */
#ifdef UART_DBG
#ifndef UART_ADDR
#define UART_ADDR 0x10015000UL
#endif
static void uputc(char c) { *(volatile uint32_t *)(UART_ADDR) = (uint32_t)(uint8_t)c; }
static void uputs(const char *s) { while (*s) uputc(*s++); }
#else
static void uputc(char c) { (void)c; }
static void uputs(const char *s) { (void)s; }
#endif

static int tensor_elem_count(struct csinn_tensor *t)
{
    int n = 1;
    for (int d = 0; d < t->dim_count; d++)
        n *= t->dim[d];
    return n;
}

#ifdef PARAMS_IN_SRAM
/* ---- SRAM-blob + golden-verification path -------------------------------- */

static const unsigned long in_addrs[]  = MODEL_INPUT_ADDRS;
static const int           in_elems[]  = MODEL_INPUT_ELEMS;
static const unsigned long out_addrs[] = MODEL_OUTPUT_ADDRS;
static const int           out_elems[] = MODEL_OUTPUT_ELEMS;

static float fabsf_(float x) { return x < 0 ? -x : x; }

int main(void)
{
    uputs("[A] main\n");
    install_trap_handler();

#ifndef STOP_STAGE
#define STOP_STAGE 0
#endif
#if STOP_STAGE == 1
    return 0;                    /* probe: PASS reaching main body */
#endif

    struct csinn_session *sess =
        (struct csinn_session *)csinn_((char *)PARAMS_BASE_ADDR);
    if (!sess) { __fail(); return -1; }
    uputs("[B] graph built\n");
#if STOP_STAGE == 2
    return 0;                    /* probe: PASS iff csinn_() build ok */
#endif

    /* Point each input tensor directly at its fp32 window in SRAM. */
    for (int i = 0; i < NUM_BIN_INPUTS; i++) {
        struct csinn_tensor *ref = sess->input[i];
        struct csinn_tensor *t = csinn_alloc_tensor(NULL);
        t->dim_count = ref->dim_count;
        memcpy(t->dim, ref->dim, sizeof(int32_t) * ref->dim_count);
        t->dtype = CSINN_DTYPE_FLOAT32;
        t->layout = ref->layout;
        t->data = (void *)in_addrs[i];
        csinn_update_input(i, t, sess);
    }
    uputs("[C] inputs set\n");
#if STOP_STAGE == 3
    return 0;                    /* probe: PASS iff inputs set ok */
#endif

    csinn_session_run(sess);
    uputs("[D] run done\n");

#if defined(SKIP_VERIFY) || STOP_STAGE == 4
    return 0;   /* run-to-completion smoke: PASS if no trap */
#endif

    /* Compare each output against its golden. */
    int fail = 0;
    for (int k = 0; k < NUM_OUTPUTS; k++) {
        struct csinn_tensor *ot = csinn_alloc_tensor(NULL);
        ot->data = NULL;
        csinn_get_output(k, ot, sess);
        struct csinn_tensor *fo = shl_ref_tensor_transform_f32(ot);
        float *got = (float *)fo->data;
        float *gold = (float *)out_addrs[k];
        int n = out_elems[k];
        float maxabs = 0.0f;
        int bad = 0, gmax_i = 0, omax_i = 0;
        float gmax = gold[0], omax = got[0];
        for (int j = 0; j < n; j++) {
            float d = fabsf_(got[j] - gold[j]);
            float tol = VERIFY_ATOL + VERIFY_RTOL * fabsf_(gold[j]);
            if (d > tol) bad++;
            if (d > maxabs) maxabs = d;
            if (gold[j] > gmax) { gmax = gold[j]; gmax_i = j; }
            if (got[j] > omax) { omax = got[j]; omax_i = j; }
        }
        uputs("[E] out "); uputc('0' + k); uputs(bad ? " MISMATCH\n" : " ok\n");
#ifdef VERIFY_ARGMAX
        if (gmax_i != omax_i) { bad++; uputs("argmax differ\n"); }
        else uputs("argmax ok\n");
#endif
        (void)maxabs;
        if (bad) fail = 1;
        shl_ref_tensor_transform_free_f32(fo);
        if (!ot->is_const && ot->data) shl_mem_free(ot->data);
        csinn_free_tensor(ot);
    }

    csinn_session_deinit(sess);
    csinn_free_session(sess);

    if (fail) { __fail(); return -1; }
    return 0;   /* -> crt0 __exit writes PASS magic */
}

#else
/* ---- Legacy path: weights baked into ELF, run-to-completion = pass -------- */

int main(void)
{
    install_trap_handler();

    struct csinn_session *sess =
        (struct csinn_session *)csinn_((char *)model_params);
    if (!sess) return -1;

    int input_num = sess->input_num;
    float *float_ptr = (float *)INPUT_BASE_ADDR;

    uint8_t **conv_bufs =
        (uint8_t **)malloc(input_num * sizeof(uint8_t *));
    struct csinn_tensor **inputs =
        (struct csinn_tensor **)malloc(input_num * sizeof(void *));

    for (int i = 0; i < input_num; i++) {
        struct csinn_tensor *ref = sess->input[i];
        int elem_count = tensor_elem_count(ref);
        conv_bufs[i] = shl_ref_f32_to_input_dtype(i, float_ptr, sess);
        float_ptr += elem_count;
        inputs[i] = csinn_alloc_tensor(NULL);
        inputs[i]->dim_count = ref->dim_count;
        memcpy(inputs[i]->dim, ref->dim, sizeof(int32_t) * ref->dim_count);
        inputs[i]->data = conv_bufs[i];
        csinn_update_input(i, inputs[i], sess);
    }

    csinn_session_run(sess);

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
#endif
