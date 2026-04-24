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
	@python3 ./scripts/prepare_model.py \
	    ./tests/cases/model_compiled/$(1) ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all \
	    CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian \
	    CASENAME=$(1) FILE=bare_main \
	    EXTRA_CFLAGS="-DSHL_BUILD_RTOS -isystem stubs \
	        -I$$(CSI_NN2_INSTALL)/include \
	        -I$$(CSI_NN2_INSTALL)/include/csinn \
	        -I$$(CSI_NN2_INSTALL)/include/shl_public \
	        -ffunction-sections -fdata-sections" \
	    EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,-z,muldefs \
	        $$(CSI_NN2_INSTALL)/lib/libshl_c906_rtos.a" \
	    >& $(1)_build.case.log
	@python3 ./scripts/prepare_model.py \
	    ./tests/cases/model_compiled/$(1) ./work
endef

$(foreach case,$(MODEL_CASES),$(eval $(call NN_MODEL_BUILD,$(case))))



# Adjust verilog filelist for *.v case...
ifeq ($(CASE), debug)
SIM_FILELIST := ../tests/cases/debug/JTAG_DRV.vh ../tests/cases/debug/C906_DEBUG_PATTERN.v
endif


define newline


endef


