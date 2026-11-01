"""Review renders of the oven from build/oven.blend, in the studio, from camera.json views.

    Blender -b -P scripts/blender/render.py -- --stage 4 [--preview | --final] [--res W H]
                                               [--samples N] [--force] [--only VIEW ...] [--heroes]

Writes to build/renders/stage<N>/: the stage's views, a hinge test strip (0 to 180 degrees, side
view, with a per-vertex clipping check), comparison sheets against reference/, and report.json.
Stages 1-2 are clay; 3 materials with the tubes off; 4+ glow on, plus the final stills
(hero_closed, hero_open: 1600 x 1200, 256 samples, bloom) and the rack clearance check.
Existing images are skipped unless --force.
"""
import argparse
import json
import math
import os
import sys
from types import SimpleNamespace

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import materials  # noqa: E402
import studio  # noqa: E402
from layout import (CAV_X0, CAV_X1, CAV_Z0, CAV_Z1, COUNTER_EDGE_Y, COUNTER_T, D, ELEMENT_R,  # noqa: E402
                    ELEMENT_ZS, RACKS, TRAYS, X0, X1, Z0, Z1)

HINGE_TEST_ANGLES = (0, 30, 60, 88, 120, 150, 180)
OPEN_ANGLE = 88
CAKE_ALLOWANCE = 0.065   # tallest cupcake plus a margin, for the rack spacing check

# Scene state per review view (the cameras themselves live in camera.json):
# view -> (door angle, rack pull-outs in metres, first stage it appears in)
VIEW_STATE = {
    "front_closed": (0, {}, 1),
    "open_34": (OPEN_ANGLE, {}, 1),
    "refmatch_open": (OPEN_ANGLE, {}, 1),
    "ortho_front": (0, {}, 1),
    "detail_controls": (0, {}, 2),
    "detail_cavity": (OPEN_ANGLE, {}, 2),
    "detail_hinge": (60, {}, 2),
    "detail_back": (0, {}, 2),
    "racks_out": (OPEN_ANGLE, {"Rack1": 0.24, "Rack2": 0.13}, 4),
}
HEROES = (("hero_closed", "front_closed"), ("hero_open", "open_34"))


# ------------------------------------------------------------------ oven state

def set_door(angle):
    door = bpy.data.objects["Door"]
    door.rotation_euler = (0, 0, 0)
    if door.get("hinge") == "left":
        door.rotation_euler.z = -math.radians(angle)
    else:
        door.rotation_euler.x = math.radians(angle)
    bpy.context.view_layer.update()


def slide_racks(offsets):
    """Pull each rack out along -Y by `offsets[name]` metres (0 = home)."""
    for name in RACKS:
        rack = bpy.data.objects[name]
        if "home_y" not in rack:
            rack["home_y"] = rack.location.y
        rack.location.y = rack["home_y"] - offsets.get(name, 0.0)
    bpy.context.view_layer.update()


def pose(view):
    angle, racks, _ = VIEW_STATE[view]
    set_door(angle)
    slide_racks(racks)


def principled(name, color, roughness=0.5, transmission=0.0, ior=1.45):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = ior
    return mat


def apply_clay(objects=None):
    clay = principled("Clay", (0.30, 0.30, 0.30), roughness=0.55)
    glass = principled("ClayGlass", (0.85, 0.85, 0.85), roughness=0.03, transmission=1.0, ior=1.5)
    for obj in objects or bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name == "Floor" or obj.users_collection[0].name.startswith("Studio"):
            continue
        obj.data.materials.clear()
        obj.data.materials.append(glass if "Glass" in obj.name else clay)


# ------------------------------------------------------------------ checks

def door_clearance(angle):
    """Every vertex of the door and its children must stay out of the body's box and out of the
    counter slab."""
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


def rack_clearance():
    """Each rack with its tray must fit through the cavity mouth inside the gasket, and each tray
    needs room for a cupcake above it."""
    slide_racks({})
    out, tops = {}, {}
    for name in RACKS:
        meshes = [o.name for o in C.descendants(bpy.data.objects[name]) if o.type == "MESH"]
        lo, hi = C.world_bounds(meshes)
        tray_lo, _ = C.world_bounds([TRAYS[name][0]])
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


def hinge_test(out_dir, args):
    studio.camera("hinge_side")
    frames, checks = [], []
    for angle in HINGE_TEST_ANGLES:
        checks.append(door_clearance(angle))
        path = os.path.join(out_dir, f"hinge_{angle:03d}.png")
        studio.render(path, args, view_res=(480, 480))
        frames.append(path)
    strip = np.concatenate([I.over_background(I.load(p)) for p in frames], axis=1)
    I.save(strip, os.path.join(out_dir, "hinge_test.png"))
    return checks


def render_heroes(out_dir, args):
    """Final stills: 1600 x 1200, 256 samples (unless --preview), bloom on."""
    hero_args = SimpleNamespace(**vars(args))
    if not args.preview:
        hero_args.res = hero_args.res or (1600, 1200)
        hero_args.samples = hero_args.samples or 256
    studio.bloom(True)
    for name, view in HEROES:
        pose(view)
        studio.camera(view)
        path = os.path.join(out_dir, f"{name}.png")
        if studio.render(path, hero_args):
            I.clean_transparent(path)
    studio.bloom(False)


# ------------------------------------------------------------------ main

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=4)
    parser.add_argument("--blend", default=os.path.join(C.BUILD, "oven.blend"))
    parser.add_argument("--only", nargs="*", help="render just these views (quick look; no sheets)")
    parser.add_argument("--bloom", action="store_true", help="with --only: bloom on, as in the finals")
    parser.add_argument("--heroes", action="store_true", help="stage 4+: only the final stills")
    studio.add_render_args(parser)
    args = C.script_args(parser)

    bpy.ops.wm.open_mainfile(filepath=args.blend)
    studio.use()
    out_dir = os.path.join(C.BUILD, "renders", f"stage{args.stage}")
    os.makedirs(out_dir, exist_ok=True)
    if args.stage <= 2:
        apply_clay()
        materials.set_heat(0.0)
    else:
        materials.set_heat(0.0 if args.stage == 3 else 1.0)
        materials.set_display_glow(0.08 if args.stage >= 4 else 0.0)

    views = [v for v, (_, _, first) in VIEW_STATE.items() if args.stage >= first]
    if args.heroes:
        render_heroes(out_dir, args)
        return
    if args.only:
        studio.bloom(args.bloom)
        for view in args.only:
            pose(view)
            studio.camera(view)
            studio.render(os.path.join(out_dir, f"quick_{view}.png"), args, view_res=(800, 600))
        return

    report = {"stage": args.stage}
    report["triangles"], _ = C.triangle_count(C.descendants(bpy.data.objects["Oven"]))
    for view in views:
        pose(view)
        studio.camera(view)
        studio.render(os.path.join(out_dir, f"{view}.png"), args)
    slide_racks({})
    if args.stage >= 4:
        render_heroes(out_dir, args)
        report["racks"] = rack_clearance()
    p = lambda name: os.path.join(out_dir, name)  # noqa: E731
    report["proportions_closed"] = I.comparison(I.REF_CLOSED, p("ortho_front.png"), p("compare_closed_ortho.png"))
    report["compare_closed"] = I.comparison(I.REF_CLOSED, p("front_closed.png"), p("compare_closed.png"))
    report["compare_open"] = I.comparison(I.REF_OPEN, p("refmatch_open.png"), p("compare_open.png"))
    report["hinge"] = hinge_test(out_dir, args)
    with open(p("report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print("[render] report " + json.dumps(report))


if __name__ == "__main__":
    main()
