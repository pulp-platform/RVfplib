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


#define xl a0
#define xh a1
#define yl a2
#define yh a3

#ifdef PERFORMANCE

# This division is slower than the libgcc's one
# Use the one from libgcc instead

## Add two numbers stored in two and three regs (x1-x0 and y2-y1-y0).
## x1 and y2 are the most significant regs
## The MSb of x1 and y2 is zero
## Result stored in y2, y1, y0
## x1 and x0 can be overwritten
#.macro ADD3Rto2T y2, y1, y0, x1, x0
#  add \y0, \y0, \x0
#  sltu \x0, \y0, \x0
#  add \x1, \x1, \x0
#  add \y1, \y1, \x1
#  sltu \x1, \y1, \x1
#  add \y2, \y2, \x1
#.endm
#
## Add two numbers stored in two couples of regs (x1-x0 and y1-y0).
## x1 and y1 are the most significant regs
## The MSb of x1 and y1 is zero
## Result stored in y1-y0
## x1 and x0 can be overwritten
#.macro ADD2Rto2R y1, y0, x1, x0
#  add \y0, \y0, \x0
#  sltu \x0, \y0, \x0
#  add \x1, \x1, \x0
#  add \y1, \y1, \x1
#.endm
#
## Shift left by 1 a number stored in two registers
## MSB in x1
#.macro SLLI1_2R x1, x0, a5
#  slli \x1, \x1, 1
#  srli \a5, \x0, 31
#  or \x1, \x1, \a5
#  slli \x0, \x0, 1
#.endm
#
## Shift right by 1 a number stored in two registers
## MSB in x1
#.macro SRLI1_2R x1, x0, temp
#  srli \x0, \x0, 1
#  slli \temp, \x1, 31
#  or \x0, \x0, \temp
#  srli \x1, \x1, 1
#.endm
#
## Shift left by 1 a number stored in three registers
## MSB in x2
#.macro SLLI1_3R x2, x1, x0, a5
#  slli \x2, \x2, 1
#  srli \a5, \x1, 31
#  or \x2, \x2, \a5
#  slli \x1, \x1, 1
#  srli \a5, \x0, 31
#  or \x1, \x1, \a5
#  slli \x0, \x0, 1
#.endm
#
#
#__divdf3:
#
#  # Check special cases
#  lui a5, 0xFFE00        # Load the exponent mask
#  slli a4, xh, 1         # Isolate X's sign and exponent
#  slli a6, yh, 1         # Isolate Y's sign and exponent
#  bgeu a4, a5, inf_nan    # Jump if A is Inf/NaN
#  bgeu a6, a5, inf_nan    # Jump if B is Inf/NaN
#  srli a4, a4, 21
#  srli a6, a6, 21
#  beqz a4, zero_denormal # Jump if A is zero/denormal
#  beqz a6, zero_denormal # Jump if B is zero/denormal
#
#normal_case:
#  # Subtract Y exponent from X exponent together
#  sub a4, a4, a6
#
#  # Preserve the final sign
#  xor t0, xh, yh                 # Determine the final sign
#
#	# Convert mantissa to unsigned integer
#	# Dividend in a5-a6, divisor in yh-yl
#  slli yh, yh, 12             # Clear exponent, isolate mantissa
#  or a5, yl, yh               # Look if the divisor mantissa is all 0
#  slli xh, xh, 12             # Clear exponent of dividend too
#  beqz a5, pow_2              # Jump to power of 2 divisor code
#  lui a5, 0x10000             # Implicit 1
#  srli yh, yh, 4              # Shift yh to its position
#  or yh, yh, a5               # Add implicit bit to divisor
#  srli t1, yl, 24             # Transfer divisor LSbs to higher reg
#  or yh, yh, t1
#  slli yl, yl, 8              # Complete the shift for yl
#  srli t1, xh, 4              # Do the same things for the dividend too
#  or a5, a5, t1
#  srli t1, xl, 24
#  or a5, a5, t1
#  slli a6, xl, 8
#
## Initialize the result with the final sign
#  lui t1, 0x80000               # Load 0x80000 mask for the sign
#  and xh, t0, t1                # Isolate the division sign
#
## Add exponent bias and check if dividend < divisor
## If yes, right shift divisor and adjut the exponent accordingly
#  sub t1, a5, yh
#  seqz t1, t1
#  sltu t2, a6, yl
#  and t1, t1, t2
#  sltu t0, a5, yh
#  or t1, t1, t0
#  addi a4, a4, 1022             # 1023-1, preventively. -1 is for the implicit bit that will be added in the end
#  sub a4, a4, t1                # Sub 1 if dividend < divisor
#  beqz t1, 1f                   # Jump away it dividend >= divisor
## If dividend < divisor, right shift the divisor by one. The exponent was decreased by one more
#  SRLI1_2R yh, yl, t1
#1:
## Subtract one to be aligned by half of a Byte
#  sltu t2, a6, yl
#  sub a6, a6, yl
#  sub a5, a5, yh
#  sub a5, a5, t2                # Subtract one more if a6 < yl
#  SRLI1_2R yh, yl, t1
#  lui xl, 0x00100               # Implicit bit for the result, We can put it thanks to the previous sub
#  lui t2, 0x00080               # Chisel for the result
#
## Division loop
#div_loop_start:
#  sltu t1, a6, yl
#  sub t0, a5, yh
#  sub t0, t0, t1
#  bltz t0, 1f
#  sub a6, a6, yl
#  mv a5, t0
#  or xl, xl, t2
#1:
#  SRLI1_2R yh, yl, t0
#  sltu t1, a6, yl
#  sub t0, a5, yh
#  sub t0, t0, t1
#  bltz t0, 2f
#  sub a6, a6, yl
#  mv a5, t0
#  srli t0, t2, 1
#  or xl, xl, t0
#2:
#  SRLI1_2R yh, yl, t0
#  sltu t1, a6, yl
#  sub t0, a5, yh
#  sub t0, t0, t1
#  bltz t0, 3f
#  sub a6, a6, yl
#  mv a5, t0
#  srli t0, t2, 2
#  or xl, xl, t0
#3:
#  SRLI1_2R yh, yl, t0
#  sltu t1, a6, yl
#  sub t0, a5, yh
#  sub t0, t0, t1
#  bltz t0, 4f
#  sub a6, a6, yl
#  mv a5, t0
#  srli t0, t2, 3
#  or xl, xl, t0
#4:
#  or t0, a5, a6
#  beqz t0, div_loop_exit
#  slli a5, a5, 4
#  srli t0, a6, 28
#  or a5, a5, t0
#  slli a6, a6, 4
#  slli yh, yh, 3
#  srli t0, yl, 29
#  or yh, yh, t0
#  slli yl, yl, 3
#  srli t2, t2, 4
#  bnez t2, div_loop_start
#
## Loop again for the lower word of the dividend
#  lui t0, 0x00100
#  and t0, t0, xh
#  bnez t0, checks
#  or xh, xh, xl
#  li xl, 0
#  lui t2, 0x80000
#  j div_loop_start
#
## The result should start from the MSR
#div_loop_exit:
#  lui t0, 0x00100
#  and t0, t0, xh
#  bnez t0, checks
#  or xh, xh, xl
#  li xl, 0
#checks:
## Check for overflow/underflow
#  addi t2, a4, -253
#  bgeu t2, a4, exp_round
#  li t0, 0x700
#  bgtu t2, t0, und_ov_flow
#
#exp_round:
## Round the result and merge the final exponent
#  slli a4, a4, 20
#  add xh, xh, a4
## Round up if r5-r6 > yh-yl. If equal, round up if the result is ODD
#  bltu a5, yh, exit
#  bgtu a5, yh, round_up
#  bltu a6, yl, exit
#  bgt a6, yl, round_up
#  slli t0, xl, 31
#  beqz t0, exit
#round_up:
#  addi xl, xl, 1
#  seqz t0, xl
#  add xh, xh, t0
#exit:
#  ret
#
## Division by 0x1p*: let's shortcut a lot of code
#pow_2:
#  lui t1, 0x80000                 # Load 0x80000 mask for the sign
#  and t0, t0, t1
#  srli xh, xh, 12                 # Bring mantissa to its place
#  or xh, xh, t0                   # Restore the sign
#  addi a4, a4, 0x3FF              # Add 2047 (bias)
#  blez a4, pre_underflow
#  slti t0, a4, 0x7FF
#  beqz t0, ovf
#  slli a4, a4, 20
#  or xh, xh, a4
#  ret
#
## Under/Overflow: fix things up for the code below
#pre_underflow:
#  li a6, 0
#  li a5, 0
#  lui t0, 0x00100                 # Load implicit 1 pattern
#  or xh, xh, t0                   # Load implicit 1 into the result
#  addi a4, a4, -1                 # Decrement the exponent by one
#  j denormal_check
#
## Check for overflow/underflow
## If we are here, we ore either in ovf or in underflow
#und_ov_flow:
## Overflow?
#  bgt t2, t0, ovf                # Branch to Ovf handling if an overflow occurred
## Check if denormlized result is possible, otherwise return signed 0
#denormal_check:
#  li t1, -53                     # Prepare condition
#  blt a4, t1, signed_zero        # Can we return something different than zero? Branch if no.
#
## Shift value right, round, etc.
## If we are here, (-53 <= a4 <= -1)
#denormal_end:
#  or a6, a6, a5
#  snez a6, a6
#  lui t5, 0x80000
#  li t4, 0
#  and t5, t5, xh                  # Save the sign
#  xor xh, xh, t5                  # Clear the sign from xh
#  neg a4, a4                      # Find shamt = |exp|
## (1 <= shamt <= 53)
#  li a5, 32
#  bge a4, a5, 1f                  # Branch away if (32 <= shamt <= 53)
## We do not need a preshift
#  sub a5, a5, a4                  # Find the complementary shamt
#
## (1 <= shamt <= 20). We need a right-shift.
## OR
## (21 <= shamt <= 31). We need a fake 32-bit preshift and a left shift
#3:
#  snez a2, t4                     # Concentrate a partial sticky bit in t1
#  sll t4, xl, a5                 # Setup the round bit and the other sticky bits
#  or t4, t4, a2                   # Append the partial sticky bit to the others
#  srl xl, xl, a4                 # Right shift xl by the correct amount
#  sll a2, xh, a5                 # Left shift xh after a fake 32-bit preshift
#  or xl, xl, a2                  # Append it to xl
#  srl xh, xh, a4                 # Right shift xh
#
#den_rounding:
#  or xh, xh, t5                  # Restore the sign
#  bgez t4, exit
#  addi xl, xl, 1
#  seqz t0, xl
#  add xh, xh, t0
#  slli t4, t4, 1
#  or t4, t4, a6
#  bnez t4, exit
#  andi xl, xl, -2
#  ret
#
## (32 <= shamt <= 53). We need a 32-bit preshift and a right shift
#1:
#  addi a4, a4, -32                # Adjust the exponent taking into account the 32-bit preshift
## Preshift by 32-bit
#  mv t4, xl
#  mv xl, xh
#  li xh, 0
#  beqz a4, den_rounding               # Branch away if shamt was 32.
## (1 < shamt <= 21) with a previous 32-bit preshift.
#  sub a5, a5, a4                  # Find the complementary shamt
## Right shift by shamt
#  j 3b
#
## One or both arguments are denormalized. None of them is zero.
## Scale them leftwards and preserve sign bit
## a5 contains 0x80000000
#denormal:
#  lui a5, 0x80000
#  srli t3, a5, 11               # Prepare the implicit 1
## Check if X is denormalized
#  and t1, xh, a5                # Extract sign of X
#  bnez a4, 3f                   # Branch if X is not a denormal
## X is denormalized
#2:
#  SLLI1_2R xh, xl, t5           # Shift left X by 1 position
#  and t2, xh, t3                # Implicit 1 restored?
#  bnez t2, 3f                   # Branch if the implicit 1 is restored
#  addi a4, a4, -1               # Subtract 1 from X exponent
#  j 2b
#3:
#  or xh, xh, t1                 # Restore X sign
## Check if Y is denormalized
#  and a5, a5, yh                # Extract sign of Y
#  bnez a6, 5f                   # Jump if Y is not denormal
## Y is denormalized
#4:
#  SLLI1_2R yh, yl, t5           # Shift left Y by 1 position
#  and t2, yh, t3                # Implicit 1 restored?
#  bnez t2, 5f                   # Branch if the implicit 1 is restored
#  addi a6, a6, -1               # Subtract 1 from Y exponent
#  j 4b
#5:
#  or yh, yh, a5                 # Restore Y sign
#  j normal_case
#
## One or more arguments are either denormalized or zero
## a5 contains 0x7FF00000
#zero_denormal:
#  slli a5, yh, 1
#  or a5, a5, yl
#  slli t2, xh, 1
#  or t2, t2, xl
#  beqz a5, div_by_zero
#  bnez t2, denormal
## Result is zero, but determine sign anyway
## a5 contains 0x7FF00000
#zero:
#  xor xh, xh, yh                # Determine the correct sign of the division
#signed_zero:
#  srli xh, xh, 31               # Clear mantissa
#  slli xh, xh, 31
#  li xl, 0                      # Append zero
#  ret
#
## One or both args are inf or NaN
#inf_nan:
## Check for NaN
#  snez t0, xl
#  or t0, t0, a4
#  bgtu t0, a5, nan               # NaN if X is NaN
#  snez t0, yl
#  or t0, t0, a6
#  bgtu t0, a5, nan               # NaN if Y is NaN
## At least one of the two is Inf
#  beq a4, a6, nan               # Jump away if both inf
## There is only one Inf
#  beq a6, a5, zero              # Divisor is an Inf, return zero
## The dividend is an Inf. The result is inf, determine its sign
#inf:
#  xor xh, xh, yh
#
## Overflow: return Inf (sign already in a0).
#ovf:
#  lui a3, 0x7FF00               # Load inf pattern
#  srli xh, xh, 31               # Clean xh mantissa
#  slli xh, xh, 31               # Clean xh mantissa
#  or xh, xh, a3                 # Add the inf pattern
#  li xl, 0
#  ret
#
#div_by_zero:
## Check 0/0 case -> NaN
#  bnez t2, inf
## Return a quiet NaN.
#nan:
#  lui xh, 0x7FF80               # Load qNaN pattern
#  li xl, 0                      # Add qNaN pattern to xh
#  ret                           # Return

