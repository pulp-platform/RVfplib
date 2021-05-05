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
	and t2, t2, t0       # Isolate the sign
	srli a5, a0, 9
	or a0, t2, a5
	addi a2, a2, 127     # Add full bias, as we don't have the implicit bit
  blez a2, pre_und_ov_flow
	li a3, 255
  bge a2, a3, pre_und_ov_flow
	slli a2, a2, 23
	or a0, a0, a2
	ret

	# Under/overflow: fix things up for the code below
pre_und_ov_flow:
	addi a2, a2, -1
und_ov_flow:
  # Overflow?
  bgtz a2, ovf         # If here, a2 is either in ovf (> 0) or in underflow (<= 0)
# Return signed 0
  srli a0, a0, 31
  slli a0, a0, 31
  ret

zero_denormal:
# Here, one or more arguments are either denormalized or zero.
  bnez a2, inf         # Jump to Inf if X is not zero (Y is 0)
# X == 0
  beqz a3, nan         # Return NaN if 0/0
# Result is 0, but determine sign anyway.
zero:
  xor a0, a0, a1       # Determine the correct sign of the multiplication
# t0 = 0x80000
  and a0, a0, t0       # Append Zero
  ret

  # One or both args are INF or NAN.
inf_nan:
  slli a5, a5, 24        # Prepare the mask for NaN
# Check for NaN first
  slli a2, a0, 1         # Eliminate the sign of A
  bltu a5, a2, nan       # Return NaN if A is NaN
  slli a3, a1, 1         # Eliminate the sign of B
  bltu a5, a3, nan       # Return NaN if B is NaN
# Check for Inf
  beq a2, a3, nan        # They are both Inf -> return NaN
# There is only one Inf.
  beq a3, a5, zero       # Y is an inf, return zero
# X is inf, Y is a number. Result is INF, but we need to determine its sign.
inf:
  xor a0, a0, a1         # Put the correct sign into a0

  # Overflow: return Inf (sign already in a0).
ovf:
# t0 = 0x80000
  and a0, a0, t0         # Isolate the sign
  lui t0, 0x7f800        # Set max exponent
  or a0, a0, t0          # Set max exponent
  ret                    # Return

# Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#else

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
  bgtz a2, ovf         # If here, a2 is either in ovf (> 0) or in underflow (<= 0)
  srli a0, a0, 31
  slli a0, a0, 31
  # Return signed 0
  ret

zero_denormal:
# Here, one or more arguments are either denormalized or zero.
  bnez a2, inf         # Jump to Inf if X is not zero (Y is 0)
# X == 0
  beqz a3, nan         # Return NaN if 0/0
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
  xor a0, a0, a1       # Put the correct sign into a0
  # Overflow: return Inf (sign already in a0).
ovf:
# t0 = 0x80000
  and a0, a0, t0       # Isolate the sign
  lui t0, 0x7f800      # Set max exponent
  or a0, a0, t0        # Set max exponent
  ret                  # Return

# Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#endif
