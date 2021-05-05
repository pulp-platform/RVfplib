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

.global __extendsfdf2

#ifdef PERFORMANCE

__extendsfdf2:
  lui a1, 0x80000        # Mask for the sign
  and a1, a1, a0         # Save the sign
  slli a3, a0, 1         # Eat the sign
# Check for zeroes/denormals
  srai a4, a3, 24
  beqz a4, zero_den
# Prepare a0 and a1
  srai a5, a3, 3         # Position the exponent and mantissa bits (trick to easily adjust the bias)
  srli a5, a5, 1         # Prepare a void for the sign
  slli a0, a3, 28        # Adjust LSbs
  or a1, a1, a5          # Restore the sign
# Check for inf/NaN
  addi a4, a4, 1
  beqz a4, inf_nan
# Adjust the bias for the exponent (add 1023-127 with a trick)
  lui a5, 0x38000
  xor a1, a1, a5
exit:
  ret

inf_nan:
# Check for NaN, otherwise the result is correct
  slli a3, a3, 8
  beqz a3, exit
  lui a1, 0x7FF80        # Make the output a quiet NaN
  li a0, 0
  ret

# Flush denormals to corretly signed 0
zero_den:
  bnez a3, denormal
  li a0, 0
  ret

denormal:
# Normalize the mantissa where it is, shift later. In the end, add the implicit 1 to the exponent
  li a4, 0x380            # Load minimum exponent
# CLZ
  lui a5, 0x00002
  bgeu a3, a5, 1f
  slli a3, a3, 12
  addi a4, a4, -12
1:
  slli a5, a5, 6
  bgeu a3, a5, 2f
  slli a3, a3, 6
  addi a4, a4, -6
2:
  slli a5, a5, 3
  bgeu a3, a5, 3f
  slli a3, a3, 3
  addi a4, a4, -3
3:
  slli a5, a5, 1
  bgeu a3, a5, 4f
  slli a3, a3, 1
  addi a4, a4, -1
4:
  slli a5, a5, 1
  bgeu a3, a5, 5f
  slli a3, a3, 1
  addi a4, a4, -1
5:
# Shift the mantissa and align to a double-precision format
  slli a0, a3, 28         # Save the bits that would be lost after adaptation
  srli a3, a3, 4          # Adapt to DP format
  slli a4, a4, 20         # Add the exponent
  add a3, a3, a4
  or a1, a1, a3           # Merge the sign
  ret

#else

__extendsfdf2:
  lui a1, 0x80000         # Mask for the sign
  and a1, a1, a0          # Save the sign
  slli a3, a0, 1          # Eat the sign
# Check for zeroes/denormals
  srai a4, a3, 24
  beqz a4, zero_den
# Prepare a0 and a1
  srai a5, a3, 3          # Position the exponent and mantissa bits (trick to easily adjust the bias)
  srli a5, a5, 1          # Prepare a void for the sign
  slli a0, a3, 28         # Adjust LSbs
  or a1, a1, a5           # Restore the sign
# Check for inf/NaN
  addi a4, a4, 1
  beqz a4, inf_nan
# Adjust the bias for the exponent (add 1023-127 with a trick)
  lui a5, 0x38000
  xor a1, a1, a5
exit:
  ret

inf_nan:
# Check for NaN, otherwise the result is correct
  slli a3, a3, 8
  beqz a3, exit
  lui a4, 0x00080         # Make the output a quiet NaN
  or a1, a1, a4
  ret

# Flush denormals to corretly signed 0
zero_den:
  bnez a3, denormal
  li a0, 0
  ret

denormal:
# Normalize the mantissa where it is, shift later. In the end, add the implicit 1 to the exponent
  lui a5, 0x01000
  li a4, 0x380            # Load minimum exponent
clz_loop:
  slli a3, a3, 1
  addi a4, a4, -1
  bltu a3, a5, clz_loop
# Shift the mantissa and align to a double-precision format
  slli a0, a3, 28         # Save the bits that would be lost after adaptation
  srli a3, a3, 4          # Adapt to DP format
  slli a4, a4, 20         # Add the exponent
  add a3, a3, a4
  or a1, a1, a3           # Merge the sign
  ret

#endif
