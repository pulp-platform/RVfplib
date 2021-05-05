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

# RISC-V 64-bit mul

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

#ifdef PERFORMANCE

# Mask out exponents, trap any zero/denormal/inf/NaN
__muldf3:
	li a5, 0x7FF                  # Load mask to isolate the exponent
	srli a4, xh, 20               # Isolate sign and exponent of X
	and a4, a4, a5                # Isolate exp of X
	srli a6, yh, 20               # Isolate sign and exponent of Y
	and a6, a6, a5                # Isolate exp of Y
	beq a4, a5, inf_nan           # Jump if X is inf/NaN
	beq a6, a5, inf_nan           # Jump if Y is inf/NaN
	beqz a4, zero_denormal        # Jump if X is zero/denormal
	beqz a6, zero_denormal        # Jump if Y is zero/denormal

normal_case:
# Add exponents together
	add a4, a4, a6                # Add exponents together

# Determine final sign
	xor a6, xh, yh                # Xor xh and yh to have also the correct sign
	lui a5, 0x80000               # Load 0x80000 mask for the sign
	and t0, a6, a5                # Isolate the product sign

# Convert mantissa to unsigned integer
# If we have a power of two, branch to a separate path
	lui a5, 0xFFF00               # Mask to isolate mantissa
	not a5, a5                    # Mask to isolate mantissa
	and xh, xh, a5                # Isolate mantissa X
	and yh, yh, a5                # Isolate mantissa Y
#ifdef POW2
	or a5, xh, xl
	beqz a5, pow_2                # Branch if X is a power of 2
	or a5, yh, yl
	beqz a5, pow_2                # Branch if Y is a power of 2
#endif
	lui a5, 0x00100               # Prepare the implicit 1 mask
	or xh, xh, a5                 # Add the implicit 1 to X
	or yh, yh, a5                 # Add the implicit 1 to Y

# The actual multiplication.
# (xh*yh)<<64 + (xh*yl + xl*yh)<<32 + (xl*yl)
# Put the 128-bit result in a7-a6-t4-t3
# Todo: check if all these numbers are actually needed
# (xh*yl)<<32
	mul t1, xh, yl
	mulhu t2, xh, yl
# (xl*yh)<<32
	mul a6, xl, yh
	mulhu a7, xl, yh
# Add these two results together
	ADD2Rto2R t2, t1, a7, a6
# (xl*yl)
	mul t3, xl, yl
	mulhu t4, xl, yl
#(xh*yh)<<64
	mul a6, xh, yh
	mulhu a7, xh, yh
# Add together
	ADD3Rto2T a7, a6, t4, t2, t1

# LSBs in t3 are significant only for the final rounding. Merge them into t4.
	snez a5, t3
	or t4, t4, a5

# Adjust the result upon the MSB position
	li t2, 512                       # Prepare the mask in position 10. t2 = 1 << 9
	bgeu a7, t2, 1f                  # Branch if there is no need for adjusting
	SLLI1_3R a7, a6, t4, a5          # Adjust: shift left the result by 1
	addi a4, a4, -1                  # Adjust the exponent after the shift

1:
# Shift to the final position and add the sign to result
	slli xh, a7, 11                  # Shift the implicit 1 in its correct position (position 21, shift by 11)
	srli a5, a6, 21                  # Save the bits of the lower P that should shift in the higher P
	or xh, xh, a5                    # Add the lower P shifted bits to higher P
	slli xl, a6, 11                  # Shift the lower part of the product by 11
	srli a5, t4, 21                  # Save the bits of R that should shift in the lower P
	or xl, xl, a5                    # Add the R bits to lower P
	slli t4, t4, 11                  # Shift R by 11

# Apply exponent bias and check exponent range for under/overflow
	addi a4, a4, -1023               # Apply exponent bias
	li t1, 2046                      # Prepare to check for under/over flow
	bgeu a4, t1, und_ov_flow         # We have either an underflow or an overflow

# Round the result, merge final exponent.
	slli a4, a4, 20                 # Bring the exponent to its position
	add xh, xh, a4                  # Add the exponent to the result (the implicit 1 is added)
