# Copyright ETH Zurich 2020
#
# Author: Matteo Perotti
#
# This file is part of rvfplib.
#
# rvfplib is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# rvfplib is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with rvfplib  If not, see <https://www.gnu.org/licenses/>.
# Copyright ETH Zurich 2020

# rvfplib Makefile
# Build the default lib optimized for performance (librvfp.a), and the lib optimized for size (librvfp_s.a), in both the standard and non-subnormal versions

LIB_NAME       := librvfp
LIB_ND_NAME    := librvfp_nd

CC             := riscv32-unknown-elf-gcc
CCFLAGS        := -march=rv32imc -mabi=ilp32
OBJDUMP        := riscv32-unknown-elf-objdump

PERF_FLAG      := -DPERFORMANCE=1
SIZE_FLAG      := -DSIZE=1

BUILD_DIR      := build
LIB_DIR        := $(BUILD_DIR)/lib
SRC_DIR        := src/asm/ieee754
SRC_ND_DIR     := src/asm/ieee754_nd
OBJ_DIR        := $(BUILD_DIR)/obj
OBJ_ND_DIR     := $(BUILD_DIR)/obj_nd
OBJ_S_DIR      := $(BUILD_DIR)/obj_s
OBJ_ND_S_DIR   := $(BUILD_DIR)/obj_nd_s

SRC_FILES      := $(wildcard $(SRC_DIR)/*.S)
SRC_ND_FILES   := $(wildcard $(SRC_ND_DIR)/*.S)
OBJ_FILES      := $(patsubst $(SRC_DIR)/%.S, $(OBJ_DIR)/%.o, $(SRC_FILES))
OBJ_ND_FILES   := $(patsubst $(SRC_ND_DIR)/%.S, $(OBJ_ND_DIR)/%.o, $(SRC_ND_FILES))
OBJ_S_FILES    := $(patsubst $(SRC_DIR)/%.S, $(OBJ_S_DIR)/%.o, $(SRC_FILES))
OBJ_ND_S_FILES := $(patsubst $(SRC_ND_DIR)/%.S, $(OBJ_ND_S_DIR)/%.o, $(SRC_ND_FILES))
LIB            := $(LIB_DIR)/$(LIB_NAME).a
LIB_ND         := $(LIB_DIR)/$(LIB_ND_NAME).a
LIB_S          := $(LIB_DIR)/$(LIB_NAME)_s.a
LIB_ND_S       := $(LIB_DIR)/$(LIB_ND_NAME)_s.a

DUMP           := $(LIB_DIR)/$(LIB_NAME).dump
DUMP_ND        := $(LIB_DIR)/$(LIB_ND_NAME).dump
DUMP_S         := $(LIB_DIR)/$(LIB_NAME)_s.dump
DUMP_ND_S      := $(LIB_DIR)/$(LIB_ND_NAME)_s.dump

.PHONY: all
.PHONY: size
.PHONY: performance
.PHONY: clean
.PHONY: build_dirs

all: performance size

performance: CCFLAGS += $(PERF_FLAG)
performance: build_dirs $(LIB) $(LIB_ND) $(DUMP) $(DUMP_ND)

size: CCFLAGS += $(SIZE_FLAG)
size: build_dirs $(LIB_S) $(LIB_ND_S) $(DUMP_S) $(DUMP_ND_S)

$(DUMP): $(LIB)
	$(OBJDUMP) -xD $^ > $@
$(DUMP_ND): $(LIB_ND)
	$(OBJDUMP) -xD $^ > $@

$(DUMP_S): $(LIB_S)
	$(OBJDUMP) -xD $^ > $@
$(DUMP_ND_S): $(LIB_ND_S)
	$(OBJDUMP) -xD $^ > $@

$(LIB): $(OBJ_FILES)
	$(AR) rcs $@ $^
$(LIB_ND): $(OBJ_ND_FILES)
	$(AR) rcs $@ $^

$(LIB_S): $(OBJ_S_FILES)
	$(AR) rcs $@ $^
$(LIB_ND_S): $(OBJ_ND_S_FILES)
	$(AR) rcs $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.S
	$(CC) $(CCFLAGS) -c $< -o $@
$(OBJ_ND_DIR)/%.o: $(SRC_ND_DIR)/%.S
	$(CC) $(CCFLAGS) -c $< -o $@

$(OBJ_S_DIR)/%.o: $(SRC_DIR)/%.S
	$(CC) $(CCFLAGS) -c $< -o $@
$(OBJ_ND_S_DIR)/%.o: $(SRC_ND_DIR)/%.S
	$(CC) $(CCFLAGS) -c $< -o $@

build_dirs:
	mkdir -p $(OBJ_DIR) $(OBJ_ND_DIR) $(OBJ_S_DIR) $(OBJ_ND_S_DIR) $(LIB_DIR)

clean:
	rm -rf $(BUILD_DIR)
