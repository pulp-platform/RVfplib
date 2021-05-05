#!/usr/bin/env python3

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

# This script needs to be called from test64.sh

import sys
from fp_util import *

# Check if out is correct, considering golden_out
# Avoid fp comparisons, they can be misleading
# All the arguments are binary strings, except for op, which is a string indicating the FUT (like "f32_add")
def check_op(in0, out, out_g, operation, prec_in, prec_out):
    # Check if we need to analyze the non-standard cases
    if out_g == out:
        # Strings are equal or they are both NaN
        return 1
    else:
        if operation == 'f32_to_f64' or operation == 'f64_to_f32':
            if isNan(out, prec_out) and isNan(out_g, prec_out):
                return 1
        return 0

def check_op_nd(in0, out, out_g, operation, prec_in, prec_out):
    # Check if we need to analyze the non-standard cases
    if out_g == out:
        # Strings are equal or they are both NaN
        return 1
    else:
        if operation == 'f32_to_f64' or operation == 'f64_to_f32':
            if isDenormal(in0, prec_in) and isZero(out, prec_out):
                return 1
        if operation == 'f64_to_f32':
            if isDenormal(out_g, prec_out) and isZero(out, prec_out):
                return 1
            if isZero(out, prec_out) and out[0] == '0' and out_g == '00000000100000000000000000000000' or isZero(out, prec_out) and out[0] == '1' and out_g == '10000000100000000000000000000000':
                # This is a denormal input, that would become a normalized value only after rounding. Treated as a denormal.
                return 1
            if isNan(out, prec_out) and isNan(out_g, prec_out):
                return 1
        return 0

def main():
    # Output from FUT and Golden Model
    FUT        = sys.argv[1]
    ND         = sys.argv[2]
    PREC_IN    = sys.argv[3]
    PREC_OUT   = sys.argv[4]
    OUT_PATH   = sys.argv[5]
    G_OUT_PATH = sys.argv[6]

    # No error detected
    error = 0
    with open(OUT_PATH, "r") as out, open(G_OUT_PATH, "r") as gout:
        for out_line, golden_line in zip(out, gout):
            out_line = out_line.split()
            golden_line = golden_line.split()
            # Convert data to binary
            in_b    = hex2bin(out_line[0], PREC_IN)
            out_b   = hex2bin(out_line[1], PREC_OUT)
            gold_b  = hex2bin(golden_line[1], PREC_OUT)
            # Check
            if ND == 'nd':
                line_ok = check_op_nd(in_b, out_b, gold_b, FUT, PREC_IN, PREC_OUT)
            else:
                line_ok = check_op(in_b, out_b, gold_b, FUT, PREC_IN, PREC_OUT)
            # Output potential error
            if not line_ok:
                print('Error detected. FUT line: ')
                print(out_line)
                print('is not compatible with golden line: ')
                print(golden_line)
                print('\n')
                error = 1

    if not error:
        print('{} - test against libgcc successful.'.format(FUT))
    else:
        print('{} - test against libgcc failed.'.format(FUT))

if __name__ == '__main__':
    main()
