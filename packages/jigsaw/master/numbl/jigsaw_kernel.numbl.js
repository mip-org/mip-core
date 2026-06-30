// wasm: jigsaw
//
// numbl_wasm kernel for JIGSAW.
//
// The upstream jigsaw.m / tripod.m / marche.m drive standalone executables over
// files via system(). numbl supports neither, so the numbl overrides of those
// .m files (numbl/jigsaw.m, etc.) read the input .msh files with loadmsh, then
// call this single builtin to do the actual meshing in WASM, then write the
// result with savemsh. This builtin owns the bridge between numbl mesh structs
// and JIGSAW's in-memory C library (jigsaw.wasm, the lib_jigsaw API).
//
// Call shape (from the .m overrides):
//   mesh = jigsaw_kernel(mode, opts, geom, init, hfun)
//     mode : 'jigsaw' | 'tripod' | 'marche'
//     opts : the OPTS struct (jig options; file-name fields are ignored)
//     geom/init/hfun : mesh structs (as returned by loadmsh) or [] if absent
//   returns the output mesh struct in loadmsh's field layout (1-based indices),
//   so savemsh can write it back unchanged. For 'marche', the returned struct
//   is the gradient-limited copy of hfun.

register({
  resolve: function (argTypes, nargout) {
    if (argTypes.length < 2) return null;
    return {
      outputTypes: [{ kind: "unknown" }],
      apply: function (args) {
        return callJigsaw(args);
      },
    };
  },
});

// ── runtime-value helpers ───────────────────────────────────────────────────

function isTensor(v) {
  return v && typeof v === "object" && v.kind === "tensor";
}
function isChar(v) {
  return v && typeof v === "object" && v.kind === "char";
}
function isStruct(v) {
  return v && typeof v === "object" && v.kind === "struct";
}
function isCell(v) {
  return v && typeof v === "object" && v.kind === "cell";
}

// A numbl `[]` arrives as an empty tensor; treat as "argument not supplied".
function isAbsent(v) {
  if (v === undefined || v === null) return true;
  if (isTensor(v)) {
    var n = 1;
    for (var i = 0; i < v.shape.length; i++) n *= v.shape[i];
    return n === 0;
  }
  return false;
}

function asString(v) {
  if (typeof v === "string") return v;
  if (isChar(v)) return v.value || "";
  return null;
}

function asNumber(v) {
  if (typeof v === "number") return v;
  if (typeof v === "boolean") return v ? 1 : 0;
  if (isTensor(v) && v.data.length >= 1) return v.data[0];
  return NaN;
}

// Field of a struct runtime value, or undefined.
function field(s, name) {
  if (!isStruct(s)) return undefined;
  return s.fields.get(name);
}

// [m, n] of a 2-D tensor (collapsing trailing dims into n).
function tensorMN(t) {
  var s = t.shape;
  var m = s[0] | 0;
  var n = 1;
  for (var i = 1; i < s.length; i++) n *= s[i];
  return { m: m, n: n };
}

// ── JIGSAW constants (jigsaw_const.h) ───────────────────────────────────────

var FLAG_BY_ID = {
  "EUCLIDEAN-MESH": 100,
  "EUCLIDEAN-GRID": 101,
  "EUCLIDEAN-DUAL": 102,
  "ELLIPSOID-MESH": 200,
  "ELLIPSOID-GRID": 201,
  "ELLIPSOID-DUAL": 202,
};
var ID_BY_FLAG = {
  100: "EUCLIDEAN-MESH",
  101: "EUCLIDEAN-GRID",
  102: "EUCLIDEAN-DUAL",
  200: "ELLIPSOID-MESH",
  201: "ELLIPSOID-GRID",
  202: "ELLIPSOID-DUAL",
};
function isGridFlag(f) {
  return f === 101 || f === 201;
}

// String-valued options -> jig_t enum ints.
var MESH_KERN = { delfront: 400, delaunay: 401, bisector: 402 };
var OPTM_KERN = { "odt+dqdx": 404, "cvt+dqdx": 405, "h95+dqdx": 406 };
var HFUN_SCAL = { relative: 300, absolute: 301 };
var BNDS_KERN = { "bnd-tria": 402, "bnd-dual": 403 };

