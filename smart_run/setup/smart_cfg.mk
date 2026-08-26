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
#*/
#*/
CPU_ARCH_FLAG_0 := c906fd
CASE_LIST := \
      ISA_THEAD \
      ISA_INT \
      ISA_LS \
      ISA_FP \
      coremark \
      MMU \
      interrupt \
      exception \
      debug \
      csr \
      cache \
      conv_softmax \
      cp0_random \

# Randomized per-unit stress tests (doc/specs/unit-random-tests.md). They must
# be in CASE_LIST because buildcase/runcase gate on membership. They ARE part of
# the default regression, at the short default iteration counts below, so that a
# future RTL change that hangs them is caught. To skip them:
#   make regress REGRESS_LIST="$(filter-out $(RAND_CASES),$(CASE_LIST))"
RAND_CASES := iu_random vidu_random idu_random ifu_random
CASE_LIST  += $(RAND_CASES)

REGRESS_LIST ?= $(CASE_LIST)


ISA_THEAD_build:
	@cp ./tests/cases/ISA/ISA_THEAD/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=ISA_THEAD FILE=C906_THEAD_ISA_EXTENSION >& ISA_THEAD_build.case.log 


ISA_INT_build:
	@cp ./tests/cases/ISA/ISA_INT/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=ISA_INT FILE=C906_INT_SMOKE >& ISA_INT_build.case.log 


ISA_LS_build:
	@cp ./tests/cases/ISA/ISA_LS/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=ISA_LS FILE=C906_LSU_SMOKE >& ISA_LS_build.case.log 


ISA_FP_build:
	@cp ./tests/cases/ISA/ISA_FP/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=ISA_FP FILE=C906_FPU_SMOKE >& ISA_FP_build.case.log 


