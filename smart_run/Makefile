#/*Copyright 2020-2021 T-Head Semiconductor Co., Ltd.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#*/

include ./setup/smart_cfg.mk
include ./setup/env_check.mk

################################################################################
# Simulation related
################################################################################
SIM = vcs
DUMP = on

# Repo-root regress/ -- where report_gen.pl and regress_report live.
REGRESS_DIR ?= ../regress

################################################################################
# Code coverage.  COVERAGE = off (default) | line | all
#   line : Verilator --coverage-line       / VCS -cm line+cond+branch+fsm
#   all  : line + toggle                   / VCS  ... +tgl
#
# Artifacts land in smart_run/cov/ -- NOT work/cov/, because `make regress` does
# `rm -rf ./work/*` between cases and `make clean` wipes work/ entirely, and
# coverage is only useful when it accumulates across cases.
#
# Coverage and waveform dumping are mutually exclusive by policy: both are slow
# and nobody needs both at once.  DUMP defaults to on, so COVERAGE forces it
# off; set COV_ALLOW_DUMP=1 to keep the dump anyway.
#
# Report with `make covreport` (see cli_tools/cov_report.py).
################################################################################
COVERAGE       ?= off
COV_DIR        ?= ../cov
COV_NAME       ?= $(if $(CASE),$(CASE),nocase)
COV_ALLOW_DUMP ?=
COV_ARGS       ?=

ifneq ($(COVERAGE), off)
  ifeq ($(DUMP), on)
    ifeq ($(COV_ALLOW_DUMP),)
      $(warning [THead-smart] COVERAGE=$(COVERAGE): forcing DUMP=off (set COV_ALLOW_DUMP=1 to keep it))
      override DUMP := off
    endif
  endif
endif

# Options added to the *run* step, and a free-form user hook.  SIM_ARGS is what
# makes plusargs reachable from make at all -- without it there is no way to
# pass +MAX_SIM_TIME=, and the default MAX_RUN_TIME of 3e9 ns means a livelock
# runs for hours before the testbench declares FAIL.
#   make runcase CASE=cp0_random SIM_ARGS=+MAX_SIM_TIME=4e6
SIM_RUN_OPT :=
SIM_ARGS    ?=

ifeq ($(DUMP), on)
SIM_DUMP :=
else
ifeq (${SIM}, iverilog)
SIM_DUMP = -DNO_DUMP
else
SIM_DUMP := +define+NO_DUMP
endif
endif

# FSDB dump scope for VCS (DUMP=on). Default 'core' dumps only `CPU_TOP (matches
# the PTPX read_fsdb -strip_path / GLS SDF region and keeps files tractable);
# FSDB_SCOPE=full adds +define+FSDB_FULL_SOC to dump the whole SoC.
FSDB_SCOPE ?= core
ifeq ($(FSDB_SCOPE), full)
FSDB_DEF := +define+FSDB_FULL_SOC
else
FSDB_DEF :=
endif

ifeq ($(SIM), vcs)
TIMESCALE := -timescale=1ns/1ps
SIMULATOR_OPT := -sverilog -full64 -kdb -lca -debug_access +nospecify +notimingchecks
SIMULATOR_DEF := +define+no_warning +define+TSMC_NO_WARNING $(FSDB_DEF)
SIMULATOR_LOG := -l comp.vcs.log
ifneq ($(COVERAGE), off)
  # -cm_line contassign is load-bearing: VCS line coverage ignores continuous
  # assignments by default, and this RTL is almost entirely `assign`.
  # -cm_hier restricts instrumentation to the five pipeline units (see
  # setup/cov_hier.cfg), which keeps the slowdown and the .vdb size down.
  # The run step needs the -cm flags too, or nothing is recorded.
  CM_METRICS := line+cond+branch+fsm
  ifeq ($(COVERAGE), all)
    CM_METRICS := line+cond+branch+fsm+tgl
  endif
  SIMULATOR_OPT += -cm $(CM_METRICS) -cm_dir $(COV_DIR)/simv.vdb -cm_name $(COV_NAME) \
                   -cm_hier ../setup/cov_hier.cfg -cm_line contassign -cm_cond allops
  ifeq ($(COVERAGE), all)
    SIMULATOR_OPT += -cm_seqnoconst
  endif
  SIM_RUN_OPT += -cm $(CM_METRICS) -cm_dir $(COV_DIR)/simv.vdb -cm_name $(COV_NAME)