#else

.global __divdf3

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

# Shift right by 1 a number stored in two registers
# MSB in x1
.macro SRLI1_2R x1, x0, temp
  srli \x0, \x0, 1
  slli \temp, \x1, 31
  or \x0, \x0, \temp
  srli \x1, \x1, 1
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


__divdf3:
  # Check special cases
  lui a5, 0xFFE00        # Load the exponent mask
  slli a4, xh, 1         # Isolate X's sign and exponent
  slli a6, yh, 1         # Isolate Y's sign and exponent
  bgeu a4, a5, inf_nan    # Jump if A is Inf/NaN
  bgeu a6, a5, inf_nan    # Jump if B is Inf/NaN
  srli a4, a4, 21
  srli a6, a6, 21
  beqz a4, zero_denormal # Jump if A is zero/denormal
  beqz a6, zero_denormal # Jump if B is zero/denormal

normal_case:
  # Subtract Y exponent from X exponent together
  sub a4, a4, a6

  # Preserve the final sign
  xor t0, xh, yh                 # Determine the final sign

  # Convert mantissa to unsigned integer
  # Dividend in a5-a6, divisor in yh-yl
  slli yh, yh, 12             # Clear exponent, isolate mantissa
  slli xh, xh, 12             # Clear exponent of dividend too
  lui a5, 0x10000             # Implicit 1
  srli yh, yh, 4              # Shift yh to its position
  or yh, yh, a5               # Add implicit bit to divisor
  srli t1, yl, 24             # Transfer divisor LSbs to higher reg
  or yh, yh, t1
  slli yl, yl, 8              # Complete the shift for yl
  srli t1, xh, 4              # Do the same things for the dividend too
  or a5, a5, t1
  srli t1, xl, 24
  or a5, a5, t1
  slli a6, xl, 8

