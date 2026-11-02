"""Copy the rendered oven into the app: door frames + a layout file the Swift side reads.

    Blender -b -P scripts/blender/app_export.py -- [--every 1]

Takes build/renders/stage5/door/door_*.png (camera.json "frames"), crops them all to the
union of their visible pixels, and writes them to
Packages/ClocheKit/Sources/Features/Resources/OvenRender/oven_door_NNN.png with
oven_layout.json: the crop size, the door angle of each frame, and pixel rects (in the cropped
image, top-left origin) for the oven body, the display window, the cavity mouth, the hinge line
and the knob centres, projected through the same camera. That folder is generated and
gitignored; the app falls back to its drawn oven when it is missing.
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
from layout import (CAV_X0, CAV_X1, CAV_Z0, CAV_Z1, DOOR_MAX_ANGLE, DOOR_X0, DOOR_X1, HINGE_Y,  # noqa: E402
                    HINGE_Z)

SRC = os.path.join(C.BUILD, "renders", "stage5", "door")
DST = os.path.join(C.REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources", "OvenRender")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--every", type=int, default=1, help="keep every Nth frame (size budget)")
    args = C.script_args(parser)

    files = sorted(f for f in os.listdir(SRC) if f.startswith("door_") and f.endswith(".png"))
    count = len(files)
    frames = [I.load(os.path.join(SRC, f)) for f in files]
    h, w = frames[0].shape[:2]
    alpha = np.max([f[..., 3] for f in frames], axis=0)
    ys, xs = np.nonzero(alpha > 0.02)
    pad = 4
    x0, y0 = max(int(xs.min()) - pad, 0), max(int(ys.min()) - pad, 0)
    x1, y1 = min(int(xs.max()) + 1 + pad, w), min(int(ys.max()) + 1 + pad, h)

    # Projections through the frames camera (full-frame pixels, then shifted into the crop).
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
    studio.use()
    cam = studio.camera("frames")
    scene = bpy.context.scene

    def px(p):
        v = world_to_camera_view(scene, cam, C.Vector(p))
        return [round(v.x * w - x0, 1), round((1 - v.y) * h - y0, 1)]

    def rect(points):
        pts = [px(p) for p in points]
        xs_, ys_ = [p[0] for p in pts], [p[1] for p in pts]
        return [min(xs_), min(ys_), round(max(xs_) - min(xs_), 1), round(max(ys_) - min(ys_), 1)]

    closed = frames[0]
    cy, cx = np.nonzero(closed[..., 3] > 0.9)
    body = [int(cx.min()) - x0, int(cy.min()) - y0, int(cx.max() - cx.min()) + 1, int(cy.max() - cy.min()) + 1]
    lo, hi = C.world_bounds(["Display"])
    display = rect([(lo.x, lo.y, lo.z), (hi.x, lo.y, lo.z), (lo.x, lo.y, hi.z), (hi.x, lo.y, hi.z)])
    cavity = rect([(CAV_X0, 0, CAV_Z0), (CAV_X1, 0, CAV_Z0), (CAV_X0, 0, CAV_Z1), (CAV_X1, 0, CAV_Z1)])
    # The door's clear glass (inside the frit) when it hangs fully open: where the app lays its
    # bottom-half content over the door like a HUD.
    import render as R  # noqa: E402
    from door import FRIT_W  # noqa: E402
    R.set_door(DOOR_MAX_ANGLE)
    glo, ghi = C.world_bounds(["DoorGlass"])
    y_front = glo.y
    glass_open = rect([(glo.x + FRIT_W, y_front, glo.z + FRIT_W), (ghi.x - FRIT_W, y_front, glo.z + FRIT_W),
                       (glo.x + FRIT_W, y_front, ghi.z - FRIT_W), (ghi.x - FRIT_W, y_front, ghi.z - FRIT_W)])
    R.set_door(0)
    # The upper tray's floor (where the dish sits), door shut: the lift point when the dish is
    # taken out for plating.
    tlo, thi = C.world_bounds(["Tray1"])
    tray = rect([(tlo.x, tlo.y, tlo.z), (thi.x, tlo.y, tlo.z), (tlo.x, thi.y, tlo.z), (thi.x, thi.y, tlo.z),
                 (tlo.x, tlo.y, thi.z), (thi.x, tlo.y, thi.z)])
    knobs = {}
    for name in ("Knob1", "Knob2", "Knob3"):
        k = bpy.data.objects[name]
        klo, khi = C.world_bounds([name])
        centre = px(k.matrix_world.translation)
        edge = px((khi.x, k.matrix_world.translation.y, k.matrix_world.translation.z))
        knobs[name] = {"centre": centre, "radius": round(abs(edge[0] - centre[0]), 1)}

    os.makedirs(DST, exist_ok=True)
    for old in os.listdir(DST):
        os.remove(os.path.join(DST, old))
    kept = []
    for i in range(0, count, args.every):
        I.save(frames[i][y0:y1, x0:x1], os.path.join(DST, f"oven_door_{i:03d}.png"))
        kept.append({"index": i, "name": f"oven_door_{i:03d}", "angle": round(DOOR_MAX_ANGLE * i / (count - 1), 4)})
    layout = {
        "source": "scripts/blender/app_export.py from build/renders/stage5 (camera.json views.frames)",
        "image_size": [x1 - x0, y1 - y0], "pixel_origin": "top-left",
        "max_angle": DOOR_MAX_ANGLE, "frames": kept,
        "body": body, "display": display, "cavity": cavity, "glass_open": glass_open, "tray": tray,
        "hinge": [px((DOOR_X0, HINGE_Y, HINGE_Z)), px((DOOR_X1, HINGE_Y, HINGE_Z))],
        "knobs": knobs,
    }
    with open(os.path.join(DST, "oven_layout.json"), "w") as f:
        json.dump(layout, f, indent=2)
    size = sum(os.path.getsize(os.path.join(DST, f)) for f in os.listdir(DST))
    print(f"[export] {len(kept)} frames, crop {x1 - x0}x{y1 - y0}, {size / 1e6:.1f} MB -> {os.path.relpath(DST, C.REPO)}")
    print(f"[export] layout body {body} display {display} glass_open {glass_open}")


if __name__ == "__main__":
    main()
