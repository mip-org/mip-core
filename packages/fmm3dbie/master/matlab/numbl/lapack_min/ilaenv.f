      INTEGER FUNCTION ILAENV( ISPEC, NAME, OPTS, N1, N2, N3, N4 )
*     Minimal stub for the numbl_wasm minimal-LAPACK build: always report a
*     block size / parameter of 1, forcing the unblocked code paths. This
*     avoids the real ILAENV's environment heuristics (and its IEEECK/IPARMQ
*     dependencies), which buy nothing for the small dense LU/inverse fmm3dbie
*     uses. NB=1 keeps the factorizations correct, just unblocked.
      CHARACTER*( * )    NAME, OPTS
      INTEGER            ISPEC, N1, N2, N3, N4
      ILAENV = 1
      RETURN
      END
