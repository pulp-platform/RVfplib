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

.global __fixunssfsi

__fixunssfsi:
  # Check special cases
  blez a0, undflow   # Return 0 if negative
  slli a0, a0, 1     # Remove the sign
  srli a1, a0, 24    # Isolate Exponent
  # Add bias to the exponent
  addi a1, a1, -127
  bltz a1, undflow   # Branch if underflow and ret 0
  neg a1, a1
  addi a1, a1, 31
  bltz a1, ovflow
  # Isolate mantissa and load implicit 1
  slli a0, a0, 7
  lui a4, 0x80000
  or a0, a0, a4      # Add implicit 1
  # Multiply number by 2^exp
  srl a0, a0, a1
  # Ret
  ret

ovflow:
#ifdef ZERO_NAN
  lui a3, 0xFF000
  bgt a0, a3, nan
#endif
  li a0, -1
  ret

#ifdef ZERO_NAN
nan:
#endif
undflow:
  li a0, 0
  ret