rounding:
	lui a5, 0x80000                 # Prepare the mask for the RNE
	bltu t4, a5, exit               # Branch if we cannot guess to round up
	addi xl, xl, 1                  # Guess a first rounding up
	seqz t1, xl                     # Guess a first rounding up
	add xh, xh, t1                  # Guess a first rounding up
	bne t4, a5, exit                # Check for a tie -> in the case, RNE. Jump if there is no tie
	andi xl, xl, -2                 # RNE (we have already added 1)
exit:
	or xh, xh, t0                   # Add the correct sign to the result
	ret                             # Return

#ifdef POW2
# Multiplication by 0x1p*: let's shortcut a lot of code
pow_2:
	or xh, xh, yh                   # Multiply
	or xl, xl, yl                   # Multiply
	addi a4, a4, -1023              # Apply exponent bias to have a correct exponent
	bge x0, a4, pre_under_ov_flow   # Branch if an underflow occurred
	li t1, 2047                     # Prepare mask for overflow
	bge a4, t1, pre_under_ov_flow   # Branch if an overflow occurred
	slli a4, a4, 20                 # Shift the exponent to the correct position
	or xh, xh, a4                   # Apply the exponent to the result
	or xh, xh, t0                   # Add the correct sign to the result
	ret                             # Return

# Under/Overflow: fix things up for the code below
pre_under_ov_flow:
	lui a5, 0x00100                 # Load implicit 1 pattern
	or xh, xh, a5                   # Load implicit 1 into the result
	li t4, 0                        # Reg containing the Round bit and the Stickies
	addi a4, a4, -1                 # Decrement the exponent by one
#endif

# Check for overflow/underflow
# If we are here, we ore either in ovf or in underflow
und_ov_flow:
# Overflow?
	blt x0, a4, pre_ovf                 # Branch to Ovf handling if an overflow occurred

# Check if denormlized result is possible, otherwise return signed 0
	li t1, -53                      # Prepare condition
	bge a4, t1, denormal_end        # Can we return something different than zero? Branch if yes.
# Return signed 0
	li xl, 0                        # Clear the lower P
	mv xh, t0                       # Return signed 0
	ret

# Shift value right, round, etc.
# If we are here, (-53 <= a4 <= -1)
denormal_end:
	neg a4, a4                      # Find shamt = |exp|
# (1 <= shamt <= 53)
	li a5, 32
	bge a4, a5, 1f                  # Branch away if (32 <= shamt <= 53)
# We do not need a preshift
	sub a5, a5, a4                  # Find the complementary shamt

# (1 <= shamt <= 20). We need a right shift.
# OR
# (21 <= shamt <= 31). We need a fake 32-bit preshift and a left shift
3:
	snez a2, t4                     # Concentrate a partial sticky bit in t1
	sll t4, xl, a5                 # Setup the round bit and the other sticky bits
	or t4, t4, a2                   # Append the partial sticky bit to the others
	srl xl, xl, a4                 # Right shift xl by the correct amount
	sll a2, xh, a5                 # Left shift xh after a fake 32-bit preshift
	or xl, xl, a2                   # Append it to xl
	srl xh, xh, a4                 # Right shift xh
	j rounding                      # Round

# (32 <= shamt <= 53). We need a 32-bit preshift and a right shift
1:
	addi a4, a4, -32                # Adjust the exponent taking into account the 32-bit preshift
# Preshift by 32-bit
	snez a2, t4
	mv t4, xl
	mv xl, xh
	li xh, 0
	or t4, t4, a2
	beqz a4, rounding               # Branch away if shamt was 32.
# (1 < shamt <= 21) with a previous 32-bit preshift.
	sub a5, a5, a4                  # Find the complementary shamt
# Right shift by shamt
	j 3b

# One or both arguments are denormalized. No one of them is zero.
# Scale them leftwards and preserve sign bit
# a5 contains 0x80000000
denormal:
	srli t3, a5, 11               # Prepare the implicit 1
# Check if X is denormalized
	and t1, xh, a5                # Extract sign of X
	bnez a4, 3f                   # Branch if X is not a denormal
# X is denormalized
2:
	SLLI1_2R xh, xl, t5           # Shift left X by 1 position
	and t2, xh, t3                # Implicit 1 restored?
	bnez t2, 3f                   # Branch if the implicit 1 is restored
	addi a4, a4, -1               # Subtract 1 from X exponent
	j 2b
