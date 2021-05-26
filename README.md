# RVfplib - Optimized RISC-V FP emulation for 32-bit processors #
RVfplib is an optimized RISC-V library for FP arithmetic on 32-bit integer processors, for single and double-precision FP.
RVfplib is IEEE 754 compliant, with the following exceptions:
  - It does not support exception flags.
  - It does not support signaling `NaNs`, all the produced `NaNs` are quiet in the form of `0x7FC00000` and `0x7FF8000000000000`.
  - The only provided rounding mode is `RNE`.

RVfplib is available in 4 versions:
 - **RVfplib**, optimized for performance. It is compatible with RV32IM[C] processors.
 - **RVfplib_s**, optimized for low code-size. It is compatible with RV32IM[C] processors.
 - **RVfplib_nd**, optimized for performance, with no support for subnormal values (they are considered correctly signed zeroes). It is compatible with RV32EM[C] processors.
 - **RVfplib_nd_s**, optimized for low code-size, with no support for subnormal values (they are considered correctly signed zeroes). It is compatible with RV32EM[C] processors.

The optimizations for performance are input-dependent, and in certain contextes can lead to slower code. If in doubt, use the the code optimized for size.

The functions are aliased with those automatically linked from `libgcc`, e.g. the single-precision addition is called `__addsf3`.

## Dependencies ##
To build the library, a RISC-V RV32IM[C] toolchain is needed. Make sure that ``riscv32-unknown-elf-gcc`` is available in the used shell.
To do so, add to the ``PATH`` variable the path to the ``bin`` directory of your ``riscv32-unknown-elf`` toolchain. If this directory is called ``${RISCV_TOOLS_BIN_DIR}``, then execute the following command in the shell that will be used to build the library.

`export PATH="${RISCV_TOOLS_BIN_DIR}:$PATH"`

For custom needs, modify the Makefile.

The library itself has no external dependencies.

## Build the library ##
In the following, the directory in which this file is stored will be identified as `$(BASE_DIR)`

To build the library, open a terminal in this directory and execute:

``make``

This command will build the four libraries in `$(BASE_DIR)/build/lib/`.

## Use the library ##
The following steps work with a RISC-V GCC toolchain.

To use the library, add:

``-L $(BASE_DIR)/build/lib -nolibc -lc``

to the linker flags, and:

``-lrvfp``

to the linker flags, but only after the source files and the other external needed libraries.

For example, to compile a `main.c` program with RVfplib, use:

``riscv32-unknown-elf-gcc -march=rv32imc main.c -L $(BASE_DIR)/build/lib -nolibc -lc -lm -lrvfp``

## Use another RVfplib version ##
To link one of the other three RVfplib versions, just replace

``-lrvfp``

with one of the following:

``-lrvfp_s``
``-lrvfp_nd``
``-lrvfp_nd_s``

## Source ##
The source code of the functions is kept in `src/asm/`, whereas `src/c/` contains test-related C code.

## Test ##
It's possible to select which function to test commenting/un-commenting the related line in the file `script/topScript_test.sh`.

Then, from `$(BASE_DIR)`, launch:

``./script/topScript_test.sh size`` - To test the size-optimized library

``./script/topScript_test.sh performance`` - To test the performance-optimized library

The test depends upon `riscv32-unknown-elf-` tools, `TestFloat` programs, `SPIKE`, `PK`, and Python3. The `TestFloat` programs and Python3 should be accessible from the shell. For the others, make sure to define and export the following variables before calling the script:

- `GCC_TOOLS_BIN_PATH` : the bin path to your GCC tools
- `SPIKE_PATH` : the path to your SPIKE program
- `PK_PATH` : the path to your Proxy Kernel program

## Acknowledgements ##
Part of this library is inspired by the Arm FP support provided within libgcc:
  - https://github.com/gcc-mirror/gcc/blob/master/libgcc/config/arm/ieee754-sf.S
  - https://github.com/gcc-mirror/gcc/blob/master/libgcc/config/arm/ieee754-df.S
