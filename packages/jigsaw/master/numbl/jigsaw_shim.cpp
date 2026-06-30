// JIGSAW numbl_wasm shim.
//
// numbl can't run JIGSAW's native CLI (no system(), and a .numbl.js builtin
// has no filesystem access), so the file/process protocol of jigsaw.m can't be
// reused. Instead we compile JIGSAW's C library (lib_jigsaw, the same
// jigsaw.cpp the native shared library is built from, via -D__lib_jigsaw) to a
// standalone WASM and drive it through its in-memory C API: jigsaw(), tripod()
// and marche() operate purely on jigsaw_msh_t / jigsaw_jig_t structs.
//
// This shim exposes a flat C ABI the jigsaw_kernel.numbl.js builtin can call
// over WASM linear memory:
//   * msh_*  — build a jigsaw_msh_t from column-major arrays (the layout numbl
//              tensors / MATLAB matrices use), and read one back out.
//   * jig_*  — populate the (flat, all-scalar) jigsaw_jig_t by option name.
//   * run_*  — invoke jigsaw / tripod / marche.
//
// Element index arrays use JIGSAW's native 0-based node indices here; the JS
// side converts to/from the 1-based convention that loadmsh.m / savemsh.m use.

#include "lib_jigsaw.h"

#include <cstdlib>
#include <cstring>
#include <string>

#ifdef __EMSCRIPTEN__
#define EXPORT(name) __attribute__((export_name(#name), used))
#else
#define EXPORT(name) __attribute__((visibility("default"), used))
#endif

// Last error message, surfaced to JS via jig_get_error().
static std::string g_error;

// Column-major element access for a flat [m x ncols] buffer: data[c*m + r].
static inline double colv(const double *d, int m, int r, int c) {
  return d[(size_t)c * (size_t)m + (size_t)r];
}

