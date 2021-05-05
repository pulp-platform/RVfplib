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

.global __addsf3

#ifndef SPLIT_SUB

.global __subsf3

__subsf3:
  lui a5, 0x80000                                   # change sign
  xor a1, a1, a5                                    # change sign of opB
# Go on with the addition

#endif

#ifdef PERFORMANCE

__addsf3:
  lui t1, 0x80000
  xor t2, a0, a1                                    # Check if we will have an effective addition or subtraction
  and a4, a0, t1                                    # Isolate the final sign of the sum
  slli a2, a0, 1                                    # remove signA
  slli a3, a1, 1                                    # remove signB
# Swap operands and dominant sign if X < Y
  bgeu a2, a3, 2f
  and a4, a1, t1                                    # Isolate the final sign of the sum
  slli a2, a1, 1                                    # remove signA
  slli a3, a0, 1                                    # remove signB
2:
# The final sign is in a4
  lui a5, 0xFF000                                   # load minimum pattern for {inf, NaN}
  bgeu a2, a5, infnan                               # The greater number is inf or NaN, no info on the smaller
  bgeu a3, a5, infnan                               # The smaller number is inf or NaN, the greater is not
# Mandatory check to catch +-zero case before losing the info on the sign
  beq a2, a3, equal                                 # branch if opA == opB # Do this check before zero operand!!!!
# At this point the numbers in a2 and a3 are perfectly ordered, and are not special (they can be zero or denormal)
# Prepare the mantissas, leaving space for the implicit 1 on the MSb
  slli a0, a2, 7
  slli a1, a3, 7
# Isolate the exponents
  srli a2, a2, 24                                   # logically isolate maxExp
  srli a3, a3, 24                                   # logically isolate minExp
# Subtract here the two exponent, so that a both-denormal operation can proceed
  sub t0, a2, a3                                    # compute (expA - expB)
  sltiu a7, t0, 26                                  # test if the lower is negligible (25 of exp diff is still ok if one of the operands is negative!)
  beqz a7, return_greater                           # immediately return the greater number if the lower is negligible
# The two numbers are normal or denormal
  beqz a2, both_denormal_zero                       # branch to a special case if the greater number is denormal. They are both denormals or one denormal and the other zero
# The bigger number is normal, the lower is not special
  addi a2, a2, -1                                   # subtract one from MAX(exp). This is done becuse the implicit 1 is kept and the exponent added
  or a0, a0, t1                                     # add the implicit 1 to the mantissaA
  beqz a3, lower_denormal                           # branch to a special case if Y is 0 or denormal
  or a1, a1, t1                                     # add the implicit 1 to the mantissaB
sum:
  srl a5, a1, t0                                    # shift right the lower operand by the exp diff
  addi t0, t0, 1                                    # Count as it was shifted one more
  neg t0, t0                                        # Save shifted out part plus the G bit
  sll a1, a1, t0                                    # a1 was NOT shifted, the implicit bit is still in the MSb
  bltz t2, diff_sign                                # Jump away if effective subtraction
# No numerical cancellation possible, but possible normalization and overflow check required
  add a0, a0, a5                                    # add the two operands (the second is shifted)
pos_or_zero:
  bgeu a0, a5, adjust                               # branch if we should not normalize
  srli a0, a0, 1                                    # we should normalize -> right shift the sum by one to normalize
  or a0, a0, t1                                     # Restore the implicit bit
  addi a2, a2, 1                                    # add 1 to MAX(exp)
  li a5, 254                                        # ready to check for ovf
  bge a2, a5, inf                                   # branch if MAX(exp) >= 254 (ovf)
# Adjust alignment before rounding
adjust:
  srli a1, a1, 1                                    # Count all the bits that were shifted out and do not appear in the sum. Put them to the right of the round bit
  slli a3, a0, 24                                   # Save the bits that will be shifted out
  or a3, a3, a1                                     # Restore the round bit, update its right bits
return_a0:
  srli a0, a0, 8                                    # Shift the sum to its final position. The implicit 1 will be added to the exponent
