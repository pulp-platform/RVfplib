// Copyright ETH Zurich 2020
//
// Author: Matteo Perotti
//
// This file is part of rvfplib.
//
// rvfplib is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// rvfplib is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with rvfplib  If not, see <https://www.gnu.org/licenses/>.
// Copyright ETH Zurich 2020

/*
    Wrapper for ASM RISC-V functions.
*/

#include <stdio.h>
#include "rvfplib.h"

int main(int argc, char** argv) {

    double op0, op1, res, gold_res;
    char flags[10];
    int ret = 0;

    // Read the operands from stdin, print on stdout
    while (ret != EOF) {
        ret = scanf("%llX %llX %llX %s", &op0, &op1, &gold_res, flags);
        res = __divdf3(op0, op1);
        printf("%016llX %016llX %016llX %s\n", *(uint64_t*)&op0, *(uint64_t*)&op1, *(uint64_t*)&res, flags);
    }

    return 0;
}
