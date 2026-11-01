"""Build the hero oven and save build/oven.blend.

    Blender -b -P scripts/blender/oven.py -- [--stage 1] [--hinge bottom|left] [--angle 0]

Axes: metres, camera looks along +Y, the oven front is the y = 0 plane, Z up, the floor is z = 0.
Every part is its own named object under the `Oven` root empty. The door's origin sits on its
hinge axis: bottom hinge opens with rotation_euler.x = +radians(angle) (0 shut, 88 open); left
hinge opens with rotation_euler.z = -radians(angle).

Stages add detail on top of the same layout: 1 blockout. (Later stages extend `build`.)
"""
import argparse
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402

# ------------------------------------------------------------------ layout (metres)
W, H, D = 0.52, 0.35, 0.40          # overall incl. feet; 0.35 not the brief's 0.33 so the front reads ~1.45:1 like the reference
FOOT_H = 0.032                      # feet lift the body so the open door's handle clears the floor
X0, X1 = -W / 2, W / 2
Z0, Z1 = FOOT_H, H                  # body shell
PANEL_X0 = 0.162                    # control column starts here (to X1)

DOOR_X0, DOOR_X1 = X0 + 0.008, PANEL_X0 - 0.010
DOOR_Z0, DOOR_Z1 = Z0 + 0.008, Z1 - 0.008
DOOR_T = 0.024                      # door thickness; it sits proud of the front, y in [-DOOR_T, 0]
DOOR_BORDER = 0.020                 # frame width around the glass (sides and bottom)
DOOR_TOP_BAND = 0.042               # thicker top band that carries the handle, as in the reference

CAV_X0, CAV_X1 = X0 + 0.025, PANEL_X0 - 0.027
CAV_Z0, CAV_Z1 = Z0 + 0.028, Z1 - 0.030
CAV_Y1 = D - 0.025

RACK_Z = (CAV_Z0 + CAV_Z1) / 2 - 0.012
ELEMENT_R = 0.0055
ELEMENT_YS = (0.11, 0.27)
TRAY_DEPTH = 0.018
CAKE_SPACING = 0.072


def build_body(root):
    body = C.box_object("Body", (X0, 0, Z0), (X1, D, Z1), origin=(0, D / 2, Z0), parent=root)
    cutter = C.box_object("cavity_cut", (CAV_X0, -0.01, CAV_Z0), (CAV_X1, CAV_Y1, CAV_Z1))
    C.boolean_difference(body, cutter)
    return body


def build_door(root, hinge):
    bm = C.bmesh.new()
    b = DOOR_BORDER
    y0, y1 = -DOOR_T, 0.0
    # Frame: four bars around the glass.
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z0), (DOOR_X1, y1, DOOR_Z0 + b))
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z1 - DOOR_TOP_BAND), (DOOR_X1, y1, DOOR_Z1))
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z0 + b), (DOOR_X0 + b, y1, DOOR_Z1 - DOOR_TOP_BAND))
    C.add_box(bm, (DOOR_X1 - b, y0, DOOR_Z0 + b), (DOOR_X1, y1, DOOR_Z1 - DOOR_TOP_BAND))
    pivot = (DOOR_X0, -DOOR_T, DOOR_Z0) if hinge == "left" else ((DOOR_X0 + DOOR_X1) / 2, -DOOR_T, DOOR_Z0)
    door = C.mesh_object("Door", bm, origin=pivot, parent=root)
    door["hinge"] = hinge

    bm = C.bmesh.new()
    C.add_box(bm, (DOOR_X0 + b - 0.002, -DOOR_T * 0.6, DOOR_Z0 + b - 0.002),
              (DOOR_X1 - b + 0.002, -DOOR_T * 0.3, DOOR_Z1 - DOOR_TOP_BAND + 0.002))
    C.mesh_object("DoorGlass", bm, origin=pivot, parent=door)

    # Handle on two standoffs, on the edge opposite the hinge.
    bm = C.bmesh.new()
    reach = 0.030
    if hinge == "left":
        hx = DOOR_X1 - 0.016
        zc = (DOOR_Z0 + DOOR_Z1) / 2
        C.add_cylinder(bm, (hx, -DOOR_T - reach, zc), 0.0065, 0.22, axis="Z")
        for dz in (-0.09, 0.09):
            C.add_cylinder(bm, (hx, -DOOR_T - reach / 2, zc + dz), 0.005, reach, axis="Y")
    else:
        hz = DOOR_Z1 - DOOR_TOP_BAND / 2
        xc = (DOOR_X0 + DOOR_X1) / 2
        C.add_cylinder(bm, (xc, -DOOR_T - reach, hz), 0.0065, 0.30, axis="X")
        for dx in (-0.125, 0.125):
            C.add_cylinder(bm, (xc + dx, -DOOR_T - reach / 2, hz), 0.005, reach, axis="Y")
    C.mesh_object("DoorHandle", bm, origin=pivot, parent=door)
    return door


