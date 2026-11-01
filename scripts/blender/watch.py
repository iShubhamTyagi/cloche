"""Open Blender's window on build/oven.blend and reload it whenever a build script saves it.

    open -a Blender --args "build/oven.blend" --python scripts/blender/watch.py

Lets the owner watch each build step live while the headless scripts do the work.
"""
import os

import bpy

BLEND = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "build", "oven.blend"))
_state = {"mtime": os.path.getmtime(BLEND) if os.path.exists(BLEND) else 0}


def _frame_view():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type != "VIEW_3D":
                continue
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "SOLID"
                    space.shading.color_type = "OBJECT"
                    space.overlay.show_floor = True
            region = next((r for r in area.regions if r.type == "WINDOW"), None)
            if region is not None:
                with bpy.context.temp_override(window=window, area=area, region=region):
                    bpy.ops.view3d.view_all(center=False)


def _poll():
    try:
        mtime = os.path.getmtime(BLEND)
    except OSError:
        return 2.0
    if mtime != _state["mtime"]:
        _state["mtime"] = mtime
        bpy.ops.wm.open_mainfile(filepath=BLEND)
        print(f"[watch] reloaded {BLEND}")
        bpy.app.timers.register(_frame_view, first_interval=0.5)
    return 2.0


bpy.app.timers.register(_poll, first_interval=2.0, persistent=True)
bpy.app.timers.register(_frame_view, first_interval=1.0)
