"""Stage 5: door animation frames, manifest, contact sheet, reference comparison, USDZ.

    Blender -b -P scripts/blender/frames.py -- [--count 48] [--preview | --final] [--samples N]
                                               [--force] [--test] [--usdz-only]

Renders door_000.png .. door_047.png into build/renders/stage5/door/ from camera.json's
"frames" camera, in the studio, heat on: the door at equal hinge-angle steps from 0 (shut) to
180 (hanging straight down, like the Duo unfolded). The knobs are NOT in these frames (hidden
from the camera only, so their shadows and reflections stay): they are a separate layer of
sprites (knobs.py) so the app can turn them. Existing frames are skipped unless --force.

manifest.json records each frame's angle, the camera, and where the hinge axis and the body
front land in the image, so the app can line the frames up with its own layout.
"""
import argparse
import json
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import materials  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402
from layout import (D, DOOR_MAX_ANGLE, DOOR_X0, DOOR_X1, HINGE_Y, HINGE_Z, X0, X1, Z0,  # noqa: E402
                    Z1)

OUT = os.path.join(C.BUILD, "renders", "stage5")
KNOBS = ("Knob1", "Knob2", "Knob3")


def setup():
    """The oven in the studio from the app's camera, heat on, bloom on."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
    studio.use()
    materials.set_heat(1.0)
    materials.set_display_glow(0.08)
    studio.bloom(True)
    keep_studio_lights_off_glass()
    return studio.camera("frames")


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


def hide_knobs_from_camera(hidden=True):
    for name in KNOBS:
        bpy.data.objects[name].visible_camera = not hidden


def angles(count):
    return [DOOR_MAX_ANGLE * i / (count - 1) for i in range(count)]


def frames_res():
    return tuple(studio.views()["frames"]["resolution"])


def to_pixels(cam, point):
    """World point -> [x, y] pixels, top-left origin, at the frames camera's resolution."""
    w, h = frames_res()
    v = world_to_camera_view(bpy.context.scene, cam, C.Vector(point))
    return [round(v.x * w, 1), round((1 - v.y) * h, 1)]


def render_frames(count, args):
    frames = []
    for i, angle in enumerate(angles(count)):
        path = os.path.join(OUT, "door", f"door_{i:03d}.png")
        R.set_door(angle)
        if studio.render(path, args, view_res=frames_res()):
            I.clean_transparent(path)
        frames.append({"index": i, "file": f"door/door_{i:03d}.png", "angle": round(angle, 4)})
        print(f"[frames] {i + 1}/{count} at {angle:.2f} deg", flush=True)
    return frames


def manifest(cam, frames, args):
    scene = bpy.context.scene
    body = {name: to_pixels(cam, p) for name, p in (
        ("front_top_left", (X0, 0, Z1)), ("front_top_right", (X1, 0, Z1)),
        ("front_bottom_left", (X0, 0, Z0)), ("front_bottom_right", (X1, 0, Z0)))}
    res, samples = studio.resolved(args, frames_res())
    return {
        "asset": "oven", "units": "metres", "axes": "camera looks +Y, oven front y=0, Z up",
        "frame_count": len(frames), "angle_range_degrees": [0, DOOR_MAX_ANGLE],
        "angle_of_frame": f"{DOOR_MAX_ANGLE} * index / {len(frames) - 1}",
        "resolution": list(res), "pixel_origin": "top-left", "background": "transparent RGBA PNG",
        "camera": "build/camera.json views.frames",
        "render": {"engine": "Cycles", "samples": samples, "denoiser": "OpenImageDenoise",
                   "view_transform": scene.view_settings.view_transform, "look": scene.view_settings.look,
                   "heat": 1.0, "bloom": True,
                   "note": "studio softboxes light-linked off DoorGlass (no glint flashes)"},
        "knobs": "not in these frames; overlay the sprites listed in knobs.json",
        "hinge_axis_pixels": [to_pixels(cam, (DOOR_X0, HINGE_Y, HINGE_Z)), to_pixels(cam, (DOOR_X1, HINGE_Y, HINGE_Z))],
        "body_front_pixels": body,
        "depth_m": D,
        "frames": frames,
    }


def export_usdz():
    """Optional USDZ of the shut oven: only the `Oven` hierarchy (no studio), converted to Y-up
    for RealityKit and Quick Look, metres. Procedural materials don't survive USD (base colours
    only); this is for shape, part names and pivots, not the look."""
    R.set_door(0)
    R.slide_racks({})
    hide_knobs_from_camera(False)
    path = os.path.join(C.BUILD, "oven.usdz")
    oven = C.descendants(bpy.data.objects["Oven"])
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
    parser.add_argument("--test", action="store_true", help="three preview frames to check framing")
    parser.add_argument("--usdz-only", action="store_true")
    studio.add_render_args(parser, samples=96)
    args = C.script_args(parser)

    os.makedirs(os.path.join(OUT, "door"), exist_ok=True)
    cam = setup()
    if args.usdz_only:
        print(f"[frames] usdz {export_usdz()}")
        return
    hide_knobs_from_camera()
    if args.test:
        args.preview, args.force = True, True
        for angle in (0, 88, 180):
            R.set_door(angle)
            studio.render(os.path.join(OUT, f"test_{angle:03d}.png"), args)
        return

    frames = render_frames(args.count, args)
    data = manifest(cam, frames, args)
    data["usdz"] = export_usdz()
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(data, f, indent=2)
    I.grid([os.path.join(OUT, fr["file"]) for fr in frames], os.path.join(OUT, "contact_sheet.png"), columns=8)
    nearest = min(frames, key=lambda fr: abs(fr["angle"] - 88))
    I.comparison(I.REF_OPEN, os.path.join(OUT, nearest["file"]), os.path.join(OUT, "compare_open.png"))
    I.comparison(I.REF_CLOSED, os.path.join(OUT, frames[0]["file"]), os.path.join(OUT, "compare_closed.png"))
    print("[frames] done")


if __name__ == "__main__":
    main()