endif
else
    ifeq ($(SIM), nc) 
    TIMESCALE := -timescale 1ns/1ps
    SIMULATOR_OPT := +v2k -sysv +sv +access+wrc +notimingcheck -default_ext verilog -elaborate +tcl+../setup/nc.tcl
    SIMULATOR_DEF := +define+no_warning +define+TSMC_NO_WARNING +define+VMC +define+NC_SIM 
    SIMULATOR_LOG := -l comp.nc.log
    else
    ifeq ($(SIM), iverilog)
      TIMESCALE :=
      SIMULATOR_OPT := -o xuantie_core.vvp -Diverilog=1 -g2012
      SIMULATOR_DEF := -DIVERILOG_SIM
      SIMULATOR_LOG :=
    endif
    ifeq ($(SIM), verilator)
      VERILATOR ?= verilator
      VL_JOBS ?= 10
      VL_THREADS ?= 1
      TIMESCALE := --timescale 1ns/1ps
      SIMULATOR_OPT := --binary -j $(VL_JOBS) --threads $(VL_THREADS) -O3 --top-module tb \
                       -Wno-fatal -Wno-TIMESCALEMOD -Wno-IMPLICIT -Wno-WIDTH -Wno-UNOPTFLAT \
                       --x-assign fast --x-initial fast -o simv
      ifeq ($(DUMP), on)
        SIMULATOR_OPT += --trace-vcd
      endif
      # NOT bare --coverage: that is an alias for line+toggle+user, and toggle
      # coverage over the whole SoC (including the two 128MB SRAM banks) is
      # unaffordable.  --coverage-user is dead here -- there are no covergroups.
      # -O3 is safe: Verilator declines to apply the table optimisation to any
      # block containing coverage points, so points are never optimised away.
      ifneq ($(COVERAGE), off)
        SIMULATOR_OPT += --coverage-line
        ifeq ($(COVERAGE), all)
          SIMULATOR_OPT += --coverage-toggle --coverage-max-width 256 ../setup/cov_units.vlt
        endif
        SIM_RUN_OPT += +verilator+coverage+file+$(COV_DIR)/$(COV_NAME).dat
      endif
      SIMULATOR_DEF :=
      SIMULATOR_LOG :=
    endif
    endif
endif

ifeq ($(SIM), iverilog)
SIM_FILELIST := $(SIM_FILELIST) -f ${CODE_BASE_PATH}/gen_rtl/filelists/C906_asic_rtl.fl -f ${CODE_BASE_PATH}/gen_rtl/filelists/tdt_dmi_top_rtl.fl -c ../logical/filelists/smart.fl -c ../logical/filelists/tb.fl
else
ifeq ($(SIM), verilator)
SIM_FILELIST := $(SIM_FILELIST) -f ${CODE_BASE_PATH}/gen_rtl/filelists/C906_asic_rtl.fl -f ${CODE_BASE_PATH}/gen_rtl/filelists/tdt_dmi_top_rtl.fl -f ../logical/filelists/smart.fl -f ../logical/filelists/tb.fl
else
SIM_FILELIST := $(SIM_FILELIST) -f ../logical/filelists/sim.fl
endif
endif

compile:
	@echo "  [THead-smart] Compiling smart now ... "
	@echo "  [THead-smart] SIM = $(SIM)"
	@mkdir -p ./cov
# A COVERAGE=off -> COVERAGE=line transition must rebuild from scratch: the
# verilator leg below does not clean, and a stale obj_dir built without
# instrumentation silently produces an empty coverage.dat.
ifneq ($(COVERAGE), off)
	@make -s cleansim
endif
ifeq ($(SIM), vcs)
	@make -s cleansim
	@cd ./work && vcs $(SIMULATOR_OPT) $(TIMESCALE) $(SIMULATOR_DEF) $(SIM_FILELIST) $(SIM_DUMP) $(SIMULATOR_LOG) 