coremark_build:
	@cp ./tests/cases/coremark/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cp ./tests/lib/clib/* ./work
	@cp ./tests/lib/newlib_wrap/* ./work
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=coremark FILE=core_main >& coremark_build.case.log 


MMU_build:
	@cp ./tests/cases/MMU/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=MMU FILE=C906_mmu_basic >& MMU_build.case.log 


interrupt_build:
	@cp ./tests/cases/interrupt/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=interrupt FILE=C906_plic_int_smoke >& interrupt_build.case.log 




exception_build:
	@cp ./tests/cases/exception/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=exception FILE=C906_Exception >& exception_build.case.log 


debug_build:
	@cp ./tests/cases/debug/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=debug FILE=C906_DEBUG_PATTERN >& debug_build.case.log 


csr_build:
	@cp ./tests/cases/csr/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=csr FILE=C906_CSR_OPERATION >& csr_build.case.log 


cache_build:
	@cp ./tests/cases/cache/* ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd  ENDIAN_MODE=little-endian CASENAME=cache FILE=C906_IDCACHE_OPER >& cache_build.case.log 


################################################################################
# cp0_random -- randomized CP0 stress test.
#
# CP0_ITERS is the number of dynamic dispatch-loop iterations (100k by default);
# CP0_SEED seeds the in-test xorshift64 generator, so a run is reproducible.
# Both are overridable on the make command line, e.g.
#   make runcase CASE=cp0_random SIM=vcs DUMP=off CP0_ITERS=5000
#
# -fno-optimize-sibling-calls is mandatory (see CLAUDE.md "Known Bugs": jr-based
# tail calls stall retirement on this RTL). -fno-jump-tables removes the only
# other computed jr, the big dispatch switch.
################################################################################
# CP0_EXTRA passes extra -D flags through, e.g. -DCP0_ONLY_GROUP=21 to run a
# single operation group. tests/cases/cp0_random/run_groups.sh uses it to bisect.
CP0_ITERS ?= 100000
CP0_SEED  ?= 0x2024C906
CP0_EXTRA ?=

cp0_random_build:
	@cp ./tests/cases/cp0_random/C906_CP0_RANDOM.c ./work
	@cp ./tests/cases/cp0_random/cp0_trap.S ./work
	@cp ./tests/cases/cp0_random/cp0_csrs.h ./work
	@cp ./tests/cases/cp0_random/cp0_th_insn.h ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=cp0_random FILE=C906_CP0_RANDOM EXTRA_CFLAGS="-fno-optimize-sibling-calls -fno-jump-tables -DCP0_ITERS=$(CP0_ITERS) -DCP0_SEED=$(CP0_SEED) $(CP0_EXTRA)" >& cp0_random_build.case.log


################################################################################
# iu_random / vidu_random / idu_random / ifu_random
#
# Randomized per-unit stress tests, modelled on cp0_random
# (doc/specs/cp0-design-and-test.md Part II) and sharing tests/cases/rand_common/
# for the trap handler, xorshift64 PRNG, PMP helper, baseline-state restore and
# D-cache-off UART printer. Full description: doc/specs/unit-random-tests.md.
#
# Per case:
#   <U>_ITERS  dynamic dispatch-loop iterations. Defaults are deliberately small
#              so `make regress` stays usable; long-soak invocations are in the
#              doc.
#   <U>_SEED   xorshift64 seed -- fixes the entire data sequence.
#   <U>_OPT    optimisation level. Changing it changes the compiler's
#              instruction selection, i.e. changes the stimulus: the same source
#              at -O0/-O1/-O2/-Os gives four different decode streams for free.
#              Highest-value knob for idu/ifu.
#   <U>_EXTRA  extra -D flags, e.g. -DIU_ONLY_GROUP=23 to bisect one group
#              (tests/cases/<case>/run_groups.sh uses it).
#
# -fno-optimize-sibling-calls is mandatory (CLAUDE.md "Known Bugs": an indirect
# jump used as a tail call stalls retirement on this RTL). -fno-jump-tables
# removes the other computed jr, GCC's switch dispatch table.
#
# vidu is the *scalar FP* issue unit in this configuration -- every port is
# vidu_*_fp_*, misa.V=0 and the vector side of aq_vidu_top.v is a tie-off block
# -- so it builds c906fd. c906fdv must NOT be used: GCC 14 emits RVV 1.0 and
# this RTL is RVV 0.7.1.
#
# Files are copied one at a time on purpose: tests/lib/Makefile globs work/*.c
# work/*.s work/*.S and links every object, and `make cleancase` deletes
# work/*.v -- so the generated monitor, the .f filelist and the bisect script
# must never land in work/. Note also that the case Makefile's `clean` removes
# work/*.pat, which is why ifu_random's far-stub pattern is copied in after the
# build (same reason conv_softmax_build copies input.pat last).
################################################################################
RAND_COMMON       := ./tests/cases/rand_common
RAND_COMMON_FILES := rand_common.h rand_csrs.h rand_th_insn.h rand_trap.S rand_lib.c

# Calibrated, not guessed: measured cycles/iteration from a 200-iteration
# bring-up run of each case (doc/results/unit_random_runlog.md R003), scaled
# to land at roughly 90 s wall each under Verilator on macOS in the plain
# configuration (no coverage, one monitor -- the cp0_random anchor is 118 us of
# simulated time per wall-second). Four cases at 90 s adds ~6 min to a
# regression. Long soaks pass a bigger value explicitly.
IU_ITERS   ?= 16000
IU_SEED    ?= 0x2024C906
IU_OPT     ?= -O2
IU_EXTRA   ?=

iu_random_build:
	@for f in $(RAND_COMMON_FILES); do cp $(RAND_COMMON)/$$f ./work; done
	@cp ./tests/cases/iu_random/C906_IU_RANDOM.c ./work
	@cp ./tests/cases/iu_random/iu_defs.h        ./work
	@cp ./tests/cases/iu_random/iu_sweeps.S      ./work
	@cp ./tests/cases/iu_random/iu_bju.S         ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=iu_random FILE=C906_IU_RANDOM EXTRA_CFLAGS="-fno-optimize-sibling-calls -fno-jump-tables $(IU_OPT) -DIU_ITERS=$(IU_ITERS) -DIU_SEED=$(IU_SEED) $(IU_EXTRA)" >& iu_random_build.case.log


VIDU_ITERS ?= 10000
VIDU_SEED  ?= 0x2024C906
VIDU_OPT   ?= -O2
VIDU_EXTRA ?=

vidu_random_build:
	@for f in $(RAND_COMMON_FILES); do cp $(RAND_COMMON)/$$f ./work; done
	@cp ./tests/cases/vidu_random/C906_VIDU_RANDOM.c ./work
	@cp ./tests/cases/vidu_random/vidu_defs.h        ./work
	@cp ./tests/cases/vidu_random/vidu_sweeps.S      ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=vidu_random FILE=C906_VIDU_RANDOM EXTRA_CFLAGS="-fno-optimize-sibling-calls -fno-jump-tables $(VIDU_OPT) -DVIDU_ITERS=$(VIDU_ITERS) -DVIDU_SEED=$(VIDU_SEED) $(VIDU_EXTRA)" >& vidu_random_build.case.log


IDU_ITERS  ?= 6000
IDU_SEED   ?= 0x2024C906
IDU_OPT    ?= -O2
IDU_EXTRA  ?=

idu_random_build:
	@for f in $(RAND_COMMON_FILES); do cp $(RAND_COMMON)/$$f ./work; done
	@cp ./tests/cases/idu_random/C906_IDU_RANDOM.c ./work
	@cp ./tests/cases/idu_random/idu_defs.h        ./work
	@cp ./tests/cases/idu_random/idu_encodings.h   ./work
	@python3 ./tests/cases/idu_random/gen_idu_sweeps.py \
	    --out-s ./work/idu_sweeps.S --out-h ./work/idu_sweeps.h
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=idu_random FILE=C906_IDU_RANDOM EXTRA_CFLAGS="-fno-optimize-sibling-calls -fno-jump-tables -Wa,-mno-relax $(IDU_OPT) -DIDU_ITERS=$(IDU_ITERS) -DIDU_SEED=$(IDU_SEED) $(IDU_EXTRA)" >& idu_random_build.case.log


# IFU iterations are the most expensive (an I-cache invalidate-all is 256 set
# writes, a refill is tens to hundreds of cycles), hence the lower default.
# IFU_ARENA_SEED reseeds the *code layout*, so a new value produces a different
# program, not just different data.
# IFU_ITERS is 200, and unlike the other three it is NOT calibrated to the 90 s
# target. There is an unexplained runtime cliff between 200 and 400 iterations:
# 200 completes in 0.594 ms of simulated time, 400 exceeds 15 ms and 1200
# exceeds 20 ms -- with the core retiring throughout, so it is cost, not a hang.
# See doc/specs/unit-random-tests.md Part IV "OPEN ISSUE" for what has been
# ruled out and for the one-run diagnostic that would localise it.
# Do not raise this without re-measuring.
IFU_ITERS  ?= 200
IFU_SEED       ?= 0x2024C906
IFU_ARENA_SEED ?= 0x5A5AC906
# IFU_ARENA_BASE must match the ADDRESS on the `.text.arena` output section in
# tests/cases/ifu_random/linker_ifu.lcf -- an explicit output-section address,
# NOT a `. = 0x8000;` assignment, which ld silently ignores for a section that
# names a memory region. The generator computes every branch offset, I-cache set
# index (VA[13:6]), BTB tag (PC[15:0]) and 4 KB page boundary from it, so a
# mismatch would leave the test passing while covering nothing; the ASSERTs at
# the bottom of that script turn it into a link error. Change both together, and
# remember that .text.jit and .rodata are placed after the arena, so base + size
# must stay below MEM1's 0x40000 top (0x8000 + 0x30000 = 0x38000 leaves 32 KB
# for them).
IFU_ARENA_BASE ?= 0x8000
IFU_ARENA_SIZE ?= 0x30000
IFU_OPT        ?= -O2
IFU_EXTRA      ?=

ifu_random_build:
	@for f in $(RAND_COMMON_FILES); do cp $(RAND_COMMON)/$$f ./work; done
	@cp ./tests/cases/ifu_random/C906_IFU_RANDOM.c ./work
	@cp ./tests/cases/ifu_random/ifu_defs.h        ./work
	@python3 ./tests/cases/ifu_random/gen_ifu_arena.py \
	    --seed $(IFU_ARENA_SEED) \
	    --arena-base $(IFU_ARENA_BASE) --arena-size $(IFU_ARENA_SIZE) \
	    --out-s ./work/ifu_arena.S --out-h ./work/ifu_arena.h \
	    --out-far-pat ./work/ifu_far.patgen --far-base 0x01000000 --check
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cp ./tests/cases/ifu_random/linker_ifu.lcf ./work/linker.lcf
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=ifu_random FILE=C906_IFU_RANDOM EXTRA_CFLAGS="-fno-optimize-sibling-calls -fno-jump-tables -Wa,-mno-relax $(IFU_OPT) -DIFU_ITERS=$(IFU_ITERS) -DIFU_SEED=$(IFU_SEED) $(IFU_EXTRA)" >& ifu_random_build.case.log
	@mv ./work/ifu_far.patgen ./work/input.pat


CSI_NN2_INSTALL := ../../csi-nn2/install_nn2/c906
conv_softmax_build:
	@cp ./tests/cases/conv_softmax/bare_main.c ./work
	@cp ./tests/cases/conv_softmax/model.c ./work
	@cp ./tests/cases/conv_softmax/sbrk.c ./work
	@cp ./tests/cases/conv_softmax/test_data.h ./work
	@cp -r ./tests/cases/conv_softmax/stubs ./work/stubs
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \; 
	@cd ./work && make -s clean && make -s all CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian CASENAME=conv_softmax FILE=bare_main EXTRA_CFLAGS="-DSHL_BUILD_RTOS -isystem stubs -I$(CSI_NN2_INSTALL)/include -I$(CSI_NN2_INSTALL)/include/csinn -I$(CSI_NN2_INSTALL)/include/shl_public -ffunction-sections -fdata-sections" EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,-z,muldefs $(CSI_NN2_INSTALL)/lib/libshl_c906_rtos.a" >& conv_softmax_build.case.log
	@cp ./tests/cases/conv_softmax/input.pat ./work


################################################################################
# Auto-discovered CSI-NN2 model_compiled test cases
################################################################################
MODEL_COMPILED_DIR := ./tests/cases/model_compiled
MODEL_CASES := $(patsubst $(MODEL_COMPILED_DIR)/%/model.c,%,$(wildcard $(MODEL_COMPILED_DIR)/*/model.c))
CASE_LIST += $(MODEL_CASES)

