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

# RISC-V f64_add, denormals flushed to 0

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
	xor yh, yh, a5             # Negate the sign of Y
# Fall-through the addition without any jump

#endif

__adddf3:
# Check for zeroes, equal values, inf, NaN
	lui a5, 0xFFE00            # Load pattern to match {inf, NaN} when operand << 1
	slli t2, xh, 1             # Remove sign X (X << 1)
	slli t0, yh, 1             # Remove sign Y (Y << 1)
	bgeu t2, a5, infnan        # Branch if opX in {inf, NaN}
	bgeu t0, a5, infnan_B_only # Branch if opY in {inf, NaN}
#ifdef SPECIAL_SAME
	xor a4, t2, t0             # Let's check if the operands are the same (sign not checked!) (Understand if it is important to perform this check)
	xor t1, xl, yl             # Let's check if the operands are the same
	or a4, a4, t1              # Let's check if the operands are the same
	beqz a4, equal             # Branch if X == Y
#endif
# The two numbers are normals or denormals
# Compute the exponent difference. Largest exponent in t2,
# corresponding arg in xh-xl, and positive exp difference in t1
	srli t2, t2, 21            # logically isolate expX
	srli t0, t0, 21            # logically isolate expY
	beqz t2, zero_operand      # Branch if X is 0
	beqz t0, zero_operand_Y    # Branch if Y is 0
	sub t1, t2, t0             # compute (expX - expY)
	bgeu t2, t0, 2f            # Branch if (expX > expY)
	neg t1, t1                 # if (expX < expY) compute expA - expB
	mv t2, t0                  # if (expX < expY) save expY in t2
	xor yl, xl, yl             # if (expX < expY) shift opX with opY
	xor yh, xh, yh             # if (expX < expY) shift opX with opY
	xor xl, yl, xl             # if (expX < expY) shift opX with opY
	xor xh, yh, xh             # if (expX < expY) shift opX with opY
	xor yl, xl, yl             # if (expX < expY) shift opX with opY
	xor yh, xh, yh             # if (expX < expY) shift opX with opY
# The exponent difference can be so large to immediately return the greater number
# (54 bit required in total to determine the rounding)
2:
	sltiu t0, t1, 55
	beqz t0, exit
# Convert the operands to signed integers
# If we are here, t0 contains 1, a5 contains 0xFFE00000
	not a5, a5                 # Mask to clear sign and exp. a5 = 0x001FFFFF
	slli t0, t0, 20            # Prepare the implicit 1 in t0
	or xh, xh, t0              # Add the implicit 1 to X
	or yh, yh, t0              # Add the implicit 1 to Y
	slli t0, t0, 11            # Mask to test the sign. t0 = 0x8000000
	sltu a4, xh, t0            # Test if X is positive (set if positive)
	and xh, xh, a5             # Isolate mantissa X with implicit 1
	bnez a4, 3f                # Jump if X is positive
# Negate X if it is negative
	seqz a4, xl                # If xl is 0, we will add 1 to the complement of xh
	not xh, xh                 # Complement the upper part
	neg xl, xl                 # Negate the lower part of X
	add xh, xh, a4             # Add the possible 1
3:
	sltu a4, yh, t0            # Test if Y is positive (set if positive)
	and yh, yh, a5             # Isolate mantissa Y with implicit 1
	bnez a4, 4f                # Jump if Y is positive
# Negate Y if it is negative
	seqz a4, yl                # If yl is 0, we will add 1 to the complement of yh
	not yh, yh                 # Complement the upper part
	neg yl, yl                 # Negate the lower part of Y
	add yh, yh, a4             # Add the possible 1
# Branch away if one or both arguments are denormals
4:
# Effective addition. If we are here, t0 = 0x80000000
sum:
	addi t2, t2, -1            # subtract one from MAX(exp). This is done becuse the exponent will be added to the mantissa, and the implicit 1 will be present with an overlap

	# Shift yh-yl right by t1, add to xh-xl
	# The result will be kept in xh-xl-a4
	# The bits to the right of a4 does not count,
	# it's only important to know if there is at least a 1 there, for a correct c2 complement
	li a4, 0                   # Initialize to 0 the lower register of Y, the lower operand (yh-yl-a4)
	li a5, 32                  # Prepare to check if (shamt < 32)
	bltu t1, a5, 1f            # Branch if (shamt < 32)