else 
    ifeq ($(SIM), nc)
	@cd ./work && irun $(SIMULATOR_OPT) $(TIMESCALE) $(SIMULATOR_DEF) $(SIM_FILELIST) $(SIM_DUMP) $(SIMULATOR_LOG) 
    else
        ifeq ($(SIM), iverilog)
	  @cd ./work && iverilog $(TIMESCALE) $(SIMULATOR_OPT) $(SIMULATOR_DEF) $(SIM_FILELIST) $(SIM_DUMP) $(SIMULATOR_LOG)
        else
        ifeq ($(SIM), verilator)
	  @cd ./work && $(VERILATOR) $(SIMULATOR_OPT) $(TIMESCALE) $(SIMULATOR_DEF) $(SIM_FILELIST) $(SIM_DUMP) 2>&1 | tee comp.verilator.log
	  @cd ./work && ln -sf obj_dir/simv simv
        else
	  @echo "  [THead-smart] Please specify SIM = vcs to use VCS, or SIM = nc to use irun ..."
        endif
        endif
    endif 
endif 

cleansim:
	@cd ./work && rm -rf simv* csrc ucli.key *.vcs.log novas_dump.log *.fsdb obj_dir comp.verilator.log run.verilator.log

################################################################################
# Coverage reporting.  See cli_tools/cov_report.py for the options accepted via
# COV_ARGS, e.g.
#   make covreport SIM=verilator COV_ARGS="--top-cold 5"
#   make covreport SIM=verilator COV_ARGS="--baseline ../doc/results/unit_coverage_baseline.json"
################################################################################
covreport:
ifeq ($(SIM), vcs)
	@urg -dir ./cov/simv.vdb -format text -report ./cov/urgReport -show tests
	@python3 ./cli_tools/cov_report.py --urg ./cov/urgReport $(COV_ARGS)
else
	@python3 ./cli_tools/cov_report.py --dat ./cov $(COV_ARGS)
endif

cleancov:
	@rm -rf ./cov

################################################################################
# Cases related
################################################################################
showcase:
	@echo "  Case lists:" \ 
	@for case in $(CASE_LIST) ; do \
          echo "    $$case"; \
        done

buildcase: tool-chain-chk
ifeq ($(CASE),)
	$(error Please specify CASE=xxx on the command line, like: \
        $(newline)   > make buildcase CASE=xxx... \
        $(newline)   The list of valid cases can be obtained by executing: \
        $(newline)   > make showcase ...)
endif
ifeq ($(findstring $(CASE), $(CASE_LIST)), $(CASE))
	@make -s cleancase
	@make -s $(CASE)_build
else
	$(error Argument CASE=xxx is not valid: \
        $(newline)   The list of valid cases can be obtained by executing: \
        $(newline)   > make showcase ...)
endif


cleancase:
	@cd ./work && rm -rf *.s *.S *.c *.o *.pat *.h *.lcf *.hex *.obj *.vh *.v *.report *.elf Makefile *.case.log

################################################################################
# Combined flows
################################################################################
# Execute one case
runcase:
ifeq ($(CASE),)
	$(error Please specify CASE=xxx on the command line, like: \
        $(newline)   > make buildcase CASE=xxx... \
        $(newline)   The list of valid cases can be obtained by executing: \
        $(newline)   > make showcase ...)
endif
ifeq ($(findstring $(CASE), $(CASE_LIST)), $(CASE))
	@make -s compile
	@make -s buildcase CASE=$(CASE)
ifeq ($(SIM), vcs)
	cd ./work && ./simv -l run.vcs.log $(SIM_RUN_OPT) $(SIM_ARGS)
else
        ifeq ($(SIM), nc)
	cd ./work && irun -R -l run.irun.log $(SIM_ARGS)
        else
        ifeq ($(SIM), verilator)
	cd ./work && ./simv $(SIM_RUN_OPT) $(SIM_ARGS) 2>&1 | tee run.verilator.log
        else
	cd ./work && vvp xuantie_core.vvp -l run.iverilog.log $(SIM_ARGS)
        endif
        endif
