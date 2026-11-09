"""Decorating step 2: the topping models and the HUD bowl icons (docs/prompts/toppings.md).

    $B -b -P scripts/blender/toppings.py [-- --force --samples N]

Outputs: build/toppings.blend (every model in topping_models.MODELS, three variants each, at the
origin, for toppings3d.py and station.py), build/renders/toppings/icons/<topping>.png (256 px,
transparent, a natural heap seen from above with a soft shadow), icons_sheet.png, manifest.json.
"""
import argparse
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D  # noqa: E402
import topping_models as T  # noqa: E402

OUT = os.path.join(D.OUT, "toppings")
# HUD topping: [(model, count)], heap radius (m)
HEAPS = {
    "berries": ([("raspberry", 5), ("blueberry", 8)], 0.017),
    "raspberries": ([("raspberry", 8)], 0.018),
    "blueberries": ([("blueberry", 14)], 0.018),
    "mint": ([("mint_leaf", 9)], 0.024),
    "chocolate_shavings": ([("chocolate_curl", 9), ("chocolate_shard", 4)], 0.025),
    "gold_flakes": ([("gold_flake", 40)], 0.02),
    "sprinkles": ([("sprinkle", 160)], 0.022),
    "sugar_pearls": ([("sugar_pearl", 80)], 0.021),
    "crushed_pistachio": ([("pistachio_crumb", 90)], 0.022),
    "flower_petals": ([("flower_petal", 10)], 0.024),
}
EXTENT = 0.068


def heap(name, parts, radius, protos):
    """Scatter copies of the prototypes into a dome-shaped pile at the station centre."""
    rng = random.Random(name)
    placed = []
    height = radius * 0.55
    for model, count in parts:
        variants = [p for k, p in protos.items() if k.startswith(model + "_")]
        for i in range(count):
            r = radius * math.sqrt(rng.random())
            a = rng.uniform(0, 2 * math.pi)
            dome = height * (1 - (r / radius) ** 2) ** 0.8
            z = dome * rng.uniform(0.55, 1.0)
            obj = variants[i % len(variants)].copy()
            bpy.context.scene.collection.objects.link(obj)
            obj.location = D.STATION + Vector((r * math.cos(a), r * math.sin(a), z))
            tilt = 0.5 if model in ("sprinkle", "sugar_pearl", "pistachio_crumb", "gold_flake") else 0.35
            obj.rotation_euler = Euler((rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), rng.uniform(0, 2 * math.pi)))
            obj.hide_render = False
            placed.append(obj)
    return placed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--samples", type=int, default=48)
    args = C.script_args(parser)
    D.setup(samples=args.samples)
    materials = T.mats()
    protos = {}
    for kind in T.MODELS:
        for v in range(5 if kind == "sprinkle" else 3):
            obj = T.build(kind, v, hero=True, materials=materials)
            obj.hide_render = True
            protos[obj.name] = obj
    D.sprite_camera(EXTENT, res=256)
    icons, manifest = [], {}
    for topping, (parts, radius) in HEAPS.items():
        placed = heap(topping, parts, radius, protos)
        path = os.path.join(OUT, "icons", f"{topping}.png")
        D.render(path, 256, samples=args.samples, force=args.force)
        icons.append(path)
        manifest[topping] = {"icon": f"icons/{topping}.png", "models": [m for m, _ in parts],
                             "extent_mm": EXTENT * 1000}
        for o in placed:
            bpy.data.objects.remove(o)
    D.sheet(icons, os.path.join(OUT, "icons_sheet.png"), columns=4, cell=256)
    D.write_json(os.path.join(OUT, "manifest.json"),
                 {"icons": manifest, "size_mb": D.dir_mb(os.path.join(OUT, "icons")), "budget_mb": 5})
    # toppings.blend: the models alone, at the origin.
    for o in list(bpy.data.objects):
        if o.name not in protos:
            bpy.data.objects.remove(o)
    for o in protos.values():
        o.hide_render = False
        o.location = (0, 0, 0)
    D.save_blend(os.path.join(C.BUILD, "toppings.blend"))
    print(f"[toppings] icons {D.dir_mb(os.path.join(OUT, 'icons'))} MB")


if __name__ == "__main__":
    main()
