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

.global __ltdf2

__ltdf2:
# Check for NaN first
	snez a4, xl
	slli a5, xh, 1
	or a5, a5, a4
	lui a4, 0xFFE00          # Load shifted NaN pattern
	bltu a4, a5, ret_0       # Branch if NaN is detected
	snez a5, yl
	slli t0, yh, 1
	or t0, t0, a5
	bltu a4, t0, ret_0       # Branch if NaN is detected
# Check for +0 -0
	or a4, xh, yh
	slli a4, a4, 1
	or a4, a4, xl
	or a4, a4, yl
	beqz a4, ret_0
# Check the signs
	xor a4, xh, yh           # Check the signs
	bltz a4, pn_np           # Branch if different signs
# pp_nn
	beq xh, yh, pp_nn_h_eq
# pp_nn_not_eq
	sltu a4, xh, yh
end:
	sltz a0, xh
	xor a0, a0, a4
	slli a0, a0, 31          # Only to interface with libgcc (negative result instead of positive)
	ret

pp_nn_h_eq:
	beq xl, yl, ret_0
	sltu a4, xl, yl
	j end

ret_0:
	li a0, 0
	ret

pn_np:
	sltz a0, xh              # Return 1 if x is negative and y positive, 0 if the opposite
	slli a0, a0, 31          # Only to interface with libgcc (negative result instead of positive)
	ret

