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

# RISC-V 64-bit FP sub
# Define SPLIT_SUB to keep the subtraction split from the addition. This can be more modular, but less effective in performance and also bigger in code size if both the functions are required

#ifdef SPLIT_SUB

.global __subdf3
.global __adddf3

#define xh a1
#define xl a0
#define yh a3
#define yl a2

__subdf3:
	lui a4, 0x80000            # Load sign mask
	xor yh, yh, a4             # Reverse sign Y
	j __adddf3                 # Jump to add

#endif
