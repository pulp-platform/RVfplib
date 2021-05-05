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

# Single Precision FP equivalence checker
# Return value less than 0 if the arguments are not NaN and x < y
# +0 == -0

# This function can also be faster, removing the two "slli" at the ends. We provide a negative result only for compliancy to libgcc interface

.global __ltsf2

__ltsf2:
# Check for NaN first
	lui a3, 0xFF000          # Load shifted NaN pattern
	slli a2, a0, 1
	bltu a3, a2, ret_0       # Branch if NaN is detected
	slli a2, a1, 1
	bltu a3, a2, ret_0       # Branch if NaN is detected
# Check for +0 -0 (special equality)
	or a3, a0, a1
	slli a3, a3, 1
	beqz a3, ret_0           # +0 == -0
# Check for the signs
	and a3, a0, a1
	bltz a3, nn
# pp_pn_np
	slt a0, a0, a1
	slli a0, a0, 31          # Neg only for standard libgcc interface
	ret

ret_0:
	li a0, 0
	ret

nn:
	slt a0, a1, a0
	slli a0, a0, 31          # Neg only for standard libgcc interface
	ret
