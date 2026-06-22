// native: fmm2d
// wasm: fmm2d
//
// Single-builtin replacement for the upstream fmm2d MEX file.
//
// The upstream `matlab/rfmm2d.m`, `cfmm2d.m`, `lfmm2d.m`, `hfmm2d.m`,
// and `stfmm2d.m` all dispatch through `fmm2d(mex_id_, ...args)` where
// `mex_id_` is the mwrap-generated stub signature string.  This builtin
// marshals each runtime arg into a shim mxArray, calls our wasm/native
// `mex_dispatch` (which forwards to the original mexFunction inside
// fmm2d.c), and decodes the resulting plhs[] back into runtime values.
//
// fmm2d's stubs are stateless (no plan/setpts/destroy lifecycle like
// finufft), so input mxArrays can be freed immediately after each call.

register({
  resolve: function (argTypes, nargout) {
    if (argTypes.length < 1) return null;
    var outs = [];
    var n = nargout > 0 ? nargout : 0;
    for (var i = 0; i < n; i++) outs.push({ kind: "unknown" });
    return {
      outputTypes: outs,
      apply: function (args, nargout) {
        return callFmm2d(args, nargout);
      },
    };
  },
});

// ── runtime-value helpers ──────────────────────────────────────────────────

function isTensor(v) {
  return v && typeof v === "object" && v.kind === "tensor";
}
function isChar(v) {
  return v && typeof v === "object" && v.kind === "char";
}
function isStruct(v) {
  return v && typeof v === "object" && v.kind === "struct";
}
function isClassInstance(v) {
  return v && typeof v === "object" && v.kind === "class_instance";
}
function isComplexNumber(v) {
  return v && typeof v === "object" && v.kind === "complex_number";
}

// MATLAB-style m and n for an mxArray reflecting the runtime tensor.
// Numbl tensors keep at least 2D shape; we collapse trailing singletons
// the same way mwrap does (m * n must equal numel).
function tensorMxDims(t) {
  var s = t.shape;
  var m = s[0] | 0;
  var n = 1;
  for (var i = 1; i < s.length; i++) n *= s[i];
  return { m: m, n: n };
}

// ── mxArray construction (delegates to bridge for the buffer transport) ───

function buildMxArray(bridge, v) {
  if (typeof v === "number") {
    return bridge.makeDoubleScalar(v);
  }
  if (typeof v === "boolean") {
    return bridge.makeDoubleScalar(v ? 1 : 0);
  }
  if (typeof v === "string") {
    return bridge.makeString(v);
  }
  if (isChar(v)) {
    return bridge.makeString(v.value || "");
  }
  if (isComplexNumber(v)) {
    var rer = new Float64Array(1);
    var imr = new Float64Array(1);
    rer[0] = v.re;
    imr[0] = v.im;
    return bridge.makeComplexMatrix(1, 1, rer, imr);
  }
  if (isTensor(v)) {
    var dims = tensorMxDims(v);
    var n = dims.m * dims.n;
    if (v.imag) {
      var re = n === v.data.length ? v.data : v.data.subarray(0, n);
      var im = n === v.imag.length ? v.imag : v.imag.subarray(0, n);
      return bridge.makeComplexMatrix(dims.m, dims.n,
                                      asFloat64(re), asFloat64(im));
    }
    var data = n === v.data.length ? v.data : v.data.subarray(0, n);
    return bridge.makeRealMatrix(dims.m, dims.n, asFloat64(data));
  }
  if (isStruct(v)) {
    var keys = [];
    var values = [];
    v.fields.forEach(function (val, key) {
      keys.push(key);
      values.push(val);
    });
    var s = bridge.makeStruct(keys.length);
    for (var i = 0; i < keys.length; i++) {
      var sub = buildMxArray(bridge, values[i]);
      bridge.structSetField(s, i, keys[i], sub);
    }
    return s;
  }
  if (isClassInstance(v)) {
    var mw = v.fields.get("mwptr");
    if (mw === undefined) {
      throw new RuntimeError("fmm2d: class instance has no mwptr field");
    }
    return buildMxArray(bridge, mw);
  }
  throw new RuntimeError("fmm2d: unsupported argument type " + (v && v.kind));
}

function asFloat64(arr) {
  if (arr instanceof Float64Array) return arr;
  return new Float64Array(arr);
}

// ── mxArray decoding back to runtime values ───────────────────────────────

