      SUBROUTINE XERBLA( SRNAME, INFO )
*     Minimal stub for the numbl_wasm minimal-LAPACK build. The real XERBLA
*     prints the offending routine/argument and STOPs; here we just return so
*     the build needs no Fortran I/O runtime. Callers already pass valid
*     arguments (INFO is also returned to the caller), so this is never the
*     sole error signal.
      CHARACTER*( * )    SRNAME
      INTEGER            INFO
      RETURN
      END