3:
	or xh, xh, t1                 # Restore X sign
# Check if Y is denormalized
	and a5, a5, yh                # Extract sign of Y
	bnez a6, 5f                   # Jump if Y is not denormal
# Y is denormalized
4:
	SLLI1_2R yh, yl, t5           # Shift left Y by 1 position
	and t2, yh, t3                # Implicit 1 restored?
	bnez t2, 5f                   # Branch if the implicit 1 is restored
	addi a6, a6, -1               # Subtract 1 from Y exponent
	j 4b
5:
	or yh, yh, a5                 # Restore Y sign
	j normal_case

# One or more arguments are either denormalized or zero
# a5 contains 0x000007FF
zero_denormal:
# Check if X or Y is zero. If none of them is, one of them is denormal
	slli a5, a5, 31               # Prepare mask for the sign. a5 = 0x80000000
	not t3, a5                    # Mask for the sign. t3 = 0x7FFFFFFF
	and a7, xh, t3
	or a7, a7, xl
	beqz a7, zero                 # Return zero if X is zero
	and a7, yh, t3
	or a7, a7, yl
	bnez a7, denormal             # Go on and return zero if Y is zero, otherwise, jump to denormal

# Result is zero, but determine sign anyway
# a5 contains 0x80000000
zero:
	xor xh, xh, yh                # Determine the correct sign of the multiplication
	and xh, xh, a5                # Append zero
	li xl, 0                      # Append zero
	ret

# One or both args are inf or NaN
inf_nan:
# Return NaN if one of the operands is 0
	slli a7, xh, 1
	or a7, a7, xl
	beqz a7, nan
	slli a7, yh, 1
	or a7, a7, yl
	beqz a7, nan
# Return NaN if one of the elements is a NaN
# a5 contains 0x000007FF
	bne a4, a5, 1f                # Jump away if X is not a Inf/Nan
	slli a7, xh, 12
	or a7, a7, xl
	bnez a7, nan                  # Jump away if X is NaN, return NaN
1:
	bne a6, a5, inf               # Jump away if Y is not a Inf/Nan
	slli a4, yh, 12
	or a4, a4, yl
	bnez a4, nan                  # Jump away if Y is NaN, return NaN

# Load the correct sign
inf:
	xor xh, xh, yh
	j ovf

# Load the sign
pre_ovf:
	or xh, xh, t0
# Return inf (the sign is already in xh)
ovf:
	lui a3, 0x7FF00               # Load inf pattern
	srli xh, xh, 20               # Clean xh mantissa
	slli xh, xh, 20               # Clean xh mantissa
	or xh, xh, a3                 # Add the inf pattern
	li xl, 0
	ret

# Return a quiet NaN
nan:
	lui xh, 0x7FF80               # Load qNaN pattern
	li xl, 0                      # Add qNaN pattern to xh
	ret                           # Return

#else

# Mask out exponents, trap any zero/denormal/inf/NaN
__muldf3:
	li a5, 0x7FF                  # Load mask to isolate the exponent
	srli a4, xh, 20               # Isolate sign and exponent of X
	and a4, a4, a5                # Isolate exp of X
	srli a6, yh, 20               # Isolate sign and exponent of Y
	and a6, a6, a5                # Isolate exp of Y
	beq a4, a5, inf_nan           # Jump if X is inf/NaN
	beq a6, a5, inf_nan           # Jump if Y is inf/NaN
	beqz a4, zero_denormal        # Jump if X is zero/denormal
	beqz a6, zero_denormal        # Jump if Y is zero/denormal

normal_case:
# Add exponents together
	add a4, a4, a6                # Add exponents together

# Determine final sign
	xor a6, xh, yh                # Xor xh and yh to have also the correct sign
	lui a5, 0x80000               # Load 0x80000 mask for the sign
	and t0, a6, a5                # Isolate the product sign

# Convert mantissa to unsigned integer
# If we have a power of two, branch to a separate path
	lui a5, 0xFFF00               # Mask to isolate mantissa
	not a5, a5                    # Mask to isolate mantissa
	and xh, xh, a5                # Isolate mantissa X
	and yh, yh, a5                # Isolate mantissa Y
	lui a5, 0x00100               # Prepare the implicit 1 mask
	or xh, xh, a5                 # Add the implicit 1 to X
	or yh, yh, a5                 # Add the implicit 1 to Y