# normalization already performed, no numerical cancellation -> round to nearest even
rounding:
  bltu a3, t1, exp_sign_and_exit                    # check if we can guess to round up (jump away if we do not round)
  addi a0, a0, 1                                    # guess the first rounding (no need for normalization, everything's smooth because we add the exponent)
  bne a3, t1, exp_sign_and_exit                     # check for a tie -> in the case, round to nearest even (if decimal bits are equal to 0.5, clear the LSB) (we have already added 1 in case of rounding)
  andi a0, a0, -2                                   # Clear LSB
exp_sign_and_exit:
  slli a2, a2, 23                                   # bring MAX(exp) to its position in the sum
  add a0, a0, a2                                    # bring MAX(exp) to its position in the sum
sign_and_exit:
  or a0, a0, a4                                     # add the correct sign
exit:
  ret                                               # return

# effective subtraction. If we are here, a3 = 0x80000000
diff_sign:
  snez a3, a1
  or a5, a5, a3
  sub a0, a0, a5                                    # sub the two operands (the second is shifted)
# We know the correct final sign, and the result of the previous operation is positive
# the addition gave positive or zero result (or we have in a0 the absolute value of the sum)
  bltz a0, adjust                               # branch if we don't have numerical cancellation
# normalization already performed, no numerical cancellation -> round to nearest even

# we had numerical cancellation, the shift was by 0 or 1. Everythin is contained in a0
num_canc:
# a5 keeps 0x00800000
  slli a0, a0, 1                                    # left shift the sum
  mv a5, a2                                         # save MAX(exp)
  addi a2, a2, -1                                   # subtract one from MAX(exp)
  beqz a5, denormal_or_strong_cancellation          # jump if (MAX(exp) was 0) -> we have a denormal. Otherwise, maybe we can have soft cancellation with a normal result
  bgeu a0, t1, adjust                               # jump if (MAX(exp) was not 0 && there is no more cancellation) -> soft cancellation -> maybe we need for a rounding
denormal_or_strong_cancellation:
# clz inline replacement. No rounding necessary here
  lui a5, 0x00080
  bgeu a0, a5, 1f    # Jump if a0 has at least a 1 in bits [23:12]
  slli a0, a0, 12
  addi a2, a2, -12
1:
  slli a5, a5, 6
  bgeu a0, a5, 2f
  slli a0, a0, 6
  addi a2, a2, -6
2:
  slli a5, a5, 3
  bgeu a0, a5, 3f
  slli a0, a0, 3
  addi a2, a2, -3
3:
  slli a5, a5, 1
  bgeu a0, a5, 4f
  slli a0, a0, 1
  addi a2, a2, -1
4:
  slli a5, a5, 1
  bgeu a0, a5, 5f
  slli a0, a0, 1
  addi a2, a2, -1
5:
# Adjust the implicit 1 in the correct position
  srli a0, a0, 7
  addi a2, a2, -1
  bge a2, zero, exp_sign_and_exit                   # branch if the final exponent is lower than zero (denormal)
denormal_cancellation:
  neg a2, a2                                        # add the sign
  srl a0, a0, a2
  j sign_and_exit                                   # return signed zero

# Only the lower operand is a denormal
lower_denormal:
  not a7, t1  # TODO SIMPLIFY ME
  and a1, a1, a7                                    # Clean the hypothethical implicit bit
  addi t0, t0, -1                                   # Subtract 1 from exponent difference, as denormal value has 0 exponent but has the same weight of a 1 exponent
  j sum                                             # Avoid implicit 1 addition, as we have a denormal

both_denormal:
  not a7, t1  # TODO SIMPLIFY ME
  and a1, a1, a7                                    # Clean the hypothethical implicit bit
  and a0, a0, a7                                    # Clean the hypothethical implicit bit
  j sum

# The greater number is a denormal, the lower is zero or denormal. The "both zeros" case is caught by the "equal" label
both_denormal_zero:
  bnez a1, both_denormal                            # Branch if operands are both denormals (if lower operand is a denormal)
# Return the higher denormal if the lower is zero
  srli a0, a0, 8
  j exp_sign_and_exit

# Return the greater number
return_greater:
  slli a0, a0, 1                                    # Clean the hypothethical implicit bit
  srli a0, a0, 9
  j exp_sign_and_exit

