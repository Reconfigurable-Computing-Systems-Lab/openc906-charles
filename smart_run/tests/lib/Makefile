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
CC      = ${TOOL_EXTENSION}/riscv64-unknown-elf-gcc
AS      = ${TOOL_EXTENSION}/riscv64-unknown-elf-as
LINK    = ${TOOL_EXTENSION}/riscv64-unknown-elf-ld
OBJDUMP = ${TOOL_EXTENSION}/riscv64-unknown-elf-objdump
OBJCOPY = ${TOOL_EXTENSION}/riscv64-unknown-elf-objcopy
# Overridable: on macOS the prebuilt Srec2vmem (Linux x86-64 ELF) cannot run;
# export CONVERT="python3 .../tests/bin/srec2vmem.py" (see setup/local_setup.sh)
CONVERT		?=../tests/bin/Srec2vmem

SSRC = $(wildcard *.S)
sSRC = $(wildcard *.s)
CSRC = $(wildcard *.c)

OBJECTS = $(SSRC:%.S=%.o) $(sSRC:%.s=%.o) $(CSRC:%.c=%.o)

#INCDIR = -I/tools/cskytools/csky-abiv2-elf-tools-x86_64-20130312/csky-abiv2-elf/include -I.

# THEAD_GCC=1 (default): Xuantie GCC with xtheadc meta-extension + custom passes.
# THEAD_GCC=0: portable flags for upstream/xPack GCC (no xtheadc, no Xuantie-only
# options); used for local macOS builds (see setup/local_setup.sh).
THEAD_GCC ?= 1
COREMARK_ITER ?= 10000

FLAG_ABI =
ifeq (${THEAD_GCC}, 0)
#CPU_ARCH_FLAG_0 => CPU Arch: c906, c906fd, c906fdv
ifeq (${CPU_ARCH_FLAG_0}, c906)
  FLAG_MARCH = -march=rv64imac_zicsr_zifencei -mtune=thead-c906
  FLAG_ABI   = -mabi=lp64
else
  ifeq (${CPU_ARCH_FLAG_0}, c906fd)
    FLAG_MARCH = -march=rv64imafdc_zfh_zicsr_zifencei -mtune=thead-c906
    FLAG_ABI   = -mabi=lp64d
  else  # c906fdv
    FLAG_MARCH = -march=rv64imafdcv_zfh_zicsr_zifencei -mtune=thead-c906
    FLAG_ABI   = -mabi=lp64d
  endif
endif
else
FLAG_MARCH = -mtune=c906
#CPU_ARCH_FLAG_0 => CPU Arch: c906, c906fd, c906fdv
ifeq (${CPU_ARCH_FLAG_0}, c906)
  FLAG_MARCH += -march=rv64imac_zifencei_xtheadc
  FLAG_ABI   = -mabi=lp64
else
  ifeq (${CPU_ARCH_FLAG_0}, c906fd)
    FLAG_MARCH += -march=rv64imafdc_zfh_zifencei_xtheadc
    FLAG_ABI   = -mabi=lp64d
  else  # c906fdv
    FLAG_MARCH = -march=rv64imafdcv_zfh_zifencei_xtheadc
    FLAG_ABI   = -mabi=lp64d
  endif
endif
endif
CFLAGS = ${FLAG_MARCH} ${FLAG_ABI}

ifeq (${CASENAME}, coremark)
  ifeq (${THEAD_GCC}, 0)
    CFLAGS +=  -c -O3 -static -funroll-all-loops -finline-limit=500 -fgcse-sm -fno-schedule-insns --param max-rtl-if-conversion-unpredictable-cost=100 -fno-code-hoisting -DITERATIONS=${COREMARK_ITER} -Wno-error=implicit-function-declaration
  else
    CFLAGS +=  -c -O3 -mtune=c906 -static -funroll-all-loops -finline-limit=500 -fgcse-sm -fno-schedule-insns --param max-rtl-if-conversion-unpredictable-cost=100 -msignedness-cmpiv -fno-code-hoisting -mno-thread-jumps1 -mno-iv-adjust-addr-cost -mno-expand-split-imm -DITERATIONS=${COREMARK_ITER} -Wno-error=implicit-function-declaration
  endif
else
  CFLAGS += -c -O2
endif

CFLAGS += ${EXTRA_CFLAGS}

LINKFLAGS = -Tlinker.lcf -nostartfiles ${FLAG_MARCH} ${FLAG_ABI}

# LINKLIBS  = -L${TOOL_PATH}/lib/gcc/riscv64-unknown-elf/8.1.0/rv32imac
# LINKLIBS += -L${TOOL_PATH}/riscv64-unknown-elf/lib/rv32imac
# LINKLIBS += -L${TOOL_PATH}/riscv32-unknown-elf/lib

LINKLIBS = -lc -lgcc

OBJDUMPFLAGS = -S -Mnumeric

HEXFLAGS	= -O srec

%.o : %.c
	${CC} -c ${CFLAGS} -o $@ $<

%.o : %.s
	${CC} -c ${CFLAGS} -o $@ $<

%.o : %.S
	${CC} -c ${CFLAGS} -o $@ $<

${FILE}.elf : ${OBJECTS} linker.lcf
	${CC} ${LINKFLAGS} ${LINKLIBS} ${OBJECTS} -o $@ ${EXTRA_LDFLAGS} -lm

${FILE}.obj : ${FILE}.elf
	${OBJDUMP} ${OBJDUMPFLAGS} $< > $@

INST_HEX = ${FILE}_inst.hex
DATA_HEX = ${FILE}_data.hex
FILE_HEX = ${FILE}.hex

${FILE}.hex : ${FILE}.elf
	${OBJCOPY} ${HEXFLAGS} $< ${INST_HEX} -j .text*  -j .rodata* -j .eh_frame*
	${OBJCOPY} ${HEXFLAGS} $< ${DATA_HEX} -j .data*  -j .bss -j .COMMON
	${OBJCOPY} ${HEXFLAGS} $< $@ 

INST_PAT = inst.pat
DATA_PAT = data.pat
FILE_PAT = case.pat

%.pat	: %.hex
	rm -f *.pat
	${CONVERT} ${INST_HEX} ${INST_PAT}
	${CONVERT} ${DATA_HEX} ${DATA_PAT}
	${CONVERT} ${FILE_HEX} ${FILE_PAT}


#--------------------------------------------------------------------
# target setting
.PHONY :all
all : ${FILE}.pat ${FILE}.hex ${FILE}.elf ${FILE}.obj

#---------------------------------------------------------------------
# clean some medium code and .pat
.PHONY :clean 
clean:
	rm -rf *.o *.pat *.elf *.obj *.hex