function decodeMxArray(bridge, mx) {
  var classID = bridge.getClassID(mx);
  var m = bridge.getM(mx);
  var n = bridge.getN(mx);
  var isCpx = bridge.getIsComplex(mx);

  // mxClassID values match the enum in mex_shim/mex.h
  var MX_CHAR_CLASS = 4;
  var MX_DOUBLE_CLASS = 6;

  if (classID === MX_CHAR_CLASS) {
    return RTV.char(bridge.readString(mx));
  }
  if (classID === MX_DOUBLE_CLASS) {
    var total = m * n;
    if (total === 1 && !isCpx) {
      return RTV.num(bridge.readDoubleScalar(mx));
    }
    if (isCpx) {
      var re = new Float64Array(total);
      var im = new Float64Array(total);
      bridge.readComplex(mx, total, re, im);
      return RTV.tensor(re, [m, n], im);
    }
    var data = new Float64Array(total);
    bridge.readReal(mx, total, data);
    return RTV.tensor(data, [m, n]);
  }
  throw new RuntimeError("fmm2d: unsupported output mxArray classID " + classID);
}

// ── wasm bridge ────────────────────────────────────────────────────────────

function makeWasmBridge() {
  var exports = wasm.exports;

  function memView64() {
    return new Float64Array(exports.memory.buffer);
  }
  function mem8() {
    return new Uint8Array(exports.memory.buffer);
  }

  function copyDoublesIn(arr, n) {
    if (!arr || n === 0) return 0;
    var ptr = exports.my_malloc(n * 8);
    memView64().set(arr.subarray(0, n), ptr / 8);
    return ptr;
  }

  function copyStringIn(s) {
    var bytes = new TextEncoder().encode(s + "\0");
    var ptr = exports.my_malloc(bytes.length);
    mem8().set(bytes, ptr);
    return ptr;
  }

  function readDoublesOut(ptr, n) {
    if (n === 0) return new Float64Array(0);
    var view = memView64();
    return new Float64Array(view.subarray(ptr / 8, ptr / 8 + n));
  }

  function readStringFromBuf(ptr, len) {
    var bytes = mem8().subarray(ptr, ptr + len);
    return new TextDecoder().decode(bytes);
  }

  return {
    makeDoubleScalar: function (v) {
      return exports.mex_make_double_scalar(v);
    },
    makeRealMatrix: function (m, n, data) {
      var ptr = copyDoublesIn(data, m * n);
      var mx = exports.mex_make_real_matrix(m, n, ptr);
      if (ptr) exports.my_free(ptr);
      return mx;
    },
    makeComplexMatrix: function (m, n, re, im) {
      var rePtr = copyDoublesIn(re, m * n);
      var imPtr = copyDoublesIn(im, m * n);
      var mx = exports.mex_make_complex_matrix(m, n, rePtr, imPtr);
      if (rePtr) exports.my_free(rePtr);
      if (imPtr) exports.my_free(imPtr);
      return mx;
    },
    makeString: function (s) {
      var ptr = copyStringIn(s);
      var mx = exports.mex_make_string(ptr);
      exports.my_free(ptr);
      return mx;
    },
    makeStruct: function (nfields) {
      return exports.mex_make_struct(nfields);
    },
    structSetField: function (s, idx, name, value) {
      var ptr = copyStringIn(name);
      exports.mex_struct_set_field(s, idx, ptr, value);
      exports.my_free(ptr);
    },

    getClassID: function (mx) { return exports.mex_get_classid(mx); },
    getM: function (mx) { return exports.mex_get_m(mx); },
    getN: function (mx) { return exports.mex_get_n(mx); },
    getIsComplex: function (mx) { return exports.mex_get_is_complex(mx); },

    readDoubleScalar: function (mx) {
      return exports.mex_read_double_scalar(mx);
    },
    readReal: function (mx, n, out) {
      var ptr = exports.my_malloc(n * 8);
      exports.mex_read_real(mx, ptr);
      var data = readDoublesOut(ptr, n);
      out.set(data);
      exports.my_free(ptr);
    },
    readComplex: function (mx, n, outRe, outIm) {
      var rePtr = exports.my_malloc(n * 8);
      var imPtr = exports.my_malloc(n * 8);
      exports.mex_read_complex(mx, rePtr, imPtr);
      outRe.set(readDoublesOut(rePtr, n));
      outIm.set(readDoublesOut(imPtr, n));
      exports.my_free(rePtr);
      exports.my_free(imPtr);
    },
    readString: function (mx) {
      var bufLen = exports.mex_get_m(mx) * exports.mex_get_n(mx) + 1;
      var ptr = exports.my_malloc(bufLen);
      var len = exports.mex_read_string(mx, ptr, bufLen);
      var s = readStringFromBuf(ptr, len);
      exports.my_free(ptr);
      return s;
    },

    allocArgs: function (n) { return exports.mex_alloc_args(n); },
    setArg: function (arr, idx, mx) { exports.mex_set_arg(arr, idx, mx); },
    getArg: function (arr, idx) { return exports.mex_get_arg(arr, idx); },
    freeArgs: function (arr) { exports.mex_free_args(arr); },
    freeArray: function (mx) { if (mx) exports.mex_free_array(mx); },
    dispatch: function (nlhs, plhs, nrhs, prhs) {
      return exports.mex_dispatch(nlhs, plhs, nrhs, prhs);
    },
    getError: function () {
      var ptr = exports.mex_get_error();
      var bytes = mem8();
      var end = ptr;
      while (bytes[end] !== 0 && end - ptr < 4096) end++;
      return new TextDecoder().decode(bytes.subarray(ptr, end));
    },
  };
}