// opts field -> jig_t setter classification.
var JIG_INT = ["verbosity", "geom_seed", "mesh_iter", "mesh_dims", "optm_iter"];
var JIG_BOOL = [
  "geom_feat", "mesh_top1", "mesh_top2",
  "optm_tria", "optm_dual", "optm_zip_", "optm_div_",
];
var JIG_REAL = [
  "init_near", "geom_eta1", "geom_eta2", "hfun_hmax", "hfun_hmin",
  "mesh_siz1", "mesh_siz2", "mesh_siz3", "mesh_eps1", "mesh_eps2",
  "mesh_rad2", "mesh_rad3", "mesh_off2", "mesh_off3",
  "mesh_snk2", "mesh_snk3", "mesh_vol3", "optm_qtol", "optm_qlim",
];

// ── wasm bridge ─────────────────────────────────────────────────────────────

function makeBridge() {
  var ex = wasm.exports;

  // ALLOW_MEMORY_GROWTH may detach the buffer, so re-derive views on demand.
  function f64() {
    return new Float64Array(ex.memory.buffer);
  }
  function u8() {
    return new Uint8Array(ex.memory.buffer);
  }

  // Copy a JS array of doubles into freshly malloc'd linear memory.
  function pushDoubles(arr) {
    var n = arr.length;
    if (n === 0) return 0;
    var ptr = ex.my_malloc(n * 8);
    f64().set(arr.length === n ? arr : arr.subarray(0, n), ptr / 8);
    return ptr;
  }
  function pushString(s) {
    var bytes = new TextEncoder().encode(s + "\0");
    var ptr = ex.my_malloc(bytes.length);
    u8().set(bytes, ptr);
    return ptr;
  }
  function readDoubles(ptr, n) {
    return new Float64Array(f64().subarray(ptr / 8, ptr / 8 + n));
  }

  return {
    exports: ex,
    f64: f64,
    pushDoubles: pushDoubles,
    pushString: pushString,
    readDoubles: readDoubles,
    malloc: function (n) {
      return ex.my_malloc(n);
    },
    free: function (p) {
      if (p) ex.my_free(p);
    },
    error: function () {
      var ptr = ex.jig_get_error();
      var bytes = u8();
      var end = ptr;
      while (bytes[end] !== 0 && end - ptr < 4096) end++;
      return new TextDecoder().decode(bytes.subarray(ptr, end));
    },
  };
}

// ── jig_t population ────────────────────────────────────────────────────────

function buildJig(bridge, opts) {
  var ex = bridge.exports;
  var jig = ex.jig_create();

  function setInt(key, val) {
    var kp = bridge.pushString(key);
    ex.jig_set_int(jig, kp, val | 0);
    bridge.free(kp);
  }
  function setReal(key, val) {
    var kp = bridge.pushString(key);
    ex.jig_set_real(jig, kp, +val);
    bridge.free(kp);
  }

  if (!isStruct(opts)) return jig;

  var i, key, v;
  for (i = 0; i < JIG_INT.length; i++) {
    key = JIG_INT[i];
    v = field(opts, key);
    if (v !== undefined) setInt(key, asNumber(v));
  }
  for (i = 0; i < JIG_BOOL.length; i++) {
    key = JIG_BOOL[i];
    v = field(opts, key);
    if (v !== undefined) setInt(key, asNumber(v) ? 1 : 0);
  }
  for (i = 0; i < JIG_REAL.length; i++) {
    key = JIG_REAL[i];
    v = field(opts, key);
    if (v !== undefined) setReal(key, asNumber(v));
  }

  // String-valued enum options.
  var s;
  s = asString(field(opts, "mesh_kern"));
  if (s !== null && MESH_KERN[s.toLowerCase()] !== undefined)
    setInt("mesh_kern", MESH_KERN[s.toLowerCase()]);
  s = asString(field(opts, "optm_kern"));
  if (s !== null && OPTM_KERN[s.toLowerCase()] !== undefined)
    setInt("optm_kern", OPTM_KERN[s.toLowerCase()]);
  s = asString(field(opts, "hfun_scal"));
  if (s !== null && HFUN_SCAL[s.toLowerCase()] !== undefined)
    setInt("hfun_scal", HFUN_SCAL[s.toLowerCase()]);
  s = asString(field(opts, "bnds_kern"));
  if (s !== null && BNDS_KERN[s.toLowerCase()] !== undefined)
    setInt("bnds_kern", BNDS_KERN[s.toLowerCase()]);

  return jig;
}

// ── msh_t population (numbl struct -> jigsaw_msh_t) ──────────────────────────

