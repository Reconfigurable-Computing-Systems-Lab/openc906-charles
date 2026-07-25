/* _sbrk implementation for bare-metal newlib heap support.
 *
 * When the linker script defines a dedicated high-SRAM heap window
 * (__heap_start/__heap_end, see linker_model.lcf) the heap lives there — needed
 * for CSI-NN2 model activations that far exceed the ~700 KB between 'end' and
 * the stack. Otherwise it falls back to growing from 'end' (legacy behavior).
 */
extern char end[];
extern char __heap_start __attribute__((weak));
extern char __heap_end __attribute__((weak));

static char *heap_ptr = 0;

void *_sbrk(int incr)
{
    if (heap_ptr == 0)
        heap_ptr = (&__heap_start != 0) ? &__heap_start : end;
    char *limit = (&__heap_end != 0) ? &__heap_end : (char *)0xee000;
    if (heap_ptr + incr > limit)
        return (void *)-1;          /* ENOMEM */
    char *prev = heap_ptr;
    heap_ptr += incr;
    return prev;
}

/* Stub: C906-optimized backend init is unavailable without RVV intrinsics. */
void shl_target_init_c906(void) {}

/* Stubs for trace functions not compiled when SHL_TRACE is off,
 * but still referenced directly (not via SHL_TRACE_CALL) in graph_ref/setup.c */
struct shl_trace;
void shl_trace_move_events(struct shl_trace *from, struct shl_trace *to) {}

/*
 * Override shl_get_runtime_callback to bypass a hang caused by tail-calling
 * through the callback table in RTL simulation.
 */
#include <csinn/csinn_data_structure.h>
extern void *shl_gref_runtime_callback(int op);

void *shl_get_runtime_callback(struct csinn_session *sess, int op)
{
    if ((sess->base_run_mode == CSINN_RM_CPU_GRAPH && sess->base_api == CSINN_REF) ||
        sess->base_run_mode == CSINN_RM_CPU_BASE_HYBRID) {
        return shl_gref_runtime_callback(op);
    }
    return ((void *)0);
}
