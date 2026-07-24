# SPDX-License-Identifier: Apache-2.0
################################################################################
# Gate-level simulation (SDF-annotated) for the synthesized openC906 netlist.
#
# Reuses the smart_run testbench (logical/filelists/smart.fl + tb.fl) and the
# smart_run case builder; only the openC906 core is swapped for the DC netlist.
# VCS runs from smart_run/work_gls so the filelists' relative paths resolve
# exactly as they do for the behavioral sim in smart_run/work.
#
# Usage (from this directory, after `source ../../setup/example_setup.csh`):
#   make compile BATCH_DIR=../syn/batch_YYYYMMDD_HH
#   make runcase BATCH_DIR=../syn/batch_YYYYMMDD_HH CASE=coremark
#   make runcase BATCH_DIR=... CASE=... NTC=1     # zero-delay fallback
#
# NTC=1 disables SDF annotation and timing checks (+nospecify +notimingchecks)
# — useful to separate netlist functional bugs from timing/X-propagation issues.
#
# Per-case gate-level FSDBs land in impl/gls/results/<CASE>.fsdb — these are
# the inputs to the PrimePower flow (impl/ptpx).
################################################################################

SMART_RUN := $(abspath ../..)
GLS_DIR   := $(abspath .)
WORK      := $(SMART_RUN)/work_gls

TOP_MODULE := openC906
SDF_INST   := tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top

NTC ?= 0

ifeq ($(BATCH_DIR),)
ifneq ($(filter compile runcase,$(MAKECMDGOALS)),)
$(error Please specify BATCH_DIR=<syn batch dir>, e.g. make compile BATCH_DIR=../syn/batch_20260723_10)
endif
endif
BATCH_ABS := $(abspath $(BATCH_DIR))
NETLIST   := $(BATCH_ABS)/results/$(TOP_MODULE).mapped.v
SDF_FILE  := $(BATCH_ABS)/results/$(TOP_MODULE).mapped.sdf

ifeq ($(NTC),1)
TIMING_OPT := +nospecify +notimingchecks
else
TIMING_OPT := +neg_tchk -negdelay -sdfretain +sdfverbose \
              -sdf max:$(SDF_INST):$(SDF_FILE)
endif

VCS_OPT := -sverilog -full64 -kdb -lca -debug_access -timescale=1ns/1ps \
           +define+no_warning +define+TSMC_NO_WARNING \
           +libext+.v+.h+.V+.sv+

compile:
	@echo "  [GLS] Compiling netlist $(NETLIST)"
	@test -f $(NETLIST) || (echo "Error: netlist not found: $(NETLIST)"; exit 1)
ifneq ($(NTC),1)
	@test -f $(SDF_FILE) || (echo "Error: SDF not found: $(SDF_FILE)"; exit 1)
endif
	@mkdir -p $(WORK)
	cd $(WORK) && vcs $(VCS_OPT) $(TIMING_OPT) \
	    $(NETLIST) \
	    -f ../impl/gls/gls.f \
	    -f ../logical/filelists/smart.fl \
	    -f ../logical/filelists/tb.fl \
	    -l comp.gls.log

# Build the test program with the existing smart_run case builder, then copy
# the memory images (inst/data/input .pat) into the GLS work dir.
buildcase:
ifeq ($(CASE),)
	$(error Please specify CASE=xxx (see `make showcase` in smart_run))
endif
	@$(MAKE) -s -C $(SMART_RUN) buildcase CASE=$(CASE)
	@cp $(SMART_RUN)/work/*.pat $(WORK)/

runcase: compile buildcase
	cd $(WORK) && ./simv -l run.gls.log
	@mkdir -p $(GLS_DIR)/results
	@if [ -f $(WORK)/novas.fsdb ]; then \
	    cp $(WORK)/novas.fsdb $(GLS_DIR)/results/$(CASE).fsdb; \
	    echo "  [GLS] waveform saved to results/$(CASE).fsdb"; \
	fi
	@if [ -f $(WORK)/run_case.report ]; then \
	    cp $(WORK)/run_case.report $(GLS_DIR)/results/$(CASE).report; \
	    cat $(WORK)/run_case.report; \
	fi

clean:
	rm -rf $(WORK) $(GLS_DIR)/results

.PHONY: compile buildcase runcase clean
