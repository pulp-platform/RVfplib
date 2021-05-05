# Copyright ETH Zurich 2020
#
# Author: Matteo Perotti
#
# This file is part of rvfplib.
#
#     rvfplib is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     rvfplib is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
# Under Section 7 of GPL version 3, you are granted additional
# permissions described in the GCC Runtime Library Exception, version
# 3.1, as published by the Free Software Foundation.
#
# You should have received a copy of the GNU General Public License and
# a copy of the GCC Runtime Library Exception along with this program;
# see the files LICENSE.txt and LICENSE-EXCEPTION.txt respectively.  If not, see
# <http://www.gnu.org/licenses/>.  */

.global __mulsf3

#ifdef PERFORMANCE

__mulsf3:
  lui a4, 0x80000           # Prepare the mask for the sign
  # Mask out exponents, trap any zero/denormal/INF/NAN.
  addi a6, x0, 0xff         # Prepare the exp. mask
  srli a2, a0, 23           # Isolate sign and exp. (A)
  and a2, a2, a6            # Isolate exp. (A)
  srli a3, a1, 23           # Isolate sign and exp. (B)
  and a3, a3, a6            # Isolate exp. (B)
  beq a2, a6, inf_nan       # Jump if A is Inf/NaN
  beq a3, a6, inf_nan       # Jump if B is Inf/NaN
  beqz a2, zero_denormal    # Jump if A is zero/denormal
  beqz a3, zero_denormal    # Jump if B is zero/denormal

normal_case:
  # Add exponents together
  add a2, a2, a3            # Add exponents together

  # Determine final sign.
  xor a6, a0, a1            # Determine also the final sign
  lui a4, 0x80000           # Prepare the mask for the sign
  and a6, a6, a4            # Determine the final sign

  # Convert mantissa to unsigned integer.
  # If power of two, branch to a separate path.
  # Make up for final alignment.
  slli a0, a0, 9            # Isolate mantissa A
  slli a1, a1, 9            # Isolate mantissa B
#ifdef POW2
  beqz a0, pow_2            # Branch if A power of 2
  beqz a1, pow_2            # Branch if B power of 2
#endif
  lui a3, 0x08000           # Prepare the implicit 1
  srli a0, a0, 5            # Shift mantissa A to have the MSB of the result in a convenient position
  srli a1, a1, 5            # Shift mantissa B to have the MSB of the result in a convenient position
  or a0, a0, a3             # Add the implicit 1 (A) in position 28
  or a1, a1, a3             # Add the implicit 1 (B) in position 28

  # The actual multiplication.
  mul a3, a0, a1            # LSbs of the result
  mulhu a1, a0, a1          # MSbs of the result

  # Put final sign in a0.
  mv a0, a6                  # Write the correct sign in a0

  # Adjust result upon the MSB position.
  lui a6, 0x00800            # Prepare the mask in position 24
  bgeu a1, a6, 1f            # Branch if there is no need for normalizing
  slli a1, a1, 1             # Normalize: shift left the result (1)
  srli a6, a3, 31            # Normalize: shift left the result (2)
  or a1, a1, a6              # Normalize: shift left the result (3)
  slli a3, a3, 1             # Normalize: shift left the result (4)
  addi a2, a2, -1            # Adjust the final exponent because of the normalization

  # Add sign to result.
1:
  or a0, a0, a1      # Add sign to the result

  # Apply exponent bias, check for under/overflow.
  addi a2, a2, -127          # Apply exponent bias
  addi a6, x0, 254           # Prepare to check for under/overflow
  bgeu a2, a6, und_ov_flow

  # Round the result, merge final exponent.
# a4 = 0x80000
  slli a2, a2, 23
  add a0, a0, a2
  bltu a3, a4, exit
  addi a0, a0, 1
  bne a3, a4, exit
  andi a0, a0, -2
exit:
  ret

#ifdef POW2
  # Multiplication by 0x1p*: let's shortcut a lot of code.
pow_2:
  srli a0, a0, 9               # Isolate mantissa A
  srli a1, a1, 9               # Isolate mantissa B
  or a0, a0, a1                # Perform the multiplication
  or a0, a0, a6                # Add sign to the result
  addi a2, a2, -127            # Apply exponent Bias for correct exponent
  bge x0, a2, pre_und_ov_flow  # Underflow detected # MATTEO CHECK
  addi a6, x0, 255             # Prepare overflow mask
  bge a2, a6, pre_und_ov_flow  # Overflow detected
  slli a2, a2, 23              # Prepare the exponent
  or a0, a0, a2                # Add the exponent to the result
  ret                          # Return

  # Under/overflow: fix things up for the code below.
pre_und_ov_flow:
  lui a6, 0x00800
  or a0, a0, a6
  mv a3, x0
  addi a2, a2, -1
#endif

und_ov_flow:
  # Overflow?
  blt x0, a2, ovf      # If here, a2 is either in ovf (> 0) or in underflow (<= 0)

  # Check if denormalized result is possible, otherwise return signed 0.
  addi a6, a2, 26
  bge a6, x0, denormal_end
