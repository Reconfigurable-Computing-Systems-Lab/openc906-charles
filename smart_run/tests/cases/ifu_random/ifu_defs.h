/*
 * Case-local defines for ifu_random. Knob defaults, the group taxonomy, and the
 * handful of helpers that only this case wants.
 *
 * Everything genuinely shared with iu_random / vidu_random / idu_random lives in
 * tests/cases/rand_common/ instead; nothing here duplicates it.
 *
 * Knobs (setup/smart_cfg.mk):
 *   IFU_ITERS       dispatch-loop iterations.               default 10000
 *   IFU_SEED        xorshift64 seed for the DATA sequence.  default 0x2024C906
 *   IFU_ARENA_SEED  seed for the CODE LAYOUT -- a new value produces a
 *                   different program, not just different data. Consumed by
 *                   gen_ifu_arena.py at build time, not by this file.
 *   IFU_ARENA_BASE  where linker_ifu.lcf pins .text.arena.  default 0x8000
 *   IFU_ARENA_SIZE  byte budget for the arena.              default 0x30000
 *   IFU_OPT         optimisation level: changes the compiler's instruction
 *                   selection, i.e. changes the *decode stream* for free.
 *   IFU_EXTRA       extra -D flags. The ones this file understands:
 *                     -DIFU_ONLY_GROUP=n  run just group n (run_groups.sh)
 *                     -DIFU_MMU           enable group 19 (Sv39 instruction
 *                                         fetch). Off by default: it needs the
 *                                         full S-mode + page-table apparatus
 *                                         and can burn the run.
 *                     -DIFU_MMU_FAULT     with IFU_MMU, additionally provoke a
 *                                         real instruction page fault. This one
 *                                         WILL usually cost the run; it exists
 *                                         so the cause-12 path can be proven
 *                                         once by hand.
 *                     -DIFU_JIT           enable group 41 (runtime code
 *                                         generation into .text.jit). Off by
 *                                         default: the same IFU coverage is
 *                                         available more safely by re-running
 *                                         generated code after th.icache.iall.
 */

#ifndef IFU_DEFS_H
#define IFU_DEFS_H

#ifndef IFU_ITERS
#define IFU_ITERS 10000
#endif
#ifndef IFU_SEED
#define IFU_SEED 0x2024C906
#endif

/* Groups 0..NGROUPS-1 are the main rotation; NGROUPS..NGROUPS_TOTAL-1 ride the
 * sparse second selector. The split follows doc/specs' group taxonomy exactly,
 * so a group index here means the same thing as in the coverage table. */
#define NGROUPS       32
#define NGROUPS_TOTAL 42

/* Two groups sit in the main rotation because that is where the taxonomy puts
 * them, but are far too expensive or too destructive to run on every visit:
 *
 *   group 2  high_pc  a jalr to an address with VA bit 39 set. The fetch there
 *                     always faults, so every visit costs a trap and an
 *                     excursion unwind.
 *   group 8  walk     a 48 KB straight-line sled: ~25k retired instructions
 *                     and 768 line refills, i.e. two orders of magnitude more
 *                     simulated time than any other group.
 *
 * Both therefore gate on their own sub-selector and keep their own counter, so
 * the report shows how often they actually fired rather than how often they
 * were selected.
 */
#define IFU_HIGHPC_1_IN  8u
#define IFU_WALK_1_IN    32u

/* mhint / mhcr bits this case toggles, named for readability at the call site.
 * Provenance is rand_csrs.h; repeated here only as a reminder of which IFU
 * structure each one gates:
 *   MHCR_IE    (0)  I-cache enable          -> icache_refill_ca, arlen/arburst
 *   MHCR_RSE   (4)  RAS enable              -> pred_ras_tar, pred_ras_link_vld
 *   MHCR_BPE   (5)  BHT enable              -> bht_cen
 *   MHCR_BTBE  (6)  BTB enable              -> btb update / clear / predict
 *   MHINT_IPREF_EN (8)  I-cache next-line prefetch -> the 8-state pf FSM
 *   MHINT_IWPE    (10)  I-cache way predict       -> the tag-hit buffer
 *   MCOR_BHT_INV  (16)  one-shot BHT invalidate (1024 rows)
 *   MCOR_BTB_INV  (17)  one-shot BTB invalidate (all 16 entries)
 */
#define IFU_FE_MHCR_BITS  (MHCR_IE | MHCR_RSE | MHCR_BPE | MHCR_BTBE)
#define IFU_FE_MHINT_BITS (MHINT_IPREF_EN | MHINT_IWPE)

/* Pull one field out of the single rand_rnd() word that drives a whole
 * iteration. Keeping every group's sub-case selection inside one word is what
 * makes -DIFU_ONLY_GROUP=n reproduce the same sub-case sequence as the full
 * run. */
#define IFU_SEL(r, sh, n) ((unsigned)(((u64)(r) >> (sh)) % (u64)(n)))
#define IFU_BIT(r, sh)    ((unsigned)(((u64)(r) >> (sh)) & 1u))

#endif /* IFU_DEFS_H */