# The actual multiplication.
# (xh*yh)<<64 + (xh*yl + xl*yh)<<32 + (xl*yl)
# Put the 128-bit result in a7-a6-t4-t3
# Todo: check if all these numbers are actually needed
# (xh*yl)<<32
	mul t1, xh, yl
	mulhu t2, xh, yl
# (xl*yh)<<32
	mul a6, xl, yh
	mulhu a7, xl, yh
# Add these two results together
	ADD2Rto2R t2, t1, a7, a6
# (xl*yl)
	mul t3, xl, yl
	mulhu t4, xl, yl
#(xh*yh)<<64
	mul a6, xh, yh
	mulhu a7, xh, yh
# Add together
	ADD3Rto2T a7, a6, t4, t2, t1

# LSBs in t3 are significant only for the final rounding. Merge them into t4.
	snez a5, t3
	or t4, t4, a5

# Adjust the result upon the MSB position
	li t2, 512                       # Prepare the mask in position 10. t2 = 1 << 9
	bgeu a7, t2, 1f                  # Branch if there is no need for adjusting
	SLLI1_3R a7, a6, t4, a5          # Adjust: shift left the result by 1
	addi a4, a4, -1                  # Adjust the exponent after the shift

1:
# Shift to the final position and add the sign to result
	slli xh, a7, 11                  # Shift the implicit 1 in its correct position (position 21, shift by 11)
	srli a5, a6, 21                  # Save the bits of the lower P that should shift in the higher P
	or xh, xh, a5                    # Add the lower P shifted bits to higher P
	slli xl, a6, 11                  # Shift the lower part of the product by 11
	srli a5, t4, 21                  # Save the bits of R that should shift in the lower P
	or xl, xl, a5                    # Add the R bits to lower P
	slli t4, t4, 11                  # Shift R by 11

# Apply exponent bias and check exponent range for under/overflow
	addi a4, a4, -1023               # Apply exponent bias
	li t1, 2046                      # Prepare to check for under/over flow
	bgeu a4, t1, und_ov_flow         # We have either an underflow or an overflow

# Round the result, merge final exponent.
	slli a4, a4, 20                  # Bring the exponent to its position
	add xh, xh, a4                   # Add the exponent to the result (the implicit 1 is added)
rounding:
	lui a5, 0x80000                  # Prepare the mask for the RNE
	bltu t4, a5, exit                # Branch if we cannot guess to round up
	addi xl, xl, 1                   # Guess a first rounding up
	seqz t1, xl                      # Guess a first rounding up
	add xh, xh, t1                   # Guess a first rounding up
	bne t4, a5, exit                 # Check for a tie -> in the case, RNE. Jump if there is no tie
	andi xl, xl, -2                  # RNE (we have already added 1)
exit:
	or xh, xh, t0                    # Add the correct sign to the result
	ret                              # Return

# Check for overflow/underflow
# If we are here, we ore either in ovf or in underflow
und_ov_flow:
# Overflow?
	blt x0, a4, pre_ovf              # Branch to Ovf handling if an overflow occurred
# Check if denormlized result is possible, otherwise return signed 0
	li t1, -53                       # Prepare condition
	bge a4, t1, denormal_end         # Can we return something different than zero? Branch if yes.
# Return signed 0
	li xl, 0                         # Clear the lower P
	mv xh, t0                        # Return signed 0
	ret

# Shift value right, round, etc.
# If we are here, (-53 <= a4 <= -1)
denormal_end:
	neg a4, a4                      # Find shamt = |exp|
# (1 <= shamt <= 53)
	li a5, 32
	bge a4, a5, 1f                  # Branch away if (32 <= shamt <= 53)
# We do not need a preshift
	sub a5, a5, a4                  # Find the complementary shamt

# (1 <= shamt <= 20). We need a right shift.
# OR
# (21 <= shamt <= 31). We need a fake 32-bit preshift and a left shift
3:
	snez a2, t4                     # Concentrate a partial sticky bit in t1
	sll t4, xl, a5                  # Setup the round bit and the other sticky bits
	or t4, t4, a2                   # Append the partial sticky bit to the others
	srl xl, xl, a4                  # Right shift xl by the correct amount
	sll a2, xh, a5                  # Left shift xh after a fake 32-bit preshift
	or xl, xl, a2                   # Append it to xl
	srl xh, xh, a4                  # Right shift xh
	j rounding                      # Round

