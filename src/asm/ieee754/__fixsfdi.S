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

# #define ZERO_NAN 1

.global __fixsfdi

__fixsfdi:
  # Check special cases
  lui a4, 0x80000
  srai a5, a0, 31    # Reproduce sign
  slli a0, a0, 1     # Remove the sign
  srli a2, a0, 24    # Isolate Exponent
  # Add bias to the exponent
  addi a2, a2, -127
  bltz a2, undflow   # Branch if underflow and ret 0
  # Isolate mantissa and load implicit 1
  slli a0, a0, 7
  or a0, a0, a4      # Add implicit 1
  # Understand if the exp falls within [0, 31)
  neg a2, a2
  addi a2, a2, 31
  bltz a2, ge_32
  # lt_32
  # Multiply number by 2^exp
  # a1 is empty
  li a1, 0
  srl a0, a0, a2
  # Neg it if necessary
  beqz a5, 1f
  neg a0, a0
  not a1, a1
  seqz a4, a0
  add a1, a1, a4
1:
  ret

ge_32:
  addi a2, a2, 32
  blez a2, ovflow
  mv a1, a0
  li a0, 0
  neg a4, a2
  sll a0, a1, a4
  srl a1, a1, a2
  # Neg it if necessary
  beqz a5, 1f
  neg a0, a0
  not a1, a1
  seqz a4, a0
  add a1, a1, a4
  # Ret
1:
  ret

ovflow:
#ifdef ZERO_NAN
  lui a3, 0xFF000
  bgt a0, a3, nan
#endif
  li a0, -1
  not a1, a4
  xor a0, a0, a5
  xor a1, a1, a5
  ret

#ifdef ZERO_NAN
nan:
#endif
undflow:
  li a0, 0
  li a1, 0
  ret
