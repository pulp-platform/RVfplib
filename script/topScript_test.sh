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

# Test the rvfplib functions
# Uncomment a line to test the corresponding function, otherwise comment it

# FORMAT
# test_script      | function_name          | lib_version | skip_testfloat | inputs_precision | output_precision | number_of_inputs | testing_depth | optimization        | [rounding mode]
# ./script/test.sh | [f32_add, f32_eq, ...] | [std, nd]   | [0, 1]         | [32, 64]         | [32, 64]]        | [1, 2]           | [1, 2]        | [size, performance] | [ , -rminMag]

# Hardcode this variable to optimize on performance or on size, otherwise it's up to the caller.
LIB_OPT=$1
#LIB_OPT=performance
#LIB_OPT=size

### Standard
./script/test.sh f32_add     std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_sub     std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_mul     std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_div     std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_eq      std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_le      std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_lt      std 1 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_ne      std 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_ge      std 1 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_gt      std 1 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_to_i32  std 0 32 32 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f32_to_ui32 std 0 32 32 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f32_to_i64  std 0 32 64 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f32_to_ui64 std 0 32 64 1 1 $LIB_OPT -rminMag &&\
./script/test.sh i32_to_f32  std 0 32 32 1 1 $LIB_OPT          &&\
./script/test.sh ui32_to_f32 std 0 32 32 1 1 $LIB_OPT          &&\
./script/test.sh i64_to_f32  std 0 64 32 1 1 $LIB_OPT          &&\
./script/test.sh ui64_to_f32 std 0 64 32 1 1 $LIB_OPT          &&\
./script/test.sh f64_add     std 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_sub     std 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_mul     std 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_div     std 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_eq      std 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_le      std 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_lt      std 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_ne      std 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_ge      std 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_gt      std 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_to_i32  std 0 64 32 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f64_to_ui32 std 0 64 32 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f64_to_i64  std 0 64 64 1 1 $LIB_OPT -rminMag &&\
./script/test.sh f64_to_ui64 std 0 64 64 1 1 $LIB_OPT -rminMag &&\
./script/test.sh i32_to_f64  std 0 32 64 1 1 $LIB_OPT          &&\
./script/test.sh ui32_to_f64 std 0 32 64 1 1 $LIB_OPT          &&\
./script/test.sh i64_to_f64  std 0 64 64 1 1 $LIB_OPT          &&\
./script/test.sh ui64_to_f64 std 0 64 64 1 1 $LIB_OPT          &&\
./script/test.sh f32_to_f64  std 0 32 64 1 1 $LIB_OPT          &&\
./script/test.sh f64_to_f32  std 0 64 32 1 1 $LIB_OPT          &&\
### RV32EM, no-denormal
./script/test.sh f32_add      nd 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_sub      nd 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_mul      nd 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_div      nd 0 32 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_add      nd 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_sub      nd 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_mul      nd 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_div      nd 0 64 64 2 1 $LIB_OPT          &&\
./script/test.sh f64_eq       nd 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_le       nd 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_lt       nd 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_ne       nd 0 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_ge       nd 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f64_gt       nd 1 64 32 2 1 $LIB_OPT          &&\
./script/test.sh f32_to_f64   nd 0 32 64 1 1 $LIB_OPT          &&\
./script/test.sh f64_to_f32   nd 0 64 32 1 1 $LIB_OPT          &&\

echo "Test for optimization=$LIB_OPT completed"