// Set an element array. `idxCols` (1-based) get -1 applied (JIGSAW is 0-based);
// other columns (coords, tags) pass through unchanged.
function setElems(bridge, mptr, fn, tensor, ncols, idxCols) {
  var mn = tensorMN(tensor);
  var m = mn.m;
  if (m === 0) return;
  var src = tensor.data;
  var buf = new Float64Array(m * ncols);
  for (var c = 0; c < ncols; c++) {
    var dec = idxCols.indexOf(c) >= 0 ? 1 : 0;
    for (var r = 0; r < m; r++) buf[c * m + r] = src[c * m + r] - dec;
  }
  var ptr = bridge.pushDoubles(buf);
  bridge.exports[fn](mptr, ptr, m);
  bridge.free(ptr);
}

// value/slope/power are stored per-node, V values per node, in JIGSAW's linear
// (node-major) order. numbl tensors are column-major, so for V>1 we transpose;
// V==1 is already linear. `rows` is the node count.
function nodeMajor(tensor, rows) {
  var data = tensor.data;
  var n = data.length;
  var V = rows > 0 ? n / rows : 1;
  if (V <= 1 || !Number.isInteger(V)) return data;
  var out = new Float64Array(n);
  for (var k = 0; k < rows; k++)
    for (var v = 0; v < V; v++) out[k * V + v] = data[v * rows + k];
  return out;
}

function setReals(bridge, mptr, fn, arr) {
  if (arr.length === 0) return;
  var ptr = bridge.pushDoubles(arr instanceof Float64Array ? arr : new Float64Array(arr));
  bridge.exports[fn](mptr, ptr, arr.length);
  bridge.free(ptr);
}

function buildMsh(bridge, s) {
  var ex = bridge.exports;
  // Absent inputs become an empty msh_t (flags = JIGSAW_NULL_FLAG), exactly
  // what the native CLI passes when a file is not supplied. Never pass NULL —
  // the library dereferences every msh_t argument.
  if (isAbsent(s) || !isStruct(s)) return ex.msh_create();
  var mptr = ex.msh_create();

  var idStr = asString(field(s, "mshID")) || "EUCLIDEAN-MESH";
  var flag = FLAG_BY_ID[idStr.toUpperCase()] || 100;
  ex.msh_set_flags(mptr, flag);

  var point = field(s, "point");
  var nodeRows = 0;

  if (isGridFlag(flag)) {
    // point.coord is a cell {xgrid, ygrid[, zgrid]}.
    var coord = point && field(point, "coord");
    if (isCell(coord)) {
      var gridFns = ["msh_set_xgrid", "msh_set_ygrid", "msh_set_zgrid"];
      var prod = 1;
      for (var gi = 0; gi < coord.data.length && gi < 3; gi++) {
        var g = coord.data[gi];
        if (isTensor(g)) {
          setReals(bridge, mptr, gridFns[gi], g.data);
          prod *= g.data.length;
        }
      }
      nodeRows = prod;
    }
    var radii = field(s, "radii");
    if (isTensor(radii)) setReals(bridge, mptr, "msh_set_radii", radii.data);
  } else {
    // point.coord is [NP x ND+1]; ND+1 = 3 -> vert2, 4 -> vert3.
    var coordT = point && field(point, "coord");
    if (isTensor(coordT)) {
      var cmn = tensorMN(coordT);
      nodeRows = cmn.m;
      if (cmn.n === 3) setElems(bridge, mptr, "msh_set_vert2", coordT, 3, []);
      else if (cmn.n === 4) setElems(bridge, mptr, "msh_set_vert3", coordT, 4, []);
    }
    var power = point && field(point, "power");
    if (isTensor(power)) setReals(bridge, mptr, "msh_set_power", power.data);

    setElemField(bridge, mptr, s, "edge2", "msh_set_edge2", 3, [0, 1]);
    setElemField(bridge, mptr, s, "tria3", "msh_set_tria3", 4, [0, 1, 2]);
    setElemField(bridge, mptr, s, "quad4", "msh_set_quad4", 5, [0, 1, 2, 3]);
    setElemField(bridge, mptr, s, "tria4", "msh_set_tria4", 5, [0, 1, 2, 3]);
    setElemField(bridge, mptr, s, "hexa8", "msh_set_hexa8", 9, [0, 1, 2, 3, 4, 5, 6, 7]);
    setElemField(bridge, mptr, s, "wedg6", "msh_set_wedg6", 7, [0, 1, 2, 3, 4, 5]);
    setElemField(bridge, mptr, s, "pyra5", "msh_set_pyra5", 6, [0, 1, 2, 3, 4]);
    setElemField(bridge, mptr, s, "bound", "msh_set_bound", 3, [1]); // _indx col

    var seeds = field(s, "seeds");
    if (isStruct(seeds)) {
      var sc = field(seeds, "coord");
      if (isTensor(sc)) {
        var smn = tensorMN(sc);
        if (smn.n === 3) setElems(bridge, mptr, "msh_set_seed2", sc, 3, []);
        else if (smn.n === 4) setElems(bridge, mptr, "msh_set_seed3", sc, 4, []);
      }
    }
  }

  // value / slope live on nodes for both mesh and grid forms.
  var value = field(s, "value");
  if (isTensor(value))
    setReals(bridge, mptr, "msh_set_value", nodeMajor(value, nodeRows || tensorMN(value).m));
  var slope = field(s, "slope");
  if (isTensor(slope))
    setReals(bridge, mptr, "msh_set_slope", nodeMajor(slope, nodeRows || tensorMN(slope).m));

  return mptr;
}

