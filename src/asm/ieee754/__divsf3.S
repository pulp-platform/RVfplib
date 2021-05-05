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

# Define OPPORTUNISTIC_NAN to save code size. The information in the input NaN will be discarded, and the output will be a quiet NaN different from the input one
# If OPPORTUNISTIC_NAN is not defined, the input NaN is extended and transformed into a quiet NaN (consistent with libgcc)

.global __divsf3

#ifdef PERFORMANCE

__divsf3:
	# Determine the final sign
	lui t0, 0x80000        # Load the sign mask
	# Check special cases
	li a5, 0xff            # Load the exponent mask
	srli a2, a0, 23        # Isolate X's sign and exponent
	and a2, a2, a5         # Isolate X's exponent
	srli a3, a1, 23        # Isolate Y's sign and exponent
	and a3, a3, a5         # Isolate Y's exponent
	beq a2, a5, inf_nan    # Jump if A is Inf/NaN
	beq a3, a5, inf_nan    # Jump if B is Inf/NaN
	beqz a2, zero_denormal # Jump if A is zero/denormal
	beqz a3, zero_denormal # Jump if B is zero/denormal

normal_case:
	# Subtract Y exponent from X exponent together
	sub a2, a2, a3

	# Preserve the final sign
	xor t2, a0, a1         # Determine the final sign

	# Convert mantissa to unsigned integer
	# Dividend in a3, divisor in a1
	slli a0, a0, 9         # Isolate X's mantissa
	slli a1, a1, 9         # Isolate Y's mantissa
	beqz a1, pow_2         # Check if divisor is power of 2
	lui a3, 0x10000        # Prepare the implicit 1
	srli a0, a0, 4
	srli a1, a1, 4
	or a1, a1, a3          # Add implicit 1 to dividend (a3) and divisor (a1)
	or a3, a3, a0

	# Initialize the result with the final sign
	and a0, t2, t0         # Isolate the sign

	# Add exponent bias and check if dividend < divisor
	# If no, left shift dividend and adjut the exponent accordingly
	slt a5, a3, a1
	sll a3, a3, a5
	addi a2, a2, 126       # Add one less as we will add also the implicit 1 to the exponent
	sub a2, a2, a5         # Subtract one if needed

	# Division loop
	lui a5, 0x00800
div_loop_start:
	blt a3, a1, 1f
	sub a3, a3, a1
	or a0, a0, a5
1:
	srli a4, a1, 1
	blt a3, a4, 2f
	srli t1, a5, 1
	sub a3, a3, a4
	or a0, a0, t1
2:
	srli a4, a1, 2
	blt a3, a4, 3f
	srli t1, a5, 2
	sub a3, a3, a4
	or a0, a0, t1
3:
	srli a4, a1, 3
	blt a3, a4, 4f
	srli t1, a5, 3
	sub a3, a3, a4
	or a0, a0, t1
4:
	slli a3, a3, 4
	beqz a3, div_loop_exit
	srli a5, a5, 4
	bnez a5, div_loop_start

div_loop_exit:
	# Check for under/overflow
	li t2, 254
	bgeu a2, t2, und_ov_flow

	# Round the result and merge the final exponent
	slli a2, a2, 23
	add a0, a0, a2
	bltu a3, a1, exit
	addi a0, a0, 1
	bne a3, a1, exit
	andi a0, a0, -2
exit:
	ret

	# The divisor is a multiple of 2
pow_2:
	and t2, t2, t0         # Isolate the sign
	srli a5, a0, 9
	or a0, t2, a5
	addi a2, a2, 127       # Add full bias, as we don't have the implicit bit
  blez a2, pre_und_ov_flow
	li a3, 255
  bge a2, a3, pre_und_ov_flow
	slli a2, a2, 23
	or a0, a0, a2
	ret

	# Under/overflow: fix things up for the code below
pre_und_ov_flow:
	lui t2, 0x00800
	or a0, a0, t2
	li a3, 0
	addi a2, a2, -1

und_ov_flow:
  # Overflow?
  bgtz a2, ovf      # If here, a2 is either in ovf (> 0) or in underflow (<= 0)

  # Check if denormalized result is possible, otherwise return signed 0.
  addi t2, a2, 26
  bge t2, x0, denormal_end
# t0 = 0x80000
  and a0, a0, t0
  ret

  # Shift value right, round, etc.
denormal_end:
  neg a5, a2         # Make a2 positive in t2
# t0 = 0x80000
  and t2, t0, a0     # Sign in t0
  xor a0, a0, t2     # Mask sign
  add a2, a2, 32     # Reg-compl shamt in a2
  sll a2, a0, a2     # Isolate excluded bits of a0 in a2 MSbs
  srl a0, a0, a5     # Shift right a0 by |a2|
  or a0, a0, t2      # Re-apply the sign to a0