// ── native (koffi) bridge ──────────────────────────────────────────────────

var nativeFns = null;

function getNativeFns() {
  if (nativeFns) return nativeFns;
  var lib = native;
  nativeFns = {
    mex_make_double_scalar: lib.func("void *mex_make_double_scalar(double v)"),
    mex_make_real_matrix:   lib.func("void *mex_make_real_matrix(int m, int n, double *data)"),
    mex_make_complex_matrix:lib.func("void *mex_make_complex_matrix(int m, int n, double *re, double *im)"),
    mex_make_string:        lib.func("void *mex_make_string(const char *s)"),
    mex_make_struct:        lib.func("void *mex_make_struct(int n)"),
    mex_struct_set_field:   lib.func("void mex_struct_set_field(void *s, int idx, const char *name, void *val)"),
    mex_get_classid:        lib.func("int mex_get_classid(void *a)"),
    mex_get_m:              lib.func("int mex_get_m(void *a)"),
    mex_get_n:              lib.func("int mex_get_n(void *a)"),
    mex_get_is_complex:     lib.func("int mex_get_is_complex(void *a)"),
    mex_read_double_scalar: lib.func("double mex_read_double_scalar(void *a)"),
    mex_read_real:          lib.func("void mex_read_real(void *a, _Out_ double *out)"),
    mex_read_complex:       lib.func("void mex_read_complex(void *a, _Out_ double *out_re, _Out_ double *out_im)"),
    mex_read_string:        lib.func("int mex_read_string(void *a, _Out_ char *out, int buflen)"),
    mex_alloc_args:         lib.func("void **mex_alloc_args(int n)"),
    mex_set_arg:            lib.func("void mex_set_arg(void **arr, int idx, void *val)"),
    mex_get_arg:            lib.func("void *mex_get_arg(void **arr, int idx)"),
    mex_free_args:          lib.func("void mex_free_args(void **arr)"),
    mex_free_array:         lib.func("void mex_free_array(void *a)"),
    mex_dispatch:           lib.func("int mex_dispatch(int nlhs, void **plhs, int nrhs, void **prhs)"),
    mex_get_error:          lib.func("const char *mex_get_error()"),
  };
  return nativeFns;
}

