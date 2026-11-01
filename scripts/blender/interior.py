"""Inside the cavity: two wire racks on side rails, the enamel tray with a rolled rim (on the
upper rack), quartz heating tubes with ceramic end caps and wall mounts, and a crumb tray."""
import bpy

import common as C
from layout import (CAKE_SPACING, ELEMENT_LIGHT_COLOR, ELEMENT_LIGHT_WATTS, TRAYS, CAV_X0, CAV_X1, CAV_XC, CAV_Y1, CAV_Z0, ELEMENT_R, ELEMENT_YS,
                    ELEMENT_ZS, FRAME_ROD_R, RACKS, RAIL_LEVELS, ROD_R, TRAY_DEPTH, TRAY_X0, TRAY_X1,
                    TRAY_Y0, TRAY_Y1)

RACK_Y0, RACK_Y1 = 0.020, CAV_Y1 - 0.012
RACK_X0, RACK_X1 = CAV_X0 + 0.007, CAV_X1 - 0.007


def build(root, body):
    build_rails(body)
    build_crumb_tray(body)
    for name, z in RACKS.items():
        rack = build_rack(root, name, z)
        rack["slides"] = "-Y"           # code pulls it out along -Y from its back-edge origin
        tray_name, letters = TRAYS[name]
        build_tray(rack, z, tray_name, letters)
    for prefix, z in ELEMENT_ZS.items():
        for i, y in enumerate(ELEMENT_YS[prefix], start=1):
            build_element(root, f"HeatingElement_{prefix}{i}", y, z)


def build_rails(body):
    """Pressed ribs on both side walls; each rack's frame rests on a pair."""
    bm = C.bmesh.new()
    for z in RAIL_LEVELS:
        rz = z - FRAME_ROD_R - 0.002
        for x0, x1 in ((CAV_X0 - 0.001, CAV_X0 + 0.004), (CAV_X1 - 0.004, CAV_X1 + 0.001)):
            C.add_box(bm, (x0, 0.012, rz - 0.002), (x1, CAV_Y1 - 0.004, rz + 0.002))
    rails = C.mesh_object("RackRails", bm, origin=(CAV_XC, 0.2, 0.2), parent=body)
    C.finish(rails, bevel=0.0012)


def build_rack(root, name, z):
    """Wire rack of round rods: a perimeter frame, rods front to back every 22 mm, and two
    cross bars underneath. Origin at the back edge so code can slide it out along -Y."""
    bm = C.bmesh.new()
    length_x, length_y = RACK_X1 - RACK_X0, RACK_Y1 - RACK_Y0
    xc, yc = (RACK_X0 + RACK_X1) / 2, (RACK_Y0 + RACK_Y1) / 2
    for y in (RACK_Y0, RACK_Y1):
        C.add_cylinder(bm, (xc, y, z), FRAME_ROD_R, length_x + 2 * FRAME_ROD_R, axis="X", segments=16)
    for x in (RACK_X0, RACK_X1):
        C.add_cylinder(bm, (x, yc, z), FRAME_ROD_R, length_y, axis="Y", segments=16)
    count = int(length_x / 0.022)
    pitch = length_x / count
    for i in range(1, count):
        C.add_cylinder(bm, (RACK_X0 + i * pitch, yc, z), ROD_R, length_y, axis="Y", segments=12)
    for y in (RACK_Y0 + length_y / 3, RACK_Y0 + 2 * length_y / 3):
        C.add_cylinder(bm, (xc, y, z - FRAME_ROD_R - ROD_R + 0.0004), FRAME_ROD_R * 0.9, length_x, axis="X", segments=16)
    rack = C.mesh_object(name, bm, origin=(xc, RACK_Y1, z), parent=root)
    C.finish(rack, angle=60)
    return rack