// Helper: set an element array from a struct sub-field s.<name>.index.
function setElemField(bridge, mptr, s, name, fn, ncols, idxCols) {
  var sub = field(s, name);
  if (!isStruct(sub)) return;
  var idx = field(sub, "index");
  if (isTensor(idx)) setElems(bridge, mptr, fn, idx, ncols, idxCols);
}

// ── msh_t decode (jigsaw_msh_t -> numbl struct in loadmsh layout) ────────────

// Read an element array; add 1 to `idxCols` to restore 1-based indices.
function getElems(bridge, mptr, sizeFn, getFn, ncols, idxCols) {
  var ex = bridge.exports;
  var m = ex[sizeFn](mptr);
  if (m <= 0) return null;
  var ptr = bridge.malloc(m * ncols * 8);
  ex[getFn](mptr, ptr);
  var raw = bridge.readDoubles(ptr, m * ncols);
  bridge.free(ptr);
  for (var c = 0; c < ncols; c++) {
    if (idxCols.indexOf(c) >= 0)
      for (var r = 0; r < m; r++) raw[c * m + r] += 1;
  }
  return RTV.tensor(raw, [m, ncols]);
}

function getReals(bridge, mptr, sizeFn, getFn) {
  var ex = bridge.exports;
  var n = ex[sizeFn](mptr);
  if (n <= 0) return null;
  var ptr = bridge.malloc(n * 8);
  ex[getFn](mptr, ptr);
  var raw = bridge.readDoubles(ptr, n);
  bridge.free(ptr);
  return raw;
}

