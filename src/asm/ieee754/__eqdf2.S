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

# Double Precision FP equivalence checker
# Return 0 if the arguments are equal and neither of them is NaN
# +0 == -0

#define xh a1
#define xl a0
#define yh a3
#define yl a2

.global __eqdf2
.global __nedf2

__nedf2:
__eqdf2:
# Check for NaN first
	snez a4, xl
	slli a5, xh, 1
	or a5, a5, a4
	lui a4, 0xFFE00        # Load shifted NaN pattern
	bltu a4, a5, nan       # Branch if NaN is detected
	snez a5, yl
	slli t0, yh, 1
	or t0, t0, a5
	bltu a4, t0, nan       # Branch if NaN is detected
# Check for +0 -0
	or a4, xh, yh
	slli a4, a4, 1
	or a4, a4, xl
	or a4, a4, yl
	beqz a4, normal_end
# Check for equality
	xor xl, xl, yl
	xor xh, xh, yh
	or a4, xh, xl
normal_end:
nan:
	snez xl, a4            # Set the correct result
	ret