def build_controls(root):
    panel = C.box_object("ControlPanel", (PANEL_X0, -0.006, DOOR_Z0), (X1 - 0.004, 0.0, DOOR_Z1), parent=root)
    cx = (PANEL_X0 + X1) / 2
    C.box_object("Display", (cx - 0.034, -0.0065, DOOR_Z1 - 0.050), (cx + 0.034, -0.006, DOOR_Z1 - 0.016), parent=panel)
    for i, z in enumerate((DOOR_Z1 - 0.115, DOOR_Z1 - 0.180, DOOR_Z1 - 0.245), start=1):
        bm = C.bmesh.new()
        C.add_cylinder(bm, (cx, -0.006 - 0.010, z), 0.019, 0.020, axis="Y", segments=48)
        C.mesh_object(f"Knob{i}", bm, origin=(cx, -0.006, z), parent=panel)
    return panel


def build_interior(root):
    length = CAV_X1 - CAV_X0 - 0.020
    xc = (CAV_X0 + CAV_X1) / 2
    for prefix, z in (("Top", CAV_Z1 - 0.018), ("Bottom", CAV_Z0 + 0.016)):
        for i, y in enumerate(ELEMENT_YS, start=1):
            bm = C.bmesh.new()
            C.add_cylinder(bm, (xc, y, z), ELEMENT_R, length, axis="X")
            C.mesh_object(f"HeatingElement_{prefix}{i}", bm, origin=(xc, y, z), parent=root)

    # Rack: origin at its back edge, so code can slide it out along -Y.
    rack = C.box_object("Rack", (CAV_X0 + 0.006, 0.020, RACK_Z - 0.003), (CAV_X1 - 0.006, CAV_Y1 - 0.010, RACK_Z),
                        origin=(xc, CAV_Y1 - 0.010, RACK_Z), parent=root)

    tray_x0, tray_x1 = xc - 0.155, xc + 0.155
    tray_y0, tray_y1 = 0.075, 0.315
    tray = C.box_object("Tray", (tray_x0, tray_y0, RACK_Z), (tray_x1, tray_y1, RACK_Z + TRAY_DEPTH), parent=rack)
    yc = (tray_y0 + tray_y1) / 2
    for i, letter in enumerate("ABCD"):
        x = xc + (i - 1.5) * CAKE_SPACING
        slot = C.empty(f"CakeSlot_{letter}", (0, 0, 0), size=0.03, kind="SINGLE_ARROW")
        slot.parent = tray
        bpy.context.view_layer.update()
        slot.matrix_world = C.Matrix.Translation((x, yc, RACK_Z + 0.004))
    return rack


def build_feet(root):
    bm = C.bmesh.new()
    for x in (X0 + 0.045, X1 - 0.045):
        for y in (0.045, D - 0.045):
            C.add_cylinder(bm, (x, y, FOOT_H / 2), 0.014, FOOT_H, axis="Z")
    return C.mesh_object("Feet", bm, origin=(0, D / 2, 0), parent=root)


def set_door(angle, hinge):
    door = bpy.data.objects["Door"]
    door.rotation_euler = (0, 0, 0)
    if hinge == "left":
        door.rotation_euler.z = -math.radians(angle)
    else:
        door.rotation_euler.x = math.radians(angle)


def build(stage, hinge):
    root = C.empty("Oven", size=0.1)
    build_body(root)
    build_door(root, hinge)
    build_controls(root)
    build_interior(root)
    build_feet(root)
    root["stage"] = stage
    root["hinge"] = hinge
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--hinge", choices=("bottom", "left"), default="bottom")
    parser.add_argument("--angle", type=float, default=0)
    parser.add_argument("--out", default=os.path.join(C.BUILD, "oven.blend"))
    args = C.script_args(parser)

    C.reset_scene()
    bpy.context.scene.unit_settings.system = "METRIC"
    build(args.stage, args.hinge)
    set_door(args.angle, args.hinge)

    total, per = C.triangle_count()
    print(f"[oven] stage {args.stage}, hinge {args.hinge}: {total} triangles")
    for name, n in sorted(per.items()):
        print(f"[oven]   {name}: {n}")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=args.out)
    print(f"[oven] saved {args.out}")


if __name__ == "__main__":
    main()