# Initialize the result with the final sign
  lui t1, 0x80000               # Load 0x80000 mask for the sign
  and xh, t0, t1                # Isolate the division sign

# Add exponent bias and check if dividend < divisor
# If yes, right shift divisor and adjut the exponent accordingly
  sub t1, a5, yh
  seqz t1, t1
  sltu t2, a6, yl
  and t1, t1, t2
  sltu t0, a5, yh
  or t1, t1, t0
  addi a4, a4, 1022             # 1023-1, preventively. -1 is for the implicit bit that will be added in the end
  sub a4, a4, t1                # Sub 1 if dividend < divisor
  beqz t1, 1f                   # Jump away it dividend >= divisor
# If dividend < divisor, right shift the divisor by one. The exponent was decreased by one more
  SRLI1_2R yh, yl, t1
1:
# Subtract one to be aligned by half of a Byte
  sltu t2, a6, yl
  sub a6, a6, yl
  sub a5, a5, yh
  sub a5, a5, t2                # Subtract one more if a6 < yl
  SRLI1_2R yh, yl, t1
  lui xl, 0x00100               # Implicit bit for the result, We can put it thanks to the previous sub
  lui t2, 0x00080               # Chisel for the result

# Division loop
div_loop_start:
  sltu t1, a6, yl
  sub t0, a5, yh
  sub t0, t0, t1
  bltz t0, 1f
  sub a6, a6, yl
  mv a5, t0
  or xl, xl, t2
