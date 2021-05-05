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

    double op0, op1;
    int res, gold_res;
    char flags[10];
    int ret = 0;

    // Read the operands from stdin, print on stdout
    while (ret != EOF) {
        ret = scanf("%llX %llX %d %s", &op0, &op1, &gold_res, flags);
        res = __ltdf2(op0, op1);
        printf("%016llX %016llX %d %s\n", *(uint64_t*)&op0, *(uint64_t*)&op1, res, flags);
    }

    // Dummy call to __lesf2 to avoid problems at link time
    // In libgcc, __lesf2 calls also the libgcc __ltsf2. We don't want this, otherwise we would have 2 __ltsf2 definitions
    // Therefore, link rvfplib's __lesf2
    __ledf2(op0, op1);

    return 0;
}