extern "C" {

// ── raw memory helpers (JS stages argument/return buffers here) ─────────────

EXPORT(my_malloc) void *my_malloc(int size) { return std::malloc((size_t)size); }
EXPORT(my_free) void my_free(void *ptr) { std::free(ptr); }

EXPORT(jig_get_error) const char *jig_get_error(void) { return g_error.c_str(); }

// ── jigsaw_msh_t lifecycle ──────────────────────────────────────────────────

EXPORT(msh_create) void *msh_create(void) {
  jigsaw_msh_t *m = (jigsaw_msh_t *)std::calloc(1, sizeof(jigsaw_msh_t));
  jigsaw_init_msh_t(m);
  return m;
}

EXPORT(msh_destroy) void msh_destroy(void *p) {
  if (!p) return;
  jigsaw_msh_t *m = (jigsaw_msh_t *)p;
  jigsaw_free_msh_t(m);
  std::free(m);
}

EXPORT(msh_set_flags) void msh_set_flags(void *p, int f) {
  ((jigsaw_msh_t *)p)->_flags = (indx_t)f;
}
EXPORT(msh_get_flags) int msh_get_flags(void *p) {
  return (int)((jigsaw_msh_t *)p)->_flags;
}

// ── setters: input arrays are column-major [m x ncols], ncols fixed per kind ─

EXPORT(msh_set_vert2) void msh_set_vert2(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_vert2(&M->_vert2, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_vert2._data[r]._ppos[0] = colv(d, m, r, 0);
    M->_vert2._data[r]._ppos[1] = colv(d, m, r, 1);
    M->_vert2._data[r]._itag = (indx_t)colv(d, m, r, 2);
  }
}
EXPORT(msh_set_vert3) void msh_set_vert3(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_vert3(&M->_vert3, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_vert3._data[r]._ppos[0] = colv(d, m, r, 0);
    M->_vert3._data[r]._ppos[1] = colv(d, m, r, 1);
    M->_vert3._data[r]._ppos[2] = colv(d, m, r, 2);
    M->_vert3._data[r]._itag = (indx_t)colv(d, m, r, 3);
  }
}
EXPORT(msh_set_seed2) void msh_set_seed2(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_vert2(&M->_seed2, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_seed2._data[r]._ppos[0] = colv(d, m, r, 0);
    M->_seed2._data[r]._ppos[1] = colv(d, m, r, 1);
    M->_seed2._data[r]._itag = (indx_t)colv(d, m, r, 2);
  }
}
EXPORT(msh_set_seed3) void msh_set_seed3(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_vert3(&M->_seed3, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_seed3._data[r]._ppos[0] = colv(d, m, r, 0);
    M->_seed3._data[r]._ppos[1] = colv(d, m, r, 1);
    M->_seed3._data[r]._ppos[2] = colv(d, m, r, 2);
    M->_seed3._data[r]._itag = (indx_t)colv(d, m, r, 3);
  }
}
EXPORT(msh_set_edge2) void msh_set_edge2(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_edge2(&M->_edge2, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_edge2._data[r]._node[0] = (indx_t)colv(d, m, r, 0);
    M->_edge2._data[r]._node[1] = (indx_t)colv(d, m, r, 1);
    M->_edge2._data[r]._itag = (indx_t)colv(d, m, r, 2);
  }
}
EXPORT(msh_set_tria3) void msh_set_tria3(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_tria3(&M->_tria3, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_tria3._data[r]._node[0] = (indx_t)colv(d, m, r, 0);
    M->_tria3._data[r]._node[1] = (indx_t)colv(d, m, r, 1);
    M->_tria3._data[r]._node[2] = (indx_t)colv(d, m, r, 2);
    M->_tria3._data[r]._itag = (indx_t)colv(d, m, r, 3);
  }
}
EXPORT(msh_set_quad4) void msh_set_quad4(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_quad4(&M->_quad4, (size_t)m);
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 4; k++)
      M->_quad4._data[r]._node[k] = (indx_t)colv(d, m, r, k);
    M->_quad4._data[r]._itag = (indx_t)colv(d, m, r, 4);
  }
}
EXPORT(msh_set_tria4) void msh_set_tria4(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_tria4(&M->_tria4, (size_t)m);
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 4; k++)
      M->_tria4._data[r]._node[k] = (indx_t)colv(d, m, r, k);
    M->_tria4._data[r]._itag = (indx_t)colv(d, m, r, 4);
  }
}
EXPORT(msh_set_hexa8) void msh_set_hexa8(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_hexa8(&M->_hexa8, (size_t)m);
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 8; k++)
      M->_hexa8._data[r]._node[k] = (indx_t)colv(d, m, r, k);
    M->_hexa8._data[r]._itag = (indx_t)colv(d, m, r, 8);
  }
}
EXPORT(msh_set_wedg6) void msh_set_wedg6(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_wedg6(&M->_wedg6, (size_t)m);
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 6; k++)
      M->_wedg6._data[r]._node[k] = (indx_t)colv(d, m, r, k);
    M->_wedg6._data[r]._itag = (indx_t)colv(d, m, r, 6);
  }
}
EXPORT(msh_set_pyra5) void msh_set_pyra5(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_pyra5(&M->_pyra5, (size_t)m);
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 5; k++)
      M->_pyra5._data[r]._node[k] = (indx_t)colv(d, m, r, k);
    M->_pyra5._data[r]._itag = (indx_t)colv(d, m, r, 5);
  }
}
EXPORT(msh_set_bound) void msh_set_bound(void *p, const double *d, int m) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_bound(&M->_bound, (size_t)m);
  for (int r = 0; r < m; r++) {
    M->_bound._data[r]._itag = (indx_t)colv(d, m, r, 0);
    M->_bound._data[r]._indx = (indx_t)colv(d, m, r, 1);
    M->_bound._data[r]._kind = (indx_t)colv(d, m, r, 2);
  }
}

