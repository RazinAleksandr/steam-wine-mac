#!/bin/bash
# Builds the dwmapi.dll shim. usage: build.sh <wine/lib/wine/x86_64-windows> <out-dir>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WINELIB="$1"; OUT="$2"
command -v zig >/dev/null || { echo "zig is required: brew install zig" >&2; exit 1; }
mkdir -p "$OUT"
# Every named export of the real dwmapi becomes a forwarder to dwmapi_orig
python3 -I - "$WINELIB/dwmapi.dll" > "$OUT/dwmapi.def" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
pe = struct.unpack_from("<I", d, 0x3C)[0]
nsec, optsz = struct.unpack_from("<H", d, pe + 6)[0], struct.unpack_from("<H", d, pe + 20)[0]
opt = pe + 24
secs = [struct.unpack_from("<IIII", d, opt + optsz + 40 * i + 8) for i in range(nsec)]
def off(rva):
    for vs, va, rs, ra in secs:
        if va <= rva < va + max(vs, rs): return rva - va + ra
    raise SystemExit("bad rva")
exp = off(struct.unpack_from("<I", d, opt + 112)[0])
nnames, names = struct.unpack_from("<I", d, exp + 24)[0], off(struct.unpack_from("<I", d, exp + 32)[0])
print("LIBRARY dwmapi\nEXPORTS")
for i in range(nnames):
    o = off(struct.unpack_from("<I", d, names + 4 * i)[0])
    n = d[o:d.index(b"\0", o)].decode()
    print(f"  {n} = dwmapi_orig.{n}")
PY
zig cc -target x86_64-windows-gnu -O2 -shared \
  -o "$OUT/dwmapi.dll" "$HERE/shim.c" "$OUT/dwmapi.def"
rm -f "$OUT"/dwmapi.lib "$OUT"/dwmapi.pdb
echo "ok: $OUT/dwmapi.dll"
