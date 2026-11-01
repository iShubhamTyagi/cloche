"""Stage 5: door animation frames, manifest, contact sheet, reference comparison, USDZ.

    Blender -b -P scripts/blender/frames.py -- [--count 48] [--samples 96] [--test] [--force]

Renders door_000.png .. door_047.png into build/renders/stage5/door/: the same camera, lights
and heat for every frame, the door at equal hinge-angle steps from 0 (shut) to 180 (hanging
straight down, like the Duo unfolded). The app maps any hinge angle to the nearest frame (or
blends the two either side). Existing frames are kept unless --force, so a stopped run resumes.

manifest.json records each frame's angle, the camera, the resolution, and where the hinge axis
and the oven body land in the image, so the app can line the frames up with its own layout.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import materials  # noqa: E402
import render as R  # noqa: E402
from layout import (D, DOOR_MAX_ANGLE, DOOR_X0, DOOR_X1, HINGE_Y, HINGE_Z, X0, X1, Z0,  # noqa: E402
                    Z1)

# One camera for every frame: near-level front view, framed for the door's whole sweep
# (flat toward the camera at 88, hanging below the counter edge at 180).
DOOR_CAMERA = {"location": (0.0, -2.30, 0.36), "target": (0.0, -0.05, 0.05), "lens": 110}
RESOLUTION = (1000, 1200)


def setup(samples):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
    R.setup_cycles("preview")
    bpy.context.scene.cycles.samples = samples
    R.add_floor()
    R.studio_lighting()
    materials.set_heat(1.0)
    materials.set_display_glow(0.08)
    bpy.context.scene.view_settings.look = "AgX - Medium High Contrast"
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = DOOR_CAMERA["location"]
    R.aim(cam, DOOR_CAMERA["target"])
    cam.data.lens = DOOR_CAMERA["lens"]
    cam.data.clip_start = 0.01
    R.bloom(True)
    keep_studio_lights_off_glass()
    return cam


def keep_studio_lights_off_glass():
    """Light linking: the studio softboxes don't light (or glint on) the door glass. Around
    145-160 degrees the key softbox's hard edge otherwise flashes across the hanging door as a
    white wedge for a few frames. Everything else keeps its highlights."""
    glass = bpy.data.objects["DoorGlass"]
    receivers = bpy.data.collections.new("StudioLightReceivers")
    receivers.objects.link(glass)
    receivers.collection_objects[0].light_linking.link_state = "EXCLUDE"
    for name in ("SoftboxKey", "SoftboxFill", "Rim"):
        bpy.data.objects[name].light_linking.receiver_collection = receivers


def angles(count):
    return [DOOR_MAX_ANGLE * i / (count - 1) for i in range(count)]


def to_pixels(cam, point):
    """World point -> (x, y) pixels, top-left origin."""
    scene = bpy.context.scene
    v = world_to_camera_view(scene, cam, C.Vector(point))
    w, h = RESOLUTION
    return [round(v.x * w, 1), round((1 - v.y) * h, 1)]


def render_frames(cam, count, out_dir, force):
    frames = []
    for i, angle in enumerate(angles(count)):
        path = os.path.join(out_dir, "door", f"door_{i:03d}.png")
        if force or not os.path.exists(path):
            R.set_door(angle)
            R.render(path, RESOLUTION)
            R.clean_transparent(path)
        frames.append({"index": i, "file": f"door/door_{i:03d}.png", "angle": round(angle, 4)})
        print(f"[frames] {i + 1}/{count} at {angle:.2f} deg", flush=True)
    return frames


def manifest(cam, frames, samples):
    scene = bpy.context.scene
    body = {name: to_pixels(cam, p) for name, p in (
        ("front_top_left", (X0, 0, Z1)), ("front_top_right", (X1, 0, Z1)),
        ("front_bottom_left", (X0, 0, Z0)), ("front_bottom_right", (X1, 0, Z0)))}
    return {
        "asset": "oven", "units": "metres", "axes": "camera looks +Y, oven front y=0, Z up",
        "frame_count": len(frames), "angle_range_degrees": [0, DOOR_MAX_ANGLE],
        "angle_of_frame": f"{DOOR_MAX_ANGLE} * index / {len(frames) - 1}",
        "resolution": list(RESOLUTION), "pixel_origin": "top-left", "background": "transparent RGBA PNG",
        "camera": {**{k: list(v) if isinstance(v, tuple) else v for k, v in DOOR_CAMERA.items()},
                   "sensor_width_mm": cam.data.sensor_width},
        "render": {"engine": "Cycles", "samples": samples, "denoiser": "OpenImageDenoise",
                   "view_transform": scene.view_settings.view_transform, "look": scene.view_settings.look,
                   "heat": 1.0, "bloom": True,
                   "note": "studio softboxes light-linked off DoorGlass (no glint flashes)"},
        "hinge_axis_pixels": [to_pixels(cam, (DOOR_X0, HINGE_Y, HINGE_Z)), to_pixels(cam, (DOOR_X1, HINGE_Y, HINGE_Z))],
        "body_front_pixels": body,
        "depth_m": D,
        "frames": frames,
    }


def contact_sheet(out_dir, frames, columns=8, thumb_h=240):
    tiles = [R.to_height(R.over_background(R.load(os.path.join(out_dir, f["file"]))), thumb_h) for f in frames]
    tw = tiles[0].shape[1]
    rows = math.ceil(len(tiles) / columns)
    sheet = np.full((rows * thumb_h, columns * tw, 4), 0.07, dtype=np.float32)
    sheet[..., 3] = 1
    for i, tile in enumerate(tiles):
        r, c = divmod(i, columns)
        sheet[r * thumb_h:(r + 1) * thumb_h, c * tw:c * tw + tile.shape[1]] = tile[:, :tw]
    R.save(sheet, os.path.join(out_dir, "contact_sheet.png"))


def export_usdz():
    """Optional USDZ of the shut oven: only the `Oven` hierarchy (no counter, camera or studio
    lights), converted to Y-up for RealityKit and Quick Look, metres. Procedural materials don't
    survive USD (base colours only); this is for shape, part names and pivots, not the look."""
    R.set_door(0)
    R.slide_racks({})
    path = os.path.join(C.BUILD, "oven.usdz")
    oven = [o for o in C.descendants(bpy.data.objects["Oven"])]
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in oven)
    try:
        bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_animation=False,
                              export_materials=True, evaluation_mode="RENDER", export_lights=False,
                              export_cameras=False, convert_orientation=True,
                              export_global_up_selection="Y", export_global_forward_selection="NEGATIVE_Z")
        return os.path.relpath(path, C.REPO)
    except Exception as exc:
        print(f"[frames] USDZ export failed: {exc}")
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=48)
    parser.add_argument("--samples", type=int, default=96)
    parser.add_argument("--test", action="store_true", help="three low-res frames to check framing")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--usdz-only", action="store_true")
    args = C.script_args(parser)

    out_dir = os.path.join(C.BUILD, "renders", "stage5")
    os.makedirs(os.path.join(out_dir, "door"), exist_ok=True)
    cam = setup(16 if args.test else args.samples)

    if args.usdz_only:
        print(f"[frames] usdz {export_usdz()}")
        return

    if args.test:
        global RESOLUTION
        RESOLUTION = (500, 600)
        for angle in (0, 88, 180):
            R.set_door(angle)
            R.render(os.path.join(out_dir, f"test_{angle:03d}.png"), RESOLUTION)
        return

    frames = render_frames(cam, args.count, out_dir, args.force)
    data = manifest(cam, frames, args.samples)
    R.set_door(88)
    data["usdz"] = export_usdz()
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(data, f, indent=2)
    contact_sheet(out_dir, frames)
    # Against the reference: the frame nearest 88 degrees beside oven_ref.png.
    nearest = min(frames, key=lambda f: abs(f["angle"] - 88))
    R.comparison(R.REF_OPEN, os.path.join(out_dir, nearest["file"]), os.path.join(out_dir, "compare_open.png"))
    R.comparison(R.REF_CLOSED, os.path.join(out_dir, frames[0]["file"]), os.path.join(out_dir, "compare_closed.png"))
    print("[frames] done")


if __name__ == "__main__":
    main()