def build_tray(rack, rack_z, name, letters):
    """Black enamel tray with sloped walls and a rolled rim, four cake slots on its floor.
    A child of its rack, so it comes out with it; code can also lift it off on its own."""
    base = rack_z + FRAME_ROD_R
    inset = 0.006            # walls slope in toward the floor
    bm = C.bmesh.new()
    C.add_box(bm, (TRAY_X0, TRAY_Y0, base), (TRAY_X1, TRAY_Y1, base + TRAY_DEPTH))
    for v in bm.verts:
        if v.co.z < base + 0.001:
            v.co.x += inset if v.co.x < CAV_XC else -inset
            v.co.y += inset if v.co.y < (TRAY_Y0 + TRAY_Y1) / 2 else -inset
    tray = C.mesh_object(name, bm, origin=((TRAY_X0 + TRAY_X1) / 2, (TRAY_Y0 + TRAY_Y1) / 2, base), parent=rack)

    hollow = C.bmesh.new()
    wall = 0.0012
    C.add_box(hollow, (TRAY_X0 + wall, TRAY_Y0 + wall, base + wall), (TRAY_X1 - wall, TRAY_Y1 - wall, base + TRAY_DEPTH + 0.01))
    for v in hollow.verts:
        if v.co.z < base + wall + 0.001:
            v.co.x += inset if v.co.x < CAV_XC else -inset
            v.co.y += inset if v.co.y < (TRAY_Y0 + TRAY_Y1) / 2 else -inset
    C.cut(tray, hollow)

    # Rolled rim: a tube round the top edge, with round corners.
    rim = C.bmesh.new()
    r = 0.0022
    top = base + TRAY_DEPTH
    C.add_cylinder(rim, ((TRAY_X0 + TRAY_X1) / 2, TRAY_Y0, top), r, TRAY_X1 - TRAY_X0, axis="X", segments=16)
    C.add_cylinder(rim, ((TRAY_X0 + TRAY_X1) / 2, TRAY_Y1, top), r, TRAY_X1 - TRAY_X0, axis="X", segments=16)
    C.add_cylinder(rim, (TRAY_X0, (TRAY_Y0 + TRAY_Y1) / 2, top), r, TRAY_Y1 - TRAY_Y0, axis="Y", segments=16)
    C.add_cylinder(rim, (TRAY_X1, (TRAY_Y0 + TRAY_Y1) / 2, top), r, TRAY_Y1 - TRAY_Y0, axis="Y", segments=16)
    for x in (TRAY_X0, TRAY_X1):
        for y in (TRAY_Y0, TRAY_Y1):
            C.add_sphere(rim, (x, y, top), r, segments=16)
    rim_obj = C.mesh_object(f"{name}Rim", rim, origin=tray.location, parent=tray)
    C.finish(rim_obj, angle=80)
    C.finish(tray, bevel=0.0008, segments=2)

    yc = (TRAY_Y0 + TRAY_Y1) / 2
    for i, letter in enumerate(letters):
        x = CAV_XC + (i - 1.5) * CAKE_SPACING
        slot = C.empty(f"CakeSlot_{letter}", (0, 0, 0), size=0.03, kind="SINGLE_ARROW")
        slot.parent = tray
        bpy.context.view_layer.update()
        slot.matrix_world = C.Matrix.Translation((x, yc, base + wall))


def build_element(root, name, y, z):
    """Quartz tube between ceramic end caps that sit in steel mounts on the side walls.
    The tube is the object (its own material later); caps and mounts are a child."""
    tube_x0, tube_x1 = CAV_X0 + 0.016, CAV_X1 - 0.016
    bm = C.bmesh.new()
    C.add_cylinder(bm, ((tube_x0 + tube_x1) / 2, y, z), ELEMENT_R, tube_x1 - tube_x0, axis="X", segments=24)
    tube = C.mesh_object(name, bm, origin=((tube_x0 + tube_x1) / 2, y, z), parent=root)
    C.finish(tube, angle=60)

    bm = C.bmesh.new()
    for wall, inward in ((CAV_X0, 1), (CAV_X1, -1)):
        cap_c = wall + inward * 0.012
        C.add_cylinder(bm, (cap_c, y, z), ELEMENT_R + 0.002, 0.016, axis="X", segments=24)
        C.add_box(bm, (min(wall, wall + inward * 0.005), y - 0.009, z - 0.009),
                  (max(wall, wall + inward * 0.005), y + 0.009, z + 0.009))
    caps = C.mesh_object(f"{name}_Caps", bm, origin=tube.location, parent=tube)
    C.finish(caps, bevel=0.0008)

    # A thin area light along the tube so its glow lights the racks and walls (the emissive
    # tube alone is too small for Cycles to sample cleanly). Top tubes shine down, bottom up.
    data = bpy.data.lights.new(f"{name}_Light", "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = tube_x1 - tube_x0, 0.010
    data.color = ELEMENT_LIGHT_COLOR
    data.energy = 0.0
    light = bpy.data.objects.new(f"{name}_Light", data)
    light["watts_at_full"] = ELEMENT_LIGHT_WATTS
    light.visible_camera = False
    shines_down = name.startswith("HeatingElement_Top")
    offset = -(ELEMENT_R + 0.001) if shines_down else ELEMENT_R + 0.001
    light.location = ((tube_x0 + tube_x1) / 2, y, z + offset)
    if not shines_down:
        light.rotation_euler = (3.14159265, 0, 0)
    C.link(light)
    bpy.context.view_layer.update()
    light.parent = tube
    light.matrix_parent_inverse = tube.matrix_world.inverted()


def build_crumb_tray(body):
    """Shallow pull-out pan on the cavity floor with a finger tab at the front."""
    x0, x1 = CAV_X0 + 0.004, CAV_X1 - 0.004
    y0, y1 = 0.004, CAV_Y1 - 0.006
    z0, z1 = CAV_Z0, CAV_Z0 + 0.007
    bm = C.bmesh.new()
    C.add_box(bm, (x0, y0, z0), (x1, y1, z1))
    pan = C.mesh_object("CrumbTray", bm, origin=((x0 + x1) / 2, y0, z0), parent=body)
    inner = C.bmesh.new()
    C.add_box(inner, (x0 + 0.001, y0 + 0.001, z0 + 0.001), (x1 - 0.001, y1 - 0.001, z1 + 0.01))
    C.cut(pan, inner)
    tab = C.bmesh.new()
    C.add_box(tab, (CAV_XC - 0.03, y0 - 0.002, z0), (CAV_XC + 0.03, y0 + 0.001, z0 + 0.013))
    tab_obj = C.mesh_object("CrumbTrayTab", tab, origin=pan.location, parent=pan)
    C.finish(pan, bevel=0.0006, segments=2)
    C.finish(tab_obj, bevel=0.0008)
