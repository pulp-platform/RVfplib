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
# Under Section 7 of GPL version 3, you are granted additional
# permissions described in the GCC Runtime Library Exception, version
# 3.1, as published by the Free Software Foundation.
#
# You should have received a copy of the GNU General Public License and
# a copy of the GCC Runtime Library Exception along with this program;
# see the files LICENSE.txt and LICENSE-EXCEPTION.txt respectively.  If not, see
# <http://www.gnu.org/licenses/>.  */

# RISC-V 64-bit mul, denormals flushed to 0

.global __muldf3

#define xl a0
#define xh a1
#define yl a2
#define yh a3

# Add two numbers stored in two and three regs (x1-x0 and y2-y1-y0).
# x1 and y2 are the most significant regs
# The MSb of x1 and y2 is zero
# Result stored in y2, y1, y0
# x1 and x0 can be overwritten
.macro ADD3Rto2T y2, y1, y0, x1, x0
	add \y0, \y0, \x0
	sltu \x0, \y0, \x0
	add \x1, \x1, \x0
	add \y1, \y1, \x1
	sltu \x1, \y1, \x1
	add \y2, \y2, \x1
.endm

# Add two numbers stored in two couples of regs (x1-x0 and y1-y0).
# x1 and y1 are the most significant regs
# The MSb of x1 and y1 is zero
# Result stored in y1-y0
# x1 and x0 can be overwritten
.macro ADD2Rto2R y1, y0, x1, x0
	add \y0, \y0, \x0
	sltu \x0, \y0, \x0
	add \x1, \x1, \x0
	add \y1, \y1, \x1
.endm

# Shift left by 1 a number stored in two registers
# MSB in x1
.macro SLLI1_2R x1, x0, a5
	slli \x1, \x1, 1
	srli \a5, \x0, 31
	or \x1, \x1, \a5
	slli \x0, \x0, 1
.endm

# Shift left by 1 a number stored in three registers
# MSB in x2
.macro SLLI1_3R x2, x1, x0, a5
	slli \x2, \x2, 1
	srli \a5, \x1, 31
	or \x2, \x2, \a5
	slli \x1, \x1, 1
	srli \a5, \x0, 31
	or \x1, \x1, \a5
	slli \x0, \x0, 1
.endm

# Mask out exponents, trap any zero/denormal/inf/NaN
__muldf3:
	xor a4, xh, yh                # Determine the final sign xor xh and yh to have also the correct sign
	lui a5, 0x80000               # Load 0x80000 mask for the sign
	and t0, a4, a5                # Isolate the product sign
	li a5, 0x7FF                  # Load mask to isolate the exponent
	srli a4, xh, 20               # Isolate sign and exponent of X
	and a4, a4, a5                # Isolate exp of X
	srli t1, yh, 20               # Isolate sign and exponent of Y
	and t1, t1, a5                # Isolate exp of Y
	beq a4, a5, inf_nan           # Jump if X is inf/NaN
	beq t1, a5, inf_nan           # Jump if Y is inf/NaN
	beqz a4, zero_denormal        # Jump if X is zero/denormal
	beqz t1, zero_denormal        # Jump if Y is zero/denormal

normal_case:
# Add exponents together
	add a4, a4, t1                # Add exponents together

# Convert mantissa to unsigned integer
	lui a5, 0xFFF00               # Mask to isolate mantissa
	not a5, a5                    # Mask to isolate mantissa
	and xh, xh, a5                # Isolate mantissa X
	and yh, yh, a5                # Isolate mantissa Y
	lui a5, 0x00100               # Prepare the implicit 1 mask
	or xh, xh, a5                 # Add the implicit 1 to X
	or yh, yh, a5                 # Add the implicit 1 to Y

# The actual multiplication.
# (xh*yh)<<64 + (xh*yl + xl*yh)<<32 + (xl*yl)
# Put the 128-bit result in xh-xl-yl-a5
# Todo: check if all these numbers are actually needed
# (xh*yl)<<32
# (xl*yh)<<32
# Add these two results together: mix the operations to fit in RV32E
	mul t1, xh, yl
	mul a5, xl, yh
	add t1, t1, a5
	sltu a5, t1, a5
	mulhu t2, xh, yl
	add t2, t2, a5
	mulhu a5, xl, yh
	add t2, t2, a5
