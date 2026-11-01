"""Build the hero oven and save build/oven.blend.

    Blender -b -P scripts/blender/oven.py -- [--stage 2] [--hinge bottom|left] [--angle 0]

Axes: metres, camera looks along +Y, the oven front is the y = 0 plane, Z up, the floor is z = 0.
Every part is its own named object under the `Oven` root empty. The door's origin sits on its
hinge axis: bottom hinge opens with rotation_euler.x = +radians(angle) (0 shut, 88 open); left
hinge opens with rotation_euler.z = -radians(angle). The angle runs 0..180 (DOOR_MAX_ANGLE),
matching the Duo's hinge: 180 hangs straight down in front of the counter edge.

Parts: Body (children RackRails, CrumbTray, Gasket, BodyScrews, HingeKnuckles), Door (DoorGlass,
DoorFrit, DoorHandle, DoorHingeArms), ControlPanel (Display, KnobRings, Knob1-3), Rack1 (upper,
carries Tray1 > Tray1Rim, CakeSlot_A-D), Rack2 (lower, carries Tray2 > Tray2Rim, CakeSlot_E-H),
HeatingElement_Top1/2 and _Bottom1/2 (each with _Caps and an area _Light), Feet (FeetRings).
Each rack is its own object with its origin on its back edge: slide it out along -Y (its tray
comes with it) for plating. Layout numbers live in layout.py.
"""
import argparse
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import door as door_parts  # noqa: E402
import interior  # noqa: E402
import materials  # noqa: E402
from layout import *  # noqa: E402,F403


def build_body(root):
    body = C.box_object("Body", (X0, 0, Z0), (X1, D, Z1), origin=(0, D / 2, Z0), parent=root)

    cuts = C.bmesh.new()
    C.add_box(cuts, (CAV_X0, -0.01, CAV_Z0), (CAV_X1, CAV_Y1, CAV_Z1))
    # Sheet-metal seams (0.7 mm wide, 0.5 mm deep): the wrap meets the front bezel 18 mm back
    # on the top and sides, and the back panel 12 mm from the rear.
    g, d = 0.0007, 0.0005
    for y in (0.018, D - 0.012):
        C.add_box(cuts, (X0 - 0.01, y, Z1 - d), (X1 + 0.01, y + g, Z1 + 0.01))
        C.add_box(cuts, (X0 - 0.01, y, Z0 - 0.01), (X0 + d, y + g, Z1 + 0.01))
        C.add_box(cuts, (X1 - d, y, Z0 - 0.01), (X1 + 0.01, y + g, Z1 + 0.01))
    # Seam where the control column meets the oven on top.
    C.add_box(cuts, (PANEL_X0 - 0.004, 0.018, Z1 - d), (PANEL_X0 - 0.004 + g, D - 0.012, Z1 + 0.01))
    # Vent slits: a block on the top toward the back, two rows on the rear panel.
    for i in range(14):
        x = X0 + 0.06 + i * 0.012
        C.add_box(cuts, (x, D - 0.115, Z1 - 0.003), (x + 0.0045, D - 0.045, Z1 + 0.01))
    for z in (Z1 - 0.040, Z1 - 0.050, Z1 - 0.060, Z1 - 0.070):
        for x in (X0 + 0.07, X0 + 0.20):
            C.add_box(cuts, (x, D - 0.003, z - 0.0018), (x + 0.11, D + 0.01, z + 0.0018))
    C.cut(body, cuts)
    C.finish(body, bevel=0.0018, segments=4)

    build_gasket(body)
    build_screws(body)
    build_hinge_knuckles(body)
    return body


def build_gasket(body):
    """Rubber seal lining the cavity mouth, 6 mm deep, flush with the front."""
    t, depth = 0.004, 0.006
    bm = C.bmesh.new()
    C.add_box(bm, (CAV_X0, -0.0005, CAV_Z0), (CAV_X1, depth, CAV_Z0 + t))
    C.add_box(bm, (CAV_X0, -0.0005, CAV_Z1 - t), (CAV_X1, depth, CAV_Z1))
    C.add_box(bm, (CAV_X0, -0.0005, CAV_Z0), (CAV_X0 + t, depth, CAV_Z1))
    C.add_box(bm, (CAV_X1 - t, -0.0005, CAV_Z0), (CAV_X1, depth, CAV_Z1))
    gasket = C.mesh_object("Gasket", bm, origin=(CAV_XC, 0, CAV_Z0), parent=body)
    C.finish(gasket, bevel=0.0015, segments=4)


def build_screws(body):
    """Small pan-head screws holding the back panel and the side wrap."""
    bm = C.bmesh.new()
    for x in (X0 + 0.02, 0.0, X1 - 0.02):
        for z in (Z0 + 0.015, Z1 - 0.015):
            C.add_cylinder(bm, (x, D + 0.0006, z), 0.0028, 0.0012, axis="Y", segments=20)
    for x in (X0 - 0.0006, X1 + 0.0006):
        for y in (0.06, D - 0.06):
            C.add_cylinder(bm, (x, y, Z0 + 0.012), 0.0028, 0.0012, axis="X", segments=20)
    screws = C.mesh_object("BodyScrews", bm, origin=(0, D, Z0), parent=body)
    C.finish(screws, bevel=0.0004, segments=2)