# Special case: unsigned opA == unsigned opB
# in a0 and a1 we have the original values
# a2 and a3 are not ordered wrt a0 and a1, but this is not important since the numbers are the same
equal:
  bgez t2, equal_samesign                           # are the signs equal too?
zero:
  mv  a0, zero                                      # if not, the result is zero
  ret                                               # return if the result was zero
# a5 = 0xFF
equal_samesign:
  and a5, a5, a2                                    # the signs are equal. test unsigned opA (in a5 we have 0xFF)
  bnez a5, equal_nodenormal                         # branch if opA is a denormal (opA and opB are both denormal and are equal)
# opA and opB are both denormal, equal, with the same sign
  mv a0, a2                                         # replace the return value with 2*opA
  bgeu a2, a1, exit                                 # if opB (i.e. opA) is unsigned-less then its 2 times with no sign, opB (i.e. opA) was positive because bit[30] of opB was 0 before the multiplication. If equal, we had double zero (positive).
  lui a5, 0x80000                                   # prepare to re-set the sign bit if the denormal was negative
  or a0, a0, a5                                     # re-set the sign bit if the denormal was negative
  ret                                               # return

# Special case: (unsigned opA == unsigned opB) && we have no denormals
equal_nodenormal:
  srli a2, a2, 24                                   # isolate the exponent in a convenient position
  sltiu a5, a2, 0xFE                                # test if we can multiply the number by 2 with no ovf (check if the exponent is < 254)
  beqz a5, 7f                                       # branch if we will overflow
# a5 is 0
  lui a5, 0x00800                                   # if we can multiply by 2 with no ovf, double the result
  add a0, a0, a5                                    # if we can multiply by 2 with no ovf, double the result
  ret                                               # return 2*opA if we do not ovf
7:
# a5 is 1
  slli a5, a5, 31                                   # we will ovf: save the sign of opA
  and a3, a5, a0                                    # we will ovf: save the sign of opA in a3
# prepare the infinite
inf:
  lui a0, 0x7F800                                   # load unsigned infinite in the result
  j sign_and_exit                                   # return the correct infinite

# BE AWARE: a2 contains the higher operand << 2, and NOT X << 2. a2 and a3 are ordered, but a0 and a1 are not!
# Special case: X == {inf, NaN} and maybe also Y == {inf, NaN}
infnan:
  bgtu a2, a5, produce_nan                          # If there is a NaN in the operands, it is in a2 (greatest operand)
  bne a2, a3, inf

inf_inf:
  beq a0, a1, exit                                  # Return if same infinity
# Opposite infinities, produce a NaN
produce_nan:
# a5 = 0xFF000
  lui a0, 0x7FC00
  ret                                               # return quiet NaN

#else

__addsf3:
  lui t1, 0x80000
  xor t2, a0, a1                                    # Check if we will have an effective addition or subtraction
  and a4, a0, t1                                    # Isolate the final sign of the sum
  slli a2, a0, 1                                    # remove signA
  slli a3, a1, 1                                    # remove signB
# Swap operands and dominant sign if X < Y
  bgeu a2, a3, 2f
  and a4, a1, t1                                    # Isolate the final sign of the sum
  slli a2, a1, 1                                    # remove signA
  slli a3, a0, 1                                    # remove signB
2:
# The final sign is in a4
  lui a5, 0xFF000                                   # load minimum pattern for {inf, NaN}
  bgeu a2, a5, infnan                               # The greater number is inf or NaN, no info on the smaller
  bgeu a3, a5, infnan                               # The smaller number is inf or NaN, the greater is not
# Mandatory check to catch +-zero case before losing the info on the sign
  beq a2, a3, equal                                 # branch if opA == opB # Do this check before zero operand!!!!
# At this point the numbers in a2 and a3 are perfectly ordered, and are not special (they can be zero or denormal)
# Prepare the mantissas, leaving space for the implicit 1 on the MSb
  slli a0, a2, 7
  slli a1, a3, 7
# Isolate the exponents
  srli a2, a2, 24                                   # logically isolate maxExp
  srli a3, a3, 24                                   # logically isolate minExp
# Subtract here the two exponent, so that a both-denormal operation can proceed
  sub t0, a2, a3                                    # compute (expA - expB)
  sltiu a7, t0, 26                                  # test if the lower is negligible (25 of exp diff is still ok if one of the operands is negative!)
  beqz a7, return_greater                           # immediately return the greater number if the lower is negligible
