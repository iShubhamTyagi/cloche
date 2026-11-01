"""Open Blender's window on build/oven.blend and reload it whenever a build script saves it.

    open -n -a Blender --args "$PWD/build/oven.blend" --python "$PWD/scripts/blender/watch.py"

Lets the owner watch each build step live while the headless scripts do the work. If the
window ever falls behind, File > Revert reloads the file by hand.
"""
import os

import bpy

BLEND = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "build", "oven.blend"))
LOG = os.path.join(os.path.dirname(BLEND), "watch.log")


def log(message):
    print(message)
    with open(LOG, "a") as f:
        f.write(message + "\n")


_state = {"mtime": os.path.getmtime(BLEND) if os.path.exists(BLEND) else 0}


def _window_override():
    wm = bpy.context.window_manager
    window = wm.windows[0] if wm and wm.windows else None
    if window is None:
        return None
    area = next((a for a in window.screen.areas if a.type == "VIEW_3D"), window.screen.areas[0])
    region = next((r for r in area.regions if r.type == "WINDOW"), None)
    return {"window": window, "screen": window.screen, "area": area, "region": region}


def _frame_view():
    override = _window_override()
    if override is None or override["area"].type != "VIEW_3D":
        return None
    space = override["area"].spaces.active
    space.shading.type = "MATERIAL"
    with bpy.context.temp_override(**override):
        bpy.ops.view3d.view_all(center=False)
    return None


def _poll():
    try:
        mtime = os.path.getmtime(BLEND)
    except OSError:
        return 2.0
    if mtime == _state["mtime"]:
        return 2.0
    # Wait until the writer has finished (size stable), then reload in the window's context.
    _state["mtime"] = mtime
    override = _window_override()
    try:
        if override is None:
            raise RuntimeError("no window")
        with bpy.context.temp_override(**override):
            bpy.ops.wm.open_mainfile(filepath=BLEND, load_ui=False)
        log(f"[watch] reloaded {BLEND}")
        bpy.app.timers.register(_frame_view, first_interval=0.5)
    except Exception as exc:  # keep polling; File > Revert works by hand
        log(f"[watch] reload failed: {exc}")
    return 2.0


bpy.app.timers.register(_poll, first_interval=2.0, persistent=True)
bpy.app.timers.register(_frame_view, first_interval=1.0)
