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

# RISC-V FP 64-bit addition
# double __adddf3(double a, double b);

#define xl a0
#define xh a1
#define yl a2
#define yh a3

.global __adddf3

# Shift right a number stored into 3 registers
# cshamt = 32 - shamt
.macro shift3ra x2, x1, x0, shamt, cshamt, temp
	srl  \x0, \x0, \shamt      # Shift right the Less Significant Reg (LSR)
	sll  \temp, \x1, \cshamt   # Save the bit that would be lost from the mid reg
	or \x0, \x0, \temp         # Transfer them to the LSR
	srl  \x1, \x1, \shamt      # Shift right the mid reg
	sll  \temp, \x2, \cshamt   # Save the bit that would be lost from the MSR
	or \x1, \x1, \temp         # Transfer them to the mid reg
	sra  \x2, \x2, \shamt      # Shift right the MSR
.endm

# The sum is saved in x1, x0
# y1, y0 can be overwritten
.macro add2 x1, x0, y1, y0
	add \x0, \x0, \y0
	sltu \y0, \x0, \y0
	add \y1, \y1, \y0
	add \x1, \x1, \y1
.endm

# Negate a value stored into 3 regs
.macro neg3_t x2, x1, x0, t0, t1
	neg \x0, \x0               # Negate the Less Significant Reg (LSR)
	seqz \t1, \x0              # If it is zero, we should than add 1 to the next reg
	not \x1, \x1               # Negate the mid register
	add \x1, \x1, \t1          # Add the hypothetical 1 calculated before
	seqz \t0, \x1              # If both the first two regs were zero, the one will be propagated
	and \t0, \t0, \t1          # If both the first two regs were zero, the one will be propagated
	not \x2, \x2               # Negate the MSR
	add \x2, \x2, \t0          # Add the hyp. 1
.endm

#ifndef SPLIT_SUB

.global __subdf3

__subdf3:
  lui a5, 0x80000            # Load sign mask
  xor yh, yh, a5             # Reverse sign of Y
# Fall-throught the addition

#endif

__adddf3:
# Check for zeroes, equal values, inf, NaN
	lui a5, 0xFFE00            # Load pattern to match {inf, NaN} when operand << 1
	slli a6, xh, 1             # Remove sign X (X << 1)
	slli a7, yh, 1             # Remove sign Y (Y << 1)
	bgeu a6, a5, infnan        # Branch if opX in {inf, NaN}
	bgeu a7, a5, infnan_B_only # Branch if opY in {inf, NaN}
	xor a4, a6, a7             # Let's check if the operands are the same (sign not checked!) (Understand if it is important to perform this check)
	xor t1, xl, yl             # Let's check if the operands are the same
	or a4, a4, t1              # Let's check if the operands are the same
	beqz a4, equal             # Branch if X == Y
	or a4, a6, xl              # Check if X is 0 (this check is necessary)
	beqz a4, zero_operand      # Branch if X is 0
	or t1, a7, yl              # Check if Y is 0
	beqz t1, zero_operand      # Branch if Y is 0
# The two numbers are normals or denormals
# Compute the exponent difference. Largest exponent in a6,
# corresponding arg in xh-xl, and positive exp difference in t0
	srli a6, a6, 21            # logically isolate expX
	srli a7, a7, 21            # logically isolate expY
	sub t0, a6, a7             # compute (expC - expY)
	bgeu a6, a7, 2f            # Branch if (expX >= expY)
	neg t0, t0                 # if (expX < expY) compute expA - expB
	mv a6, a7                  # if (expX < expY) save expY in a6
	xor yl, xl, yl             # if (expX < expY) swap opX with opY
	xor yh, xh, yh             # if (expX < expY) swap opX with opY
	xor xl, yl, xl             # if (expX < expY) swap opX with opY
	xor xh, yh, xh             # if (expX < expY) swap opX with opY
	xor yl, xl, yl             # if (expX < expY) swap opX with opY
	xor yh, xh, yh             # if (expX < expY) swap opX with opY
# The exponent difference can be so large to immediately return the greater number
# (54 bit required in total to determine the rounding)
2:
	sltiu a7, t0, 55
	beqz a7, exit