// value/slope are fp32 arrays; power/radii/grid coords are real (double).
EXPORT(msh_set_value) void msh_set_value(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_flt32(&M->_value, (size_t)n);
  for (int i = 0; i < n; i++) M->_value._data[i] = (fp32_t)d[i];
}
EXPORT(msh_set_slope) void msh_set_slope(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_flt32(&M->_slope, (size_t)n);
  for (int i = 0; i < n; i++) M->_slope._data[i] = (fp32_t)d[i];
}
EXPORT(msh_set_power) void msh_set_power(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_reals(&M->_power, (size_t)n);
  for (int i = 0; i < n; i++) M->_power._data[i] = (real_t)d[i];
}
EXPORT(msh_set_radii) void msh_set_radii(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_reals(&M->_radii, (size_t)n);
  for (int i = 0; i < n; i++) M->_radii._data[i] = (real_t)d[i];
}
EXPORT(msh_set_xgrid) void msh_set_xgrid(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_reals(&M->_xgrid, (size_t)n);
  for (int i = 0; i < n; i++) M->_xgrid._data[i] = (real_t)d[i];
}
EXPORT(msh_set_ygrid) void msh_set_ygrid(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_reals(&M->_ygrid, (size_t)n);
  for (int i = 0; i < n; i++) M->_ygrid._data[i] = (real_t)d[i];
}
EXPORT(msh_set_zgrid) void msh_set_zgrid(void *p, const double *d, int n) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  jigsaw_alloc_reals(&M->_zgrid, (size_t)n);
  for (int i = 0; i < n; i++) M->_zgrid._data[i] = (real_t)d[i];
}

// ── getters: write column-major [m x ncols] into out (JS pre-allocates) ──────

EXPORT(msh_get_vert2_size) int msh_get_vert2_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_vert2._size;
}
EXPORT(msh_get_vert2) void msh_get_vert2(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_vert2._size;
  for (int r = 0; r < m; r++) {
    out[0 * m + r] = M->_vert2._data[r]._ppos[0];
    out[1 * m + r] = M->_vert2._data[r]._ppos[1];
    out[2 * m + r] = (double)M->_vert2._data[r]._itag;
  }
}
EXPORT(msh_get_vert3_size) int msh_get_vert3_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_vert3._size;
}
EXPORT(msh_get_vert3) void msh_get_vert3(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_vert3._size;
  for (int r = 0; r < m; r++) {
    out[0 * m + r] = M->_vert3._data[r]._ppos[0];
    out[1 * m + r] = M->_vert3._data[r]._ppos[1];
    out[2 * m + r] = M->_vert3._data[r]._ppos[2];
    out[3 * m + r] = (double)M->_vert3._data[r]._itag;
  }
}
EXPORT(msh_get_edge2_size) int msh_get_edge2_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_edge2._size;
}
EXPORT(msh_get_edge2) void msh_get_edge2(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_edge2._size;
  for (int r = 0; r < m; r++) {
    out[0 * m + r] = (double)M->_edge2._data[r]._node[0];
    out[1 * m + r] = (double)M->_edge2._data[r]._node[1];
    out[2 * m + r] = (double)M->_edge2._data[r]._itag;
  }
}
EXPORT(msh_get_tria3_size) int msh_get_tria3_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_tria3._size;
}
EXPORT(msh_get_tria3) void msh_get_tria3(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_tria3._size;
  for (int r = 0; r < m; r++) {
    out[0 * m + r] = (double)M->_tria3._data[r]._node[0];
    out[1 * m + r] = (double)M->_tria3._data[r]._node[1];
    out[2 * m + r] = (double)M->_tria3._data[r]._node[2];
    out[3 * m + r] = (double)M->_tria3._data[r]._itag;
  }
}
EXPORT(msh_get_quad4_size) int msh_get_quad4_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_quad4._size;
}
EXPORT(msh_get_quad4) void msh_get_quad4(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_quad4._size;
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 4; k++)
      out[k * m + r] = (double)M->_quad4._data[r]._node[k];
    out[4 * m + r] = (double)M->_quad4._data[r]._itag;
  }
}
EXPORT(msh_get_tria4_size) int msh_get_tria4_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_tria4._size;
}
EXPORT(msh_get_tria4) void msh_get_tria4(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_tria4._size;
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 4; k++)
      out[k * m + r] = (double)M->_tria4._data[r]._node[k];
    out[4 * m + r] = (double)M->_tria4._data[r]._itag;
  }
}
EXPORT(msh_get_hexa8_size) int msh_get_hexa8_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_hexa8._size;
}
EXPORT(msh_get_hexa8) void msh_get_hexa8(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_hexa8._size;
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 8; k++)
      out[k * m + r] = (double)M->_hexa8._data[r]._node[k];
    out[8 * m + r] = (double)M->_hexa8._data[r]._itag;
  }
}
EXPORT(msh_get_wedg6_size) int msh_get_wedg6_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_wedg6._size;
}
EXPORT(msh_get_wedg6) void msh_get_wedg6(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_wedg6._size;
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 6; k++)
      out[k * m + r] = (double)M->_wedg6._data[r]._node[k];
    out[6 * m + r] = (double)M->_wedg6._data[r]._itag;
  }
}
EXPORT(msh_get_pyra5_size) int msh_get_pyra5_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_pyra5._size;
}
EXPORT(msh_get_pyra5) void msh_get_pyra5(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_pyra5._size;
  for (int r = 0; r < m; r++) {
    for (int k = 0; k < 5; k++)
      out[k * m + r] = (double)M->_pyra5._data[r]._node[k];
    out[5 * m + r] = (double)M->_pyra5._data[r]._itag;
  }
}
EXPORT(msh_get_bound_size) int msh_get_bound_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_bound._size;
}
EXPORT(msh_get_bound) void msh_get_bound(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int m = (int)M->_bound._size;
  for (int r = 0; r < m; r++) {
    out[0 * m + r] = (double)M->_bound._data[r]._itag;
    out[1 * m + r] = (double)M->_bound._data[r]._indx;
    out[2 * m + r] = (double)M->_bound._data[r]._kind;
  }
}
EXPORT(msh_get_value_size) int msh_get_value_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_value._size;
}
EXPORT(msh_get_value) void msh_get_value(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_value._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_value._data[i];
}
EXPORT(msh_get_slope_size) int msh_get_slope_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_slope._size;
}
EXPORT(msh_get_slope) void msh_get_slope(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_slope._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_slope._data[i];
}
EXPORT(msh_get_power_size) int msh_get_power_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_power._size;
}
EXPORT(msh_get_power) void msh_get_power(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_power._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_power._data[i];
}
EXPORT(msh_get_radii_size) int msh_get_radii_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_radii._size;
}
EXPORT(msh_get_radii) void msh_get_radii(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_radii._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_radii._data[i];
}
EXPORT(msh_get_xgrid_size) int msh_get_xgrid_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_xgrid._size;
}
EXPORT(msh_get_xgrid) void msh_get_xgrid(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_xgrid._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_xgrid._data[i];
}
EXPORT(msh_get_ygrid_size) int msh_get_ygrid_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_ygrid._size;
}
EXPORT(msh_get_ygrid) void msh_get_ygrid(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_ygrid._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_ygrid._data[i];
}
EXPORT(msh_get_zgrid_size) int msh_get_zgrid_size(void *p) {
  return (int)((jigsaw_msh_t *)p)->_zgrid._size;
}
EXPORT(msh_get_zgrid) void msh_get_zgrid(void *p, double *out) {
  jigsaw_msh_t *M = (jigsaw_msh_t *)p;
  int n = (int)M->_zgrid._size;
  for (int i = 0; i < n; i++) out[i] = (double)M->_zgrid._data[i];
}