# (xl*yl)
	mul a5, xl, yl
	mulhu yl, xl, yl
#(xh*yh)<<64
	mul xl, xh, yh
	mulhu xh, xh, yh
# Add together
	ADD3Rto2T xh, xl, yl, t2, t1

# LSBs in a5 are significant only for the final rounding. Merge them into yl
	snez a5, a5
	or yl, yl, a5

# Adjust the result upon the MSB position
	li t2, 512                       # Prepare the mask in position 10. t2 = 1 << 9
	bgeu xh, t2, 1f                  # Branch if there is no need for adjusting
	SLLI1_3R xh, xl, yl, a5          # Adjust: shift left the result by 1
	addi a4, a4, -1                  # Adjust the exponent after the shift

1:
# Shift to the final position and add the sign to result
	slli xh, xh, 11                  # Shift the implicit 1 in its correct position (position 21, shift by 11)
	srli a5, xl, 21                  # Save the bits of the lower P that should shift in the higher P
	or xh, xh, a5                    # Add the lower P shifted bits to higher P
	slli xl, xl, 11                  # Shift the lower part of the product by 11
	srli a5, yl, 21                  # Save the bits of R that should shift in the lower P
	or xl, xl, a5                    # Add the R bits to lower P
	slli yl, yl, 11                  # Shift R by 11

# Apply exponent bias and check exponent range for under/overflow
	addi a4, a4, -1023               # Apply exponent bias
	li t1, 2046                      # Prepare to check for under/over flow
	bgeu a4, t1, und_ov_flow         # We have either an underflow or an overflow

# Round the result, merge final exponent.
	slli a4, a4, 20                 # Bring the exponent to its position
	add xh, xh, a4                  # Add the exponent to the result (the implicit 1 is added)
rounding:
	lui a5, 0x80000                 # Prepare the mask for the RNE
	bltu yl, a5, exit               # Branch if we cannot guess to round up
	addi xl, xl, 1                  # Guess a first rounding up
	seqz t1, xl                     # Guess a first rounding up
	add xh, xh, t1                  # Guess a first rounding up
	bne yl, a5, exit                # Check for a tie -> in the case, RNE. Jump if there is no tie
	andi xl, xl, -2                 # RNE (we have already added 1)
exit:
	or xh, xh, t0                   # Add the correct sign to the result
	ret                             # Return

# Check for overflow/underflow
# If we are here, we ore either in ovf or in underflow
und_ov_flow:
# Overflow?
	blt x0, a4, inf                 # Branch to Ovf handling if an overflow occurred
# Underflow: return signed 0
	j signed_zero

# One or more arguments are either denormalized or zero
# a5 contains 0x000007FF
zero_denormal:
# Result is zero, but determine sign anyway
# a5 contains 0x80000000
signed_zero:
	mv xh, t0                     # Load correctly signed zero
zero_xl:
	li xl, 0                      # Append zero
	ret

# One or both args are inf or NaN
inf_nan:
	li t2, 0x7FF
# Return NaN if one of the operands is 0 or denormal
	slli a5, a4, 21
	beqz a5, nan
	slli a5, t1, 21
	beqz a5, nan
# Return NaN if one of the elements is a NaN
# a5 contains 0x000007FF
	bne a4, t2, 1f                # Jump away if X is not a Inf/Nan
	slli a5, xh, 12
	or a5, a5, xl
	bnez a5, nan                  # Jump away if X is NaN, return NaN
1:
	bne t1, t2, inf               # Jump away if Y is not a Inf/Nan
	slli a4, yh, 12
	or a4, a4, yl
	bnez a4, nan                  # Jump away if Y is NaN, return NaN

inf:
	lui xh, 0x7FF00               # Load inf pattern
	or xh, xh, t0
	j zero_xl

# Return a quiet NaN
nan:
	lui xh, 0x7FF80               # Load qNaN pattern
	j zero_xl
