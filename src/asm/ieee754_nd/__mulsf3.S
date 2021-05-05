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

# RISC-V mul, denormals flushed to 0

.global __mulsf3

__mulsf3:
  lui a4, 0x80000           # Prepare the mask for the sign
  xor a5, a0, a1            # Determine the final sign
  and a4, a4, a5            # Determine the final sign
  # Mask out exponents, trap any zero/denormal/INF/NAN.
  addi a5, x0, 0xff         # Prepare the exp. mask
  srli a2, a0, 23           # Isolate sign and exp. (A)
  and a2, a2, a5            # Isolate exp. (A)
  srli a3, a1, 23           # Isolate sign and exp. (B)
  and a3, a3, a5            # Isolate exp. (B)
  beq a2, a5, inf_nan       # Jump if A is Inf/NaN
  beq a3, a5, inf_nan       # Jump if B is Inf/NaN
  beqz a2, zero_denormal    # Jump if A is zero/denormal
  beqz a3, zero_denormal    # Jump if B is zero/denormal

normal_case:
  # Add exponents together
  add a2, a2, a3     # Add exponents together

  # Convert mantissa to unsigned integer.
  # If power of two, branch to a separate path.
  # Make up for final alignment.
  slli a0, a0, 9             # Isolate mantissa A
  slli a1, a1, 9             # Isolate mantissa B
  lui a3, 0x08000            # Prepare the implicit 1
  srli a0, a0, 5             # Shift mantissa A to have the MSB of the result in a convenient position
  srli a1, a1, 5             # Shift mantissa B to have the MSB of the result in a convenient position
  or a0, a0, a3              # Add the implicit 1 (A) in position 28
  or a1, a1, a3              # Add the implicit 1 (B) in position 28

  # The actual multiplication.
  mul a3, a0, a1             # LSbs of the result
  mulhu a1, a0, a1           # MSbs of the result

  # Put final sign in a0.
  mv a0, a4                  # Write the correct sign in a0

  # Adjust result upon the MSB position.
  lui a5, 0x00800            # Prepare the mask in position 24
  bgeu a1, a5, 1f            # Branch if there is no need for normalizing
  slli a1, a1, 1             # Normalize: shift left the result (1)
  srli a5, a3, 31            # Normalize: shift left the result (2)
  or a1, a1, a5              # Normalize: shift left the result (3)
  slli a3, a3, 1             # Normalize: shift left the result (4)
  addi a2, a2, -1            # Adjust the final exponent because of the normalization

  # Move the result in a0. Sign already in a0
1:
  or a0, a0, a1      # Add sign to the result

# Apply exponent bias, check for under/overflow.
  addi a2, a2, -127          # Apply exponent bias
  addi a5, x0, 254           # Prepare to check for under/overflow
  bgeu a2, a5, und_ov_flow

# Round the result, merge final exponent.
# CIAONE = 0x80000
  lui a4, 0x80000
  slli a2, a2, 23
  add a0, a0, a2
  bltu a3, a4, exit
  addi a0, a0, 1
  bne a3, a4, exit
  andi a0, a0, -2
exit:
  ret

und_ov_flow:
  # Overflow?
  blt x0, a2, inf      # If here, a2 is either in ovf (> 0) or in underflow (<= 0)
  # Underflow: return signed 0.
# a4 = 0x80000
  j append_zero

zero_denormal:
# Here, one or more arguments are either denormalized or zero.
# Result is 0, but determine sign anyway.
append_zero:
  mv a0, a4
  ret

  # One or both args are INF or NAN.
inf_nan:
  slli a2, a2, 24      # Isolate the exponent of A
  slli a3, a3, 24      # Isolate the exponent of B
  beqz a2, nan         # Return NaN if A is 0 or denormal
  beqz a3, nan         # Return NaN if B is 0 or denormal
  slli a5, a5, 24      # Prepare the mask for NaN
  slli a3, a0, 1       # Eliminate the sign of A
  bltu a5, a3, nan     # Return NaN if A is NaN
  slli a3, a1, 1       # Eliminate the sign of B
  bltu a5, a3, nan     # Return NaN if B is NaN
# One of the operands is Inf, the other is an Inf or a number.

# Overflow: return Inf (sign already in a0).
inf:
  lui a0, 0x7f800      # Set max exponent
  or a0, a0, a4        # Put the sign
  ret                  # Return

  # Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret
