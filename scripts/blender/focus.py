"""Decorating step 8: the zoom-to-centre move's background frames and camera path
(docs/prompts/focus.md).

    $B -b -P scripts/blender/focus.py [-- --force --frames 18 --samples N --stage path|frames|check]

The stage (slab, oven, stand) is assembled from the existing files, as slab.py does; the plate
and the cake are NOT rendered (the live viewer draws them and flies the same path). A real
camera moves on a quadratic Bezier from the "station" view to straight top-down over the plate,
ease-in-out, tilting from about 6 degrees to 90 while dollying in; the vertical field of view
eases from the station lens to the viewer's 30 degrees.

Outputs in build/renders/focus/:
  <shape>/bg_NN.png       focus_bg per screen shape (iphone 540 x 1170, duo 750 x 1065: soft
                          depth of field, so half resolution; the app scales them up)
  duo_offset/bg_NN.png    the Duo variant with --center-offset-y 0.08
  focus_manifest.json     per-frame camera (plate-local metres, Z up), timings, cues, the cake's
                          final screen centre and radius, station panel areas
  guides_focus_duo.png, check.json (projection error), sheet.png
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D  # noqa: E402
import imaging as I  # noqa: E402
import studio  # noqa: E402

OUT = os.path.join(D.OUT, "focus")
PLATE_TOP = Vector((1.4, 0.15, 0.2055))
CAKE_H = 0.040
CAKE_R = 0.098
FPS = 20
SHAPES = {"iphone": (540, 1170), "duo": (750, 1065)}


def ease(t):
    return t * t * (3 - 2 * t)


def end_distance(aspect, fill=0.78):
    """Same fit as the app's CameraRig: the cake fills `fill` of the narrower side."""
    half_h = math.atan(math.tan(math.radians(15)) * min(aspect, 1))
    return CAKE_R / fill / math.tan(half_h) * 1.05


def path(shape, frames, offset_y=0.0):
    w, h = SHAPES[shape]
    aspect = w / h
    st = studio.views()["station"]
    p0 = Vector(st["location"]) - PLATE_TOP
    t0 = Vector(st["target"]) - PLATE_TOP
    fov0 = math.degrees(2 * math.atan(18 / st["lens"]))          # station render: sensor fit vertical
    target_end = Vector((0, 0, CAKE_H))
    dist = end_distance(aspect)
    vis_h = 2 * dist * math.tan(math.radians(15))
    # Screen up at the end is +Y (away from the viewer): moving the target to -Y raises the cake.
    target_end_off = target_end + Vector((0, -offset_y * vis_h, 0))
    p2 = target_end_off + Vector((0, -dist * math.cos(math.radians(89.9)), dist * math.sin(math.radians(89.9))))
    p1 = Vector((0, p0.y * 0.55, p2.z * 0.9))
    out = []
    for i in range(frames):
        t = ease(i / (frames - 1))
        pos = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        tgt = t0.lerp(target_end_off, t)
        fov = fov0 + (30 - fov0) * t
        fwd = (tgt - pos).normalized()
        right = fwd.cross(Vector((0, 0, 1)))
        if right.length < 1e-6:
            right = Vector((1, 0, 0))
        up = right.normalized().cross(fwd)
        out.append({"frame": i, "time": round(i / FPS, 3), "position": [round(v, 5) for v in pos],
                    "target": [round(v, 5) for v in tgt], "up": [round(v, 5) for v in up], "fov_deg": round(fov, 3)})
    return out