# a4 = 0x80000
  and a0, a0, a4
  ret

  # Shift value right, round, etc.
denormal_end:
  neg a5, a2         # Make a2 positive in a6
# a4 = 0x80000
  and a6, a4, a0     # Sign in a4
  xor a0, a0, a6     # Mask sign
  add a2, a2, 32     # Reg-compl shamt in a2
  sll a2, a0, a2     # Isolate excluded bits of a0 in a2 MSbs
  srl a0, a0, a5     # Shift right a0 by |a2|
  or a0, a0, a6      # Re-apply the sign to a0
# Round (RNE)
  srli a3, a3, 1     # Append the lower part of the result
  or a2, a2, a3      # The MSB of a2 can be now used as a R bit
# a4 = 0x80000
  bltu a2, a4, exit  # Jump away if we do not round
  addi a0, a0, 1     # Otherwise, preventively round up
  bne a2, a4, exit   # Jump away if no tie
  andi a0, a0, -2
  ret                # Exit

  # One or both arguments are denormalized.
  # Scale them leftwards and preserve sign bit.
denormal:
  lui a6, 0x00800    # Load implicit 1 mask
# Check A
# a4 = 0x80000
  and a4, a4, a0     # Extract sign of A
  bnez a2, 3f        # Jump if A is not denormal
# A is a denormal
2:
  slli a0, a0, 1     # Shift left by one
  and a5, a0, a6     # Implicit 1 restored?
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
  and a5, a1, a6     # Implicit 1 restored?
  bnez a5, 5f        # Yes: go on (B is no more a denormal)
  addi a3, a3, -1    # No: subtract 1 to the exponent
  j 4b               # Repeat
5:
  or a1, a1, a4     # Restore sign B
  j normal_case

zero_denormal:
  # Here, one or more arguments are either denormalized or zero.
  not a6, a4           # a4 = 0x7FFFFFFF
  and a5, a6, a0       # Mask away the sign of A
  beqz a5, zero        # Retrun 0 if A is zero
  and a6, a6, a1       # Mask away the sign of B
  bnez a6, denormal    # Jump if B is not zero

  # Result is 0, but determine sign anyway.
zero:
  xor a0, a0, a1       # Determine the correct sign of the multiplication
# a4 = 0x80000
  and a0, a0, a4       # Append Zero
  ret

  # One or both args are INF or NAN.
inf_nan:
  beqz a0, nan         # Return NaN if A is +0
  beqz a1, nan         # Return NaN if B is +0
  beq a0, a4, nan      # Return NaN A is -0
  beq a1, a4, nan      # Return NaN B is -0
  slli a6, a6, 24      # Prepare the mask for NaN
  slli a5, a0, 1       # Eliminate the sign of A
  bltu a6, a5, nan     # Return NaN if A is NaN
  slli a5, a1, 1       # Eliminate the sign of B
  bltu a6, a5, nan     # Return NaN if B is NaN
# One of the operands is Inf, the other is an Inf or a number.

  # Result is INF, but we need to determine its sign.
inf:
  xor a0, a0, a1    # Put the correct sign into a0

  # Overflow: return Inf (sign already in a0).
ovf:
# a4 = 0x80000
  and a0, a0, a4    # Isolate the sign
  lui a4, 0x7f800   # Set max exponent
  or a0, a0, a4     # Set max exponent
  ret               # Return

  # Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#else

__mulsf3:
  lui a4, 0x80000     # Prepare the mask for the sign
  # Mask out exponents, trap any zero/denormal/INF/NAN.
  addi a6, x0, 0xff   # Prepare the exp. mask
  srli a2, a0, 23     # Isolate sign and exp. (A)
  and a2, a2, a6      # Isolate exp. (A)
  srli a3, a1, 23     # Isolate sign and exp. (B)
  and a3, a3, a6      # Isolate exp. (B)
  beq a2, a6, inf_nan # Jump if A is Inf/NaN
  beq a3, a6, inf_nan # Jump if B is Inf/NaN
  beqz a2, zero_denormal    # Jump if A is zero/denormal
  beqz a3, zero_denormal    # Jump if B is zero/denormal

