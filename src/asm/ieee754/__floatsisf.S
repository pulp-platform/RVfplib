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

.global __floatsisf

__floatsisf:
  beqz a0, exit
  srai a5, a0, 31      # Negate if needed
  xor a0, a0, a5
  sub a0, a0, a5
  slli a5, a5, 31      # Prepare the sign
# CLZ
  li a1, 157           # 30 + 127 (+ 1), since we will add also the implicit 1
  bltz a0, 2f          # Check if the input was 0x80000000
# The MSB cannot be zero here (number always positive)
1:
  addi a1, a1, -1
  slli a0, a0, 1
  bgtz a0, 1b
# Shift_right. The MSB is now the implicit bit
# Round to nearest even
2:
  slli a2, a0, 24
  srli a0, a0, 8
  bgez a2, 1f
  addi a0, a0, 1
  slli a2, a2, 1
  seqz a2, a2
  not a2, a2
  and a0, a0, a2
1:
# Biased Exp and sign
  slli a1, a1, 23
  add a0, a0, a1
  or a0, a0, a5
exit:
  ret
