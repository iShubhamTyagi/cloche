"""Render the stage slab as the app's background layer, from the app's two cameras.

    Blender -b -P scripts/blender/slab_export.py -- [--samples 64] [--force]

The oven frames and the station images were rendered on an invisible shadow-catcher counter;
this draws what was missing under them: the honed marble slab, from camera.json's "frames" view
(-> OvenRender/slab_oven.png) and "station" view (-> StationRender/slab_station.png), at the
same 1000 x 1200, so they sit exactly behind the oven and the stand. The oven, stand and their
shadows are not in these images (the shadows are already in the frames, drawn over the slab).
Run after app_export.py and station_export.py (they clear their folders).
"""
import argparse
import os
import shutil
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import studio  # noqa: E402

FEATURES = os.path.join(C.REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources")
OUT = os.path.join(C.BUILD, "renders", "slab", "app")


def main():
    parser = argparse.ArgumentParser()
    studio.add_render_args(parser, samples=64)
    args = C.script_args(parser)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "slab.blend"))
    # The slab is the ground here; the studio's shadow catcher would only add a second floor.
    studio.use(ground=False, station=True)
    for o in bpy.context.scene.objects:
        if o.type == "EMPTY":
            o.hide_render = True
    os.makedirs(OUT, exist_ok=True)
    for view, name, folder in (("frames", "slab_oven.png", "OvenRender"), ("station", "slab_station.png", "StationRender")):
        studio.camera(view)
        path = os.path.join(OUT, name)
        studio.render(path, args, view_res=tuple(studio.views()[view]["resolution"]))
        dst = os.path.join(FEATURES, folder)
        if os.path.isdir(dst):
            shutil.copy(path, os.path.join(dst, name))
            print(f"[slab_export] {name} -> {os.path.relpath(dst, C.REPO)}")


if __name__ == "__main__":
    main()
