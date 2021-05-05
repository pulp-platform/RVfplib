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

.global __fixunsdfdi

#ifdef ZERO_NAN

__fixunsdfdi:
  # Check special cases
  bltz a1, undflow
  lui a4, 0x80000
  slli t1, a1, 1     # Remove the sign
  srli a2, t1, 21    # Isolate Exponent
  # Add bias to the exponent
  addi a2, a2, -1023
  bltz a2, undflow   # Branch if underflow and ret 0
  # Isolate mantissa and load implicit 1
  slli a1, t1, 10
  srli a3, a0, 21
  or a1, a1, a3
  slli a0, a0, 11
  or a1, a1, a4      # Add implicit 1
  # At this point, the 12 LSbs of H and the 12 MSbs of L are ==
  # Understand if the exp falls within [0, 31)
  neg a2, a2
  addi a2, a2, 31
  bltz a2, ge_32
  # lt_32
  # Multiply number by 2^exp
  # a1 is empty
  srl a0, a1, a2
  li a1, 0
  ret

ge_32:
  # Check for overflow
  addi a2, a2, 32
  bltz a2, ovflow
  # Move mantissa
  beqz a2, eq_63_end
  neg a4, a2
  sll a3, a1, a4
  srl a1, a1, a2
  srl a0, a0, a2
  or a0, a0, a3
eq_63_end:
  ret

ovflow:
  snez a0, a0
  or a0, a0, t1
  lui a3, 0xFFE00
  bgt a0, a3, nan
  li a0, -1
  mv a1, a0
  ret

nan:
undflow:
  li a1, 0
  li a0, 0
  ret

#else

__fixunsdfdi:
  # Check special cases
  bltz a1, undflow
  lui a4, 0x80000
  slli a1, a1, 1     # Remove the sign
  srli a2, a1, 21    # Isolate Exponent
  # Add bias to the exponent
  addi a2, a2, -1023
  bltz a2, undflow   # Branch if underflow and ret 0
  # Isolate mantissa and load implicit 1
  slli a1, a1, 10
  srli a3, a0, 21
  or a1, a1, a3
  slli a0, a0, 11
  or a1, a1, a4      # Add implicit 1
  # At this point, the 12 LSbs of H and the 12 MSbs of L are ==
  # Understand if the exp falls within [0, 31]
  neg a2, a2
  addi a2, a2, 31
  bltz a2, ge_32
  # lt_32, 0 <= a2 <= 31
  # Multiply number by 2^exp
  # a1 is empty
  srl a0, a1, a2
  li a1, 0
  ret

ge_32:
  # Check if -31 <= a2 <= -1
  # Check for overflow
  addi a2, a2, 32
  # 1 <= a2 <= 31
  bltz a2, ovflow
  # 1 <= a2 <= 31
  # Move mantissa
  beqz a2, eq_63_end
  neg a4, a2
  # a4 behaves as (31 < a4 < 1)
  sll a3, a1, a4
  srl a0, a0, a2
  or a0, a0, a3
  srl a1, a1, a2
eq_63_end:
  ret

ovflow:
  li a0, -1
  mv a1, a0
  ret

undflow:
  li a0, 0
  li a1, 0
  ret

#endif