// ── jigsaw_jig_t ────────────────────────────────────────────────────────────

EXPORT(jig_create) void *jig_create(void) {
  jigsaw_jig_t *j = (jigsaw_jig_t *)std::calloc(1, sizeof(jigsaw_jig_t));
  jigsaw_init_jig_t(j);
  return j;
}
EXPORT(jig_destroy) void jig_destroy(void *p) { std::free(p); }

EXPORT(jig_set_int) void jig_set_int(void *p, const char *key, int v) {
  jigsaw_jig_t *j = (jigsaw_jig_t *)p;
  if (!std::strcmp(key, "verbosity")) j->_verbosity = v;
  else if (!std::strcmp(key, "geom_seed")) j->_geom_seed = v;
  else if (!std::strcmp(key, "geom_feat")) j->_geom_feat = v;
  else if (!std::strcmp(key, "hfun_scal")) j->_hfun_scal = v;
  else if (!std::strcmp(key, "bnds_kern")) j->_bnds_kern = v;
  else if (!std::strcmp(key, "mesh_dims")) j->_mesh_dims = v;
  else if (!std::strcmp(key, "mesh_kern")) j->_mesh_kern = v;
  else if (!std::strcmp(key, "mesh_iter")) j->_mesh_iter = v;
  else if (!std::strcmp(key, "mesh_top1")) j->_mesh_top1 = v;
  else if (!std::strcmp(key, "mesh_top2")) j->_mesh_top2 = v;
  else if (!std::strcmp(key, "optm_kern")) j->_optm_kern = v;
  else if (!std::strcmp(key, "optm_iter")) j->_optm_iter = v;
  else if (!std::strcmp(key, "optm_tria")) j->_optm_tria = v;
  else if (!std::strcmp(key, "optm_dual")) j->_optm_dual = v;
  else if (!std::strcmp(key, "optm_zip_")) j->_optm_zip_ = v;
  else if (!std::strcmp(key, "optm_div_")) j->_optm_div_ = v;
}

