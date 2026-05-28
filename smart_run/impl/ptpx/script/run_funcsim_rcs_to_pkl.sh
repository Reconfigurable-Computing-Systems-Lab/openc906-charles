#!/usr/bin/env bash
set -euo pipefail

# Convert func-sim FSDBs listed in ptpx_summary.csv for every rc file under
# ../rc, then convert each generated CSV directory to pickle files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PTPX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PYTHON_BIN="${PYTHON_BIN:-${HOME}/anaconda3/bin/python}"
SUMMARY_CSV="${SUMMARY_CSV:-${PTPX_DIR}/ptpx_summary.csv}"
RC_ROOT="${RC_ROOT:-${PTPX_DIR}/rc}"
OUT_ROOT="${OUT_ROOT:-${PTPX_DIR}/presim_db}"
CLK_PERIOD="${CLK_PERIOD:-1}"
DOWNSAMPLE="${DOWNSAMPLE:-10}"
PROCESSES="${PROCESSES:-8}"
RM_CSV=0

START_ARG=()
END_ARG=()
ONLY_JOB_ARG=()
INCLUDE_FAILED_ARG=()

usage() {
    cat <<'EOF'
Usage: run_funcsim_rcs_to_pkl.sh [options]

Run fsdb_to_csv.py followed by csv_to_pkl.py for every *.rc under:
  ../rc

Example Use:
    cd /dfs/usrhome/jjiangan/github/openc906-charles-imp/smart_run/impl/ptpx/script
    ./run_funcsim_rcs_to_pkl.sh --out-root /dfs/grphome/eeweiz/jjiangan --rm-csv

Options:
  --summary-csv PATH   ptpx summary CSV (default: ../ptpx_summary.csv)
  --rc-root DIR        rc root to search recursively (default: ../rc)
  --out-root DIR       output root (default: ../presim_db)
  --clk-period N       clock period in ns (default: 1)
  --downsample N       downsample factor (default: 10)
  --processes N        worker processes for both steps (default: 8)
  --python PATH        Python executable (default: ~/anaconda3/bin/python)
  --start N            optional start time in ns passed to fsdb_to_csv.py
  --end N              optional end time in ns passed to fsdb_to_csv.py
  --only-job NAME      optional single Job from ptpx_summary.csv
  --include-failed     also process rows whose Status != COMPLETED
  --rm-csv             remove generated CSV files after pickle conversion
  -h, --help           show this help

Environment variables with the same uppercase names can also override defaults.
Each rc writes to:
  <out-root>/<relative-rc-path-without-.rc>/
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
        --rm-csv)
            RM_CSV=1
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
RC_ROOT="${RC_ROOT%/}"
if [[ ! -d "${RC_ROOT}" ]]; then
    echo "error: rc root not found: ${RC_ROOT}" >&2
    exit 1
fi

shopt -s nullglob globstar
rc_files=("${RC_ROOT}"/**/*.rc)
shopt -u nullglob globstar

if [[ ${#rc_files[@]} -eq 0 ]]; then
    echo "error: no rc files found under ${RC_ROOT}" >&2
    exit 1
fi

echo "summary_csv=${SUMMARY_CSV}"
echo "rc_root=${RC_ROOT}"
echo "out_root=${OUT_ROOT}"
echo "clk_period=${CLK_PERIOD}, downsample=${DOWNSAMPLE}, processes=${PROCESSES}"
echo "rc files: ${#rc_files[@]}"

for rc_path in "${rc_files[@]}"; do
    rc_rel="${rc_path#${RC_ROOT}/}"
    rc_rel_no_ext="${rc_rel%.rc}"
    out_dir="${OUT_ROOT}/${rc_rel_no_ext}"

    echo
    echo "==> ${rc_rel_no_ext}: fsdb_to_csv"
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

    echo "==> ${rc_rel_no_ext}: csv_to_pkl"
    "${PYTHON_BIN}" "${SCRIPT_DIR}/csv_to_pkl.py" \
        --indir "${out_dir}/_csv" \
        --downsample "${DOWNSAMPLE}" \
        --processes "${PROCESSES}" \
        --out-dir "${out_dir}" \
        --rm-prefix

    if [[ "${RM_CSV}" -eq 1 ]]; then
        shopt -s nullglob
        csv_files=("${out_dir}/_csv/"*.csv)
        shopt -u nullglob
        if [[ ${#csv_files[@]} -gt 0 ]]; then
            echo "==> ${rc_rel_no_ext}: removing ${#csv_files[@]} CSV file(s)"
            rm -- "${csv_files[@]}"
        fi
    fi
done

echo
echo "done: outputs written under ${OUT_ROOT}"
