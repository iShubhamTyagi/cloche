"""Render the oven from build/oven.blend.

    Blender -b -P scripts/blender/render.py -- --stage 1 [--quality preview|final]

Writes to build/renders/stage<N>/: the views, a hinge test strip (0/30/60/88 degrees, side view,
with a numeric clipping check), comparison sheets against the reference, and report.json.
Transparent background (film_transparent), RGBA PNG.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402

HINGE_TEST_ANGLES = (0, 30, 60, 88)
OPEN_ANGLE = 88

# Oven bounding boxes in the reference images, in pixels (x0, y0, x1, y1), top-left origin.
# Measured by eye; the overlays show how well they line up.
REF_CLOSED = ("oven_ref_closed.png", (7, 3, 229, 163))     # body only, door shut
REF_OPEN = ("oven_ref.png", (30, 224, 374, 584))           # body + dropped door + handle

# name: (location, target, lens mm or None for ortho, ortho scale, door angle)
VIEWS = {
    "front_closed": ((0.0, -1.85, 0.62), (0.0, 0.12, 0.165), 85, None, 0),
    "open_34": ((1.05, -1.40, 0.62), (0.0, -0.05, 0.13), 70, None, OPEN_ANGLE),
    "refmatch_open": ((0.0, -1.20, 0.80), (0.0, -0.06, 0.14), 45, None, OPEN_ANGLE),
    "ortho_front": ((0.0, -2.0, 0.175), (0.0, 0.0, 0.175), None, 0.62, 0),
}
# Close-ups from Stage 2 on, to judge bevels and small parts.
DETAIL_VIEWS = {
    "detail_controls": ((0.48, -0.42, 0.34), (0.21, 0.0, 0.20), 90, None, 0),
    "detail_cavity": ((0.22, -0.70, 0.40), (-0.05, 0.18, 0.17), 45, None, OPEN_ANGLE),
    "detail_hinge": ((-0.50, -0.42, 0.16), (-0.24, -0.03, 0.05), 90, None, 60),
    "detail_back": ((-0.55, 1.10, 0.62), (0.0, 0.25, 0.20), 55, None, 0),
}


# ------------------------------------------------------------------ scene setup

def setup_cycles(quality):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.refresh_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except Exception as exc:  # CPU fallback
        print(f"[render] GPU unavailable ({exc}); using CPU")
    scene.cycles.samples = 256 if quality == "final" else 32
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.max_bounces = 12
    scene.cycles.transmission_bounces = 12
    scene.cycles.sample_clamp_indirect = 10
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"


def principled(name, color, roughness=0.5, metallic=0.0, transmission=0.0, ior=1.45):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = ior
    return mat


def apply_clay():
    clay = principled("Clay", (0.30, 0.30, 0.30), roughness=0.55)
    glass = principled("ClayGlass", (0.85, 0.85, 0.85), roughness=0.03, transmission=1.0, ior=1.5)
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name == "Floor":
            continue
        obj.data.materials.clear()
        obj.data.materials.append(glass if "Glass" in obj.name else clay)


def add_floor():
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "Floor"
    floor.is_shadow_catcher = True
    return floor


def add_area(name, location, target, size, energy, color=(1, 1, 1)):
    data = bpy.data.lights.new(name, "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = size
    data.energy = energy
    data.color = color
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = location
    aim(light, target)
    return light


def aim(obj, target):
    direction = C.Vector(target) - C.Vector(obj.location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def clay_lighting():
    world = bpy.data.worlds.new("Studio")
    bpy.context.scene.world = world
    world.color = (0.25, 0.25, 0.25)
    if world.node_tree is None:
        world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.25, 0.25, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
    add_area("Key", (-0.9, -1.2, 1.3), (0, 0.1, 0.15), (1.2, 0.8), 70)
    add_area("Fill", (1.2, -0.9, 0.5), (0, 0.1, 0.15), (1.0, 1.0), 22)
    add_area("Rim", (0.4, 1.2, 1.0), (0, 0.2, 0.2), (0.8, 0.4), 45)


def camera(view):
    location, target, lens, ortho, _ = {**VIEWS, **DETAIL_VIEWS}[view]
    cam = bpy.data.objects.get("Camera")
    if cam is None:
        cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        bpy.context.scene.collection.objects.link(cam)
        bpy.context.scene.camera = cam
    cam.location = location
    aim(cam, target)
    if lens is None:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens
    cam.data.clip_start = 0.01
    return cam


def set_door(angle):
    door = bpy.data.objects["Door"]
    door.rotation_euler = (0, 0, 0)
    if door.get("hinge") == "left":
        door.rotation_euler.z = -math.radians(angle)
    else:
        door.rotation_euler.x = math.radians(angle)
    bpy.context.view_layer.update()


def render(path, resolution):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print(f"[render] {os.path.relpath(path, C.REPO)}")


# ------------------------------------------------------------------ hinge test

def door_clearance(angle):
    """World bounds of the door and its children at an angle: it must stay above the floor and
    in front of the body (y <= 0)."""
    set_door(angle)
    names = [o.name for o in C.descendants(bpy.data.objects["Door"]) if o.type == "MESH"]
    lo, hi = C.world_bounds(names)
    return {"angle": angle, "min_z": round(lo.z, 4), "max_y": round(hi.y, 4),
            "clips_floor": lo.z < 0.0, "clips_body": hi.y > 1e-4}


def hinge_test(out_dir):
    cam = camera("ortho_front")
    cam.location = (1.6, -0.12, 0.17)
    aim(cam, (0, -0.12, 0.17))
    cam.data.ortho_scale = 0.78
    frames, checks = [], []
    for angle in HINGE_TEST_ANGLES:
        checks.append(door_clearance(angle))
        path = os.path.join(out_dir, f"hinge_{angle:03d}.png")
        render(path, (640, 480))
        frames.append(path)
    strip = np.concatenate([over_background(load(p)) for p in frames], axis=1)
    save(strip, os.path.join(out_dir, "hinge_test.png"))
    return checks


# ------------------------------------------------------------------ image tools (top-left origin)

def load(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1].copy()


def save(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print(f"[render] {os.path.relpath(path, C.REPO)}")


def over_background(arr, bg=0.07):
    a = arr[..., 3:4]
    out = arr.copy()
    out[..., :3] = arr[..., :3] * a + bg * (1 - a)
    out[..., 3] = 1
    return out


def resize(arr, w, h):
    ys = (np.arange(h) * arr.shape[0] / h).astype(int)
    xs = (np.arange(w) * arr.shape[1] / w).astype(int)
    return arr[ys][:, xs]


def to_height(arr, h):
    return resize(arr, max(1, round(arr.shape[1] * h / arr.shape[0])), h)


def alpha_bbox(arr, threshold=0.9):
    ys, xs = np.nonzero(arr[..., 3] > threshold)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def comparison(ref_spec, render_path, out_path, height=600):
    """[reference | render | 50% overlay of the reference oven scaled onto the render's oven]."""
    ref_name, (rx0, ry0, rx1, ry1) = ref_spec
    ref = load(os.path.join(C.REFERENCE, ref_name))
    ref[..., 3] = 1
    rendered = load(render_path)
    bx0, by0, bx1, by1 = alpha_bbox(rendered)
    flat = over_background(rendered)
    overlay = flat.copy()
    patch = resize(ref[ry0:ry1, rx0:rx1], bx1 - bx0, by1 - by0)
    overlay[by0:by1, bx0:bx1, :3] = 0.5 * overlay[by0:by1, bx0:bx1, :3] + 0.5 * patch[..., :3]
    gap = np.full((height, 12, 4), 1.0, dtype=np.float32)
    sheet = np.concatenate([to_height(ref, height), gap, to_height(flat, height), gap,
                            to_height(overlay, height)], axis=1)
    save(sheet, out_path)
    ref_ratio = (rx1 - rx0) / (ry1 - ry0)
    render_ratio = (bx1 - bx0) / (by1 - by0)
    return {"reference_ratio": round(ref_ratio, 3), "render_ratio": round(render_ratio, 3)}


# ------------------------------------------------------------------ main

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--quality", choices=("preview", "final"), default="preview")
    parser.add_argument("--blend", default=os.path.join(C.BUILD, "oven.blend"))
    args = C.script_args(parser)

    bpy.ops.wm.open_mainfile(filepath=args.blend)
    out_dir = os.path.join(C.BUILD, "renders", f"stage{args.stage}")
    os.makedirs(out_dir, exist_ok=True)

    setup_cycles(args.quality)
    add_floor()
    if args.stage <= 2:
        apply_clay()
        clay_lighting()

    report = {"stage": args.stage, "quality": args.quality}
    report["triangles"], _ = C.triangle_count([o for o in bpy.context.scene.objects if o.name != "Floor"])
    views = dict(VIEWS, **(DETAIL_VIEWS if args.stage >= 2 else {}))
    for view in views:
        set_door(views[view][4])
        camera(view)
        render(os.path.join(out_dir, f"{view}.png"), (1200, 900))

    report["proportions_closed"] = comparison(REF_CLOSED, os.path.join(out_dir, "ortho_front.png"),
                                              os.path.join(out_dir, "compare_closed_ortho.png"))
    report["compare_closed"] = comparison(REF_CLOSED, os.path.join(out_dir, "front_closed.png"),
                                          os.path.join(out_dir, "compare_closed.png"))
    report["compare_open"] = comparison(REF_OPEN, os.path.join(out_dir, "refmatch_open.png"),
                                        os.path.join(out_dir, "compare_open.png"))
    report["hinge"] = hinge_test(out_dir)
    with open(os.path.join(out_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print("[render] report " + json.dumps(report))


if __name__ == "__main__":
    main()