# The two numbers are normal or denormal
  beqz a2, both_denormal_zero                       # branch to a special case if the greater number is denormal. They are both denormals or one denormal and the other zero
# The bigger number is normal, the lower is not special
  addi a2, a2, -1                                   # subtract one from MAX(exp). This is done becuse the implicit 1 is kept and the exponent added
  or a0, a0, t1                                     # add the implicit 1 to the mantissaA
  beqz a3, lower_denormal                           # branch to a special case if Y is 0 or denormal
  or a1, a1, t1                                     # add the implicit 1 to the mantissaB
sum:
  srl a5, a1, t0                                    # shift right the lower operand by the exp diff
  addi t0, t0, 1                                    # Count as it was shifted one more
  neg t0, t0                                        # Save shifted out part plus the G bit
  sll a1, a1, t0                                    # a1 was NOT shifted, the implicit bit is still in the MSb
  bltz t2, diff_sign                                # Jump away if effective subtraction
# No numerical cancellation possible, but possible normalization and overflow check required
  add a0, a0, a5                                    # add the two operands (the second is shifted)
pos_or_zero:
  bgeu a0, a5, adjust                               # branch if we should not normalize
  srli a0, a0, 1                                    # we should normalize -> right shift the sum by one to normalize
  or a0, a0, t1                                     # Restore the implicit bit
  addi a2, a2, 1                                    # add 1 to MAX(exp)
  li a5, 254                                        # ready to check for ovf
  bge a2, a5, inf                                   # branch if MAX(exp) >= 254 (ovf)
# Adjust alignment before rounding
adjust:
  srli a1, a1, 1                                    # Count all the bits that were shifted out and do not appear in the sum. Put them to the right of the round bit
  slli a3, a0, 24                                   # Save the bits that will be shifted out
  or a3, a3, a1                                     # Restore the round bit, update its right bits
return_a0:
  srli a0, a0, 8                                    # Shift the sum to its final position. The implicit 1 will be added to the exponent
# normalization already performed, no numerical cancellation -> round to nearest even
rounding:
  bltu a3, t1, exp_sign_and_exit                    # check if we can guess to round up (jump away if we do not round)
  addi a0, a0, 1                                    # guess the first rounding (no need for normalization, everything's smooth because we add the exponent)
  bne a3, t1, exp_sign_and_exit                     # check for a tie -> in the case, round to nearest even (if decimal bits are equal to 0.5, clear the LSB) (we have already added 1 in case of rounding)
  andi a0, a0, -2                                   # Clear LSB
exp_sign_and_exit:
  slli a2, a2, 23                                   # bring MAX(exp) to its position in the sum
  add a0, a0, a2                                    # bring MAX(exp) to its position in the sum
sign_and_exit:
  or a0, a0, a4                                     # add the correct sign
exit:
  ret                                               # return

# effective subtraction. If we are here, a3 = 0x80000000
diff_sign:
  snez a3, a1
  or a5, a5, a3
  sub a0, a0, a5                                    # sub the two operands (the second is shifted)
# We know the correct final sign, and the result of the previous operation is positive
# the addition gave positive or zero result (or we have in a0 the absolute value of the sum)
  bltz a0, adjust                               # branch if we don't have numerical cancellation
# normalization already performed, no numerical cancellation -> round to nearest even

# we had numerical cancellation, the shift was by 0 or 1. Everythin is contained in a0
num_canc:
# a5 keeps 0x00800000
  slli a0, a0, 1                                    # left shift the sum
  mv a5, a2                                         # save MAX(exp)
  addi a2, a2, -1                                   # subtract one from MAX(exp)
  beqz a5, denormal_or_strong_cancellation          # jump if (MAX(exp) was 0) -> we have a denormal. Otherwise, maybe we can have soft cancellation with a normal result
  bgeu a0, t1, adjust                               # jump if (MAX(exp) was not 0 && there is no more cancellation) -> soft cancellation -> maybe we need for a rounding
# clz inline replacement. No rounding necessary here
clz_loop:
  slli a0, a0, 1
  addi a2, a2, -1
denormal_or_strong_cancellation:
# Check if there is at least one zero
  bltu a0, t1, clz_loop
