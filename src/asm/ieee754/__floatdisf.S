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

.global __floatdisf

__floatdisf:
  srli a5, a1, 31
# c2 the input if negative
  bgez a1, 1f
  neg a0, a0
  not a1, a1
  seqz a2, a0
  add a1, a1, a2
1:
  slli a5, a5, 31      # Prepare the sign
# CLZ
  li a2, 189           # 30 + 32 + 127 (+ 1), since we will add also the implicit 1
  bnez a1, 2f          # Jump if the MSreg is not 0
  beqz a0, exit        # The input number is 0
  mv a1, a0            # Swap a1 and a0, this works as a preshift
  li a0, 0
  addi a2, a2, -32
2:
  bltz a1, 4f          # If the implicit 1 is already positioned, skip the clz
3:
  addi a2, a2, -1
  slli a1, a1, 1
  bgtz a1, 3b
# Shift_right. The MSB is now the implicit bit
# Round to nearest even
4:
  # Adjust the shift outside the loop to save a lot of time!
  addi a4, a2, -157    # (-189 + 32)
  srl a3, a0, a4
  or a1, a1, a3
  neg a4, a4
  sll a0, a0, a4
  # Keep into account also the shifted-out LSbs in a0
  snez a4, a0
  srli a0, a1, 8
  slli a1, a1, 24
  or a1, a1, a4
  bgez a1, 1f
  addi a0, a0, 1
  slli a1, a1, 1
  seqz a1, a1
  not a1, a1
  and a0, a0, a1
1:
# Biased Exp and sign
  slli a2, a2, 23
  add a0, a0, a2
  or a0, a0, a5
exit:
  ret
