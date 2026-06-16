// El Topo BLAS/LAPACK integer-width shim (Linux + Windows).
//
// El Topo's blas_wrapper.h / lapack_wrapper.h (USE_FORTRAN_BLAS path, used on
// Linux and Windows) declare every BLAS/LAPACK integer argument as 32-bit
// `int`. The eltopo MEX links MATLAB's libmwblas/libmwlapack, whose Fortran
// integer is 64-bit (ptrdiff_t / ILP64). Passing a 4-byte `int*` where MATLAB
// reads 8 bytes feeds a garbage high word into N/INC/LDA and walks MKL off the
// end of its buffers -> access violation. (macOS is unaffected: it links
// Accelerate's 32-bit-int CBLAS, which matches El Topo, so this file is NOT
// compiled there.)
//
// This is a thin ABI adapter, not a reimplementation: MATLAB's MKL still does
// 100% of the math. Each function below has El Topo's exact 32-bit signature,
// copies the small integer arguments into ptrdiff_t storage (scalars by value;
// the few integer *arrays* -- ipiv/iwork -- into a temporary widened buffer),
// and forwards to MATLAB's real routine. The El Topo build preprocessor-renames
// its BLAS/LAPACK calls (daxpy_ -> eltopo_daxpy, ...) so they bind here instead
// of straight to libmwblas; see CMakeLists.txt (ELTOPO_BLAS_RENAME) and
// BUILD_NOTES.md ("BLAS integer width").
//
// Compiled by mex() in compile.m (not the CMake deps build), so it sees
// MATLAB's <blas.h>/<lapack.h> (ptrdiff_t prototypes) and links libmwblas/
// libmwlapack. <blas.h>'s FORTRAN_WRAPPER macro maps daxpy -> daxpy_ on
// Linux and -> daxpy on Windows, so the forwarding calls resolve to MATLAB's
// platform-correct export automatically.

#include <cstddef>   // ptrdiff_t
#include <vector>
#include "blas.h"
#include "lapack.h"

namespace {
// Copy a 32-bit integer array into a freshly allocated 64-bit buffer.
inline std::vector<ptrdiff_t> widen(const int* p, ptrdiff_t n) {
    std::vector<ptrdiff_t> w(n > 0 ? (size_t)n : 0);
    for (ptrdiff_t i = 0; i < n; ++i) w[(size_t)i] = p[i];
    return w;
}
// Copy a 64-bit integer array back down into a caller-owned 32-bit array.
inline void narrow_into(int* dst, const std::vector<ptrdiff_t>& w) {
    for (size_t i = 0; i < w.size(); ++i) dst[i] = (int)w[i];
}
}  // namespace

