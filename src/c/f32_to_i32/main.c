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

    float op0;
    int res, gold_res;
    char flags[10];
    int ret = 0;

    // Read the operands from stdin, print on stdout
    while (ret != EOF) {
        ret = scanf("%X %X %s", &op0, &gold_res, flags);
        res = __fixsfsi(op0);
        printf("%08X %08X %s\n", *(uint32_t*)&op0, *(uint32_t*)&res, flags);
    }

    return 0;
}
