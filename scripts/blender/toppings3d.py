"""Decorating step 5: the toppings as low-poly 3D models for the live viewer
(docs/prompts/toppings3d.md).

    $B -b -P scripts/blender/toppings3d.py [-- --force]

Builds from topping_models.py (the same models as toppings.py, without the hero subdivision):
twelve toppings x 3 variants plus one sprinkle rod (tinted at runtime). Each USDZ is Y-up,
metres, pivot at the contact point, +Y = the surface normal. Materials are constant
UsdPreviewSurface values (the models are untextured), so there are no atlases to ship.
Outputs: build/renders/viewer/toppings/<name>_<variant>.usdz, toppings3d_manifest.json,
check sheet (top, 45 degrees, side).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D  # noqa: E402
import topping_models as T  # noqa: E402

OUT = os.path.join(D.OUT, "viewer", "toppings")
KINDS = [k for k in T.MODELS if k != "sprinkle"]


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_materials=True,
                          convert_orientation=True, export_global_forward_selection="NEGATIVE_Z",
                          export_global_up_selection="Y", apply_subdiv=False, export_uvmaps=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    args = C.script_args(parser)
    D.setup(samples=24)
    mats = T.mats()
    manifest = {}
    objs = []
    for kind in KINDS + ["sprinkle"]:
        for v in (range(1) if kind == "sprinkle" else range(3)):
            obj = T.build(kind, v, hero=False, materials=mats)
            for m in list(obj.modifiers):            # bake the solidify (curls) into the mesh
                bpy.context.view_layer.objects.active = obj
                bpy.ops.object.modifier_apply(modifier=m.name)
            name = f"{kind}_{v}"
            tris = C.triangle_count([obj])[0]
            lo, hi = C.world_bounds([obj.name])
            radius = max(hi[0] - lo[0], hi[1] - lo[1]) / 2
            path = os.path.join(OUT, f"{name}.usdz")
            if args.force or not os.path.exists(path):
                os.makedirs(OUT, exist_ok=True)
                export(obj, path)
            manifest[name] = {"file": f"{name}.usdz", "triangles": tris, "radius_mm": round(radius * 1000, 2),
                              "height_mm": round((hi[2] - lo[2]) * 1000, 2), "pivot": "contact point, +Y normal"}
            objs.append(obj)
    over = {k: v["triangles"] for k, v in manifest.items() if v["triangles"] > (100 if k.startswith("sprinkle") else 1500)}
    # Check renders: every first variant from the top, at 45 degrees and from the side.
    sheet = []
    firsts = [o for o in objs if o.name.endswith("_0")]
    for o in objs:
        o.hide_render = True
    for i, o in enumerate(firsts):
        o.hide_render = False
        o.location = D.STATION
        for view, elev in (("top", 90), ("45", 45), ("side", 8)):
            cam = D.sprite_camera(0.04, centre=D.STATION, res=200, roll=False)
            cam.data.type = "PERSP"
            cam.data.lens = 100
            e = math.radians(elev)
            cam.location = D.STATION + Vector((0, -0.3 * math.cos(e), 0.3 * math.sin(e) + 0.004))
            cam.rotation_euler = (math.pi / 2 - e, 0, 0)
            path = os.path.join(OUT, "check", f"{o.name}_{view}.png")
            D.render(path, 200, samples=24, force=args.force)
            sheet.append(path)
        o.hide_render = True
    D.sheet(sheet, os.path.join(OUT, "check_sheet.png"), columns=9, cell=140)
    usdz_mb = round(sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".usdz")) / 1e6, 2)
    D.write_json(os.path.join(OUT, "toppings3d_manifest.json"),
                 {"models": manifest, "over_triangle_budget": over, "size_mb": usdz_mb, "budget_mb": 8})
    print(f"[toppings3d] {len(manifest)} models, {usdz_mb} MB, over budget: {over}")


if __name__ == "__main__":
    main()