def build_hinge_knuckles(body):
    """Steel brackets on the body front at each lower corner; the door's arms turn on them."""
    bm = C.bmesh.new()
    for kx0 in (X0 + 0.0006, DOOR_X1 + 0.0046):
        kx1 = kx0 + 0.0028
        C.add_box(bm, (kx0, HINGE_Y, HINGE_Z - 0.007), (kx1, 0.0, HINGE_Z + 0.005))
        C.add_cylinder(bm, ((kx0 + kx1) / 2, HINGE_Y, HINGE_Z), 0.0065, 0.004, axis="X", segments=32)
    knuckles = C.mesh_object("HingeKnuckles", bm, origin=(0, HINGE_Y, HINGE_Z), parent=body)
    C.finish(knuckles, bevel=0.0007)


def build_controls(root):
    panel = C.box_object("ControlPanel", (PANEL_X0, -PANEL_T, DOOR_Z0), (X1 - 0.004, 0.0, DOOR_Z1), parent=root)
    recess = C.bmesh.new()
    dz1 = DOOR_Z1 - 0.014
    C.add_box(recess, (PANEL_XC - 0.034, -PANEL_T - 0.01, dz1 - 0.038), (PANEL_XC + 0.034, -PANEL_T + 0.003, dz1))
    C.cut(panel, recess)
    C.finish(panel, bevel=0.0012)

    display = C.box_object("Display", (PANEL_XC - 0.0335, -PANEL_T + 0.0026, dz1 - 0.0375),
                           (PANEL_XC + 0.0335, -PANEL_T + 0.003, dz1 - 0.0005), parent=panel)
    C.finish(display, smooth=False)

    rings = C.bmesh.new()
    for i, z in enumerate(KNOB_ZS, start=1):
        C.add_ring(rings, (PANEL_XC, -PANEL_T - 0.0003, z), 0.0228, 0.0240, 0.0006, axis="Y", segments=96)
        build_knob(panel, i, z)
    ring_obj = C.mesh_object("KnobRings", rings, origin=(PANEL_XC, -PANEL_T, KNOB_ZS[1]), parent=panel)
    C.finish(ring_obj, angle=60)
    return panel


def build_knob(panel, index, z):
    """Satin knob: a thin skirt, a knurled grip, a chamfered face with a pointer notch at 12 o'clock.
    Origin on the knob's axis at the panel face, so code turns it with rotation_euler.y."""
    y_face = -PANEL_T
    bm = C.bmesh.new()
    C.add_cylinder(bm, (PANEL_XC, y_face - 0.0015, z), 0.0205, 0.003, axis="Y", segments=96)
    C.add_knurled_cylinder(bm, (PANEL_XC, y_face - 0.0030 - 0.0085, z), 0.0178, 0.017, axis="Y")
    knob = C.mesh_object(f"Knob{index}", bm, origin=(PANEL_XC, y_face, z), parent=panel)
    notch = C.bmesh.new()
    front = y_face - 0.003 - 0.017
    C.add_box(notch, (PANEL_XC - 0.0011, front - 0.002, z + 0.004), (PANEL_XC + 0.0011, front + 0.0012, z + 0.0165))
    C.cut(knob, notch)
    C.finish(knob, bevel=0.0007, segments=3, angle=40)


def build_feet(root):
    """Rubber feet, slightly tapered, each under a thin steel ring."""
    rubber, rings = C.bmesh.new(), C.bmesh.new()
    for x in (X0 + 0.045, X1 - 0.045):
        for y in (0.045, D - 0.045):
            C.add_cylinder(rubber, (x, y, (FOOT_H - 0.003) / 2), 0.0155, FOOT_H - 0.003, axis="Z",
                           segments=40, radius2=0.0135)
            C.add_ring(rings, (x, y, FOOT_H - 0.0015), 0.010, 0.0165, 0.003, axis="Z", segments=48)
    feet = C.mesh_object("Feet", rubber, origin=(0, D / 2, 0), parent=root)
    C.finish(feet, bevel=0.002, segments=4, angle=40)
    ring_obj = C.mesh_object("FeetRings", rings, origin=(0, D / 2, FOOT_H), parent=feet)
    C.finish(ring_obj, bevel=0.0004, segments=2, angle=60)


def set_door(angle, hinge):
    door = bpy.data.objects["Door"]
    door.rotation_euler = (0, 0, 0)
    if hinge == "left":
        door.rotation_euler.z = -math.radians(angle)
    else:
        door.rotation_euler.x = math.radians(angle)


def build(stage, hinge):
    root = C.empty("Oven", size=0.1)
    body = build_body(root)
    door_parts.build(root, hinge)
    build_controls(root)
    interior.build(root, body)
    build_feet(root)
    materials.assign()
    root["stage"] = stage
    root["hinge"] = hinge
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=2)
    parser.add_argument("--hinge", choices=("bottom", "left"), default="bottom")
    parser.add_argument("--angle", type=float, default=0, help="door angle, 0..180")
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
