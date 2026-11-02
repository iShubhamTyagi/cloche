"""Copy the rendered plating station into the app: its layers + a layout file.

    Blender -b -P scripts/blender/station_export.py -- [--lift-every 2]

From build/renders/cakestand/stage5/layers (camera.json "station", the oven's frames camera
slid along the counter, so 1 px is the same size as in the oven frames): base_static,
plate_station, cloche and the lift frames (every Nth, the first and last always kept), all
cropped to one shared box, into Packages/ClocheKit/Sources/Features/Resources/StationRender/
with station_layout.json (crop size, the counter line, the plate top's centre and half-width,
lift values). Generated and gitignored, like OvenRender.
"""
import argparse
import json
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import studio  # noqa: E402
import cakestand as S  # noqa: E402
from layout import STATION  # noqa: E402

SRC = os.path.join(C.BUILD, "renders", "cakestand", "stage5", "layers")
DST = os.path.join(C.REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources", "StationRender")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lift-every", type=int, default=2)
    args = C.script_args(parser)
    with open(os.path.join(SRC, "manifest.json")) as f:
        manifest = json.load(f)
    lift = next(l for l in manifest["layers"] if l["name"] == "cloche_lift")["frames"]
    keep = [fr for i, fr in enumerate(lift) if i % args.lift_every == 0 or i == len(lift) - 1]

    names = {"station_base": "base_static.png", "station_plate": "plate_station.png"}
    images = {k: I.load(os.path.join(SRC, v)) for k, v in names.items()}
    for i, fr in enumerate(keep):
        images[f"station_cloche_{i:02d}"] = I.load(os.path.join(SRC, fr["file"]))
    h, w = next(iter(images.values())).shape[:2]
    alpha = np.max([im[..., 3] for im in images.values()], axis=0)
    ys, xs = np.nonzero(alpha > 0.02)
    pad = 4
    x0, y0 = max(int(xs.min()) - pad, 0), max(int(ys.min()) - pad, 0)
    x1, y1 = min(int(xs.max()) + 1 + pad, w), min(int(ys.max()) + 1 + pad, h)

    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "cakestand.blend"))
    studio.use(station=True)
    cam = studio.camera("station")

    def px(p):
        v = world_to_camera_view(bpy.context.scene, cam, C.Vector(p))
        return [round(v.x * w - x0, 1), round((1 - v.y) * h - y0, 1)]

    top = S.at(z=S.Z_PLATE_TOP)
    centre = px(top)
    edge = px((top[0] + S.PLATE["r"], top[1], top[2]))
    front = px((top[0], top[1] - S.PLATE["r"], top[2]))

    os.makedirs(DST, exist_ok=True)
    for old in os.listdir(DST):
        os.remove(os.path.join(DST, old))
    for name, im in images.items():
        I.save(im[y0:y1, x0:x1], os.path.join(DST, f"{name}.png"))
    layout = {
        "source": "scripts/blender/station_export.py from build/renders/cakestand/stage5/layers (camera.json views.station)",
        "image_size": [x1 - x0, y1 - y0], "pixel_origin": "top-left",
        "counter_y": px((STATION[0], STATION[1], 0.0))[1],
        "plate_top": {"centre": centre, "half_width": round(edge[0] - centre[0], 1),
                      "front_y": front[1]},
        "cloche_frames": [{"name": f"station_cloche_{i:02d}", "lift": fr["lift"]} for i, fr in enumerate(keep)],
    }
    with open(os.path.join(DST, "station_layout.json"), "w") as f:
        json.dump(layout, f, indent=2)
    size = sum(os.path.getsize(os.path.join(DST, f)) for f in os.listdir(DST))
    print(f"[station] {len(images)} images, crop {x1 - x0}x{y1 - y0}, {size / 1e6:.1f} MB -> {os.path.relpath(DST, C.REPO)}")
    print(f"[station] layout {json.dumps({k: v for k, v in layout.items() if k != 'cloche_frames'})}")


if __name__ == "__main__":
    main()