extern "C" {

// ---- BLAS level 1/2/3: scalar integer args only (widen by value) ----------

double eltopo_ddot(const int* n, const double* x, const int* incx,
                   const double* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    return ddot(&n_, x, &ix, y, &iy);
}

double eltopo_dsdot(const int* n, const float* x, const int* incx,
                    const float* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    return dsdot(&n_, x, &ix, y, &iy);
}

void eltopo_daxpy(const int* n, const double* a, const double* x,
                  const int* incx, double* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    daxpy(&n_, a, x, &ix, y, &iy);
}

void eltopo_saxpy(const int* n, const float* a, const float* x,
                  const int* incx, float* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    saxpy(&n_, a, x, &ix, y, &iy);
}

void eltopo_dcopy(const int* n, const double* x, const int* incx,
                  double* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    dcopy(&n_, x, &ix, y, &iy);
}

void eltopo_scopy(const int* n, const float* x, const int* incx,
                  float* y, const int* incy) {
    ptrdiff_t n_ = *n, ix = *incx, iy = *incy;
    scopy(&n_, x, &ix, y, &iy);
}

int eltopo_idamax(const int* n, const double* x, const int* incx) {
    ptrdiff_t n_ = *n, ix = *incx;
    return (int)idamax(&n_, x, &ix);
}

int eltopo_isamax(const int* n, const float* x, const int* incx) {
    ptrdiff_t n_ = *n, ix = *incx;
    return (int)isamax(&n_, x, &ix);
}

void eltopo_dgemv(const char* trans, const int* m, const int* n,
                  const double* alpha, const double* A, const int* lda,
                  const double* x, const int* incx, const double* beta,
                  double* y, const int* incy) {
    ptrdiff_t m_ = *m, n_ = *n, lda_ = *lda, ix = *incx, iy = *incy;
    dgemv(trans, &m_, &n_, alpha, A, &lda_, x, &ix, beta, y, &iy);
}

void eltopo_sgemv(const char* trans, const int* m, const int* n,
                  const float* alpha, const float* A, const int* lda,
                  const float* x, const int* incx, const float* beta,
                  float* y, const int* incy) {
    ptrdiff_t m_ = *m, n_ = *n, lda_ = *lda, ix = *incx, iy = *incy;
    sgemv(trans, &m_, &n_, alpha, A, &lda_, x, &ix, beta, y, &iy);
}

void eltopo_dgemm(const char* ta, const char* tb, const int* m, const int* n,
                  const int* k, const double* alpha, const double* A,
                  const int* lda, const double* B, const int* ldb,
                  const double* beta, double* C, const int* ldc) {
    ptrdiff_t m_ = *m, n_ = *n, k_ = *k, lda_ = *lda, ldb_ = *ldb, ldc_ = *ldc;
    dgemm(ta, tb, &m_, &n_, &k_, alpha, A, &lda_, B, &ldb_, beta, C, &ldc_);
}

void eltopo_sgemm(const char* ta, const char* tb, const int* m, const int* n,
                  const int* k, const float* alpha, const float* A,
                  const int* lda, const float* B, const int* ldb,
                  const float* beta, float* C, const int* ldc) {
    ptrdiff_t m_ = *m, n_ = *n, k_ = *k, lda_ = *lda, ldb_ = *ldb, ldc_ = *ldc;
    sgemm(ta, tb, &m_, &n_, &k_, alpha, A, &lda_, B, &ldb_, beta, C, &ldc_);
}

// ---- LAPACK: scalar widening + integer-array translation -------------------

// dsyev: all integer args scalar.
int eltopo_dsyev(char* jobz, char* uplo, int* n, double* a, int* lda,
                 double* w, double* work, int* lwork, int* info) {
    ptrdiff_t n_ = *n, lda_ = *lda, lwork_ = *lwork, info_ = 0;
    dsyev(jobz, uplo, &n_, a, &lda_, w, work, &lwork_, &info_);
    *info = (int)info_;
    return *info;
}

// dgetrf: ipiv is an OUTPUT integer array of length min(m,n).
int eltopo_dgetrf(int* m, int* n, double* a, int* lda, int* ipiv, int* info) {
    ptrdiff_t m_ = *m, n_ = *n, lda_ = *lda, info_ = 0;
    ptrdiff_t len = (m_ < n_ ? m_ : n_);
    std::vector<ptrdiff_t> ipiv64(len > 0 ? (size_t)len : 0);
    dgetrf(&m_, &n_, a, &lda_, ipiv64.data(), &info_);
    narrow_into(ipiv, ipiv64);
    *info = (int)info_;
    return *info;
}

// dgetri: ipiv is an INPUT integer array of length n. El Topo's decl omits the
// work/lwork arguments LAPACK requires, so we allocate the workspace here (size
// from a query) -- the shim also covers that latent gap.
int eltopo_dgetri(int* n, double* a, int* lda, int* ipiv, int* info) {
    ptrdiff_t n_ = *n, lda_ = *lda, info_ = 0;
    std::vector<ptrdiff_t> ipiv64 = widen(ipiv, n_);
    double wkopt = 0.0;
    ptrdiff_t lwork = -1;
    dgetri(&n_, a, &lda_, ipiv64.data(), &wkopt, &lwork, &info_);  // workspace query
    lwork = (ptrdiff_t)wkopt;
    if (lwork < n_) lwork = n_;
    if (lwork < 1) lwork = 1;
    std::vector<double> work((size_t)lwork);
    dgetri(&n_, a, &lda_, ipiv64.data(), work.data(), &lwork, &info_);
    *info = (int)info_;
    return *info;
}

// dgelsd: iwork is an integer workspace array. El Topo passes its own iwork but
// not its length, so we size and allocate our own (LAPACK's documented LIWORK).
// rank is a scalar integer output.
int eltopo_dgelsd(int* m, int* n, int* nrhs, double* a, int* lda, double* b,
                  int* ldb, double* s, double* rcond, int* rank, double* work,
                  int* lwork, int* /*iwork*/, int* info) {
    ptrdiff_t m_ = *m, n_ = *n, nrhs_ = *nrhs, lda_ = *lda, ldb_ = *ldb;
    ptrdiff_t lwork_ = *lwork, rank_ = 0, info_ = 0;
    // LIWORK >= 3*MINMN*NLVL + 11*MINMN, NLVL = max(0, floor(log2(MINMN/26))+1).
    ptrdiff_t minmn = (m_ < n_ ? m_ : n_);
    if (minmn < 1) minmn = 1;
    ptrdiff_t nlvl = 0;
    for (ptrdiff_t t = minmn / 26; t > 0; t >>= 1) ++nlvl;  // floor(log2(minmn/26))+1
    ++nlvl;
    ptrdiff_t liwork = 3 * minmn * nlvl + 11 * minmn;
    std::vector<ptrdiff_t> iwork64((size_t)liwork);
    dgelsd(&m_, &n_, &nrhs_, a, &lda_, b, &ldb_, s, rcond, &rank_, work,
           &lwork_, iwork64.data(), &info_);
    *rank = (int)rank_;
    *info = (int)info_;
    return *info;
}

}  // extern "C"