1:
  SRLI1_2R yh, yl, t0
  sltu t1, a6, yl
  sub t0, a5, yh
  sub t0, t0, t1
  bltz t0, 2f
  sub a6, a6, yl
  mv a5, t0
  srli t0, t2, 1
  or xl, xl, t0
2:
  SRLI1_2R yh, yl, t0
  sltu t1, a6, yl
  sub t0, a5, yh
  sub t0, t0, t1
  bltz t0, 3f
  sub a6, a6, yl
  mv a5, t0
  srli t0, t2, 2
  or xl, xl, t0
3:
  SRLI1_2R yh, yl, t0
  sltu t1, a6, yl
  sub t0, a5, yh
  sub t0, t0, t1
  bltz t0, 4f
  sub a6, a6, yl
  mv a5, t0
  srli t0, t2, 3
  or xl, xl, t0
4:
  or t0, a5, a6
  beqz t0, div_loop_exit
  slli a5, a5, 4
  srli t0, a6, 28
  or a5, a5, t0
  slli a6, a6, 4
  slli yh, yh, 3
  srli t0, yl, 29
  or yh, yh, t0
  slli yl, yl, 3
  srli t2, t2, 4
  bnez t2, div_loop_start

# Loop again for the lower word of the dividend
  lui t0, 0x00100
  and t0, t0, xh
  bnez t0, checks
  or xh, xh, xl
  li xl, 0
  lui t2, 0x80000
  j div_loop_start

