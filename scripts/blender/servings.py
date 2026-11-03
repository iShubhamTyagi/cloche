"""The serving the tongs lift out of the oven, and the trays it leaves behind.

    Blender -b -P scripts/blender/servings.py -- [--samples 48] [--force]
    (run after dish_layers.py; adds to OvenRender and to oven_dishes.json)

For every bake state (dish_layers.PATH, plus over-baked), from the oven's "frames" camera:
  serving_<cupcake|cake>_<k|dark>.png  the serving alone, nothing cut away: one cupcake in its
                                       liner (slot B), or the whole upper cake out of its tin
  dish_<kind>_taken_<k|dark>.png       that load with the serving gone (oven parts in front cut
                                       in, as in dish_layers.py)
and in oven_dishes.json, per kind: the taken names, the serving names, and the serving's pixel
box (x, y, w, h, top-left origin) in the frames image. The station camera has the same lens,
distance and resolution, so the app sets the same image on the stand at the same size.
"""
import argparse
import json
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import dish_layers as DL  # noqa: E402
import imaging as I  # noqa: E402
import materials  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402

SERVING = {"cupcakes": ("cupcake", ("Cupcake_2", "Liner_2")), "cake1": ("cake", ("Cake",)),
           "cake2": ("cake", ("Cake",))}


def main():
    parser = argparse.ArgumentParser()
    studio.add_render_args(parser, samples=48)
    args = C.script_args(parser)
    res = tuple(studio.views()["frames"]["resolution"])
    states = [(f"{k}", r, b) for k, (_, r, b) in enumerate(DL.PATH)] + [("dark", DL.DARK[1], DL.DARK[2])]
    path = os.path.join(DL.DST, "oven_dishes.json")
    with open(path) as f:
        manifest = json.load(f)
    done_servings = set()

    for kind, (serving_name, serving_objs) in SERVING.items():
        bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
        studio.use()
        materials.set_heat(1.0)
        DL.dish_light()
        R.set_door(0)
        studio.camera("frames")
        dishes = DL.load(kind)
        serving = [bpy.data.objects[n] for n in serving_objs]
        taken = []
        # The load without the serving, oven in front cut in.
        DL.mode(dishes, cut_by_oven=True)
        for o in serving:
            o.hide_render = True
        for tag, rise, browning in states:
            DL.set_state(dishes, rise, browning)
            name = f"dish_{kind}_taken_{tag}"
            studio.render(os.path.join(DL.DST, f"{name}.png"), args, view_res=res)
            taken.append(name)
        manifest["kinds"][kind]["taken"] = taken[:-1]
        manifest["kinds"][kind]["taken_dark"] = taken[-1]
        # The serving alone (once per serving type), nothing else drawn.
        if serving_name not in done_servings:
            done_servings.add(serving_name)
            DL.mode(dishes, cut_by_oven=False)
            for o in dishes:
                o.hide_render = o not in serving and o.type == "MESH"
            for o in serving:
                o.hide_render = False
            names = []
            for tag, rise, browning in states:
                DL.set_state(dishes, rise, browning)
                name = f"serving_{serving_name}_{tag}"
                studio.render(os.path.join(DL.DST, f"{name}.png"), args, view_res=res)
                names.append(name)
            alpha = np.max([I.load(os.path.join(DL.DST, f"{n}.png"))[..., 3] for n in names], axis=0)
            ys, xs = np.nonzero(alpha > 0.3)        # ignore faint stray samples across the frame
            box = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min()) + 1, int(ys.max() - ys.min()) + 1]
            manifest.setdefault("servings", {})[serving_name] = {"states": names[:-1], "dark": names[-1], "box": box}
            for n in names:                          # clear stray samples outside the serving
                img = I.load(os.path.join(DL.DST, f"{n}.png"))
                keep = np.zeros(img.shape[:2], dtype=bool)
                keep[max(box[1] - 6, 0):box[1] + box[3] + 6, max(box[0] - 6, 0):box[0] + box[2] + 6] = True
                img[~keep] = 0
                I.save(img, os.path.join(DL.DST, f"{n}.png"))
        manifest["kinds"][kind]["serving"] = serving_name

    with open(path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"[servings] done: {json.dumps(manifest['servings'])}")


if __name__ == "__main__":
    main()
