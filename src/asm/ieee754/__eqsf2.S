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
# Return 0 if the arguments are equal and neither of them is NaN
# +0 == -0

.global __eqsf2
.global __nesf2

__nesf2:
__eqsf2:
  lui   a5,0xff000        # Load shifted NaN pattern
# Check for NaN
  slli  a2,a0,0x1
  bltu  a5,a2,end         # Branch if NaN is detected
  slli  a3,a1,0x1
  bltu  a5,a3,end         # Branch if NaN is detected
# Check for +0, -0
  or    a5,a2,a3
  beqz  a5,end
# Effective comparison
  xor   a5,a0,a1          # Two numbers are equal if they are equal
end:
  snez  a0,a5
  ret