EXPORT(jig_set_real) void jig_set_real(void *p, const char *key, double v) {
  jigsaw_jig_t *j = (jigsaw_jig_t *)p;
  if (!std::strcmp(key, "geom_eta1")) j->_geom_eta1 = v;
  else if (!std::strcmp(key, "geom_eta2")) j->_geom_eta2 = v;
  else if (!std::strcmp(key, "init_near")) j->_init_near = v;
  else if (!std::strcmp(key, "hfun_hmax")) j->_hfun_hmax = v;
  else if (!std::strcmp(key, "hfun_hmin")) j->_hfun_hmin = v;
  else if (!std::strcmp(key, "mesh_rad2")) j->_mesh_rad2 = v;
  else if (!std::strcmp(key, "mesh_rad3")) j->_mesh_rad3 = v;
  else if (!std::strcmp(key, "mesh_siz1")) j->_mesh_siz1 = v;
  else if (!std::strcmp(key, "mesh_siz2")) j->_mesh_siz2 = v;
  else if (!std::strcmp(key, "mesh_siz3")) j->_mesh_siz3 = v;
  else if (!std::strcmp(key, "mesh_eps1")) j->_mesh_eps1 = v;
  else if (!std::strcmp(key, "mesh_eps2")) j->_mesh_eps2 = v;
  else if (!std::strcmp(key, "mesh_off2")) j->_mesh_off2 = v;
  else if (!std::strcmp(key, "mesh_off3")) j->_mesh_off3 = v;
  else if (!std::strcmp(key, "mesh_snk2")) j->_mesh_snk2 = v;
  else if (!std::strcmp(key, "mesh_snk3")) j->_mesh_snk3 = v;
  else if (!std::strcmp(key, "mesh_vol3")) j->_mesh_vol3 = v;
  else if (!std::strcmp(key, "optm_qtol")) j->_optm_qtol = v;
  else if (!std::strcmp(key, "optm_qlim")) j->_optm_qlim = v;
}

// ── run JIGSAW / TRIPOD / MARCHE ────────────────────────────────────────────

EXPORT(run_jigsaw) int run_jigsaw(void *jcfg, void *geom, void *init, void *hfun,
                                  void *mesh) {
  g_error.clear();
  indx_t rc = jigsaw((jigsaw_jig_t *)jcfg, (jigsaw_msh_t *)geom,
                     (jigsaw_msh_t *)init, (jigsaw_msh_t *)hfun,
                     (jigsaw_msh_t *)mesh);
  if (rc != JIGSAW_NO_ERROR)
    g_error = "jigsaw returned error code " + std::to_string((int)rc);
  return (int)rc;
}

EXPORT(run_tripod) int run_tripod(void *jcfg, void *init, void *geom,
                                  void *mesh) {
  g_error.clear();
  indx_t rc = tripod((jigsaw_jig_t *)jcfg, (jigsaw_msh_t *)init,
                     (jigsaw_msh_t *)geom, (jigsaw_msh_t *)mesh);
  if (rc != JIGSAW_NO_ERROR)
    g_error = "tripod returned error code " + std::to_string((int)rc);
  return (int)rc;
}

EXPORT(run_marche) int run_marche(void *jcfg, void *ffun) {
  g_error.clear();
  indx_t rc = marche((jigsaw_jig_t *)jcfg, (jigsaw_msh_t *)ffun);
  if (rc != JIGSAW_NO_ERROR)
    g_error = "marche returned error code " + std::to_string((int)rc);
  return (int)rc;
}

} // extern "C"
