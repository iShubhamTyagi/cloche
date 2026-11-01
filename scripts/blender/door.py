"""The door: steel-framed double smoked glass with a ceramic-frit border, a handle on two
standoffs, and two chunky hinge arms. Origin on the hinge axis; children rotate with it."""
import common as C
from layout import (DOOR_BORDER, DOOR_T, DOOR_TOP_BAND, DOOR_X0, DOOR_X1, DOOR_Z0, DOOR_Z1,
                    HINGE_Y, HINGE_Z, X0)

GLASS_T = 0.004
FRIT_W = 0.007


def build(root, hinge):
    b, top = DOOR_BORDER, DOOR_TOP_BAND
    y0, y1 = -DOOR_T, 0.0
    if hinge == "left":
        pivot = (DOOR_X0, -DOOR_T, DOOR_Z0)
    else:
        pivot = ((DOOR_X0 + DOOR_X1) / 2, HINGE_Y, HINGE_Z)

    # Frame: four bars around the glass, a 3 mm lip on the inner edges holds the panes.
    bm = C.bmesh.new()
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z0), (DOOR_X1, y1, DOOR_Z0 + b))
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z1 - top), (DOOR_X1, y1, DOOR_Z1))
    C.add_box(bm, (DOOR_X0, y0, DOOR_Z0 + b - 0.001), (DOOR_X0 + b, y1, DOOR_Z1 - top + 0.001))
    C.add_box(bm, (DOOR_X1 - b, y0, DOOR_Z0 + b - 0.001), (DOOR_X1, y1, DOOR_Z1 - top + 0.001))
    door = C.mesh_object("Door", bm, origin=pivot, parent=root)
    C.finish(door, bevel=0.0015)
    door["hinge"] = hinge

    # Glass opening, overlapping the frame by 3 mm so no gap shows.
    gx0, gx1 = DOOR_X0 + b - 0.003, DOOR_X1 - b + 0.003
    gz0, gz1 = DOOR_Z0 + b - 0.003, DOOR_Z1 - top + 0.003

    # Double glazing: outer pane near the front, inner pane near the back, 14 mm air gap.
    bm = C.bmesh.new()
    C.add_box(bm, (gx0, y0 + 0.002, gz0), (gx1, y0 + 0.002 + GLASS_T, gz1))
    C.add_box(bm, (gx0 + 0.004, y1 - 0.002 - GLASS_T, gz0 + 0.004), (gx1 - 0.004, y1 - 0.002, gz1 - 0.004))
    glass = C.mesh_object("DoorGlass", bm, origin=pivot, parent=door)
    C.finish(glass, bevel=0.0006, segments=2)

    # Black ceramic frit printed on the back of the outer pane, round its edge.
    fy0 = y0 + 0.002 + GLASS_T
    bm = C.bmesh.new()
    for lo, hi in (((gx0, fy0, gz0), (gx1, fy0 + 0.0003, gz0 + FRIT_W)),
                   ((gx0, fy0, gz1 - FRIT_W), (gx1, fy0 + 0.0003, gz1)),
                   ((gx0, fy0, gz0 + FRIT_W), (gx0 + FRIT_W, fy0 + 0.0003, gz1 - FRIT_W)),
                   ((gx1 - FRIT_W, fy0, gz0 + FRIT_W), (gx1, fy0 + 0.0003, gz1 - FRIT_W))):
        C.add_box(bm, lo, hi)
    C.mesh_object("DoorFrit", bm, origin=pivot, parent=door)

    build_handle(door, pivot, hinge)
    build_hinge_arms(door, pivot)
    return door


def build_handle(door, pivot, hinge):
    """Brushed bar on two standoffs with round foot flanges, 30 mm off the door."""
    reach = 0.030
    bm = C.bmesh.new()
    if hinge == "left":
        hx, zc = DOOR_X1 - 0.016, (DOOR_Z0 + DOOR_Z1) / 2
        C.add_cylinder(bm, (hx, -DOOR_T - reach, zc), 0.0065, 0.22, axis="Z", segments=40)
        for dz in (-0.09, 0.09):
            C.add_cylinder(bm, (hx, -DOOR_T - reach / 2, zc + dz), 0.0048, reach, axis="Y", segments=32)
            C.add_cylinder(bm, (hx, -DOOR_T - 0.0015, zc + dz), 0.0085, 0.003, axis="Y", segments=32)
    else:
        hz, xc = DOOR_Z1 - DOOR_TOP_BAND / 2, (DOOR_X0 + DOOR_X1) / 2
        C.add_cylinder(bm, (xc, -DOOR_T - reach, hz), 0.0065, 0.30, axis="X", segments=40)
        for dx in (-0.125, 0.125):
            C.add_cylinder(bm, (xc + dx, -DOOR_T - reach / 2, hz), 0.0048, reach, axis="Y", segments=32)
            C.add_cylinder(bm, (xc + dx, -DOOR_T - 0.0015, hz), 0.0085, 0.003, axis="Y", segments=32)
    handle = C.mesh_object("DoorHandle", bm, origin=pivot, parent=door)
    C.finish(handle, bevel=0.0012)


def build_hinge_arms(door, pivot):
    """Steel arms down each side edge of the door, ending in a round boss on the hinge axis.
    They pivot on the body's knuckles (see oven.build_hinge_knuckles)."""
    bm = C.bmesh.new()
    for ax0 in (X0 + 0.004, DOOR_X1):
        ax1 = ax0 + 0.004
        C.add_box(bm, (ax0, -DOOR_T, HINGE_Z), (ax1, -0.003, HINGE_Z + 0.062))
        C.add_cylinder(bm, ((ax0 + ax1) / 2, HINGE_Y, HINGE_Z), 0.0085, 0.004, axis="X", segments=32)
    arms = C.mesh_object("DoorHingeArms", bm, origin=pivot, parent=door)
    C.finish(arms, bevel=0.0008)