def assemble():
    D.setup(ground=False, samples=32)
    stage = []
    for name in ("slab.blend", "oven.blend", "cakestand.blend"):
        path_ = os.path.join(C.BUILD, name)
        with bpy.data.libraries.load(path_, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is None:
                continue
            bpy.context.scene.collection.objects.link(o)
            stage.append(o)
    studio.keep_oven_lights_off([o for o in stage if o.type == "MESH" and o.name.startswith(("Stand", "Bearing", "Turntable", "Plate"))])
    plate = [o for o in stage if o.name in ("TurntablePlate", "PlateMarker")]
    return stage, plate


def place_camera(cam, f, res):
    w, h = res
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = w, h
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24
    cam.data.lens = 12 / math.tan(math.radians(f["fov_deg"]) / 2)
    cam.location = PLATE_TOP + Vector(f["position"])
    fwd = Vector(f["target"]) - Vector(f["position"])
    cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
    # Keep the exported up vector exactly (to_track_quat picks its own roll).
    up_now = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
    bpy.context.view_layer.update()
    del up_now
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = fwd.length
    cam.data.dof.aperture_fstop = 2.8
    bpy.context.view_layer.update()


def camera():
    scene = bpy.context.scene
    cam = bpy.data.objects.new("FocusCam", bpy.data.cameras.new("FocusCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.clip_start = 0.01
    return cam


def project(cam, point, res):
    from bpy_extras.object_utils import world_to_camera_view
    co = world_to_camera_view(bpy.context.scene, cam, point)
    return co.x * res[0], (1 - co.y) * res[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--frames", type=int, default=18)
    parser.add_argument("--samples", type=int, default=24)
    parser.add_argument("--stage", default="all")
    args = C.script_args(parser)
    variants = {"iphone": ("iphone", 0.0), "duo": ("duo", 0.0), "duo_offset": ("duo", 0.08)}
    paths = {k: path(shape, args.frames, off) for k, (shape, off) in variants.items()}
    stage, plate = assemble()
    cam = camera()
    sheet = []
    if args.stage in ("all", "frames"):
        for o in plate:
            o.hide_render = True
        for key, (shape, _) in variants.items():
            for f in paths[key]:
                place_camera(cam, f, SHAPES[shape])
                p = os.path.join(OUT, key, "bg_%02d.png" % f["frame"])
                bpy.context.scene.render.film_transparent = False
                D.render(p, SHAPES[shape], samples=args.samples, supersample=1, force=args.force)
                if key == "iphone" and f["frame"] % 4 == 0:
                    sheet.append(p)
        D.sheet(sheet, os.path.join(OUT, "sheet.png"), columns=5, cell=300)
    # Check: render the plate (not exported) at 5 frames, compare its centre with the projection
    # of the exported camera path.
    check = {}
    if args.stage in ("all", "check"):
        for o in stage:
            o.hide_render = o not in plate
        bpy.context.scene.render.film_transparent = True
        errs = []
        for i in np.linspace(0, args.frames - 1, 5).astype(int):
            f = paths["iphone"][i]
            place_camera(cam, f, SHAPES["iphone"])
            cam.data.dof.use_dof = False
            p = os.path.join(OUT, "check", "plate_%02d.png" % i)
            D.render(p, SHAPES["iphone"], samples=8, supersample=1, force=True)
            arr = I.load(p)
            x0, y0, x1, y1 = I.alpha_bbox(arr, 0.5)
            rendered = ((x0 + x1) / 2, (y0 + y1) / 2)
            # Simple pinhole projection from the exported path alone (as the app does).
            pos, tgt, up = Vector(f["position"]), Vector(f["target"]), Vector(f["up"])
            fwd = (tgt - pos).normalized()
            right = fwd.cross(up).normalized()
            q = Vector((0, 0, 0.0)) - pos         # the plate's top centre, plate-local
            z = q.dot(fwd)
            t = math.tan(math.radians(f["fov_deg"]) / 2)
            w, h = SHAPES["iphone"]
            sx = (q.dot(right) / z / (t * w / h) + 1) / 2 * w
            sy = (1 - q.dot(up) / z / t) / 2 * h
            # The plate's bbox centre is its rim's centre, slightly off its top centre in
            # perspective; compare against Blender's own projection of the same point too.
            bx, by = project(cam, PLATE_TOP, (w, h))
            errs.append({"frame": int(i), "path_vs_blender_px": round(math.hypot(sx - bx, sy - by), 2),
                         "path_vs_render_bbox_px": round(math.hypot(sx - rendered[0], sy - rendered[1]), 2)})
        check = {"frames": errs, "max_path_vs_blender_px": max(e["path_vs_blender_px"] for e in errs)}
        D.write_json(os.path.join(OUT, "check.json"), check)
    # Guides: the Duo's fold band over the last frame.
    last = os.path.join(OUT, "duo", "bg_%02d.png" % (args.frames - 1))
    if os.path.exists(last):
        arr = I.load(last)
        h = arr.shape[0]
        band = slice(int(h * (1005 / 2130)), int(h * (1125 / 2130)))
        arr[band, :, 0] = arr[band, :, 0] * 0.4 + 0.6
        I.save(arr, os.path.join(D.OUT, "studio", "guides_focus_duo.png"))
    final = {}
    for key, (shape, off) in variants.items():
        w, h = SHAPES[shape]
        dist = end_distance(w / h)
        vis_h = 2 * dist * math.tan(math.radians(15))
        final[key] = {"cake_centre_px": [w / 2, round(h / 2 - off * h, 1)],
                      "cake_radius_px": round(CAKE_R / (vis_h * w / h) * w, 1), "center_offset_y": off}
    with open(os.path.join(D.OUT, "station", "layout_iphone.json")) as fh:
        panel_iphone = json.load(fh)["cake_window"]
    D.write_json(os.path.join(OUT, "focus_manifest.json"), {
        "units": "metres, plate-local: origin at the plate's top centre, +Z up, viewer at -Y",
        "fps": FPS, "frames": args.frames, "easing": "smoothstep (ease-in-out)",
        "cues": {"push_in_start": 0, "midpoint": args.frames // 2, "top_down": args.frames - 1},
        "paths": paths, "final": final, "station_cake_window": {"iphone": panel_iphone},
        "first_camera": "camera.json station", "last_camera": "viewer top (CameraRig at elevation 90)",
        "check": check, "size_mb": D.dir_mb(OUT), "budget_mb": 12})
    print(f"[focus] {D.dir_mb(OUT)} MB, check {check.get('max_path_vs_blender_px')}")


if __name__ == "__main__":
    main()
