/*
 * fmm3d_c.h - support header for the fort2c-generated C port of fmm3d.
 *
 * Conventions
 * -----------
 * Each Fortran subroutine `foo` is translated to a C function `FNAME(foo)`
 * (lowercase, single trailing underscore under -DFMM3D_DROP_IN) so the object
 * files link as a drop-in replacement for the gfortran-compiled objects. All
 * arguments are passed by pointer (Fortran reference passing). Multidimensional
 * arrays are column-major; the FA(...) macros convert 1-indexed Fortran
 * subscripts to flat 0-indexed C offsets.
 *
 * fmm3d is built with mwrap's -i8, so Fortran INTEGER is 8 bytes -> `flong`.
 */

#ifndef FMM3D_C_H
#define FMM3D_C_H

#include <complex.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * Symbol naming. By default each translated routine is exported with a `_c_`
 * suffix (e.g. `lfmm3d_c_`) so it can coexist with its Fortran original in
 * differential tests. Build with -DFMM3D_DROP_IN to export the canonical
 * Fortran symbol name (e.g. `lfmm3d_`) and link against the mwrap gateway.
 */
#ifdef FMM3D_DROP_IN
#define FNAME(x) x##_
#else
#define FNAME(x) x##_c_
#endif

/* Fortran default INTEGER (4-byte) and INTEGER*8 (8-byte). */
typedef int32_t fint;
typedef int64_t flong;

/* Fortran COMPLEX*16 maps to C99 double _Complex. */
typedef double _Complex fcomplex;

/*
 * Column-major indexing helpers: each macro takes Fortran-style 1-indexed
 * subscripts and returns the linear offset into a flat 0-indexed C buffer.
 *   FA2(i,j, ld1)               <-> A(i,j)       dimensioned A(ld1,*)
 *   FA3(i,j,k, ld1,ld2)         <-> A(i,j,k)     A(ld1,ld2,*)
 *   FA4(i,j,k,l, ld1,ld2,ld3)   <-> A(i,j,k,l)   A(ld1,ld2,ld3,*)
 */
#define FA2(i, j, ld1) (((j) - 1) * (ld1) + ((i) - 1))
#define FA3(i, j, k, ld1, ld2) \
    ((((k) - 1) * (ld2) + ((j) - 1)) * (ld1) + ((i) - 1))
#define FA4(i, j, k, l, ld1, ld2, ld3) \
    ((((((l) - 1) * (ld3) + ((k) - 1)) * (ld2)) + ((j) - 1)) * (ld1) + ((i) - 1))

#endif /* FMM3D_C_H */
