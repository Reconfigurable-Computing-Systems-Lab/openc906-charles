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
	cd ./work && ./simv -l run.vcs.log
else
        ifeq ($(SIM), nc)
	cd ./work && irun -R -l run.irun.log
        else
        ifeq ($(SIM), verilator)
	cd ./work && ./simv 2>&1 | tee run.verilator.log
        else
	cd ./work && vvp xuantie_core.vvp -l run.iverilog.log
        endif
        endif
endif
else
	$(error Argument CASE=xxx is not valid: \
        $(newline)   The list of valid cases can be obtained by executing: \
        $(newline)   > make showcase ...)
endif

# Execute all cases
regress:
	rm -rf ./tests/regress/regress_result
	mkdir -p ./tests/regress/regress_result
	@(for case in $(CASE_LIST) ; do \
	 rm -rf ./work/* ; \
	 make -s runcase CASE=$$case; \
	 cp ./work/run_case.report ./tests/regress/regress_result/$$case.report; \
	 done)
	cd ./tests/regress && perl report_gen.pl
	cat ./tests/regress/regress_report

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
	@echo "  Optional arguments:";
	@echo "    SIM=                            : options: vcs / nc / iverilog / verilator";
	@echo "    CASE=                           : options: the list print by 'make showcase'"; 
	@echo "    DUMP=                           : options: on / off";
	@echo "    FSDB_SCOPE=                      : (vcs) core (default, dumps the CPU_TOP core only) / full (whole SoC)";
	@echo "  Examples:";
	@echo "    make runcase CASE=dhry          : run case 'dhry' (by vcs withtout dump) "; 
	@echo "    make runcase CASE=dhry SIM=nc   : run case 'dhry' (by nc withtout dump) "; 
	@echo "    make runcase CASE=dhry DUMP=on  : run case 'dhry' with dump "; 


