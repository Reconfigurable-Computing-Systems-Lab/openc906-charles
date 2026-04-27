#!/bin/tcsh

# Run Synopsys Design Compiler synthesis for C906 openC906
# Usage: ./run_dc.csh -mode <syn|read_ddc> [-batch_dir <directory>]
#   -mode syn      : run DC synthesis (dc.tcl)
#   -mode read_ddc : read existing DDC file (read_ddc.tcl)
#   -batch_dir     : specify batch directory (required for read_ddc mode)

if ( $#argv == 0 ) then
    echo "Error: No argument provided."
    echo "Usage: $0 -mode <syn|read_ddc> [-batch_dir <directory>]"
    echo "  -mode syn      : run DC synthesis"
    echo "  -mode read_ddc : read existing DDC file (requires -batch_dir)"
    echo "  -batch_dir     : specify batch directory"
    exit 1
endif

set mode = ""
set batch_dir = ""

# Parse arguments
while ( $#argv > 0 )
    switch ( "$1" )
        case "-mode":
            if ( $#argv < 2 ) then
                echo "Error: -mode requires an argument"
                exit 1
            endif
            set mode = "$2"
            shift; shift
            breaksw
        case "-batch_dir":
            if ( $#argv < 2 ) then
                echo "Error: -batch_dir requires an argument"
                exit 1
            endif
            set batch_dir = "$2"
            shift; shift
            breaksw
        default:
            echo "Error: Unknown option '$1'"
            echo "Usage: $0 -mode <syn|read_ddc> [-batch_dir <directory>]"
            exit 1
    endsw
end

# Validate mode
if ( "$mode" == "" ) then
    echo "Error: -mode is required"
    echo "Usage: $0 -mode <syn|read_ddc> [-batch_dir <directory>]"
    exit 1
endif

# Set script and log based on mode
if ( "$mode" == "syn" ) then
    set tcl_script = "dc.tcl"
    set log_file   = "dc.log"
    echo "Running DC synthesis with ${tcl_script}, log saved to ${log_file}"
else if ( "$mode" == "read_ddc" ) then
    if ( "$batch_dir" == "" ) then
        echo "Error: -batch_dir is required when using -mode read_ddc"
        echo "Usage: $0 -mode read_ddc -batch_dir <directory>"
        exit 1
    endif
    set tcl_script = "read_ddc.tcl"
    set log_file   = "read_ddc.log"
    echo "Reading DDC from batch ${batch_dir} with ${tcl_script}, log saved to ${log_file}"
else
    echo "Error: Invalid mode '$mode'. Must be 'syn' or 'read_ddc'"
    echo "Usage: $0 -mode <syn|read_ddc> [-batch_dir <directory>]"
    exit 1
endif

# Export BATCH_DIR if set
if ( "$batch_dir" != "" ) then
    setenv BATCH_DIR "$batch_dir"
endif

dc_shell -f ${tcl_script} |& tee -i ${log_file}
