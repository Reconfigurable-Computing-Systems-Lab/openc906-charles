# Local macOS environment for smart_run — bash/zsh replacement for
# setup/example_setup.csh (whose /dfs/... paths exist only on the remote server).
# Usage: source setup/mac_setup.sh   (from smart_run/ or anywhere)

_this="${BASH_SOURCE[0]:-${(%):-%x}}"
_repo="$(cd "$(dirname "$_this")/../.." && pwd)"

# Absolute path to the C906 RTL factory (consumed by ${CODE_BASE_PATH} in filelists)
export CODE_BASE_PATH="$_repo/C906_RTL_FACTORY"

# bin/ dir of the RISC-V bare-metal toolchain. Local install is an xPack
# riscv-none-elf-gcc with a riscv64-unknown-elf-* symlink farm so the stock
# tool names in tests/lib/Makefile keep working.
export TOOL_EXTENSION="$HOME/tools/riscv-wrap"

# ELF->pat converter: tests/bin/Srec2vmem is a Linux x86-64 binary; use the
# Python drop-in on macOS.
export CONVERT="python3 $_repo/smart_run/tests/bin/srec2vmem.py"

# Use portable -march flags (no Xuantie meta-extension xtheadc) in tests/lib/Makefile
export THEAD_GCC=0

export PATH="$HOME/.local/bin:$HOME/homebrew/bin:$TOOL_EXTENSION:$PATH"

unset _this _repo
