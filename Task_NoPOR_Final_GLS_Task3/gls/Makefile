# SPDX-FileCopyrightText: 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

# removing pdk path as everything has been included in one whole directory for this example.
# PDK_PATH = $(PDK_ROOT)/$(PDK)
scl_io_PATH = "/home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/iopad/cio250/4M1L/verilog/tsl18cio250/zero"
VERILOG_PATH = ../
RTL_PATH = $(VERILOG_PATH)/gl
BEHAVIOURAL_MODELS = ../gls
RISCV_TYPE ?= rv32imc
PDK_PATH= /home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/4M1IL/verilog/vcs_sim_model 
FIRMWARE_PATH = ../gls
GCC_PATH?=/usr/gcc/bin
GCC_PREFIX?=riscv32-unknown-elf

SIM_DEFINES = \
	+define+FUNCTIONAL \
	+define+SIM \
	+define+GLS

SIM?=gl

.SUFFIXES:

PATTERN = hkspi

vvp:  ${PATTERN:=.vvp}

hex:  ${PATTERN:=.hex}

vcd:  ${PATTERN:=.vcd}


SIMV = simv
TOP_TB = hkspi_tb.v

gls:
	vcs -sverilog -full64 \
	    -debug_access+all \
	    +neg_tchk \
	    +sdfverbose \
	    $(SIM_DEFINES) \
	    +incdir+$(VERILOG_PATH)/synthesis/output \
	    +incdir+$(BEHAVIOURAL_MODELS) \
	    +incdir+$(scl_io_PATH) \
	    +incdir+$(PDK_PATH) \
	    +incdir+$(VERILOG_PATH) \
	    +incdir+$(RTL_PATH) \
	    $(VERILOG_PATH)/synthesis/output/*.v \
	    $(PDK_PATH)/*.v \
	    $(TOP_TB) \
	    -o $(SIMV)

gls_run: gls
	./$(SIMV)




%.elf: %.c $(FIRMWARE_PATH)/sections.lds $(FIRMWARE_PATH)/start.s
	${GCC_PATH}/${GCC_PREFIX}-gcc -march=$(RISCV_TYPE) -mabi=ilp32 -Wl,-Bstatic,-T,$(FIRMWARE_PATH)/sections.lds,--strip-debug -ffreestanding -nostdlib -o $@ $(FIRMWARE_PATH)/start.s $<

%.hex: %.elf
	${GCC_PATH}/${GCC_PREFIX}-objcopy -O verilog $< $@ 
	# to fix flash base address
	sed -i 's/@10000000/@00000000/g' $@

%.bin: %.elf
	${GCC_PATH}/${GCC_PREFIX}-objcopy -O binary $< /dev/stdout | tail -c +1048577 > $@

check-env:
#ifndef PDK_ROOT
#	$(error PDK_ROOT is undefined, please export it before running make)
#endif
#ifeq (,$(wildcard $(PDK_ROOT)/$(PDK)))
#	$(error $(PDK_ROOT)/$(PDK) not found, please install pdk before running make)
#endif
ifeq (,$(wildcard $(GCC_PATH)/$(GCC_PREFIX)-gcc ))
	$(error $(GCC_PATH)/$(GCC_PREFIX)-gcc is not found, please export GCC_PATH and GCC_PREFIX before running make)
endif
# check for efabless style installation
ifeq (,$(wildcard $(PDK_ROOT)/$(PDK)/libs.ref/*/verilog))
#SIM_DEFINES := ${SIM_DEFINES} -DEF_STYLE
endif
# ---- Clean ----

clean:
	#rm -f *.elf *.hex *.bin *.vcd *.log

.PHONY: clean hex vvp vcd