# The result should start from the MSR
div_loop_exit:
  lui t0, 0x00100
  and t0, t0, xh
  bnez t0, checks
  or xh, xh, xl
  li xl, 0
checks:
# Check for overflow/underflow
  addi t2, a4, -253
  bgeu t2, a4, exp_round
  li t0, 0x700
  bgtu t2, t0, und_ov_flow

exp_round:
# Round the result and merge the final exponent
  slli a4, a4, 20
  add xh, xh, a4
# Round up if r5-r6 > yh-yl. If equal, round up if the result is ODD (Round to nearest even)
  bltu a5, yh, exit
  bgtu a5, yh, round_up
  bltu a6, yl, exit
  bgtu a6, yl, round_up
  slli t0, xl, 31
  beqz t0, exit
round_up:
  addi xl, xl, 1
  seqz t0, xl
  add xh, xh, t0
exit:
  ret

# Check for overflow/underflow
# If we are here, we ore either in ovf or in underflow
und_ov_flow:
# Overflow?
  bgt t2, t0, ovf                    # Branch to Ovf handling if an overflow occurred
# Check if denormlized result is possible, otherwise return signed 0
  li t1, -53                      # Prepare condition
  blt a4, t1, signed_zero        # Can we return something different than zero? Branch if no.

# Shift value right, round, etc.
# If we are here, (-53 <= a4 <= -1)
denormal_end:
  or a6, a6, a5
  snez a6, a6
  lui t5, 0x80000
  li t4, 0
  and t5, t5, xh                  # Save the sign
  xor xh, xh, t5                  # Clear the sign from xh
  neg a4, a4                      # Find shamt = |exp|