endif
else
	$(error Argument CASE=xxx is not valid: \
        $(newline)   The list of valid cases can be obtained by executing: \
        $(newline)   > make showcase ...)
endif

# Execute all cases.
#
# REGRESS_DIR is the repo-root regress/ directory -- that is where
# report_gen.pl actually lives, and it reads ./regress_result relative to its
# own cwd.  (This target used to point at ./tests/regress/, which does not
# exist, so the loop ran and then the summary step died.)
#
# Per-unit port-toggle reports are archived to a *sibling* directory:
# report_gen.pl does `find regress_result -type f` and treats every *.report as
# a case result, so toggle reports must not land there.
#
# REGRESS_LIST defaults to CASE_LIST (see setup/smart_cfg.mk).  To skip the
# randomized stress cases:
#   make regress REGRESS_LIST="$(filter-out $(RAND_CASES),$(CASE_LIST))"
regress:
	rm -rf $(REGRESS_DIR)/regress_result $(REGRESS_DIR)/regress_toggle
	mkdir -p $(REGRESS_DIR)/regress_result $(REGRESS_DIR)/regress_toggle
	@(for case in $(REGRESS_LIST) ; do \
	 rm -rf ./work/* ; \
	 make -s runcase CASE=$$case; \
	 cp ./work/run_case.report $(REGRESS_DIR)/regress_result/$$case.report; \
	 for r in ./work/*_toggle.report ; do \
	   if [ -f "$$r" ] ; then cp "$$r" $(REGRESS_DIR)/regress_toggle/$$case.`basename $$r` ; fi ; \
	 done ; \
	 done)
	cd $(REGRESS_DIR) && perl report_gen.pl
	cat $(REGRESS_DIR)/regress_report

################################################################################
# Misc
################################################################################
.DEFAULT_GOAL := help

clean:
	@cd ./work && rm -rf * 

help:
	@echo "  ########## Smart Help Info ##########"
	@echo "  This Makefile is the entrance of T-Head Smart simulation environment"
	@echo "  Usage: make [target] [arguments]";
	@echo "  Available targets:";
	@echo "    compile                         : compile the RTL and Smart tbench (using vcs or ius)";
	@echo "    showcase                        : list all valid cases under current configuration";
	@echo "    buildcase CASE=[casename]       : clean and compile the .c/.s case [casename]";
	@echo "    [casename]_build                : compile the .c/.s case [casename]";
	@echo "    runcase CASE=[casename]         : run the case [casename]";
	@echo "    regress                         : run all cases and summarize the regress result";
	@echo "    cleansim                        : clean files generated by simulator in ./work ";
	@echo "    cleancase                       : clean files generated by GNU in ./work ";
	@echo "    clean                           : clean ./work ";
	@echo "    covreport                       : print per-unit line/branch/toggle % (cli_tools/cov_report.py)";
	@echo "    cleancov                        : remove ./cov ";
	@echo "  Optional arguments:";
	@echo "    SIM=                            : options: vcs / nc / iverilog / verilator";
	@echo "    CASE=                           : options: the list print by 'make showcase'";
	@echo "    DUMP=                           : options: on / off";
	@echo "    FSDB_SCOPE=                      : (vcs) core (default, dumps the CPU_TOP core only) / full (whole SoC)";
	@echo "    COVERAGE=                       : off (default) / line / all (adds toggle); forces DUMP=off";
	@echo "    MON=                            : all -> compile all five per-unit port-toggle monitors";
	@echo "    SIM_ARGS=                       : extra plusargs for the run step, e.g. SIM_ARGS=+MAX_SIM_TIME=4e6";
	@echo "    COV_ARGS=                       : extra options for covreport";
	@echo "  Examples:";
	@echo "    make runcase CASE=dhry          : run case 'dhry' (by vcs withtout dump) "; 
	@echo "    make runcase CASE=dhry SIM=nc   : run case 'dhry' (by nc withtout dump) "; 
	@echo "    make runcase CASE=dhry DUMP=on  : run case 'dhry' with dump "; 


