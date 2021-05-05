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

// Arithmetical functions
// Single precision FP addition
float __addsf3(float op0, float op1);
// Single precision FP subtracion
float __subsf3(float op0, float op1);
// Single precision FP multiplication
float __mulsf3(float op0, float op1);
// Single precision FP division
float __divsf3(float op0, float op1);
// Double precision FP addition
double __adddf3(double op0, double op1);
// Double precision FP subtraction
double __subdf3(double op0, double op1);
// Double precision FP multiplication
double __muldf3(double op0, double op1);
// Double precision FP division
double __divdf3(double op0, double op1);

// Comparison functions
int __eqsf2(float op0, float op1);
int __nesf2(float op0, float op1);
int __ltsf2(float op0, float op1);
int __lesf2(float op0, float op1);
int __gtsf2(float op0, float op1);
int __gesf2(float op0, float op1);
int __eqdf2(double op0, double op1);
int __nedf2(double op0, double op1);
int __ltdf2(double op0, double op1);
int __ledf2(double op0, double op1);
int __gtdf2(double op0, double op1);
int __gedf2(double op0, double op1);

// Conversion functions
int __fixsfsi(float op0);
unsigned int __fixunssfsi(float op0);
long long int __fixsfdi(float op0);
unsigned long long int __fixunssfdi(float op0);
float __floatsisf(int op0);
float __floatunsisf(unsigned int op0);
float __floatdisf(long long int op0);
float __floatundisf(unsigned long long int op0);
double __extendsfdf2(float op0);

int __fixdfsi(double op0);
unsigned int __fixunsdfsi(double op0);
long long int __fixdfdi(double op0);
unsigned long long int __fixunsdfdi(double op0);
double __floatsidf(int op0);
double __floatunsidf(unsigned int op0);
double __floatdidf(long long int op0);
double __floatundidf(unsigned long long int op0);
float __truncdfsf2(double op0);
