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

# This script needs to be called from test32.sh

import sys
from fp_util import *

# Check if out is correct, considering golden_out
# All the arguments are binary strings, except for op, which is a string indicating the FUT (like "f32_add")
def check_op(in0, in1, out, out_g, operation, prec_in, prec_out):
    in0_b   = hex2bin(in0, prec_in)
    in1_b   = hex2bin(in1, prec_in)
    out_b   = hex2bin(out, prec_out)
    gold_b  = hex2bin(out_g, prec_out)

    if out_b == gold_b:
        return 1
    else:
        # Special cases
        if operation == 'f32_lt' or operation == 'f64_lt':
            # libgcc returns a value less than zero (lt). The actual values can also differ
            if int(out) < 0 and int(out_g) < 0 or int(out) >= 0 and int(out_g) >= 0:
                return 1
            else:
                return 0
        if operation == 'f32_le' or operation == 'f64_le':
            # libgcc returns a value less than or equal to 0 (le). The actual values can also differ
            # In the testing function, we are xoring the final bit to adapt to TestFloat interface. Xor it back here
            if int(out)^0x1 <= 0 and int(out_g)^0x1 <= 0 or int(out)^0x1 > 0 and int(out_g)^0x1 > 0:
                return 1
            else:
                return 0
        if operation == 'f32_ge' or operation == 'f64_ge':
            # libgcc returns a value less than or equal to 0 (le). The actual values can also differ
            # In the testing function, we are xoring the final bit to adapt to TestFloat interface. Xor it back here
            if int(out) >= 0 and int(out_g) >= 0 or int(out) < 0 and int(out_g) < 0:
                return 1
            else:
                return 0
        if operation == 'f32_gt' or operation == 'f64_gt':
            # libgcc returns a value less than or equal to 0 (le). The actual values can also differ
            # In the testing function, we are xoring the final bit to adapt to TestFloat interface. Xor it back here
            if int(out) > 0 and int(out_g) > 0 or int(out) <= 0 and int(out_g) <= 0:
                return 1
            else:
                return 0
        return 0

