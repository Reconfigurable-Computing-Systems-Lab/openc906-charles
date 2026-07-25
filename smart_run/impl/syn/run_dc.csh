#!/bin/tcsh

# Run Synopsys Design Compiler synthesis for openC906
# Usage: ./run_dc.csh
# Outputs: dc.log and batch_<timestamp>/ (created by dc.tcl)

echo "Running DC synthesis with dc.tcl, log saved to dc.log"

dc_shell -f dc.tcl |& tee -i dc.log
