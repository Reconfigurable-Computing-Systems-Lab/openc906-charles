/*
 * idu_random: group table and operand pools.
 *
 * Split out of C906_IDU_RANDOM.c so that run_groups.sh's NAMES[] array and the
 * end-of-run report cannot drift apart: both are derived from the one list
 * below. If you add a group, add it here, in the dispatcher, and in
 * run_groups.sh -- in that order.
 *
 * Groups 0..31 are the main rotation (`r % IDU_NGROUPS`). Groups 32..45 are the
 * expensive / fragile ones and ride a second, sparser selector
 * (`(r >> 32) % 64`, cases 0..13) so they neither dilute the main rotation nor
 * dominate the run time. -DIDU_ONLY_GROUP=n reaches any of the 46 directly.
 */

#ifndef IDU_DEFS_H
#define IDU_DEFS_H

#include "rand_common.h"

#define IDU_NGROUPS        32u   /* main rotation: 0 .. 31   */
#define IDU_NGROUPS_TOTAL  46u   /* plus the 14 sparse ones  */
#define IDU_NSPARSE        14u

/* Printed by report() for every group that was actually visited. Keeping the
 * names in the image costs ~700 bytes of .rodata and buys a report that can be
 * read without cross-referencing the source. */
static const char *const idu_group_names[IDU_NGROUPS_TOTAL] = {
    /*  0 */ "rvc_table",
    /*  1 */ "base32_alu",
    /*  2 */ "base32_ls_sys",
    /*  3 */ "fp_table_sd",
    /*  4 */ "fp_table_h",
    /*  5 */ "fma_table",
    /*  6 */ "fp_rm",
    /*  7 */ "fs_zero",
    /*  8 */ "cache_sync_table",
    /*  9 */ "theadisaee_off",
    /* 10 */ "xtheadc_alu",
    /* 11 */ "xtheadc_bits",
    /* 12 */ "xtheadc_mac",
    /* 13 */ "xtheadc_lr",
    /* 14 */ "xtheadc_idxupd",
    /* 15 */ "xtheadc_stores",
    /* 16 */ "xtheadc_fp",
    /* 17 */ "rvv_illegal",
    /* 18 */ "lsd_split",
    /* 19 */ "lsd_interrupted",
    /* 20 */ "amo_matrix",
    /* 21 */ "che_split",
    /* 22 */ "fnc_split",
    /* 23 */ "imm_src1_sweep",
    /* 24 */ "imm_src2_sweep",
    /* 25 */ "regidx_sweep",
    /* 26 */ "illegal_reserved",
    /* 27 */ "illegal_xtheadc",
    /* 28 */ "c_illegal",
    /* 29 */ "priv_cacheops",
    /* 30 */ "raw_alu_bju",
    /* 31 */ "raw_load_condbr",
    /* 32 */ "raw_fwd_bus",
    /* 33 */ "raw_src2_store",
    /* 34 */ "waw_cnt2",
    /* 35 */ "waw_dst1",
    /* 36 */ "wb_same_reg",
    /* 37 */ "late_forward",
    /* 38 */ "fp_dep_stall",
    /* 39 */ "expt_priority",
    /* 40 */ "expt_override_cp0",
    /* 41 */ "ex1_eu_full",
    /* 42 */ "pipe_sel_cross",
    /* 43 */ "dis_stall_compose",
    /* 44 */ "hpcp_class",
    /* 45 */ "zvamo_negative"
};

/* ==================================================================== *
 * Integer operand pool.
 *
 * The decoder does not look at operand *data*, but the units it dispatches to
 * do, and a stalled EU is what most of the interlock groups need: a `div` by a
 * value that makes the divider run long, a shift count in the 0..63 wrap
 * region, a `mulh` with both operands negative. So the pool is the usual
 * corner set rather than uniform random -- and it costs one AND instead of a
 * multiply to index.
 * ==================================================================== */
#define IDU_NPOOL 16u
static const u64 idu_pool[IDU_NPOOL] = {
    0x0000000000000000UL,
    0x0000000000000001UL,
    0xFFFFFFFFFFFFFFFFUL,
    0x8000000000000000UL,
    0x7FFFFFFFFFFFFFFFUL,
    0x00000000FFFFFFFFUL,
    0xFFFFFFFF00000000UL,
    0x0000000080000000UL,
    0x5555555555555555UL,
    0xAAAAAAAAAAAAAAAAUL,
    0x0123456789ABCDEFUL,
    0xFEDCBA9876543210UL,
    0x000000000000FFFFUL,
    0x0000FFFF00000000UL,
    0x000000000000003FUL,
    0x0000000000000041UL
};

#define IDU_POOL(r)  (idu_pool[(unsigned)(r) & (IDU_NPOOL - 1u)])

/* ==================================================================== *
 * FP bit-pattern pool. Fed to the FP units through fmv.d.x, so no .rodata
 * constant pool and no FP load is needed to set an operand up. NaN, infinity
 * and subnormals are in here because they change how long the FALU/FDIV take,
 * which is what the dependency-stall groups are really after.
 * ==================================================================== */
#define IDU_NFPOOL 8u
static const u64 idu_fpool[IDU_NFPOOL] = {
    0x3FF0000000000000UL,   /* +1.0                  */
    0xBFF8000000000000UL,   /* -1.5                  */
    0x0000000000000000UL,   /* +0.0                  */
    0x7FF0000000000000UL,   /* +inf                  */
    0x7FF8000000000000UL,   /* qNaN                  */
    0x0008000000000000UL,   /* subnormal             */
    0x4093480000000000UL,   /* 1234.0                */
    0xC1B1DE6A00000000UL    /* a large odd magnitude */
};

#define IDU_FPOOL(r) (idu_fpool[(unsigned)(r) & (IDU_NFPOOL - 1u)])

/* ==================================================================== *
 * Safe data targets.
 *
 * rand_scratch[128] is 1 KB of .bss inside the window tb.v wipes and loads, so
 * it is the only place the stimulus is allowed to store. Every address handed
 * to a load, a store, an AMO or a cache-maintenance op is derived from these
 * two helpers, and both are clamped so that an index-update or register-indexed
 * form cannot walk off the end: the Xtheadc forms add up to +/-120 bytes to the
 * base, and rand_scratch[32] .. rand_scratch[95] leaves 256 bytes of headroom
 * on both sides.
 * ==================================================================== */
#define IDU_SCRATCH_LO   32u
#define IDU_SCRATCH_SPAN 64u

/* Any 8-byte-aligned slot with >= 256 bytes of slack either side. */
#define IDU_PTR(r) \
    ((u64)(unsigned long)&rand_scratch[IDU_SCRATCH_LO + \
                                       ((unsigned)(r) % IDU_SCRATCH_SPAN)])

/* Same, but 64-byte (cache-line) aligned: what the AMO and cache-maintenance
 * groups want so that a .d access is naturally aligned and a line op covers a
 * predictable range. */
#define IDU_PTR_LINE(r) \
    ((u64)(unsigned long)&rand_scratch[IDU_SCRATCH_LO + \
                                       8u * ((unsigned)(r) % 8u)])

#endif /* IDU_DEFS_H */
