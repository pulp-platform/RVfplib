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
# You should have received a copy of the GNU General Public License
# along with rvfplib  If not, see <https://www.gnu.org/licenses/>.
# Copyright ETH Zurich 2020

# Return 1 if bin_string on prec bit is either Inf or NaN
def isSpecial(bin_string, prec):
    if prec == '32':
        if bin_string[1:9] == '1'*8:
            return 1
        else:
            return 0
    elif prec == '64':
        if bin_string[1:12] == '1'*11:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Return 1 if bin_string on prec bit is Inf
def isInf(bin_string, prec):
    if prec == '32':
        if isSpecial(bin_string, prec) and bin_string[9:32] == '0'*23:
            return 1
        else:
            return 0
    elif prec == '64':
        if isSpecial(bin_string, prec) and bin_string[12:64] == '0'*52:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Return 1 if bin_string on prec bit is NaN
def isNan(bin_string, prec):
    if prec == '32':
        if isSpecial(bin_string, prec) and bin_string[9:32] != '0'*23:
            return 1
        else:
            return 0
    elif prec == '64':
        if isSpecial(bin_string, prec) and bin_string[12:64] != '0'*52:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Return 1 if bin_string on prec bit is denormal
def isDenormal(bin_string, prec):
    if prec == '32':
        if bin_string[1:9] == '0'*8 and bin_string[9:32] != '0'*23:
            return 1
        else:
            return 0
    elif prec == '64':
        if bin_string[1:12] == '0'*11 and bin_string[12:64] != '0'*52:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Return 1 if bin_string on prec bit is zero
def isZero(bin_string, prec):
    if prec == '32':
        if bin_string[1:9] == '0'*8 and bin_string[9:32] == '0'*23:
            return 1
        else:
            return 0
    elif prec == '64':
        if bin_string[1:12] == '0'*11 and bin_string[12:64] == '0'*52:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Return 1 if bin_string on prec bit is zero
def isZeroDenormal(bin_string, prec):
    if prec == '32':
        if bin_string[1:9] == '0'*8:
            return 1
        else:
            return 0
    elif prec == '64':
        if bin_string[1:12] == '0'*11:
            return 1
        else:
            return 0
    else:
        print('Error: precision should be either 32 or 64.')

# Convert an hex string into a bin string of precision prec
def hex2bin(hex_string, prec):
    if prec == '32':
        return format(int(hex_string, 16), '032b')
    elif prec == '64':
        return format(int(hex_string, 16), '064b')
    else:
        print('Error: precision should be either 32 or 64.')
