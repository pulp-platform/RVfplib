#!/usr/bin/env bash

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

# This script allows testing the standard versions of the FP lib function
# This is only a wrapper to generate inputs for the test, the IEEE-compliant output and the output of the function under test

# This script should be launched from the root folder, e.g. from the same level of the test/ folder

# Function Under Test. SoftFloat format (e.g. f32_add)
FUT=$1
# Pass nd to test the no-denormal function. Pass any other string for the standard one
ND=$2
# Some functions do not have a respective in TestFloat or are problematic. Compare only against libgcc
NO_TESTFLOAT_CHECK=$3
# FP precision of the function inputs. Can be either 32 or 64. e.g., if FUT=f32_add, PREC_IN must be 32
PREC_IN=$4
# FP precision of the function output. Can be either 32 or 64. e.g., if FUT=f32_add, PREC_OUT must be 32
PREC_OUT=$5
# Number of inputs of the function. e.g., f32_add has N_IN=2
N_IN=$6
# Testing depth. It can be either 1 (superficial tests) or 2 (deep tests)
LV=$7
# Library optimization. It can be either performance or size.
LIB_OPT=$8
# Rounding mode, in TestFloat argument format (e.g. -rminMag). Leave empty not to pass any argument (default is RNE)
RND=$9

if [[ "$ND" == "std" && "$LIB_OPT" == "performance" ]] ; then
  LIB="-lrvfp"
elif [[ "$ND" == "nd" && "$LIB_OPT" == "performance" ]] ; then
  LIB="-lrvfp_nd"
elif [[ "$ND" == "std" && "$LIB_OPT" == "size" ]]; then
  LIB="-lrvfp_s"
elif [[ "$ND" == "nd" && "$LIB_OPT" == "size" ]]; then
  LIB="-lrvfp_nd_s"
fi
# Variables
BIN_PATH="test/${FUT}_${ND}_${LIB_OPT}/bin/"
G_BIN_PATH="$BIN_PATH/check/"
BIN="$BIN_PATH/$FUT.test"
G_BIN="$G_BIN_PATH/$FUT.test"
DUMP="$BIN_PATH/$FUT.dump"
G_DUMP="$G_BIN_PATH/$FUT.dump"
SRC="src/c/$FUT/main.c"
INC_PATH="include"
LIB_PATH="build/lib"
OUT_PATH="test/${FUT}_${ND}_${LIB_OPT}/out/"
G_OUT_PATH="$OUT_PATH/golden/"
IN_PATH="test/${FUT}_${ND}_${LIB_OPT}/in"
IN="$IN_PATH/in.txt"
OUT="$OUT_PATH/out.txt"
G_OUT="$G_OUT_PATH/out.txt"
GCC_PREFIX="${GCC_TOOLS_BIN_PATH}/riscv32-unknown-elf"
SPIKE="${SPIKE_PATH} --isa=rv32imc ${PK_PATH}"

# nesf2, gesf2, gtsf2, ... special cases. Alias with the respective (opposite) SoftFloat functions
SF_FUT=$FUT
if [[ "$(echo $FUT | cut -d '_' -f 2)" == "ne" ]] ; then
  SF_FUT="f${PREC_IN}_eq"
elif [[ "$(echo $FUT | cut -d '_' -f 2)" == "gt" ]] ; then
  SF_FUT="f${PREC_IN}_lt"
elif [[ "$(echo $FUT | cut -d '_' -f 2)" == "ge" ]] ; then
  SF_FUT="f${PREC_IN}_le"
fi

# Make the library
make -s clean
make -s

# Create the folder structure, if not present
mkdir -p $BIN_PATH
mkdir -p $G_BIN_PATH
mkdir -p $G_OUT_PATH
mkdir -p $IN_PATH

# Compile the two programs and obtain their dumps
$GCC_PREFIX-gcc -march=rv32imc -mabi=ilp32 -I $INC_PATH -L $LIB_PATH $SRC $LIB -o $BIN
$GCC_PREFIX-gcc -march=rv32imc -mabi=ilp32 -I $INC_PATH $SRC -o $G_BIN
$GCC_PREFIX-objdump -xD $BIN > $DUMP
$GCC_PREFIX-objdump -xD $G_BIN > $G_DUMP

# Generate input
testfloat_gen -level $LV $RND $SF_FUT > $IN

# Process the input with the golden model
cat $IN | $SPIKE $G_BIN > $G_OUT
# Remove the first output line (trash from spike)
tail -n +2 $G_OUT > $G_OUT.tmp
mv $G_OUT.tmp $G_OUT

# Process the input with the FUT
cat $IN | $SPIKE $BIN > $OUT
# Remove the first output line (trash from spike)
tail -n +2 $OUT > $OUT.tmp
mv $OUT.tmp $OUT

# Double check the result
# Check with libgcc and TestFloat. Use scripts+libgcc only if testing the no-denormal version
if [[ "$ND" == "std" && "${NO_TESTFLOAT_CHECK}" == "0" ]] ; then
  cat $OUT | testfloat_ver $RND $SF_FUT
fi
if [[ "$N_IN" == "1" ]] ; then
  ./script/check1.py $FUT $ND $PREC_IN $PREC_OUT $OUT $G_OUT
else
  ./script/check2.py $FUT $ND $PREC_IN $PREC_OUT $OUT $G_OUT
fi