# (1 <= shamt <= 53)
  li a5, 32
  bge a4, a5, 1f                  # Branch away if (32 <= shamt <= 53)
# We do not need a preshift
  sub a5, a5, a4                  # Find the complementary shamt

# (1 <= shamt <= 20). We need a right-shift.
# OR
# (21 <= shamt <= 31). We need a fake 32-bit preshift and a left shift
3:
  snez a2, t4                     # Concentrate a partial sticky bit in t1
  sll t4, xl, a5                 # Setup the round bit and the other sticky bits
  or t4, t4, a2                   # Append the partial sticky bit to the others
  srl xl, xl, a4                 # Right shift xl by the correct amount
  sll a2, xh, a5                 # Left shift xh after a fake 32-bit preshift
  or xl, xl, a2                  # Append it to xl
  srl xh, xh, a4                 # Right shift xh

den_rounding:
  or xh, xh, t5                  # Restore the sign
  bgez t4, exit
  addi xl, xl, 1
  seqz t0, xl
  add xh, xh, t0
  slli t4, t4, 1
  or t4, t4, a6
  bnez t4, exit
  andi xl, xl, -2
  ret

# (32 <= shamt <= 53). We need a 32-bit preshift and a right shift
1:
  addi a4, a4, -32                # Adjust the exponent taking into account the 32-bit preshift
# Preshift by 32-bit
  mv t4, xl
  mv xl, xh
  li xh, 0
  beqz a4, den_rounding               # Branch away if shamt was 32.
# (1 < shamt <= 21) with a previous 32-bit preshift.
  sub a5, a5, a4                  # Find the complementary shamt
# Right shift by shamt
  j 3b

# One or both arguments are denormalized. None of them is zero.
# Scale them leftwards and preserve sign bit
# a5 contains 0x80000000
denormal:
  lui a5, 0x80000
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
# a5 contains 0x7FF00000
zero_denormal:
  slli a5, yh, 1
  or a5, a5, yl
  slli t2, xh, 1
  or t2, t2, xl
  beqz a5, div_by_zero
  bnez t2, denormal
# Result is zero, but determine sign anyway
# a5 contains 0x7FF00000
zero:
  xor xh, xh, yh                # Determine the correct sign of the division
signed_zero:
  srli xh, xh, 31               # Clear mantissa
  slli xh, xh, 31
  li xl, 0                      # Append zero
  ret

# One or both args are inf or NaN
inf_nan:
# Check for NaN
  snez t0, xl
  or t0, t0, a4
  bgtu t0, a5, nan               # NaN if X is NaN
  snez t0, yl
  or t0, t0, a6
  bgtu t0, a5, nan               # NaN if Y is NaN
# At least one of the two is Inf
  beq a4, a6, nan               # Jump away if both inf
# There is only one Inf
  beq a6, a5, zero              # Divisor is an Inf, return zero
# The dividend is an Inf. The result is inf, determine its sign
inf:
  xor xh, xh, yh

# Overflow: return Inf (sign already in a0).
ovf:
  lui a3, 0x7FF00               # Load inf pattern
  srli xh, xh, 31               # Clean xh mantissa
  slli xh, xh, 31               # Clean xh mantissa
  or xh, xh, a3                 # Add the inf pattern
  li xl, 0
  ret

div_by_zero:
# Check 0/0 case -> NaN
  bnez t2, inf
# Return a quiet NaN.
nan:
  lui xh, 0x7FF80               # Load qNaN pattern
  li xl, 0                      # Add qNaN pattern to xh
  ret                           # Return

#endif
