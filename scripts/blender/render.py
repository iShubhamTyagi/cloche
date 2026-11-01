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
import materials  # noqa: E402
from layout import (CAV_X0, CAV_X1, CAV_Z0, CAV_Z1, COUNTER_EDGE_Y, COUNTER_T, D, ELEMENT_R,  # noqa: E402
                    ELEMENT_ZS, RACKS, TRAYS, X0, X1, Z0, Z1)

HINGE_TEST_ANGLES = (0, 30, 60, 88, 120, 150, 180)
OPEN_ANGLE = 88

# Oven bounding boxes in the reference images, in pixels (x0, y0, x1, y1), top-left origin.
# Measured by eye; the overlays show how well they line up.
REF_CLOSED = ("oven_ref_closed.png", (7, 3, 229, 163))     # body only, door shut
REF_OPEN = ("oven_ref.png", (30, 224, 374, 584))           # body + dropped door + handle

# name: (location, target, lens mm or None for ortho, ortho scale, door angle)
VIEWS = {
    "front_closed": ((0.0, -1.90, 0.42), (0.0, 0.12, 0.17), 85, None, 0),
    "open_34": ((1.05, -1.40, 0.62), (0.0, -0.05, 0.13), 70, None, OPEN_ANGLE),
    "refmatch_open": ((0.0, -1.25, 0.62), (0.0, -0.06, 0.12), 45, None, OPEN_ANGLE),
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

# Stage 4 on: both racks pulled part-way out over the open door, to show they come out.
RACK_VIEWS = {"racks_out": ((0.85, -1.25, 0.70), (0.0, -0.12, 0.14), 50, None, OPEN_ANGLE)}
RACKS_OUT = {"racks_out": {"Rack1": 0.24, "Rack2": 0.13}}
CAKE_ALLOWANCE = 0.065   # tallest cupcake plus a margin, for the rack spacing check


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
    """Shadow-catching counter: top at z = 0, front edge just behind the hinge, so the door can
    swing past flat (88) to hanging straight down (180) like the Duo's hinge."""
    bm = C.bmesh.new()
    C.add_box(bm, (-3, COUNTER_EDGE_Y, -COUNTER_T), (3, 3, 0))
    floor = C.mesh_object("Floor", bm)
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


def studio_lighting():
    """Studio: an environment graded from a dark floor to a bright ceiling (so steel and glass
    reflect something), two large softboxes and a rim light. Neutral white."""
    world = bpy.data.worlds.new("Studio")
    bpy.context.scene.world = world
    if world.node_tree is None:
        world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputWorld")
    bg = nodes.new("ShaderNodeBackground")
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[0].color = (0.004, 0.004, 0.004, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.09, 0.09, 0.095, 1)
    links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    # Generated world coords run -1..1; remap z to 0..1 for the ramp.
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -1
    links.new(sep.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    links.new(bg.outputs["Background"], out.inputs["Surface"])
    add_area("SoftboxKey", (-1.1, -1.3, 1.3), (0, 0.1, 0.15), (1.6, 1.0), 120)
    add_area("SoftboxFill", (1.4, -0.9, 0.7), (0, 0.1, 0.15), (1.6, 1.6), 16)
    add_area("Rim", (1.3, 0.9, 0.55), (0, 0.2, 0.2), (1.2, 0.3), 110)


def camera(view):
    location, target, lens, ortho, _ = {**VIEWS, **DETAIL_VIEWS, **RACK_VIEWS}[view]
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
    """Every vertex of the door and its children at an angle must stay out of the body's box
    and out of the counter slab."""
    set_door(angle)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    in_body = in_counter = 0
    min_z = 1e9
    for obj in C.descendants(bpy.data.objects["Door"]):
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            min_z = min(min_z, w.z)
            if 1e-4 < w.y < D and X0 < w.x < X1 and Z0 < w.z < Z1:
                in_body += 1
            if w.y > COUNTER_EDGE_Y and -COUNTER_T < w.z < -1e-4:
                in_counter += 1
        ev.to_mesh_clear()
    return {"angle": angle, "min_z": round(min_z, 4), "clips_body": in_body > 0,
            "clips_counter": in_counter > 0}


def slide_racks(offsets):
    """Pull each rack out along -Y by `offsets[name]` metres (0 = home)."""
    for name in RACKS:
        rack = bpy.data.objects[name]
        if "home_y" not in rack:
            rack["home_y"] = rack.location.y
        rack.location.y = rack["home_y"] - offsets.get(name, 0.0)
    bpy.context.view_layer.update()


def rack_clearance():
    """Each rack with its tray must fit through the cavity mouth inside the gasket (so it slides
    straight out), and each tray needs room for a cupcake above it."""
    slide_racks({})
    out = {}
    tops = {}
    for name in RACKS:
        meshes = [o.name for o in C.descendants(bpy.data.objects[name]) if o.type == "MESH"]
        lo, hi = C.world_bounds(meshes)
        tray_lo, tray_hi = C.world_bounds([TRAYS[name][0]])
        tops[name] = (lo.z, tray_lo.z)
        gasket = 0.004
        out[name] = {"slides_out_clear": bool(lo.x > CAV_X0 + gasket and hi.x < CAV_X1 - gasket
                                              and lo.z > CAV_Z0 + gasket and hi.z < CAV_Z1 - gasket)}
    top_tube_bottom = ELEMENT_ZS["Top"] - ELEMENT_R
    out["Rack1"]["cake_headroom_mm"] = round((top_tube_bottom - tops["Rack1"][1]) * 1000, 1)
    out["Rack2"]["cake_headroom_mm"] = round((tops["Rack1"][0] - tops["Rack2"][1]) * 1000, 1)
    for name in RACKS:
        out[name]["fits_cupcake"] = out[name]["cake_headroom_mm"] > CAKE_ALLOWANCE * 1000
    return out


def bloom(enabled):
    """Compositor glare (bloom) for the tubes' glow, final stills only."""
    scene = bpy.context.scene
    if enabled and scene.compositing_node_group is None:
        tree = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        layers = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.inputs["Type"].default_value = "Bloom"
        glare.inputs["Threshold"].default_value = 2.5
        glare.inputs["Strength"].default_value = 0.6
        glare.inputs["Size"].default_value = 0.35
        # Add only the glare, masked by the render's alpha, on top of the untouched render, and
        # keep that alpha: transparent pixels stay exactly zero and shadows stay untinted.
        mask = tree.nodes.new("CompositorNodeSetAlpha")
        mask.inputs["Type"].default_value = "Apply Mask"
        add = tree.nodes.new("ShaderNodeMix")
        add.data_type = "RGBA"
        add.blend_type = "ADD"
        next(i for i in add.inputs if i.identifier == "Factor_Float").default_value = 1.0
        keep_alpha = tree.nodes.new("CompositorNodeSetAlpha")
        keep_alpha.inputs["Type"].default_value = "Replace Alpha"
        out = tree.nodes.new("NodeGroupOutput")
        link = tree.links.new
        link(layers.outputs["Image"], glare.inputs["Image"])
        link(glare.outputs["Glare"], mask.inputs["Image"])
        link(layers.outputs["Alpha"], mask.inputs["Alpha"])
        ins = {i.identifier: i for i in add.inputs}
        link(layers.outputs["Image"], ins["A_Color"])
        link(mask.outputs["Image"], ins["B_Color"])
        link(next(o for o in add.outputs if o.identifier == "Result_Color"), keep_alpha.inputs["Image"])
        link(layers.outputs["Alpha"], keep_alpha.inputs["Alpha"])
        link(keep_alpha.outputs["Image"], out.inputs[0])
        scene.compositing_node_group = tree
    scene.render.use_compositing = enabled


def hinge_test(out_dir):
    cam = camera("ortho_front")
    cam.location = (1.6, -0.10, 0.04)
    aim(cam, (0, -0.10, 0.04))
    cam.data.ortho_scale = 0.95
    frames, checks = [], []
    for angle in HINGE_TEST_ANGLES:
        checks.append(door_clearance(angle))
        path = os.path.join(out_dir, f"hinge_{angle:03d}.png")
        render(path, (480, 480))
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

def clean_transparent(path):
    """Zero the colour of fully transparent pixels (bloom leaves stray colour there, which
    viewers that ignore alpha would show)."""
    arr = load(path)
    arr[arr[..., 3] < 1 / 255, :3] = 0
    save(arr, path)


def render_heroes(views, out_dir):
    """Final stills: 256 samples, bloom on, 1600 x 1200."""
    scene = bpy.context.scene
    preview_samples = scene.cycles.samples
    scene.cycles.samples = 256
    bloom(True)
    for name, view in (("hero_closed", "front_closed"), ("hero_open", "open_34")):
        set_door(views[view][4])
        slide_racks({})
        camera(view)
        path = os.path.join(out_dir, f"{name}.png")
        render(path, (1600, 1200))
        clean_transparent(path)
    bloom(False)
    scene.cycles.samples = preview_samples


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--quality", choices=("preview", "final"), default="preview")
    parser.add_argument("--blend", default=os.path.join(C.BUILD, "oven.blend"))
    parser.add_argument("--only", nargs="*", help="render just these views (quick look; no sheets)")
    parser.add_argument("--bloom", action="store_true", help="with --only: bloom on, as in the finals")
    parser.add_argument("--heroes", action="store_true", help="stage 4+: re-render only the final stills")
    parser.add_argument("--clean", action="store_true", help="only re-run clean_transparent on the final stills")
    args = C.script_args(parser)

    bpy.ops.wm.open_mainfile(filepath=args.blend)
    out_dir = os.path.join(C.BUILD, "renders", f"stage{args.stage}")
    os.makedirs(out_dir, exist_ok=True)

    setup_cycles(args.quality)
    add_floor()
    if args.stage <= 2:
        apply_clay()
        clay_lighting()
    else:
        studio_lighting()
        materials.set_heat(0.0 if args.stage == 3 else 1.0)
    if args.stage >= 4:
        bpy.context.scene.view_settings.look = "AgX - Medium High Contrast"
        materials.set_display_glow(0.08)

    report = {"stage": args.stage, "quality": args.quality}
    report["triangles"], _ = C.triangle_count([o for o in bpy.context.scene.objects if o.name != "Floor"])
    views = dict(VIEWS, **(DETAIL_VIEWS if args.stage >= 2 else {}), **(RACK_VIEWS if args.stage >= 4 else {}))
    if args.heroes:
        render_heroes(views, out_dir)
        return
    if args.clean:
        for name in ("hero_closed", "hero_open"):
            clean_transparent(os.path.join(out_dir, f"{name}.png"))
        return
    if args.only:
        bloom(args.bloom)
        for view in args.only:
            set_door(views[view][4])
            slide_racks(RACKS_OUT.get(view, {}))
            camera(view)
            render(os.path.join(out_dir, f"quick_{view}.png"), (800, 600))
        return
    for view in views:
        set_door(views[view][4])
        slide_racks(RACKS_OUT.get(view, {}))
        camera(view)
        render(os.path.join(out_dir, f"{view}.png"), (1200, 900))
    slide_racks({})

    if args.stage >= 4:
        render_heroes(views, out_dir)
        report["racks"] = rack_clearance()

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
