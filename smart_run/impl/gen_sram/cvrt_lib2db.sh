#!/bin/tcsh
# Convert all SRAM .lib files to .db using lc_shell.
# Handles both d127 (180a), UHD (170a), and 1prf (130a) compiler outputs.

source  /usr/eelocal/synopsys/lc-vx2025.06-sp3/.cshrc

# Resolve TAR_DIR relative to this script so the flow is portable across users.
set script_path = `readlink -f "$0"`
set TAR_DIR = "$script_path:h"

# Output directory for .db files
set DB_OUT_DIR = "${TAR_DIR}/db"
mkdir -p "$DB_OUT_DIR"
rm -f ${DB_OUT_DIR}/*.db

# Temporary TCL batch file (with .tcl extension)
set tcl_file = `mktemp /tmp/lib2db.XXXXXX`
set tcl_file = "${tcl_file}.tcl"

# Array to collect db paths
set db_paths = ()

# Find all tt1v25c .lib files (d127 _180a, UHD _170a, 1prf _130a)
foreach f (`find ${TAR_DIR} -type f -name '*_tt1v25c.lib'`)
    set dir_path = "$f:h"
    set db_name = "$f:t:r"
    set db_path = "${dir_path}/${db_name}.db"
    # Remove _180a / _170a / _130a version suffix for the library name
    set lc_name = `echo "$db_name" | sed 's/_[0-9]*a//'`

    echo "read_lib $f" >> "$tcl_file"
    echo "write_lib $lc_name -format db -output $db_path" >> "$tcl_file"

    set db_paths = ($db_paths $db_path)
end

# Add exit at the end of the TCL script
echo "exit" >> "$tcl_file"

# Run lc_shell once
echo "Start lib to db conversion ..."
lc_shell -f "$tcl_file"

# Clean up
rm -f "$tcl_file"
rm -f "lc_command.log" "lc_output.txt"

# Move .db files to the output directory
foreach path ($db_paths)
    if (-e "$path") then
        /usr/bin/mv -f "$path" "$DB_OUT_DIR/"
    endif
end

# Print summary list
echo ""
echo "Conversion completed. The generated DB files are:"
foreach path ($db_paths)
    echo "${DB_OUT_DIR}/$path:t"
end