# Convert the operands to signed integers
# If we are here, a7 contains 1, a5 contains 0xFFE00000
	not a5, a5                 # Mask to clear sign and exp. a5 = 0x001FFFFF
	slli a7, a7, 20            # Prepare the implicit 1 in a7
	or xh, xh, a7              # Add the implicit 1 to X
	or yh, yh, a7              # Add the implicit 1 to Y
	slli a7, a7, 11            # Mask to test the sign. a7 = 0x8000000
	sltu t1, xh, a7            # Test if X is positive (set if positive)
	and xh, xh, a5             # Isolate mantissa X with implicit 1
	bnez t1, 3f                # Jump if X is positive
# Negate X if it is negative
	seqz t1, xl                # If xl is 0, we will add 1 to the complement of xh
	not xh, xh                 # Complement the upper part
	neg xl, xl                 # Negate the lower part of X
	add xh, xh, t1             # Add the possible 1
3:
	sltu t1, yh, a7            # Test if Y is positive (set if positive)
	and yh, yh, a5             # Isolate mantissa Y with implicit 1
	bnez t1, 4f                # Jump if Y is positive
# Negate Y if it is negative
	seqz t1, yl                # If yl is 0, we will add 1 to the complement of yh
	not yh, yh                 # Complement the upper part
	neg yl, yl                 # Negate the lower part of Y
	add yh, yh, t1             # Add the possible 1
# Branch away if one or both arguments are denormals
4:
	beq a6, t0, denormal       # branch if MAX(exp) == abs(diff(exp)) -> branch if min(exp) == 0 (there is a denormal)

# Effective addition. If we are here, a7 = 0x80000000
sum:
	addi a6, a6, -1            # subtract one from MAX(exp). This is done becuse the exponent will be added to the mantissa, and the implicit 1 will be present with an overlap

	# Shift yh-yl right by t0, add to xh-xl
	# The result will be kept in xh-xl-a4
	# The bits to the right of a4 does not count,
	# it's only important to know if there is at least a 1 there, for a correct c2 complement
	li a4, 0                   # Initialize to 0 the lower register of Y, the lower operand (yh-yl-a4)
	li t1, 32                  # Prepare to check if (shamt < 32)
	bltu t0, t1, 1f            # Branch if (shamt < 32)
# (shamt >= 32).
	mv a4, yl                  # Preshift Y by 32 (move)
	mv yl, yh                  # Preshift Y by 32
	srai yh, yh, 31            # Preshift Y by 32
	addi t0, t0, -32           # Adjust the shamt (shamt -= 32)
# (shamt < 32)
1:
	beqz t0, 2f                      # Skip the shift if shamt == 0
	sub a7, t1, t0                   # Calculate the complementary shamt (32 - shamt)
	sll t1, a4, a7                   # Save the lost bits to correctly c2 complement the result
	shift3ra yh, yl, a4, t0, a7, a5  # Arithmetically shift right Y by shamt
	sltu t1, x0, t1                  # Trick to correctly complement the result (set to 1 LSB of a4 if (|lost_bits == 1))
	or a4, a4, t1                    # Trick to correctly complement the result
2:
	add2 xh, xl, yh, yl              # X + Y (a4 does not change)
# The result is saved in xh-xl-a4. Calculate the abs value of the result in xh-xl-a4. Put the sign in a7
	srli a7, xh, 31                  # Isolate the sign of the sum
	slli a7, a7, 31                  # Isolate the sign of the sum
	bge xh, zero, pos_or_zero        # No need for c2 if result is >= 0 (Jump if >= 0)
	neg3_t xh, xl, a4, t1, a5        # Correctly c2 complement the result
# Determine how to normalize the result
pos_or_zero:
	lui a5, 0x00100                  # Prepare to check if we should normalize
	bltu xh, a5, num_canc            # Branch if numerical cancellation occurred
	slli a5, a5, 1                   # Check if we need for normalizing
	bltu xh, a5, rounding            # Branch if we should not normalize
