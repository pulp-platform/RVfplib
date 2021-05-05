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

# libgcc rounds toward zero and flush the input NaN to a generic quiet NaN

.global __truncdfsf2

#define libgcc

#ifdef libgcc

__truncdfsf2:
	lui a2, 0x80000        # Mask for the sign
	and a3, a2, a1         # Save the sign
	slli a1, a1, 1         # Eat the sign
	lui a4, 0xFFE00
	bgeu a1, a4, inf_nan
	srli a4, a1, 21
	addi a4, a4, -896      # Check for an underfow -> exp-(1023-127)
	blez a4, undflow       # If exponent is less than zero, we have a denormal or zero
	addi a5, a4, -254      # Check for an overflow
	bgtz a5, inf
# Normal number
	slli a5, a0, 3         # Bits to round RNE
	srli a0, a0, 29        # Save the lsb of a0 that can be brought to a1
	slli a1, a1, 11        # Remove the exponent from a1
	srli a1, a1, 9         # Put the mantissa as for a single-precision FP
	or a0, a0, a1          # Merge this mantissa with a0 saved bits to form the new mantissa
	bgez a5, exp_sign_exit
	addi a0, a0, 1
	bne a5, a2, exp_sign_exit
	andi a0, a0, -2
exp_sign_exit:
	slli a4, a4, 23        # Move the exponent in the correct position
	add a0, a0, a4         # Merge the exponent
	or a0, a0, a3          # Merge the sign
	ret

inf_nan:
	bgtu a1, a4, nan
	bnez a0, nan
inf:
	lui a0, 0x7F800
	or a0, a0, a3
	ret

nan:
# Return the correct NaN
	lui a0, 0x7FC00
	ret

# Flush denormals to correctly signed 0
undflow:
	mv a0, a3
	ret

#else

.global __truncdfsf2

__truncdfsf2:
	lui a2, 0x80000        # Mask for the sign
	and a3, a2, a1         # Save the sign
	slli a1, a1, 1         # Eat the sign
	lui a4, 0xFFE00
	bgeu a1, a4, inf_nan
	srli a4, a1, 21
	addi a4, a4, -896      # Check for an underfow -> exp-(1023-127)
	blez a4, undflow       # If exponent is less than zero, we have a denormal or zero
	addi a5, a4, -254      # Check for an overflow
	bgtz a5, inf
# Normal number
	slli a5, a0, 3         # Bits to round RNE
	srli a0, a0, 29        # Save the lsb of a0 that can be brought to a1
	slli a1, a1, 11        # Remove the exponent from a1
	srli a1, a1, 9         # Put the mantissa as for a single-precision FP
	or a0, a0, a1          # Merge this mantissa with a0 saved bits to form the new mantissa
	bgez a5, exp_sign_exit
	addi a0, a0, 1
	bne a5, a2, exp_sign_exit
	andi a0, a0, -2
exp_sign_exit:
	slli a4, a4, 23        # Move the exponent in the correct position
	add a0, a0, a4         # Merge the exponent
	or a0, a0, a3          # Merge the sign
	ret

inf_nan:
	bgtu a1, a4, nan
	bnez a0, nan
inf:
	lui a0, 0x7F800
	or a0, a0, a3
	ret

nan:
# Return the correct quiet NaN
	slli a1, a1, 3
	srli a0, a0, 29
	srli a1, a1, 1
	srli a2, a2, 9
	or a0, a0, a2
	or a0, a0, a1
	or a0, a0, a3
	ret

# Flush denormals to correctly signed 0
undflow:
	mv a0, a3
	ret

#endif