# Generic build recipe for any model in model_compiled/
# $(1) = case name (directory name under model_compiled/)
define NN_MODEL_BUILD
$(1)_build:
	@echo "  [NN-Model] Preparing $(1)..."
	@cp ./tests/cases/nn_model_common/bare_main.c ./work/
	@cp ./tests/cases/nn_model_common/sbrk.c ./work/
	@cp -r ./tests/cases/nn_model_common/stubs ./work/stubs
	@python3 ./onnx_sim_lib/prepare_model.py \
	    ./tests/cases/model_compiled/$(1) ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cp ./tests/cases/nn_model_common/linker_model.lcf ./work/linker.lcf
	@cd ./work && make -s clean && make -s all \
	    CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian \
	    CASENAME=$(1) FILE=bare_main \
	    EXTRA_CFLAGS="-DSHL_BUILD_RTOS -isystem stubs \
	        -fno-optimize-sibling-calls $(PROBE_CFLAGS) \
	        -I$$(CSI_NN2_INSTALL)/include \
	        -I$$(CSI_NN2_INSTALL)/include/csinn \
	        -I$$(CSI_NN2_INSTALL)/include/shl_public \
	        -ffunction-sections -fdata-sections" \
	    EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,-z,muldefs \
	        $$(CSI_NN2_INSTALL)/lib/libshl_c906_rtos.a" \
	    >& $(1)_build.case.log
	@python3 ./onnx_sim_lib/prepare_model.py \
	    ./tests/cases/model_compiled/$(1) ./work