# Round (RNE)
  srli a3, a3, 1     # Append the lower part of the result
  or a2, a2, a3      # The MSB of a2 can be now used as a R bit
# t0 = 0x80000
  bltu a2, t0, exit  # Jump away if we do not round
  addi a0, a0, 1     # Otherwise, preventively round up
  bne a2, t0, exit   # Jump away if no tie
  andi a0, a0, -2
  ret             # Exit

  # One or both arguments are denormalized.
  # Scale them leftwards and preserve sign bit.
denormal:
  lui t2, 0x00800    # Load implicit 1 mask
# Check A
# t0 = 0x80000
  and a4, t0, a0     # Extract sign of A
  bnez a2, 3f        # Jump if A is not denormal
# A is a denormal
2:
  slli a0, a0, 1     # Shift left by one
  and a5, a0, t2     # Implicit 1 restored?
  bnez a5, 3f        # Yes: go on (A is no more a denormal)
  addi a2, a2, -1    # No: subtract 1 to the exponent
  j 2b               # Repeat
3:
  or a0, a0, a4      # Restore sign A
# Check B
  lui a4, 0x80000    # Load sign mask
  and a4, a4, a1     # Extract sign of B
  bnez a3, 5f        # Jump if B is not denormal
# B is a denormal
4:
  slli a1, a1, 1     # Shift left by one
  and a5, a1, t2     # Implicit 1 restored?
  bnez a5, 5f        # Yes: go on (B is no more a denormal)
  addi a3, a3, -1    # No: subtract 1 to the exponent
  j 4b               # Repeat
5:
  or a1, a1, a4      # Restore sign B
  j normal_case

zero_denormal:
  # Here, one or more arguments are either denormalized or zero.
  not t2, t0           # t0 = 0x7FFFFFFF
  and a5, t2, a1       # Mask away the sign of B
  and t2, t2, a0       # Mask away the sign of A
  beqz a5, div_by_zero # Jump to Inf if Y is 0
  bnez t2, denormal    # Retrun 0 if A is zero, otherwise jump to denormal

  # Result is 0, but determine sign anyway.
zero:
  xor a0, a0, a1       # Determine the correct sign of the multiplication
# t0 = 0x80000
  and a0, a0, t0       # Append Zero
  ret

  # One or both args are INF or NAN.
inf_nan:
  slli a5, a5, 24      # Prepare the mask for NaN
# Check for NaN first
  slli a2, a0, 1       # Eliminate the sign of A
  bltu a5, a2, nan     # Return NaN if A is NaN
  slli a3, a1, 1       # Eliminate the sign of B
  bltu a5, a3, nan     # Return NaN if B is NaN
# Check for Inf
  beq a2, a3, nan      # They are both Inf -> return NaN
# There is only one Inf.
  beq a3, a5, zero     # Y is an inf, return zero
# X is inf, Y is a number. Result is INF, but we need to determine its sign.
inf:
  xor a0, a0, a1    # Put the correct sign into a0

  # Overflow: return Inf (sign already in a0).
ovf:
# t0 = 0x80000
  and a0, a0, t0    # Isolate the sign
  lui t0, 0x7f800   # Set max exponent
  or a0, a0, t0     # Set max exponent
  ret               # Return

div_by_zero:
# Check 0/0 case -> NaN
  or a5, a5, t2
  bnez a5, inf
# Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#else

__divsf3:
  # Determine the final sign
  lui t0, 0x80000        # Load the sign mask
  # Check special cases
  lui a5, 0xff000        # Load the exponent mask
  slli a2, a0, 1         # Isolate X's sign and exponent
  slli a3, a1, 1         # Isolate Y's sign and exponent
  bgeu a2, a5, inf_nan    # Jump if A is Inf/NaN
  bgeu a3, a5, inf_nan    # Jump if B is Inf/NaN
  srli a2, a2, 24         # Isolate X's exponent
  srli a3, a3, 24         # Isolate Y's exponent
  beqz a2, zero_denormal # Jump if A is zero/denormal
  beqz a3, zero_denormal # Jump if B is zero/denormal

normal_case:
  # Subtract Y exponent from X exponent together
  sub a2, a2, a3

  # Preserve the final sign
  xor t2, a0, a1         # Determine the final sign

  # Convert mantissa to unsigned integer
  # Dividend in a3, divisor in a1
  slli a0, a0, 9         # Isolate X's mantissa
  slli a1, a1, 9         # Isolate Y's mantissa
  lui a3, 0x10000        # Prepare the implicit 1
  srli a0, a0, 4
  srli a1, a1, 4
  or a1, a1, a3          # Add implicit 1 to dividend (a3) and divisor (a1)
  or a3, a3, a0

  # Initialize the result with the final sign
  and a0, t2, t0         # Isolate the sign

  # Add exponent bias and check if dividend < divisor
  # If no, left shift dividend and adjut the exponent accordingly
  slt a5, a3, a1
  sll a3, a3, a5
  addi a2, a2, 126       # Add one less as we will add also the implicit 1 to the exponent
  sub a2, a2, a5         # Subtract one if needed

  # Condensed division loop
  lui a5, 0x00800