function readMesh(bridge, mptr) {
  var ex = bridge.exports;
  var flag = ex.msh_get_flags(mptr);
  var out = {};
  out.mshID = RTV.char(ID_BY_FLAG[flag] || "EUCLIDEAN-MESH");

  if (isGridFlag(flag)) {
    var coords = [];
    var dims = [];
    var names = ["msh_get_xgrid", "msh_get_ygrid", "msh_get_zgrid"];
    var sizes = ["msh_get_xgrid_size", "msh_get_ygrid_size", "msh_get_zgrid_size"];
    for (var gi = 0; gi < 3; gi++) {
      // grid getters are only emitted for x/y/z reals; reuse the reals reader.
      var g = getReals(bridge, mptr, sizes[gi], names[gi]);
      if (g && g.length > 0) {
        coords.push(RTV.tensor(g, [g.length, 1]));
        dims.push(g.length);
      }
    }
    if (coords.length > 0)
      out.point = RTV.struct({ coord: RTV.cell(coords, [coords.length, 1]) });
    var rad = getReals(bridge, mptr, "msh_get_radii_size", "msh_get_radii");
    if (rad) out.radii = RTV.tensor(rad, [rad.length, 1]);
    // value/slope reshape into grid dims (loadmsh stores [ny, nx(, nz)];
    // JIGSAW's linear order is column-major over those dims, == numbl layout).
    var gridShape = function (len) {
      if (dims.length === 3) return [dims[1], dims[0], dims[2]];
      if (dims.length === 2) return [dims[1], dims[0]];
      return [len, 1];
    };
    var gval = getReals(bridge, mptr, "msh_get_value_size", "msh_get_value");
    if (gval) out.value = RTV.tensor(gval, gridShape(gval.length));
    var gslope = getReals(bridge, mptr, "msh_get_slope_size", "msh_get_slope");
    if (gslope) out.slope = RTV.tensor(gslope, gridShape(gslope.length));
    return RTV.struct(out);
  }

  // EUCLIDEAN/ELLIPSOID mesh.
  var v2 = getElems(bridge, mptr, "msh_get_vert2_size", "msh_get_vert2", 3, []);
  var v3 = getElems(bridge, mptr, "msh_get_vert3_size", "msh_get_vert3", 4, []);
  var coordT = v2 || v3;
  if (coordT) {
    var pwr = getReals(bridge, mptr, "msh_get_power_size", "msh_get_power");
    var pstruct = { coord: coordT };
    if (pwr) pstruct.power = RTV.tensor(pwr, [pwr.length, 1]);
    out.point = RTV.struct(pstruct);
  }

  var e2 = getElems(bridge, mptr, "msh_get_edge2_size", "msh_get_edge2", 3, [0, 1]);
  if (e2) out.edge2 = RTV.struct({ index: e2 });
  var t3 = getElems(bridge, mptr, "msh_get_tria3_size", "msh_get_tria3", 4, [0, 1, 2]);
  if (t3) out.tria3 = RTV.struct({ index: t3 });
  var q4 = getElems(bridge, mptr, "msh_get_quad4_size", "msh_get_quad4", 5, [0, 1, 2, 3]);
  if (q4) out.quad4 = RTV.struct({ index: q4 });
  var t4 = getElems(bridge, mptr, "msh_get_tria4_size", "msh_get_tria4", 5, [0, 1, 2, 3]);
  if (t4) out.tria4 = RTV.struct({ index: t4 });
  var h8 = getElems(bridge, mptr, "msh_get_hexa8_size", "msh_get_hexa8", 9, [0, 1, 2, 3, 4, 5, 6, 7]);
  if (h8) out.hexa8 = RTV.struct({ index: h8 });
  var w6 = getElems(bridge, mptr, "msh_get_wedg6_size", "msh_get_wedg6", 7, [0, 1, 2, 3, 4, 5]);
  if (w6) out.wedg6 = RTV.struct({ index: w6 });
  var p5 = getElems(bridge, mptr, "msh_get_pyra5_size", "msh_get_pyra5", 6, [0, 1, 2, 3, 4]);
  if (p5) out.pyra5 = RTV.struct({ index: p5 });
  var bd = getElems(bridge, mptr, "msh_get_bound_size", "msh_get_bound", 3, [1]);
  if (bd) out.bound = RTV.struct({ index: bd });

  var val = getReals(bridge, mptr, "msh_get_value_size", "msh_get_value");
  if (val) out.value = RTV.tensor(val, [val.length, 1]);
  var slp = getReals(bridge, mptr, "msh_get_slope_size", "msh_get_slope");
  if (slp) out.slope = RTV.tensor(slp, [slp.length, 1]);

  return RTV.struct(out);
}

// ── main entry ───────────────────────────────────────────────────────────────

function callJigsaw(args) {
  if (!wasm) {
    throw new RuntimeError("jigsaw: WASM module not loaded");
  }
  var mode = asString(args[0]);
  if (mode === null) throw new RuntimeError("jigsaw: mode must be a string");
  var opts = args[1];
  var geomA = args[2];
  var initA = args[3];
  var hfunA = args[4];

  var bridge = makeBridge();
  var ex = bridge.exports;

  var jig = buildJig(bridge, opts);
  var geom = buildMsh(bridge, geomA);
  var init = buildMsh(bridge, initA);
  var hfun = buildMsh(bridge, hfunA);
  var mesh = ex.msh_create();

  try {
    var rc;
    if (mode === "jigsaw") {
      rc = ex.run_jigsaw(jig, geom, init, hfun, mesh);
    } else if (mode === "tripod") {
      // tripod(jcfg, init, geom, mesh); init is required, geom optional.
      rc = ex.run_tripod(jig, init, geom, mesh);
    } else if (mode === "marche") {
      // marche(jcfg, ffun) limits |dh/dx| in place; ffun arrives as hfun.
      rc = ex.run_marche(jig, hfun);
      if (rc === 0) {
        var resM = readMesh(bridge, hfun);
        return resM;
      }
    } else {
      throw new RuntimeError("jigsaw: unknown mode '" + mode + "'");
    }

    if (rc !== 0) {
      var msg = bridge.error();
      throw new RuntimeError(
        "jigsaw: " + (msg || mode + " failed with code " + rc)
      );
    }
    return readMesh(bridge, mesh);
  } finally {
    if (jig) ex.jig_destroy(jig);
    if (geom) ex.msh_destroy(geom);
    if (init) ex.msh_destroy(init);
    if (hfun) ex.msh_destroy(hfun);
    if (mesh) ex.msh_destroy(mesh);
  }
}