normal_case:
  # Add exponents together
  add a2, a2, a3     # Add exponents together

  # Determine final sign.
  xor a6, a0, a1     # Determine also the final sign
  lui a4, 0x80000    # Prepare the mask for the sign
  and a6, a6, a4     # Determine the final sign

  # Convert mantissa to unsigned integer.
  # If power of two, branch to a separate path.
  # Make up for final alignment.
  slli a0, a0, 9     # Isolate mantissa A
  slli a1, a1, 9     # Isolate mantissa B
  lui a3, 0x08000    # Prepare the implicit 1
  srli a0, a0, 5     # Shift mantissa A to have the MSB of the result in a convenient position
  srli a1, a1, 5     # Shift mantissa B to have the MSB of the result in a convenient position
  or a0, a0, a3      # Add the implicit 1 (A) in position 28
  or a1, a1, a3      # Add the implicit 1 (B) in position 28

  # The actual multiplication.
  mul a3, a0, a1     # LSbs of the result
  mulhu a1, a0, a1   # MSbs of the result

  # Put final sign in a0.
  mv a0, a6                  # Write the correct sign in a0

  # Adjust result upon the MSB position.
  lui a6, 0x00800            # Prepare the mask in position 24
  bgeu a1, a6, 1f            # Branch if there is no need for normalizing
  slli a1, a1, 1             # Normalize: shift left the result (1)
  srli a6, a3, 31            # Normalize: shift left the result (2)
  or a1, a1, a6              # Normalize: shift left the result (3)
  slli a3, a3, 1             # Normalize: shift left the result (4)
  addi a2, a2, -1            # Adjust the final exponent because of the normalization

  # Add sign to result.
1:
  or a0, a0, a1      # Add sign to the result

  # Apply exponent bias, check for under/overflow.
  addi a2, a2, -127          # Apply exponent bias
  addi a6, x0, 254           # Prepare to check for under/overflow
  bgeu a2, a6, und_ov_flow   #

  # Round the result, merge final exponent.
# a4 = 0x80000
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
  blt x0, a2, ovf      # If here, a2 is either in ovf (> 0) or in underflow (<= 0)

  # Check if denormalized result is possible, otherwise return signed 0.
  addi a6, a2, 26
  bge a6, x0, denormal_end
# a4 = 0x80000
  and a0, a0, a4
  ret

  # Shift value right, round, etc.
denormal_end:
  neg a5, a2         # Make a2 positive in a6
# a4 = 0x80000
  and a6, a4, a0     # Sign in a4
  xor a0, a0, a6     # Mask sign
  add a2, a2, 32     # Reg-compl shamt in a2
  sll a2, a0, a2     # Isolate excluded bits of a0 in a2 MSbs
  srl a0, a0, a5     # Shift right a0 by |a2|
  or a0, a0, a6      # Re-apply the sign to a0
# Round (RNE)
  srli a3, a3, 1     # Append the lower part of the result
  or a2, a2, a3      # The MSB of a2 can be now used as a R bit
# a4 = 0x80000
  bltu a2, a4, exit  # Jump away if we do not round
  addi a0, a0, 1     # Otherwise, preventively round up
  bne a2, a4, exit   # Jump away if no tie
  andi a0, a0, -2
  ret                # Exit

  # One or both arguments are denormalized.
  # Scale them leftwards and preserve sign bit.
denormal:
  lui a6, 0x00800    # Load implicit 1 mask
# Check A
# a4 = 0x80000
  and a4, a4, a0     # Extract sign of A
  bnez a2, 3f        # Jump if A is not denormal
# A is a denormal
2:
  slli a0, a0, 1     # Shift left by one
  and a5, a0, a6     # Implicit 1 restored?
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
  and a5, a1, a6     # Implicit 1 restored?
  bnez a5, 5f        # Yes: go on (B is no more a denormal)
  addi a3, a3, -1    # No: subtract 1 to the exponent
  j 4b               # Repeat
5:
  or a1, a1, a4     # Restore sign B
  j normal_case

zero_denormal:
  # Here, one or more arguments are either denormalized or zero.
  not a6, a4           # a4 = 0x7FFFFFFF
  and a5, a6, a0       # Mask away the sign of A
  beqz a5, zero        # Retrun 0 if A is zero
  and a6, a6, a1       # Mask away the sign of B
  bnez a6, denormal    # Jump if B is not zero

  # Result is 0, but determine sign anyway.
zero:
  xor a0, a0, a1       # Determine the correct sign of the multiplication
# a4 = 0x80000
  and a0, a0, a4       # Append Zero
  ret

  # One or both args are INF or NAN.
inf_nan:
  beqz a0, nan         # Return NaN if A is +0
  beqz a1, nan         # Return NaN if B is +0
  beq a0, a4, nan      # Return NaN A is -0
  beq a1, a4, nan      # Return NaN B is -0
  slli a6, a6, 24      # Prepare the mask for NaN
  slli a5, a0, 1       # Eliminate the sign of A
  bltu a6, a5, nan     # Return NaN if A is NaN
  slli a5, a1, 1       # Eliminate the sign of B
  bltu a6, a5, nan     # Return NaN if B is NaN
# One of the operands is Inf, the other is an Inf or a number.

  # Result is INF, but we need to determine its sign.
inf:
  xor a0, a0, a1    # Put the correct sign into a0

  # Overflow: return Inf (sign already in a0).
ovf:
# a4 = 0x80000
  and a0, a0, a4    # Isolate the sign
  lui a4, 0x7f800   # Set max exponent
  or a0, a0, a4     # Set max exponent
  ret               # Return

  # Return a quiet NaN.
nan:
  lui a0, 0x7fc00
  ret

#endif