# (shamt >= 32).
	mv a4, yl                  # Preshift Y by 32 (move)
	mv yl, yh                  # Preshift Y by 32
	srai yh, yh, 31            # Preshift Y by 32
	addi t1, t1, -32           # Adjust the shamt (shamt -= 32)
# (shamt < 32)
1:
	beqz t1, 2f                      # Skip the shift if shamt == 0
	sub t0, a5, t1                   # Calculate the complementary shamt (32 - shamt)
	sll a5, a4, t0                   # Save the lost bits to correctly c2 complement the result
# RV32E --- WE need another reg to be used as temp for shift3ra, so break the macro and interleave
	srl  a4, a4, t1                  # Shift right the Less Significant Reg (LSR)
	sltu a5, x0, a5                  # Trick to correctly complement the result (set to 1 LSB of a4 if (|lost_bits == 1))
	or a4, a4, a5                    # RV32E trick to free up a5. If we are here, shamt != 0 && shamt != 32
# Now we can reuse a5 as a temp reg
	sll  a5, yl, t0                  # Save the bit that would be lost from the mid reg
	or a4, a4, a5                    # Transfer them to the LSR
	srl  yl, yl, t1                  # Shift right the mid reg
	sll  a5, yh, t0                  # Save the bit that would be lost from the MSR
	or yl, yl, a5                    # Transfer them to the mid reg
	sra  yh, yh, t1                  # Shift right the MSR
2:
	add2 xh, xl, yh, yl              # X + Y (a4 does not change)
# The result is saved in xh-xl-a4. Calculate the abs value of the result in xh-xl-a4. Put the sign in t0
	srli t0, xh, 31                  # Isolate the sign of the sum
	slli t0, t0, 31                  # Isolate the sign of the sum
	bge xh, zero, pos_or_zero        # No need for c2 if result is >= 0 (Jump if >= 0)
	neg3_t xh, xl, a4, a2, a5        # Correctly c2 complement the result
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
	addi t2, t2, 1                   # Add 1 to the MAX exponent
	li a5, 2046                      # Ready to check for ovf
	bge t2, a5, inf                  # Branch if max exp >= 2046 (we have ovf)
# The result is normalized and we have no numerical cancellation. Round to Nearest Even (RNE)
rounding:
	lui a5, 0x80000                  # Prepare to compare decimal bits to 0.5
	bltu a4, a5, exp_sign_exit       # Check if we can guess to round up (jump away if we do not round)
	addi xl, xl, 1                   # Guess the first rounding (no need for normalization)
	seqz a2, xl                      # Guess the first rounding
	add xh, xh, a2                   # Guess the first rounding
	bne a4, a5, exp_sign_exit        # Check for a tie -> in the case, Round to Nearest Even (Jump if there is not a tie, i.e. a4 != 0x80000000)
	andi xl, xl, -2                  # Round to Nearest Even (we have already added 1)
exp_sign_exit:
#ifndef SPECIAL_SAME
	or a2, xh, xl
	beqz a2, signed_zero
#endif
	slli t2, t2, 20                  # Bring the exponent to its position
	add xh, xh, t2                   # Add it to the sum (the implicit 1 is added to the exponent)
sign_and_exit:
	or xh, xh, t0                    # Add the correct sign
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
	mv a5, t2                        # Save max exp
	addi t2, t2, -1                  # Subtract 1 from max exp
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
	sub t2, t2, a4                   # Adjust the exponent accordingly
	blt t2, zero, denormal_canc      # Branch if max exp is lower than 0 (denormal) # Last bug correction
	j exp_sign_exit
# Flush denormal to 0
denormal_canc:
	li xh, 0
	j sign_zero_xl                    # Append the correct sign to the sum

# mix exp == 0 (one of the operands is a denormal)
both_denormals:
pm_zero:
	and xh, xh, yh
