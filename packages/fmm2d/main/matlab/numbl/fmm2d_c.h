/*
 * fmm2d_c.h - shared definitions for the C port of fmm2d
 *
 * Conventions
 * -----------
 * Each Fortran subroutine `foo` is translated to a C function `foo_`
 * (lowercase, single trailing underscore) so the resulting object files
 * can be linked as a drop-in replacement for the gfortran-compiled
 * object files. All arguments are passed by pointer, matching the
 * Fortran reference-passing convention. Multidimensional Fortran arrays
 * are stored column-major; the FA(...) macros below convert
 * 1-indexed Fortran subscripts to the corresponding 0-indexed C
 * offsets in a flat double / double _Complex buffer.
 */

#ifndef FMM2D_C_H
#define FMM2D_C_H

#include <complex.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * Symbol naming. By default each translated routine is exported with a
 * `_c_` suffix (e.g. `hndiv2d_c_`) so it lives alongside, and does not
 * collide with, its Fortran original in differential tests. When the
 * full library has been ported and we want to link the C objects as a
 * drop-in replacement for the gfortran objects, build with
 * -DFMM2D_DROP_IN and the routines are exported under the canonical
 * Fortran symbol name (e.g. `hndiv2d_`).
 */
#ifdef FMM2D_DROP_IN
#define FNAME(x) x##_
#else
#define FNAME(x) x##_c_
#endif

/* Fortran integer is the default 4-byte integer for gfortran. */
typedef int32_t fint;

/* Fortran complex*16 maps to C99 double _Complex. */
typedef double _Complex fcomplex;

/*
 * Column-major indexing helpers. Each macro takes Fortran-style
 * 1-indexed subscripts (i, j, ...) and returns the linear offset
 * into a flat 0-indexed C buffer.
 *
 *   FA2(i,j, ld1)         <-> A(i,j)         where A is dimensioned A(ld1,*)
 *   FA3(i,j,k, ld1,ld2)   <-> A(i,j,k)       A is dimensioned A(ld1,ld2,*)
 *   FA4(i,j,k,l, ld1,ld2,ld3)               A is dimensioned A(ld1,ld2,ld3,*)
 *
 * The macros assume i,j,k,l are 1-based, matching Fortran source code.
 */
#define FA2(i, j, ld1) (((j) - 1) * (ld1) + ((i) - 1))
#define FA3(i, j, k, ld1, ld2) \
    ((((k) - 1) * (ld2) + ((j) - 1)) * (ld1) + ((i) - 1))
#define FA4(i, j, k, l, ld1, ld2, ld3) \
    ((((((l) - 1) * (ld3) + ((k) - 1)) * (ld2)) + ((j) - 1)) * (ld1) + ((i) - 1))

#endif /* FMM2D_C_H */