# No numerical cancellation, but we should normalize
	andi a5, a4, 1                   # Save the information about the last bit
	srli a4, a4, 1                   # Shift right a4
	or a4, a4, a5                    # Trick for a correct RNE rounding
	slli a5, xl, 31                  # Save the last bit of xl
	or a4, a4, a5                    # Transfer it to a4
	srli xl, xl, 1                   # Shift right xl
	slli a5, xh, 31                  # Save the last bit of xh
	or xl, xl, a5                    # Transfer it to xl
	srli xh, xh, 1                   # Shift right xh (xh is positive or zero here)
	addi a6, a6, 1                   # Add 1 to the MAX exponent
	li a5, 2046                      # Ready to check for ovf
	bge a6, a5, inf                  # Branch if max exp >= 2046 (we have ovf)
# The result is normalized and we have no numerical cancellation. Round to Nearest Even (RNE)
rounding:
	lui a5, 0x80000                  # Prepare to compare decimal bits to 0.5
	slli a6, a6, 20                  # Bring the exponent to its position
	add xh, xh, a6                   # Add it to the sum (the implicit 1 is added to the exponent)
	bltu a4, a5, complete_sum        # Check if we can guess to round up (jump away if we do not round)
	addi xl, xl, 1                   # Guess the first rounding (no need for normalization)
	seqz a2, xl                      # Guess the first rounding
	add xh, xh, a2                   # Guess the first rounding
	bne a4, a5, complete_sum         # Check for a tie -> in the case, Round to Nearest Even (Jump if there is not a tie, i.e. a4 != 0x80000000)
	andi xl, xl, -2                  # Round to Nearest Even (we have already added 1)
complete_sum:
	or xh, xh, a7                    # Add the correct sign
exit:
	ret

# Result must be shifted left and exponent adjusted
num_canc:
	slli xh, xh, 1                   # Shift left xh by 1
	srli a5, xl, 31                  # Save the MSB of xl
	or xh, xh, a5                    # Transfer it to LSB of xh
	slli xl, xl, 1                   # Shift left xl by 1
	srli a5, a4, 31                  # Save the round bit before shifting it out
	or xl, xl, a5                    # Transfer it to LSB of xl
	slli a4, a4, 1                   # Shift left the a4 reg
	mv a5, a6                        # Save max exp
	addi a6, a6, -1                  # Subtract 1 from max exp
	beqz a5, denormal_or_str_canc    # jump if (MAX(exp) was 0) -> we have a denormal. Otherwise, maybe we can have soft cancellation with a normal result
	lui a5, 0x00100                  # prepare condition to check for strong or soft cancellation
	bgeu xh, a5, rounding            # jump if (MAX(exp) was not 0 && there is no more cancellation) -> soft cancellation -> maybe we need for a rounding
# a4 is 0 here, no rounding is necessary
denormal_or_str_canc:
	bnez xh, 1f                      # Check if xh is zero (Branch if not zero)
# xh is zero. Preshift by 32. (a4 == 0) now
	mv xh, xl                        # Preshift the sum by 32
	li xl, 0                         # Preshift the sum by 32
	li a4, 32                        # a4 will be subtracted from the exponent
1:
# clz in a4, which contains either 0 or 32 (to keep into account of the zeros of the eventual preshift)

  mv a3, xh

  lui a5, 0x00010
  bgeu a3, a5, 0f
  slli a3, a3, 16
  addi a4, a4, 16
0:
  slli a5, a5, 4
  bgeu a3, a5, 1f
  slli a3, a3, 12
  addi a4, a4, 12
1:
  slli a5, a5, 4
  bgeu a3, a5, 2f
  slli a3, a3, 8
  addi a4, a4, 8
2:
  slli a5, a5, 4
  bgeu a3, a5, 3f
  slli a3, a3, 4
  addi a4, a4, 4
3:
  slli a5, a5, 2
  bgeu a3, a5, 4f
  slli a3, a3, 2
  addi a4, a4, 2
4:
  slli a5, a5, 1
  bgeu a3, a5, 5f
  slli a3, a3, 1
  addi a4, a4, 1
5:

# Remove the 11 zeros not part of the mantissa
addi a4, a4, -11

# 0) If (a4 == 0), no shift
# 1) If (0 < a4 < 21), shift left from 1 to 20
# 2) If (20 < a4 < 32), shift right from 11 to 1 (some bits percolate to xl)
# 3) If (31 < a4 < 53), shift left from 0 to 20 (xl is 0)
	beqz a4, denormal_canc           # Don't shift if there's no need to
	addi a2, a4, -32                 # Check if we are in case 3)
	bgez a2, 3f                      # Jump if in case 3)
	addi a2, a2, 12                  # Check if we are in case 1)
	blez a2, 1f                      # Jump if in case 1)
