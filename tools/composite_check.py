"""Stack app layers the way the app will and compare the result with a full beauty render.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/composite_check.py -- \\
        --layers build/renders/cakestand/stage5/layers --stack base_static plate_station cloche \\
        --beauty beauty_station.png [--background 0.055]

Reads manifest.json in --layers for each layer's file and blend mode ("normal": straight-alpha
over; "plusLighter": add colour x alpha). Both sides are composited over the app's background
grey (Palette.ground by default), so differences in alpha count too. Prints the mean and
99th-percentile absolute error (0..1, per channel) and writes composite.png and diff.png
(error x 8) next to the layers.
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts", "blender"))
import common as C  # noqa: E402
import imaging as I  # noqa: E402


def stack(layers_dir, names, manifest, background):
    entries = {e["name"]: e for e in manifest["layers"]}
    ordered = sorted(names, key=lambda n: entries[n]["z"])
    out = None
    for name in ordered:
        e = entries[name]
        src = I.load(os.path.join(layers_dir, e["file"]))
        if out is None:
            out = np.zeros_like(src)
            out[..., :3] = background
            out[..., 3] = 1
        a = src[..., 3:4]
        if e["blend"] == "plusLighter":
            out[..., :3] = np.clip(out[..., :3] + src[..., :3] * a, 0, 1)
        else:
            out[..., :3] = src[..., :3] * a + out[..., :3] * (1 - a)
    return out, ordered


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layers", required=True)
    parser.add_argument("--stack", nargs="+", required=True)
    parser.add_argument("--beauty", required=True)
    parser.add_argument("--background", type=float, default=0.055)
    args = C.script_args(parser)
    with open(os.path.join(args.layers, "manifest.json")) as f:
        manifest = json.load(f)
    comp, order = stack(args.layers, args.stack, manifest, args.background)
    beauty = I.over_background(I.load(os.path.join(args.layers, args.beauty)), args.background)
    err = np.abs(comp[..., :3] - beauty[..., :3])
    report = {"stack": order, "beauty": args.beauty, "mean_error": round(float(err.mean()), 5),
              "p99_error": round(float(np.percentile(err, 99)), 4), "max_error": round(float(err.max()), 4),
              "pixels_over_5pct": round(float((err.max(axis=2) > 0.05).mean()), 5)}
    I.save(comp, os.path.join(args.layers, "composite.png"))
    diff = np.ones_like(comp)
    diff[..., :3] = np.clip(err * 8, 0, 1)
    I.save(diff, os.path.join(args.layers, "diff.png"))
    with open(os.path.join(args.layers, "composite_check.json"), "w") as f:
        json.dump(report, f, indent=2)
    print("[composite_check] " + json.dumps(report))


if __name__ == "__main__":
    main()