# Adjust the implicit 1 in the correct position
  srli a0, a0, 8
  bge a2, zero, exp_sign_and_exit                   # branch if we don't have a denormal
denormal_cancellation:
  neg a2, a2                                        # neg the negative exponent
  srl a0, a0, a2
  j sign_and_exit                                   # return signed zero

# Only the lower operand is a denormal
lower_denormal:
  not a7, t1  # TODO SIMPLIFY ME
  and a1, a1, a7                                    # Clean the hypothethical implicit bit
  addi t0, t0, -1                                   # Subtract 1 from exponent difference, as denormal value has 0 exponent but has the same weight of a 1 exponent
  j sum                                             # Avoid implicit 1 addition, as we have a denormal

both_denormal:
  not a7, t1  # TODO SIMPLIFY ME
  and a1, a1, a7                                    # Clean the hypothethical implicit bit
  and a0, a0, a7                                    # Clean the hypothethical implicit bit
  j sum

# The greater number is a denormal, the lower is zero or denormal. The "both zeros" case is caught by the "equal" label
both_denormal_zero:
  bnez a1, both_denormal                            # Branch if operands are both denormals (if lower operand is a denormal)
# Return the higher denormal if the lower is zero
  srli a0, a0, 8
  j exp_sign_and_exit

# Return the greater number
return_greater:
  slli a0, a0, 1                                    # Clean the hypothethical implicit bit
  srli a0, a0, 9
  j exp_sign_and_exit

# Special case: unsigned opA == unsigned opB
# in a0 and a1 we have the original values
# a2 and a3 are not ordered wrt a0 and a1, but this is not important since the numbers are the same
equal:
  bgez t2, equal_samesign                           # are the signs equal too?
zero:
  mv  a0, zero                                      # if not, the result is zero
  ret                                               # return if the result was zero
# a5 = 0xFF
equal_samesign:
  and a5, a5, a2                                    # the signs are equal. test unsigned opA (in a5 we have 0xFF)
  bnez a5, equal_nodenormal                         # branch if opA is a denormal (opA and opB are both denormal and are equal)
# opA and opB are both denormal, equal, with the same sign
  mv a0, a2                                         # replace the return value with 2*opA
  bgeu a2, a1, exit                                 # if opB (i.e. opA) is unsigned-less then its 2 times with no sign, opB (i.e. opA) was positive because bit[30] of opB was 0 before the multiplication. If equal, we had double zero (positive).
  lui a5, 0x80000                                   # prepare to re-set the sign bit if the denormal was negative
  or a0, a0, a5                                     # re-set the sign bit if the denormal was negative
  ret                                               # return

# Special case: (unsigned opA == unsigned opB) && we have no denormals
equal_nodenormal:
  srli a2, a2, 24                                   # isolate the exponent in a convenient position
  sltiu a5, a2, 0xFE                                # test if we can multiply the number by 2 with no ovf (check if the exponent is < 254)
  beqz a5, 7f                                       # branch if we will overflow
# a5 is 0
  lui a5, 0x00800                                   # if we can multiply by 2 with no ovf, double the result
  add a0, a0, a5                                    # if we can multiply by 2 with no ovf, double the result
  ret                                               # return 2*opA if we do not ovf
7:
# a5 is 1
  slli a5, a5, 31                                   # we will ovf: save the sign of opA
  and a3, a5, a0                                    # we will ovf: save the sign of opA in a3
# prepare the infinite
inf:
  lui a0, 0x7F800                                   # load unsigned infinite in the result
  j sign_and_exit                                   # return the correct infinite

# BE AWARE: a2 contains the higher operand << 2, and NOT X << 2. a2 and a3 are ordered, but a0 and a1 are not!
# Special case: X == {inf, NaN} and maybe also Y == {inf, NaN}
infnan:
  bgtu a2, a5, produce_nan                          # If there is a NaN in the operands, it is in a2 (greatest operand)
  bne a2, a3, inf

inf_inf:
  beq a0, a1, exit                                  # Return if same infinity
# Opposite infinities, produce a NaN
produce_nan:
# a5 = 0xFF000
  lui a0, 0x7FC00
  ret                                               # return quiet NaN

#endif