endef

$(foreach case,$(MODEL_CASES),$(eval $(call NN_MODEL_BUILD,$(case))))



# Adjust verilog filelist for *.v case...
ifeq ($(CASE), debug)
SIM_FILELIST := ../tests/cases/debug/JTAG_DRV.vh ../tests/cases/debug/C906_DEBUG_PATTERN.v
endif

# Per-unit port-toggle monitors. Each randomized case pulls in its own unit's
# monitor plus the matching +define+. MON=all overrides that and pulls in all
# five, so that *any* case -- coremark, for the reference baseline -- can be
# measured against every pipeline unit at once.
#
# These go through a filelist rather than SIMULATOR_DEF because the Makefile
# assigns SIMULATOR_DEF with := per backend, after including this file.
# (vcs / irun / verilator all accept options inside a -f filelist; iverilog
# does not, so every case below is vcs / nc / verilator only.)
#
# Consequence to remember: the guard is a compile-time define, so switching
# CASE between any two of these five needs `make compile` again. runcase does
# that for you; the fast loop is one `make compile` then repeated
# `make buildcase` + `./simv` (which is what run_groups.sh does).
ifeq ($(MON), all)
SIM_FILELIST := -f ../logical/filelists/all_mon.f
else
ifeq ($(CASE), cp0_random)
SIM_FILELIST := -f ../tests/cases/cp0_random/cp0_mon.f
endif
ifeq ($(CASE), iu_random)
SIM_FILELIST := -f ../tests/cases/iu_random/iu_mon.f
endif
ifeq ($(CASE), vidu_random)
SIM_FILELIST := -f ../tests/cases/vidu_random/vidu_mon.f
endif
ifeq ($(CASE), idu_random)
SIM_FILELIST := -f ../tests/cases/idu_random/idu_mon.f
endif
ifeq ($(CASE), ifu_random)
SIM_FILELIST := -f ../tests/cases/ifu_random/ifu_mon.f
endif
endif

# iverilog cannot honour a +define+ inside a filelist (its -c command files take
# filenames only), so fail loudly instead of with a confusing "module not
# found" during elaboration.
ifeq ($(SIM), iverilog)
ifneq ($(filter $(CASE),cp0_random $(RAND_CASES)),)
$(warning [THead-smart] CASE=$(CASE) is not supported under SIM=iverilog: its port-toggle monitor arrives via +define+ inside a -f filelist. Use SIM=vcs, SIM=nc or SIM=verilator.)
endif
ifeq ($(MON), all)
$(warning [THead-smart] MON=all is not supported under SIM=iverilog for the same reason.)
endif
endif


define newline


endef


