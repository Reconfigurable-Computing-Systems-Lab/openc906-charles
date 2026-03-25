/* _sbrk implementation for bare-metal newlib heap support.
 * Heap grows from 'end' (linker-defined end of BSS) toward the stack. */
extern char end[];

static char *heap_ptr = 0;

void *_sbrk(int incr)
{
    if (heap_ptr == 0)
        heap_ptr = end;
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
