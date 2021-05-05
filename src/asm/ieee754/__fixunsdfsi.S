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

# Define ZERO_NAN to return a 0 if the input is a NaN. Otherwise, they are treaten as signed infinities.
# libgcc function treats NaN as signed infinities, so here the default is doing the same
# #define ZERO_NAN 1

.global __fixunsdfsi

__fixunsdfsi:
  # Return 0 if negative
  blez a1, undflow
  slli a1, a1, 1     # Remove the sign
  srli a2, a1, 21    # Isolate Exponent
  # Add bias to the exponent
  addi a2, a2, -1023
  bltz a2, undflow   # Branch if underflow and ret 0
  neg a2, a2
  addi a2, a2, 31
  bltz a2, ovflow
  # Isolate mantissa and load implicit 1
  slli a1, a1, 10
  srli a0, a0, 21
  or a1, a1, a0
  lui a4, 0x80000
  or a1, a1, a4      # Add implicit 1
  # Multiply number by 2^exp
  srl a0, a1, a2
  # Ret
  ret

ovflow:
#ifdef ZERO_NAN
  lui a3, 0xFFE00
  snez a0, a0
  or a1, a1, a0
  bgt a1, a3, nan
#endif
  li a0, -1
  ret

#ifdef ZERO_NAN
nan:
#endif
undflow:
  li a0, 0
  ret
