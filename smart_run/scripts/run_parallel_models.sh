#!/bin/bash
# Build a list of model cases serially (they share ./work), snapshot each into an
# isolated run dir, then run all simulations in parallel (one process per case)
# to use all cores. Collects PASS/FAIL per case, and (VCS) one FSDB per segment.
#
# usage: run_parallel_models.sh [--sim verilator|vcs] <MAX_SIM_TIME_ns> <case1> [case2 ...]
#
#   verilator (default): reuses a prior `make compile SIM=verilator DUMP=off`
#                        (standalone work/obj_dir/simv); no FSDB.
#   vcs:                 compiles `make compile SIM=vcs DUMP=on` once, snapshots
#                        simv + simv.daidir per segment, runs with +FSDB=<case>.fsdb,
#                        and collects work_par/results/<case>.fsdb + fsdb_run_list.txt
#                        (core scope by default; each segment its own FSDB, no merge).
set -u
export CODE_BASE_PATH=/Users/jingbo.jiang/Documents/GitHub/openc906-charles/C906_RTL_FACTORY
export TOOL_EXTENSION=$HOME/tools/riscv-wrap
export CONVERT="python3 /Users/jingbo.jiang/Documents/GitHub/openc906-charles/smart_run/tests/bin/srec2vmem.py"
export THEAD_GCC=0
ROOT=/Users/jingbo.jiang/Documents/GitHub/openc906-charles/smart_run
cd "$ROOT"

SIM=verilator
if [ "${1:-}" = "--sim" ]; then SIM="$2"; shift 2; fi
MST=$1; shift
CASES="$@"
RUNROOT="$ROOT/work_par"
rm -rf "$RUNROOT"; mkdir -p "$RUNROOT/results"

# VCS: compile the shared simv once with FSDB dumping enabled.
if [ "$SIM" = "vcs" ]; then
  echo "=== compiling RTL (SIM=vcs DUMP=on) ==="
  make -s compile SIM=vcs DUMP=on || { echo "VCS COMPILE FAILED"; exit 1; }
fi

echo "=== building ${CASES} (SIM=$SIM) ==="
for c in $CASES; do
  make -s buildcase CASE=$c PROBE_CFLAGS="-DNO_UART_DBG" >/dev/null 2>&1 || { echo "BUILD_FAIL $c"; tail -3 work/${c}_build.case.log; continue; }
  d="$RUNROOT/$c"; mkdir -p "$d"
  if [ "$SIM" = "vcs" ]; then
    # VCS simv is not standalone: needs simv.daidir alongside it.
    cp -f work/simv "$d/simv"
    rm -rf "$d/simv.daidir"; cp -R work/simv.daidir "$d/simv.daidir"
  else
    cp -f work/obj_dir/simv "$d/simv"
  fi
  cp work/inst.pat work/data.pat work/input.pat "$d/"
  echo "  built $c ($(wc -l < work/inst.pat) inst words, $(wc -l < work/input.pat) blob words)"
done

echo "=== running in parallel (SIM=$SIM MAX_SIM_TIME=$MST) ==="
for c in $CASES; do
  d="$RUNROOT/$c"; [ -d "$d" ] || continue
  if [ "$SIM" = "vcs" ]; then
    ( cd "$d" && rm -f run_case.report && ./simv +MAX_SIM_TIME=$MST +FSDB=$c.fsdb -l run.vcs.log >sim.log 2>&1; \
      echo "$(cat run_case.report 2>/dev/null || echo NO_REPORT)" > result.txt ) &
  else
    ( cd "$d" && rm -f run_case.report && ./simv +MAX_SIM_TIME=$MST >sim.log 2>&1; \
      echo "$(cat run_case.report 2>/dev/null || echo NO_REPORT)" > result.txt ) &
  fi
done
wait

echo "=== results ==="
pass=0; fail=0
: > "$RUNROOT/results/fsdb_run_list.txt"
for c in $CASES; do
  r=$(cat "$RUNROOT/$c/result.txt" 2>/dev/null)
  t=$(grep -aoE "finish at [0-9]+[a-z]+" "$RUNROOT/$c/sim.log" 2>/dev/null | tail -1)
  printf "  %-24s %s   (%s)\n" "$c" "$r" "$t"
  case "$r" in *PASS*) pass=$((pass+1));; *) fail=$((fail+1));; esac
  if [ "$SIM" = "vcs" ] && [ -f "$RUNROOT/$c/$c.fsdb" ]; then
    cp -f "$RUNROOT/$c/$c.fsdb" "$RUNROOT/results/$c.fsdb"
    echo "$RUNROOT/results/$c.fsdb" >> "$RUNROOT/results/fsdb_run_list.txt"
  fi
done
echo "PASS=$pass FAIL=$fail"
if [ "$SIM" = "vcs" ]; then
  echo "FSDBs + fsdb_run_list.txt in $RUNROOT/results/ (feed to run_ptpx_parallel.py)"
fi