def check_op_nd(in0, in1, out, out_g, operation, prec_in, prec_out):
    in0_b   = hex2bin(in0, prec_in)
    in1_b   = hex2bin(in1, prec_in)
    out_b   = hex2bin(out, prec_out)
    gold_b  = hex2bin(out_g, prec_out)

    # Check if we need to analyze the non-standard cases
    if out_b == gold_b:
        return 1
    else:
        # Non standard cases
        # Disassemble the data
        if prec_in == '32':
            in0_s   = int(in0_b[0])
            in0_e   = in0_b[1:9]
            in0_m   = in0_b[9:32]
            in1_s   = int(in1_b[0])
            in1_e   = in1_b[1:9]
            in1_m   = in1_b[9:32]
        if prec_out == '32':
            if gold_b[0] == '-':
                out_g_s = 1
            else:
                out_g_s = int(gold_b[0])
            out_g_e = gold_b[1:9]
            out_g_m = gold_b[9:32]
            if out_b[0] == '-':
                out_s = 1
            else:
                out_s = int(out_b[0])
            out_e   = out_b[1:9]
            out_m   = out_b[9:32]
        if prec_in == '64':
            # Disassemble the data
            in0_s   = int(in0_b[0])
            in0_e   = in0_b[1:12]
            in0_m   = in0_b[12:64]
            in1_s   = int(in1_b[0])
            in1_e   = in1_b[1:12]
            in1_m   = in1_b[12:64]
        if prec_out == '64':
            if gold_b[0] == '-':
                out_g_s = 1
            else:
                out_g_s = int(gold_b[0])
            out_g_e = gold_b[1:12]
            out_g_m = gold_b[12:64]
            if out_b[0] == '-':
                out_s = 1
            else:
                out_s = int(out_b[0])
            out_e   = out_b[1:12]
            out_m   = out_b[12:64]

        # Addition special rules
        if operation == 'f32_add' or operation == 'f64_add':
            # Denormals are transformed into signed zeroes
            if isDenormal(in0_b, prec_in) and isDenormal(in1_b, prec_in) or isZero(in0_b, prec_in) and isDenormal(in1_b, prec_in) or isDenormal(in0_b, prec_in) and isZero(in1_b, prec_in):
                # If we add two denormals, they are considered as signed zeroes
                if isZero(out_b, prec_out):
                    # The result should be a correctly signed zero
                    if in0_s and in1_s:
                        # Two negative inputs
                        if out_s:
                            # Negative zero as result
                            return 1
                    else:
                        # The two inputs are not both negative
                        if not out_s:
                            # The result is a positive zero
                            return 1
            elif isDenormal(in0_b, prec_in) and not isDenormal(in1_b, prec_in):
                # If only one of the input is a denormal, the result is the other input
                if out_b == in1_b:
                    return 1
            elif not isDenormal(in0_b, prec_in) and isDenormal(in1_b, prec_in):
                # If only one of the input is a denormal, the result is the other input
                if out_b == in0_b:
                    return 1
            else:
                # No input is a denormal. A denormal output can be flushed to zero
                if isDenormal(gold_b, prec_out) and isZero(out_b, prec_out):
                    # The golden output is a denormal, and we have flushed to zero
                    if out_s == out_g_s:
                        # The sign is correct
                        return 1

        # Subtraction special rules
        elif operation == 'f32_sub' or operation == 'f64_sub':
            # Denormals are transformed into signed zeroes
            if isDenormal(in0_b, prec_in) and isDenormal(in1_b, prec_in) or isZero(in0_b, prec_in) and isDenormal(in1_b, prec_in) or isDenormal(in0_b, prec_in) and isZero(in1_b, prec_in):
                # If we sub two denormals, they are considered as signed zeroes
                if isZero(out_b, prec_out):
                    # The result should be a correctly signed zero
                    if in0_s and not in1_s:
                        # Negative and positive inputs
                        if out_s:
                            # Negative zero as result
                            return 1
                    else:
                        # The two inputs are not - and +
                        if not out_s:
                            # The result is a positive zero
                            return 1
            elif isDenormal(in0_b, prec_in) and not isDenormal(in1_b, prec_in):
                # If only one of the input is a denormal, the result is the other input, negated
                if out_s != in1_s and out_e == in1_e and out_m == in1_m:
                    return 1
            elif not isDenormal(in0_b, prec_in) and isDenormal(in1_b, prec_in):
                # If only one of the input is a denormal, the result is the other input
                if out_b == in0_b:
                    return 1
            else:
                # No input is a denormal. A denormal output can be flushed to zero
                if isDenormal(gold_b, prec_out) and isZero(out_b, prec_out):
                    # The golden output is a denormal, and we have flushed to zero
                    if out_s == out_g_s:
                        # The sign is correct
                        return 1

        # Multiplication special rules
        elif operation == 'f32_mul' or operation == 'f64_mul':
            # Denormal times infinity becomes a NaN when the denormal is considered a zero
            if isNan(out_b, prec_out) and isInf(gold_b, prec_out):
                if (isDenormal(in0_b, prec_in) and isInf(in1_b, prec_in)) or (isDenormal(in1_b, prec_in) and isInf(in0_b, prec_in)):
                    return 1
            else:
                # The output sign should always be correct
                if out_s == out_g_s:
                    # Denormals are transformed into signed zeroes
                    if isDenormal(in0_b, prec_in) or isDenormal(in1_b, prec_in):
                        # If one of the input is a denormal, the result is a correctly signed zero
                        if isZero(out_b, prec_out):
                            return 1
                    else:
                        # No input is a denormal. A denormal output can be flushed to zero
                        if isZero(out_b, prec_out):
                            if isDenormal(gold_b, prec_out):
                                return 1
                            else:
                                # A denormal result that would become a normal only after the rounding, can be flushed to zero
                                if out_m == out_g_m and int(out_g_e) == 1 and int(out_e) == 0:
                                    return 1

        # Multiplication special rules
        elif operation == 'f32_div' or operation == 'f64_div':
            # Denormal/Denormal is NaN, since denormal == 0
            if isZeroDenormal(in0_b, prec_in) and isZeroDenormal(in1_b, prec_in) and isNan(out_b, prec_out):
                return 1
            # The output sign should always be correct
            if out_s == out_g_s:
                # Denormals are transformed into signed zeroes
                if isDenormal(in0_b, prec_in) and isZero(out_b, prec_out):
                    # If dividend is a denormal and divisor is not zero/denormal, the result is a correctly signed zero
                    return 1
                if isDenormal(in1_b, prec_in) and isInf(out_b, prec_out):
                    return 1
                if isZero(out_b, prec_out) and isDenormal(gold_b, prec_out):
                    return 1
                # A denormal result that would become normal only after the rounding, can be flushed to zero
                if out_m == out_g_m and int(out_g_e) == 1 and int(out_e) == 0:
                    return 1

        # Special cases
        elif operation == 'f64_eq' or operation == 'f64_ne':
            # libgcc returns a value less than zero (lt). The actual values can also differ
            if isInf(in0_b, prec_in) or isInf(in1_b, prec_in):
                return 1
            return 0
        # Special cases
        elif operation == 'f64_lt':
            # libgcc returns a value less than zero (lt). The actual values can also differ
            if int(out) < 0 and int(out_g) < 0 or int(out) >= 0 and int(out_g) >= 0:
                return 1
            else:
                if isInf(in0_b, prec_in) or isInf(in1_b, prec_in):
                    return 1
                return 0
        elif operation == 'f64_le':
            # libgcc returns a value less than or equal to 0 (le). The actual values can also differ
            # In the testing function, we are xoring the final bit to adapt to TestFloat interface. Xor it back here
            if int(out)^0x1 <= 0 and int(out_g)^0x1 <= 0 or int(out)^0x1 > 0 and int(out_g)^0x1 > 0:
                return 1
            else:
                if isInf(in0_b, prec_in) or isInf(in1_b, prec_in):
                    return 1
                return 0
        elif operation == 'f64_gt':
            # libgcc returns a value less than zero (lt). The actual values can also differ
            if int(out) > 0 and int(out_g) > 0 or int(out) <= 0 and int(out_g) <= 0:
                return 1
            else:
                if isInf(in0_b, prec_in) or isInf(in1_b, prec_in):
                    return 1
                return 0
        elif operation == 'f64_ge':
            # libgcc returns a value less than or equal to 0 (le). The actual values can also differ
            # In the testing function, we are xoring the final bit to adapt to TestFloat interface. Xor it back here
            if int(out) >= 0 and int(out_g) >= 0 or int(out) < 0 and int(out_g) < 0:
                return 1
            else:
                if isInf(in0_b, prec_in) or isInf(in1_b, prec_in):
                    return 1
                return 0

        else:
            return 0

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
            in0      = out_line[0]
            in1      = out_line[1]
            out      = out_line[2]
            gold_out = golden_line[2]
            # Check
            if ND == 'nd':
                line_ok = check_op_nd(in0, in1, out, gold_out, FUT, PREC_IN, PREC_OUT)
            else:
                line_ok = check_op(in0, in1, out, gold_out, FUT, PREC_IN, PREC_OUT)
            # Print comparison result
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