div_loop_start:
  blt a3, a1, 1f
  sub a3, a3, a1
  or a0, a0, a5
1:
  slli a3, a3, 1
  beqz a3, div_loop_exit
  srli a5, a5, 1
  bnez a5, div_loop_start

div_loop_exit:
  # Check for under/overflow
  li t2, 254
  bgeu a2, t2, und_ov_flow

  # Round the result and merge the final exponent
  slli a2, a2, 23
  add a0, a0, a2
  bltu a3, a1, exit
  addi a0, a0, 1
  bne a3, a1, exit
  andi a0, a0, -2
exit:
  ret

und_ov_flow:
  # Overflow?
  bgtz a2, ovf      # If here, a2 is either in ovf (> 0) or in underflow (<= 0)
  # Check if denormalized result is possible, otherwise return signed 0.
  addi t2, a2, 26
  bge t2, x0, denormal_end
# t0 = 0x80000
  and a0, a0, t0
  ret

  # Shift value right, round, etc.
denormal_end:
  neg a5, a2         # Make a2 positive in t2
# t0 = 0x80000
  and t2, t0, a0     # Sign in t0
  xor a0, a0, t2     # Mask sign
  add a2, a2, 32     # Reg-compl shamt in a2
  sll a2, a0, a2     # Isolate excluded bits of a0 in a2 MSbs
  srl a0, a0, a5     # Shift right a0 by |a2|
  or a0, a0, t2      # Re-apply the sign to a0
# Round (RNE)
  srli a3, a3, 1     # Append the lower part of the result
  or a2, a2, a3      # The MSB of a2 can be now used as a R bit
# t0 = 0x80000
  bltu a2, t0, exit  # Jump away if we do not round
  addi a0, a0, 1     # Otherwise, preventively round up
  bne a2, t0, exit   # Jump away if no tie
  andi a0, a0, -2
  ret             # Exit

  # One or both arguments are denormalized.
  # Scale them leftwards and preserve sign bit.
denormal:
  lui t2, 0x00800    # Load implicit 1 mask
# Check A
# t0 = 0x80000
  and a4, t0, a0     # Extract sign of A
  bnez a2, 3f        # Jump if A is not denormal
# A is a denormal
2:
  slli a0, a0, 1     # Shift left by one
  and a5, a0, t2     # Implicit 1 restored?
  bnez a5, 3f        # Yes: go on (A is no more a denormal)
  addi a2, a2, -1    # No: subtract 1 to the exponent
  j 2b               # Repeat
3:
  or a0, a0, a4      # Restore sign A
# Check B
  lui a4, 0x80000    # Load sign mask
  and a4, a4, a1     # Extract sign of B
  bnez a3, 5f        # Jump if B is not denormal
# B is a denormal
4:
  slli a1, a1, 1     # Shift left by one
  and a5, a1, t2     # Implicit 1 restored?
  bnez a5, 5f        # Yes: go on (B is no more a denormal)
  addi a3, a3, -1    # No: subtract 1 to the exponent
  j 4b               # Repeat
5:
  or a1, a1, a4      # Restore sign B
  j normal_case

zero_denormal:
  # Here, one or more arguments are either denormalized or zero.
  slli a5, a1, 1       # Mask away the sign of B
  slli t2, a0, 1       # Mask away the sign of A
  beqz a5, div_by_zero # Jump to Inf if Y is 0
  bnez t2, denormal    # Retrun 0 if A is zero, otherwise jump to denormal

  # Result is 0, but determine sign anyway.
zero:
  xor a0, a0, a1       # Determine the correct sign of the multiplication
# t0 = 0x80000
  and a0, a0, t0       # Append Zero
  ret

  # One or both args are INF or NAN.
inf_nan:
# Check for NaN first
  bltu a5, a2, nan     # Return NaN if A is NaN
  bltu a5, a3, nan     # Return NaN if B is NaN
# Check for Inf
  beq a2, a3, nan      # They are both Inf -> return NaN
# There is only one Inf.
  beq a3, a5, zero     # Y is an inf, return zero
# X is inf, Y is a number. Result is INF, but we need to determine its sign.
inf:
  xor a0, a0, a1    # Put the correct sign into a0

  # Overflow: return Inf (sign already in a0).
ovf:
# t0 = 0x80000
  and a0, a0, t0    # Isolate the sign
  lui t0, 0x7f800   # Set max exponent
  or a0, a0, t0     # Set max exponent
  ret               # Return

div_by_zero:
# Check 0/0 case -> NaN
  bnez t2, inf
# Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#endif
