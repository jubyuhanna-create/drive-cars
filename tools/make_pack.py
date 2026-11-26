#!/usr/bin/env python3
"""Build a carpack-2 file (ZIP) from a render folder.

render folder: home_off.webp, home_on.webp, spin/<row>_<index>.webp
usage: make_pack.py RENDER_DIR CODE --brand SKODA --model SUPERB --year 2020 \
         --color graphite --color-name Graphite --hex #3b4047 --rows 3,10,24 --n 72 --start 1,9
writes c/<CODE>.carpack next to this tools folder
"""
import argparse, json, os, re, zipfile

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("code")
ap.add_argument("--brand", required=True); ap.add_argument("--model", required=True); ap.add_argument("--year", default="")
ap.add_argument("--color", required=True); ap.add_argument("--color-name", default=""); ap.add_argument("--hex", required=True)
ap.add_argument("--rows", default="3,10,24"); ap.add_argument("--n", type=int, default=72); ap.add_argument("--start", default="1,9")
ap.add_argument("--w", type=int, default=1024); ap.add_argument("--h", type=int, default=576)
a = ap.parse_args()

code = re.sub(r"[^A-Z0-9]", "", a.code.upper())
assert 4 <= len(code) <= 10, "code must be 4-10 letters/digits"
rows = [float(x) for x in a.rows.split(",")]
start = [int(x) for x in a.start.split(",")]
meta = {
    "format": "carpack-2",
    "id": re.sub(r"[^a-z0-9]+", "-", a.model.lower()).strip("-") + "-" + code.lower(),
    "brand": a.brand, "model": a.model, "year": a.year,
    "color": {"k": a.color, "n": a.color_name or a.color, "hex": a.hex},
    "spin": {"n": a.n, "rows": rows, "w": a.w, "h": a.h, "start": start},
    "rev": 1,
}
missing = [f"{r}_{i:02d}" for r in range(len(rows)) for i in range(a.n) if not os.path.exists(f"{a.src}/spin/{r}_{i:02d}.webp")]
assert not missing, f"missing frames: {missing[:5]}..."

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "c")
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, code + ".carpack")
with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
    z.writestr("meta.json", json.dumps(meta, ensure_ascii=False))
    z.write(f"{a.src}/home_off.webp", f"{a.color}_off.webp")
    z.write(f"{a.src}/home_on.webp", f"{a.color}_on.webp")
    for r in range(len(rows)):
        for i in range(a.n):
            # the app reads spin/<row>_<index>.webp with a plain index (no leading zero)
            z.write(f"{a.src}/spin/{r}_{i:02d}.webp", f"spin/{r}_{i}.webp")
print(out, os.path.getsize(out), "bytes")
