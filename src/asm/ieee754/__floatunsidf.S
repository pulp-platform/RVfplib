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

.global __floatunsidf

__floatunsidf:
  mv a1, a0
  beqz a0, exit
# CLZ
  li a2, 1053           # 30 + 1023 (+ 1 after), since we will add also the implicit 1
  bltz a1, 2f           # Check if the input was 0x80000000
# The MSB cannot be zero here (number always positive)
1:
  addi a2, a2, -1
  slli a1, a1, 1
  bgez a1, 1b
# Shift_right. The MSB is now the implicit bit
# No need for rounding
2:
  slli a0, a1, 21
  srli a1, a1, 11
# Biased Exp and sign
  slli a2, a2, 20
  add a1, a1, a2
exit:
  ret