function makeNativeBridge() {
  var fns = getNativeFns();
  return {
    makeDoubleScalar: function (v) { return fns.mex_make_double_scalar(v); },
    makeRealMatrix: function (m, n, data) {
      return fns.mex_make_real_matrix(m, n, m * n > 0 ? data : null);
    },
    makeComplexMatrix: function (m, n, re, im) {
      return fns.mex_make_complex_matrix(m, n,
                                         m * n > 0 ? re : null,
                                         m * n > 0 ? im : null);
    },
    makeString: function (s) { return fns.mex_make_string(s); },
    makeStruct: function (nfields) { return fns.mex_make_struct(nfields); },
    structSetField: function (s, idx, name, value) {
      fns.mex_struct_set_field(s, idx, name, value);
    },

    getClassID: function (mx) { return fns.mex_get_classid(mx); },
    getM: function (mx) { return fns.mex_get_m(mx); },
    getN: function (mx) { return fns.mex_get_n(mx); },
    getIsComplex: function (mx) { return fns.mex_get_is_complex(mx); },

    readDoubleScalar: function (mx) { return fns.mex_read_double_scalar(mx); },
    readReal: function (mx, n, out) {
      var buf = out instanceof Float64Array ? out : new Float64Array(n);
      fns.mex_read_real(mx, buf);
      if (buf !== out) out.set(buf);
    },
    readComplex: function (mx, n, outRe, outIm) {
      var bufR = outRe instanceof Float64Array ? outRe : new Float64Array(n);
      var bufI = outIm instanceof Float64Array ? outIm : new Float64Array(n);
      fns.mex_read_complex(mx, bufR, bufI);
      if (bufR !== outRe) outRe.set(bufR);
      if (bufI !== outIm) outIm.set(bufI);
    },
    readString: function (mx) {
      var len = fns.mex_get_m(mx) * fns.mex_get_n(mx);
      var buf = new Uint8Array(len + 1);
      fns.mex_read_string(mx, buf, buf.length);
      var end = 0;
      while (end < len && buf[end] !== 0) end++;
      return new TextDecoder().decode(buf.subarray(0, end));
    },

    allocArgs: function (n) { return fns.mex_alloc_args(n); },
    setArg: function (arr, idx, mx) { fns.mex_set_arg(arr, idx, mx); },
    getArg: function (arr, idx) { return fns.mex_get_arg(arr, idx); },
    freeArgs: function (arr) { fns.mex_free_args(arr); },
    freeArray: function (mx) { if (mx) fns.mex_free_array(mx); },
    dispatch: function (nlhs, plhs, nrhs, prhs) {
      return fns.mex_dispatch(nlhs, plhs, nrhs, prhs);
    },
    getError: function () { return fns.mex_get_error(); },
  };
}

// ── main entry ─────────────────────────────────────────────────────────────

var cachedBridge = null;

function getBridge() {
  if (cachedBridge) return cachedBridge;
  cachedBridge = native ? makeNativeBridge() : makeWasmBridge();
  return cachedBridge;
}

function callFmm2d(args, nargout) {
  var bridge = getBridge();

  var nrhs = args.length;
  var nlhs = Math.max(nargout | 0, 0);

  // mwrap-generated stubs unconditionally fill all of their declared
  // outputs (no nlhs check).  rfmm2d_ndiv writes 8 plhs slots, so we
  // need at least that many.  Allocate a generous fixed cap.
  var plhsSlots = nlhs > 16 ? nlhs : 16;

  var prhs = bridge.allocArgs(nrhs);
  var plhs = bridge.allocArgs(plhsSlots);
  var ownedInputs = new Array(nrhs);

  try {
    for (var i = 0; i < nrhs; i++) {
      var mx = buildMxArray(bridge, args[i]);
      ownedInputs[i] = mx;
      bridge.setArg(prhs, i, mx);
    }

    var rc = bridge.dispatch(plhsSlots, plhs, nrhs, prhs);
    if (rc !== 0) {
      throw new RuntimeError("fmm2d: " + bridge.getError());
    }

    if (nlhs === 0) {
      // Free any plhs slots the stub may have written to.
      for (var k0 = 0; k0 < plhsSlots; k0++) {
        var ex0 = bridge.getArg(plhs, k0);
        if (ex0) bridge.freeArray(ex0);
      }
      return;
    }
    if (nlhs === 1) {
      var out0 = bridge.getArg(plhs, 0);
      var v = decodeMxArray(bridge, out0);
      bridge.freeArray(out0);
      // Free extras the stub may have written.
      for (var k1 = 1; k1 < plhsSlots; k1++) {
        var ex1 = bridge.getArg(plhs, k1);
        if (ex1) bridge.freeArray(ex1);
      }
      return v;
    }
    var results = [];
    for (var k = 0; k < nlhs; k++) {
      var mxOut = bridge.getArg(plhs, k);
      results.push(decodeMxArray(bridge, mxOut));
      bridge.freeArray(mxOut);
    }
    for (var k2 = nlhs; k2 < plhsSlots; k2++) {
      var mxExtra = bridge.getArg(plhs, k2);
      if (mxExtra) bridge.freeArray(mxExtra);
    }
    return results;
  } finally {
    for (var j = 0; j < nrhs; j++) bridge.freeArray(ownedInputs[j]);
    bridge.freeArgs(prhs);
    bridge.freeArgs(plhs);
  }
}
