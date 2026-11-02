"""The baking dishes on the oven racks, as layers over the app's oven frames.

    Blender -b -P scripts/blender/dish_layers.py -- [--samples 64] [--force]
    (run after app_export.py, which clears the folder)

From camera.json's "frames" view at 1000 x 1200 (the oven frames' own pixel space), with the
oven at full heat. Three loads, one per bake length:
  cupcakes  the muffin tin (liners, four cupcakes) on the upper tray      (Quick)
  cake1     one round cake tin on the upper tray                         (Medium)
  cake2     two round cake tins, one on each tray                        (Long)
For each: dish_<kind>_0..5.png along the bake (rise and browning together, raw to golden),
dish_<kind>_dark.png (over-baked), and dish_<kind>_free.png (raw, nothing cut away: the dish
flying in). In the bake states every oven part in front is a holdout (cavity edges, the upper
rack and tray over the lower cake), and the door is left out: door_mask_NNN.png (one per door
frame, 500 x 600, alpha = the door's frame, handle and hinges) lets the app cut the door back in
at any angle. oven_dishes.json lists all of it. Into Features/Resources/OvenRender.
"""
import argparse
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import bake_materials as BM  # noqa: E402
import common as C  # noqa: E402
import materials  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402
from layout import DOOR_MAX_ANGLE  # noqa: E402

DST = os.path.join(C.REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources", "OvenRender")
# Along the bake: progress, rise, browning (golden path); then the over-baked state.
PATH = [(0.0, 0.0, 0.0), (0.2, 0.25, 0.03), (0.4, 0.55, 0.10), (0.6, 0.85, 0.25), (0.8, 1.0, 0.45),
        (1.0, 1.0, 0.62)]
DARK = (1.0, 1.0, 0.92)
DOOR_PARTS = ("Door", "DoorHandle", "DoorHingeArms", "DoorFrit")


def append(path):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    objs = [o for o in dst.objects if o is not None]
    for o in objs:
        bpy.context.scene.collection.objects.link(o)
    return objs


def dish_light(scale=0.15):
    """The tubes' area lights sit ~2 cm over the crowns and blow them out to white; the dish
    layer shows only the dishes, so the lights are toned down for it alone."""
    for o in bpy.data.objects:
        if o.type == "LIGHT" and "watts_at_full" in o:
            o.data.energy *= scale


def load(kind):
    """Append this load's dishes into the oven scene. Returns their objects."""
    if kind == "cupcakes":
        objs = append(os.path.join(C.BUILD, "muffin_tin_golden.blend"))
    else:
        objs = append(os.path.join(C.BUILD, "cake_tin_golden.blend"))
        if kind == "cake2":
            lower = append(os.path.join(C.BUILD, "cake_tin_golden.blend"))
            dz = C.world_bounds(["Tray2"])[0].z - C.world_bounds(["Tray1"])[0].z
            for o in lower:
                if o.parent is None:
                    o.location.z += dz
            objs += lower
    for o in objs:
        if o.type == "EMPTY":
            o.hide_render = True
    BM.assign(objs)
    bpy.context.view_layer.update()
    return objs


def set_state(objs, rise, browning):
    for o in objs:
        if "rise" in o and o.data is not None and getattr(o.data, "shape_keys", None) is not None:
            o["rise"] = float(rise)
        if "browning" in o:
            o["browning"] = float(browning)
    BM.set_browning(browning)
    bpy.context.view_layer.update()


def oven_meshes():
    return [o for o in C.descendants(bpy.data.objects["Oven"]) if o.type == "MESH"]


def mode(dishes, cut_by_oven):
    """Dishes drawn; the oven either cut in as holdout (bake states) or invisible (free)."""
    door = {o.name for o in C.descendants(bpy.data.objects["Door"])}
    for o in oven_meshes():
        if o.name in door:
            o.visible_camera, o.is_holdout = False, False
        else:
            o.visible_camera, o.is_holdout = cut_by_oven, cut_by_oven
    for o in dishes:
        if o.type == "MESH":
            o.visible_camera = True
    floor = bpy.data.objects.get("Floor")
    if floor:
        floor.visible_camera = False


def main():
    parser = argparse.ArgumentParser()
    studio.add_render_args(parser, samples=64)
    args = C.script_args(parser)
    args.force = True if args.force else args.force
    res = tuple(studio.views()["frames"]["resolution"])
    manifest = {"source": "scripts/blender/dish_layers.py", "camera": "build/camera.json views.frames",
                "resolution": list(res), "states": [{"progress": p, "rise": r, "browning": b} for p, r, b in PATH],
                "dark": {"rise": DARK[1], "browning": DARK[2]}, "kinds": {}, "door_masks": None}

    for kind in ("cupcakes", "cake1", "cake2"):
        bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
        studio.use()
        materials.set_heat(1.0)
        dish_light()
        R.set_door(0)
        studio.camera("frames")
        dishes = load(kind)
        names = []
        mode(dishes, cut_by_oven=True)
        for k, (_, rise, browning) in enumerate(PATH):
            set_state(dishes, rise, browning)
            name = f"dish_{kind}_{k}"
            studio.render(os.path.join(DST, f"{name}.png"), args, view_res=res)
            names.append(name)
        set_state(dishes, DARK[1], DARK[2])
        studio.render(os.path.join(DST, f"dish_{kind}_dark.png"), args, view_res=res)
        mode(dishes, cut_by_oven=False)
        set_state(dishes, 0.0, 0.0)
        studio.render(os.path.join(DST, f"dish_{kind}_free.png"), args, view_res=res)
        manifest["kinds"][kind] = {"states": names, "dark": f"dish_{kind}_dark", "free": f"dish_{kind}_free"}

    # Door masks: only the door's opaque parts, at every frame's angle.
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
    studio.use()
    studio.camera("frames")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.visible_camera = o.name in DOOR_PARTS
    count = 48
    mask_args = argparse.Namespace(**vars(args))
    mask_args.samples, mask_args.res = 4, (res[0] // 2, res[1] // 2)
    masks = []
    for i in range(count):
        R.set_door(DOOR_MAX_ANGLE * i / (count - 1))
        name = f"door_mask_{i:03d}"
        studio.render(os.path.join(DST, f"{name}.png"), mask_args)
        masks.append(name)
    manifest["door_masks"] = {"names": masks, "scale": 0.5}
    with open(os.path.join(DST, "oven_dishes.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    size = sum(os.path.getsize(os.path.join(DST, f)) for f in os.listdir(DST) if f.startswith(("dish_", "door_mask")))
    print(f"[dishes] done, {size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
