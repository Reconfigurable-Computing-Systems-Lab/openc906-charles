#!/bin/bash
# Clean all Design Compiler intermediate results from synthesis runs.
# Usage: ./clean.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Cleaning DC intermediate results in ${SCRIPT_DIR}"

# Batch output directories (batch_YYYYMMDD_HH/ with reports/ results/ WORK/)
rm -rf batch_*

# DC log files
rm -f dc.log read_ddc.log

# DC-generated automation files
rm -f command.log default.svf

# DC library characterization cache
rm -rf alib_db *.alib

# DC temporary directories
rm -rf .tmp_* tmp.*

echo "Done."