# We are in case 2). xl was moved to xh. We should shift right from 11 to 1 to normalize
2:
	li a3, 12                        # Prepare to perform (12 - a2)
	sub a2, a3, a2                   # 12 - a2. In this moment, a2 = [1, 11]. Then, it will become a2 = [11, 1]
	sll xl, xh, a4                   # xl is empty, directly shift LSBs of xh inside it. a4 = [21, 31]
	srl xh, xh, a2                   # Right shift xh
	j 4f                             # Go on
# We are in case 1). Let's adjust a2 to fall down in case 3). a4 will be the only difference to keep track of the real case and to adjust the final exponent.
1:
	addi a2, a2, 20                  # Restore what we had removed for the checks
# We are in case 3) or in case 1) adjusted to fall into case 3). We will left shift the sum from 1 to 20 bits (or 32 to 52 in the second case. In this case, the real shift is from 0 to 20 bits).
3:
	sll xh, xh, a2                   # Left shift the MSbs of the sum
	li a3, 32                        # Prepare the complementary shamt
	sub a3, a3, a2                   # Prepare the complementary shamt
	srl a3, xl, a3                   # Complementary shamt the xl
	or xh, xh, a3                    # Transfer part of xl to xh
	sll xl, xl, a2                   # Left shift xl
# Adjust the exponent accordingly
4:
	sub a6, a6, a4                   # Adjust the exponent accordingly
	blt a6, zero, denormal_canc      # Branch if max exp is lower than 0 (denormal) # Last bug correction
	slli a6, a6, 20                  # Prepare to add the exponent to the sum
	add xh, xh, a6                   # Add the exponent to the sum
	or xh, xh, a7                    # Add the proper sign to the sum
	j exit
denormal_canc:
	neg a6, a6                       # Complement the final exponent if it is negative, then shift right the result
	addi a6, a6, -32                 # Prepare to check if we can easily shift xh in xl
	bgez a6, 2f                      # Jump if this is the case
# Shift value right of 1 to 31 bits
	addi a4, a6, 32                  # Calculate the correct shamt (a4)
	neg a6, a6                       # Calculate the complementary shamt (a6)
	srl xl, xl, a4                   # Right shift xl by shamt
	sll a6, xh, a6                   # Save the xh bits that would be lost
	or xl, xl, a6                    # Transfer them to xl
	srl xh, xh, a4                   # Right shift xh by shamt
	or xh, xh, a7                    # Append the correct sign to the sum
	j exit                           # Return

# Shift value right of 32 to 64 bits
2:
	srl xl, xh, a6                   # Shift right by 32 + a6
	mv xh, a7                        # Add the sign followed by 0s to xh (we have a signed denormal with only 0s in the upper mantissa)
	j exit                           # Return

# mix exp == 0 (one of the operands is a denormal)
denormal:
	lui a5, 0x00100                  # Clean the implicit bit of the lower number (it's a denormal)
	xor yh, yh, a5                   # Clean the implicit bit of the lower number (it's a denormal)
	beqz a6, 5f                      # Jump if (max exp == 0) -> both numbers are denormals
	addi t0, t0, -1                  # Only the lower operand is a denormal, so subtract 1 from the exp difference
	bnez a6, 6f                      # Jump if (max exp != 0) -> only the lower number is a denormal
5:
	xor xh, xh, a5                   # if (expA == 0) -> both denormal -> clean the implicit bit of the higher number (if both are denormal, denormalize also the higher number)
	addi a6, a6, 1                   # if (expA == 0) -> both denormal -> add 1 to the max exponent (if both are denormal we won't have the added implicit one to the exponent)
6:
	j sum                            # Go on with the sum

# Special case: X == 0 || Y == 0
zero_operand:
	or a5, a6, xl                    # Check if X is zero
	bnez a5, zero_operand_return     # If X != 0 -> Y == 0. So, return X
	mv xh, yh                        # If X == 0, return Y. Transfer yh to xh
	mv xl, yl                        # Transfer also yl to xl
