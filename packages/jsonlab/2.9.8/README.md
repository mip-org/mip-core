# jsonlab

[JSONLab](https://neurojson.org/) is an encoder/decoder for JSON, binary JSON (BJData/UBJSON), and MessagePack in MATLAB/Octave, and a feature-complete implementation of the [JData](https://neurojson.org) specification. It also bundles readers/writers for related scientific formats (NIfTI/JNIfTI, HDF5, BIDS TSV) and JSONPath querying.

- **Author**: Qianqian Fang and contributors (NeuroJSON)
- **License**: BSD-3-Clause (dual-licensed BSD/GPLv3 upstream)
- **Version**: `2.9.8`
- **Repository**: https://github.com/NeuroJSON/jsonlab

## Install

```matlab
mip install jsonlab
mip load jsonlab
```

Usage:

```matlab
str  = savejson('', data);     % MATLAB -> JSON text
data = loadjson(str);          % JSON text -> MATLAB
bin  = savebj('', data);       % MATLAB -> binary JSON (BJData)
data = loadbj(bin);
```

## Architecture

Pure MATLAB — a single `[any]` build, no compiled code. Core JSON/BJData encoding and zlib/gzip compression work out of the box; some advanced codecs (LZ4/Zstd/Blosc2) optionally use the external ZMat toolbox if it is installed.

## Tests

`test_jsonlab_channel.m` round-trips a nested MATLAB structure (numeric arrays, strings, nested structs, cells) through both text JSON and binary JSON and verifies the data is preserved.
