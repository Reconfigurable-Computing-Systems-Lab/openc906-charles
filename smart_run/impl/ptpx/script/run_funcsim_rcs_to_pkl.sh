#!/usr/bin/env bash
set -euo pipefail

# Convert func-sim FSDBs listed in ptpx_summary.csv for every rc file under
# ../rc/{idu,ifu}, then convert each generated CSV directory to pickle files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PTPX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PYTHON_BIN="${PYTHON_BIN:-${HOME}/anaconda3/bin/python}"
SUMMARY_CSV="${SUMMARY_CSV:-${PTPX_DIR}/ptpx_summary.csv}"
RC_ROOT="${RC_ROOT:-${PTPX_DIR}/rc}"
OUT_ROOT="${OUT_ROOT:-${PTPX_DIR}/presim_db}"
CLK_PERIOD="${CLK_PERIOD:-1}"
DOWNSAMPLE="${DOWNSAMPLE:-10}"
PROCESSES="${PROCESSES:-8}"

START_ARG=()
END_ARG=()
ONLY_JOB_ARG=()
INCLUDE_FAILED_ARG=()

usage() {
    cat <<'EOF'
Usage: run_funcsim_rcs_to_pkl.sh [options]

Run fsdb_to_csv.py followed by csv_to_pkl.py for every *.rc in:
  ../rc/idu
  ../rc/ifu

Options:
  --summary-csv PATH   ptpx summary CSV (default: ../ptpx_summary.csv)
  --rc-root DIR        rc root containing idu/ and ifu/ (default: ../rc)
  --out-root DIR       output root (default: ../presim_db)
  --clk-period N       clock period in ns (default: 1)
  --downsample N       downsample factor (default: 10)
  --processes N        worker processes for both steps (default: 8)
  --python PATH        Python executable (default: ~/anaconda3/bin/python)
  --start N            optional start time in ns passed to fsdb_to_csv.py
  --end N              optional end time in ns passed to fsdb_to_csv.py
  --only-job NAME      optional single Job from ptpx_summary.csv
  --include-failed     also process rows whose Status != COMPLETED
  -h, --help           show this help

Environment variables with the same uppercase names can also override defaults.
Each rc writes to:
  <out-root>/<idu|ifu>/<rc-basename>/
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary-csv)
            SUMMARY_CSV="$2"
            shift 2
            ;;
        --rc-root)
            RC_ROOT="$2"
            shift 2
            ;;
        --out-root)
            OUT_ROOT="$2"
            shift 2
            ;;
        --clk-period)
            CLK_PERIOD="$2"
            shift 2
            ;;
        --downsample)
            DOWNSAMPLE="$2"
            shift 2
            ;;
        --processes)
            PROCESSES="$2"
            shift 2
            ;;
        --python)
            PYTHON_BIN="$2"
            shift 2
            ;;
        --start)
            START_ARG=(--start "$2")
            shift 2
            ;;
        --end)
            END_ARG=(--end "$2")
            shift 2
            ;;
        --only-job)
            ONLY_JOB_ARG=(--only-job "$2")
            shift 2
            ;;
        --include-failed)
            INCLUDE_FAILED_ARG=(--include-failed)
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "${SUMMARY_CSV}" ]]; then
    echo "error: summary CSV not found: ${SUMMARY_CSV}" >&2
    exit 1
fi
if [[ ! -d "${RC_ROOT}/idu" || ! -d "${RC_ROOT}/ifu" ]]; then
    echo "error: expected rc directories under ${RC_ROOT}/{idu,ifu}" >&2
    exit 1
fi

shopt -s nullglob
rc_files=("${RC_ROOT}/idu/"*.rc "${RC_ROOT}/ifu/"*.rc)
shopt -u nullglob

if [[ ${#rc_files[@]} -eq 0 ]]; then
    echo "error: no rc files found under ${RC_ROOT}/{idu,ifu}" >&2
    exit 1
fi

echo "summary_csv=${SUMMARY_CSV}"
echo "rc_root=${RC_ROOT}"
echo "out_root=${OUT_ROOT}"
echo "clk_period=${CLK_PERIOD}, downsample=${DOWNSAMPLE}, processes=${PROCESSES}"
echo "rc files: ${#rc_files[@]}"

for rc_path in "${rc_files[@]}"; do
    group="$(basename "$(dirname "${rc_path}")")"
    rc_base="$(basename "${rc_path}" .rc)"
    out_dir="${OUT_ROOT}/${group}/${rc_base}"

    echo
    echo "==> ${group}/${rc_base}: fsdb_to_csv"
    "${PYTHON_BIN}" "${SCRIPT_DIR}/fsdb_to_csv.py" \
        --summary-csv "${SUMMARY_CSV}" \
        --clk-period "${CLK_PERIOD}" \
        --downsample "${DOWNSAMPLE}" \
        --func-rc "${rc_path}" \
        --mode func-sim \
        --processes "${PROCESSES}" \
        --out-dir "${out_dir}" \
        "${START_ARG[@]}" \
        "${END_ARG[@]}" \
        "${ONLY_JOB_ARG[@]}" \
        "${INCLUDE_FAILED_ARG[@]}"

    echo "==> ${group}/${rc_base}: csv_to_pkl"
    "${PYTHON_BIN}" "${SCRIPT_DIR}/csv_to_pkl.py" \
        --indir "${out_dir}/_csv" \
        --downsample "${DOWNSAMPLE}" \
        --processes "${PROCESSES}" \
        --out-dir "${out_dir}" \
        --rm-prefix
done

echo
echo "done: outputs written under ${OUT_ROOT}"