signed_zero:
	srli xh, xh, 31
	slli xh, xh, 31
zero_xl:
	li xl, 0                         # If not, return +0
	j exit                           # Return

# Special case: X == 0 || Y == 0
zero_operand:
	beqz t0, pm_zero                 # If also Y == 0, return signed zero
	mv xh, yh                        # If Y != 0, return Y. Transfer yh to xh
	mv xl, yl                        # Transfer also yl to xl
zero_operand_return:
zero_operand_Y:
	j exit                           # Return

#ifdef SPECIAL_SAME

# Special case: opA == 0 || opB == 0
equal:
	beq xh, yh, equal_samesign       # Are the signs equal too?
	li xh, 0                         # If not, return +0
	j zero_xl

# a5 = 0xFFE00000
equal_samesign:
	and a5, a5, t2                   # The signs are equal. Test unsigned X
	bnez a5, equal_nodenormal        # Branch if X is not a denormal
# X and Y are both denormal and are equal. t2 contains unsigned 2*X. Shift also xl left by 1
	j both_denormals

# Special case: (unsigned opA == unsigned opB) && we have no denormals
equal_nodenormal:
	srli t2, t2, 21                  # Isolate the exponent in a convenient position
	li a4, 0x7FE                     # Prepare the immediate to compare
	sltu a5, t2, a4                  # Test if we can multiply the number by 2 with no ovf (check if the exponent is < 2046)
	beqz a5, 7f                      # Branch if we will ovf
# a5 is 1
	slli a5, a5, 20                  # If we can multiply by 2 with no ovf, double the result
	add xh, xh, a5                   # If we can multiply by 2 with no ovf, double the result
	j exit                           # Return
7:
# a5 is 0
	lui a5, 0x80000                  # We will ovf, save the sign of X
	and t0, a5, xh                   # We will ovf, save the sign of X

#endif

# Prepare the inf
inf:
	lui xh, 0x7FF00                  # Load unsigned infinite in the result
sign_zero_xl:
	or xh, xh, t0                    # Update the sign
	li xl, 0                         # Load unsigned infinite in the result
	j exit                           # Return

# Special case: (opB == {inf, NaN} && opA != {inf, NaN})
infnan_B_only:
	mv xh, yh                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put opB also in a0 (now the operation is between {inf, NaN})
	mv xl, yl                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put opB also in a0 (now the operation is between {inf, NaN})
	mv t2, t0                        # (opB == {inf, NaN} && opA != {inf, NaN}) -> put |opB|<<1 also in t2 (because we will check t2)
	j infnan_end                     # jump -> (opB == {inf, NaN} && opA != {inf, NaN})

# Special case: opA == {inf, NaN} and maybe also opB == {inf, NaN}
infnan:
# a5 = 0xFFE000000
	bgeu t0, a5, infnan_end          # (opB == {inf, NaN} && opA == {inf, NaN}) -> jump
	mv yh, xh                        # (opB != {inf, NaN} && opA == {inf, NaN}) -> (now the operation is between {inf, NaN})
	mv yl, xl                        # (opB != {inf, NaN} && opA == {inf, NaN}) -> (now the operation is between {inf, NaN})
# We have in X and Y two {inf, NaN} values -> process them
infnan_end:
	slli t2, t2, 11                  # Prepare to check if X == NaN
	or t2, t2, xl                    # Prepare to check if X == NaN
	bnez t2, produce_nan             # If the first value is a NaN -> return a qNaN
	bne xl, yl, produce_nan          # The first value is inf. Branch to NaN if the operands differ, as Y is surely a NaN or an opposite inf.
	bne xh, yh, produce_nan          # The first value is inf. Branch to NaN if the operands differ, as Y is surely a NaN or an opposite inf.
	j exit                           # Return the correct inf

produce_nan:
# a5 = 0xFFE00000
	lui xh, 0x7FF80                  # If operands are (+inf) + (-inf) || if opA == NaN || opB == NaN -> return quiet NaN
	j zero_xl                        # Return quiet NaN