# (32 <= shamt <= 53). We need a 32-bit preshift and a right shift
1:
	addi a4, a4, -32                # Adjust the exponent taking into account the 32-bit preshift
# Preshift by 32-bit
	snez a2, t4
	mv t4, xl
	mv xl, xh
	li xh, 0
	or t4, t4, a2
	beqz a4, rounding               # Branch away if shamt was 32.
# (1 < shamt <= 21) with a previous 32-bit preshift.
	sub a5, a5, a4                  # Find the complementary shamt
# Right shift by shamt
	j 3b

# One or both arguments are denormalized. No one of them is zero.
# Scale them leftwards and preserve sign bit
# a5 contains 0x80000000
denormal:
	srli t3, a5, 11               # Prepare the implicit 1
# Check if X is denormalized
	and t1, xh, a5                # Extract sign of X
	bnez a4, 3f                   # Branch if X is not a denormal
# X is denormalized
2:
	SLLI1_2R xh, xl, t5           # Shift left X by 1 position
	and t2, xh, t3                # Implicit 1 restored?
	bnez t2, 3f                   # Branch if the implicit 1 is restored
	addi a4, a4, -1               # Subtract 1 from X exponent
	j 2b
3:
	or xh, xh, t1                 # Restore X sign
# Check if Y is denormalized
	and a5, a5, yh                # Extract sign of Y
	bnez a6, 5f                   # Jump if Y is not denormal
# Y is denormalized
4:
	SLLI1_2R yh, yl, t5           # Shift left Y by 1 position
	and t2, yh, t3                # Implicit 1 restored?
	bnez t2, 5f                   # Branch if the implicit 1 is restored
	addi a6, a6, -1               # Subtract 1 from Y exponent
	j 4b
5:
	or yh, yh, a5                 # Restore Y sign
	j normal_case

# One or more arguments are either denormalized or zero
# a5 contains 0x000007FF
zero_denormal:
# Check if X or Y is zero. If none of them is, one of them is denormal
	slli a5, a5, 31               # Prepare mask for the sign. a5 = 0x80000000
	not t3, a5                    # Mask for the sign. t3 = 0x7FFFFFFF
	and a7, xh, t3
	or a7, a7, xl
	beqz a7, zero                 # Return zero if X is zero
	and a7, yh, t3
	or a7, a7, yl
	bnez a7, denormal             # Go on and return zero if Y is zero, otherwise, jump to denormal

# Result is zero, but determine sign anyway
# a5 contains 0x80000000
zero:
	xor xh, xh, yh                # Determine the correct sign of the multiplication
	and xh, xh, a5                # Append zero
	li xl, 0                      # Append zero
	ret

# One or both args are inf or NaN
inf_nan:
# Return NaN if one of the operands is 0
	slli a7, xh, 1
	or a7, a7, xl
	beqz a7, nan
	slli a7, yh, 1
	or a7, a7, yl
	beqz a7, nan
# Return NaN if one of the elements is a NaN
# a5 contains 0x000007FF
	bne a4, a5, 1f                # Jump away if X is not a Inf/Nan
	slli a7, xh, 12
	or a7, a7, xl
	bnez a7, nan                  # Jump away if X is NaN, return NaN
1:
	bne a6, a5, inf               # Jump away if Y is not a Inf/Nan
	slli a4, yh, 12
	or a4, a4, yl
	bnez a4, nan                  # Jump away if Y is NaN, return NaN

# Load the correct sign
inf:
	xor xh, xh, yh
	j ovf

# Load the sign
pre_ovf:
	or xh, xh, t0
# Return inf (the sign is already in xh)
ovf:
	lui a3, 0x7FF00               # Load inf pattern
	srli xh, xh, 20               # Clean xh mantissa
	slli xh, xh, 20               # Clean xh mantissa
	or xh, xh, a3                 # Add the inf pattern
	li xl, 0
	ret

# Return a quiet NaN
nan:
	lui xh, 0x7FF80               # Load qNaN pattern
	li xl, 0                      # Add qNaN pattern to xh
	ret                           # Return

#endif