zero_operand_return:
	j exit                           # Return

# Special case: opA == 0 || opB == 0
equal:
	beq xh, yh, equal_samesign       # Are the signs equal too?
	li xh, 0                         # If not, return +0
	li xl, 0                         # If not, return +0
	j exit                           # Return

# a5 = 0xFFE00000
equal_samesign:
	and a5, a5, a6                   # The signs are equal. Test unsigned X
	bnez a5, equal_nodenormal        # Branch if X is not a denormal
# X and Y are both denormal and are equal. a6 contains unsigned 2*X. Shift also xl left by 1
	mv xh, a6                        # Same as slli xh, xh, 1
	srli a4, xl, 31                  # Save the bit that would be lost
	or xh, xh, a4                    # Transfer the bit to xh
	slli xl, xl, 1                   # Left shift also xl
	bgeu xh, yh, 1f                  # If opB (i.e. opA) is unsigned-less then its 2 times with no sign, opB (i.e. opA) was positive because bit[30] of opB was 0 before the multaiplication. If equal, we had double zero (positive).
	lui a5, 0x80000                  # Prepare to re-set the sign bit if the denormal was negative
	or xh, xh, a5                    # Re-set the sign bit if the denormal was negative
1:
	j exit                           # Return

# Special case: (unsigned opA == unsigned opB) && we have no denormals
equal_nodenormal:
	srli a6, a6, 21                  # Isolate the exponent in a convenient position
	li a4, 0x7FE                     # Prepare the immediate to compare
	sltu a5, a6, a4                  # Test if we can multiply the number by 2 with no ovf (check if the exponent is < 2046)
	beqz a5, 7f                      # Branch if we will ovf
# a5 is 1
	slli a5, a5, 20                  # If we can multiply by 2 with no ovf, double the result
	add xh, xh, a5                   # If we can multiply by 2 with no ovf, double the result
	j exit                           # Return
7:
# a5 is 0
	lui a5, 0x80000                  # We will ovf, save the sign of X
	and a7, a5, xh                   # We will ovf, save the sign of X
# Prepare the inf
inf:
	lui xh, 0x7FF00                  # Load unsigned infinite in the result
	li xl, 0                         # Load unsigned infinite in the result
	or xh, xh, a7                    # Update the sign
	j exit                           # Return

# Special case: (opB == {inf, NaN} && opA != {inf, NaN})
infnan_B_only:
	mv xh, yh                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put opB also in a0 (now the operation is between {inf, NaN})
	mv xl, yl                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put opB also in a0 (now the operation is between {inf, NaN})
	mv a6, a7                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put |opB|<<1 also in a6 (because we will check a6)
	j infnan_end                     # jump -> (opB == {inf, NaN} && opA != {inf, NaN})

# Special case: opA == {inf, NaN} and maybe also opB == {inf, NaN}
infnan:
# a5 = 0xFFE000000
	bgeu a7, a5, infnan_end          # (opB == {inf, NaN} && opA == {inf, NaN}) -> jump
	mv yh, xh                        # (opB != {inf, NaN} && opA == {inf, NaN}) -> (now the operation is between {inf, NaN})
	mv yl, xl                        # (opB != {inf, NaN} && opA == {inf, NaN}) -> (now the operation is between {inf, NaN})
# We have in X and Y two {inf, NaN} values -> process them
infnan_end:
	slli a6, a6, 11                  # Prepare to check if X == NaN
	or a6, a6, xl                    # Prepare to check if X == NaN
	bnez a6, produce_nan             # If the first value is a NaN -> return a qNaN
	bne xl, yl, produce_nan          # The first value is inf. Branch to NaN if the operands differ, as Y is surely a NaN or an opposite inf.
	bne xh, yh, produce_nan          # The first value is inf. Branch to NaN if the operands differ, as Y is surely a NaN or an opposite inf.
	j exit                           # Return the correct inf

produce_nan:
# a5 = 0xFFE00000
	lui xh, 0x7FF80                  # Trick to return NaNed operand
	li xl, 0                         # If operands are (+inf) + (-inf) || if opA == NaN || opB == NaN -> return quiet NaN
	j exit                           # Return quiet NaN
