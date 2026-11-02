"""Marble cake stand that doubles as a motorised turntable, and its glass cloche.

    Blender -b -P scripts/blender/cakestand.py -- [--stage 1] [--marble carrara|calacatta|emperador]
        [--brass on|off] [--finial brass|glass] [--plate-angle 0] [--led off|on]
        [--cloche-state on|lifted] [--lift 0..1] [--out build/cakestand.blend]
        [--out-cloche build/cloche.blend]
        [--preview | --final] [--res W H] [--samples N] [--force]

French pâtisserie, quiet luxury; no text, engraving or marks. Metres, Z up, camera along +Y.
The stand sits on the counter at layout.STATION, filmed by camera.json's "station" view (the
oven's "frames" camera slid along the counter), so it shares the oven's scale.

Objects (fixed names): StandBase (static pedestal: foot, turned stem, motor housing), StandPad
(cork, under the foot), BearingRing (static brushed brass, a 3 mm shadow gap below the plate),
TurntablePlate (the rotating marble plate; origin at its exact geometric centre, spins about Z)
with children PlateMarker (brass inlay at 12 o'clock) and CakeSlot_Stand (centre of the top),
StandSwitch (brass push button on the front of the foot) with StandLED (emissive ring, off).
The cloche (Cloche, ClocheFinial, ClocheRim) comes in Stage 3; it seats inboard in a polished
groove on the plate (owner, 2026-11-02: plate 30 cm, cloche 26 cm inner, sizes unchanged).

Stages: 1 base, bearing ring, plate and switch (clay). Later: 2 marble and brass, 3 cloche
(clay), 4 glass and lighting, 5 layers, lift, hotspots, composite check, 6 tilt check, rotation
validation, size report.
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import cakes  # noqa: E402  (revolve: closed solids of revolution)
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402
from layout import STATION  # noqa: E402

# Dimensions (metres). Heights are from the counter (z = 0) at the stand's base centre.
PAD_T = 0.0015
FOOT = {"r": 0.080, "h": 0.026, "edge": 0.004}
STEM = {"h": 0.120, "r_min": 0.016, "r_max": 0.027}
HOUSING = {"r": 0.068, "h": 0.026}
RING = {"r_out": 0.088, "r_in": 0.060, "h": 0.009}
GAP = 0.003                                   # the shadow gap that makes the plate float
PLATE = {"r": 0.150, "t": 0.020, "edge": 0.003}
GROOVE = {"r": 0.1342, "w": 0.0050, "d": 0.0010}     # where the cloche's rim seats
MARKER = {"r": 0.1435, "dot_r": 0.0025}
SWITCH = {"r": 0.009, "depth": 0.004, "led_in": 0.0096, "led_out": 0.0109}

Z_FOOT = PAD_T
Z_STEM = Z_FOOT + FOOT["h"]
Z_HOUSING = Z_STEM + STEM["h"]
Z_RING = Z_HOUSING + HOUSING["h"]
Z_PLATE_BOTTOM = Z_RING + RING["h"] + GAP
Z_PLATE_CENTRE = Z_PLATE_BOTTOM + PLATE["t"] / 2
Z_PLATE_TOP = Z_PLATE_BOTTOM + PLATE["t"]


def at(x=0.0, y=0.0, z=0.0):
    return (STATION[0] + x, STATION[1] + y, STATION[2] + z)


def solid(name, profile, origin, segments=192, parent=None):
    """A closed solid of revolution about the station's vertical axis; profile (r, z) from the
    bottom near the axis round to the top near the axis."""
    coords, faces = cakes.revolve(profile, at(), segments)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(c[k] - origin[k] for k in range(3)) for c in coords], [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    obj.location = origin
    C.link(obj)
    if parent is not None:
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def rounded_step(r0, z0, r1, z1, radius, steps=8):
    """Profile points round a convex corner from the flat (r0..r1 at z0) up the side to z1."""
    pts = [(r0, z0), (r1 - radius, z0)]
    pts += M_arc(r1 - radius, z0 + radius, radius, -90, 0, steps)[1:]
    pts.append((r1, z1))
    return pts


def M_arc(cx, cz, r, a0, a1, steps):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


# ------------------------------------------------------------------ the base

def stem_radius(t):
    """Turned baluster stem, t = 0 at the foot to 1 under the housing: a collar, a slender
    waist, a soft swell, and a collar again."""
    r0, r1 = STEM["r_min"], STEM["r_max"]
    collar = math.exp(-((t - 0.0) / 0.05) ** 2) + math.exp(-((t - 1.0) / 0.05) ** 2)
    swell = 0.55 * math.exp(-((t - 0.36) / 0.16) ** 2)
    ring = 0.35 * math.exp(-((t - 0.78) / 0.025) ** 2)
    return r0 + (r1 - r0) * min(1.0, collar + swell + ring)


def build_base():
    f, h = FOOT, HOUSING
    prof = [(0.0004, Z_FOOT)]
    # Foot: flat underside, a rounded rim, a gentle dome up to the stem.
    prof += rounded_step(0.001, Z_FOOT, f["r"], Z_FOOT + f["h"] - f["edge"] - 0.006, f["edge"])[1:]
    prof += M_arc(f["r"] - f["edge"], Z_FOOT + f["h"] - f["edge"] - 0.006, f["edge"], 0, 90, 8)[1:]
    for k in range(1, 13):
        t = k / 12
        prof.append((f["r"] - f["edge"] - t * (f["r"] - f["edge"] - STEM["r_max"] * 1.15),
                     Z_FOOT + f["h"] - 0.006 + 0.006 * math.sin(t * math.pi / 2)))
    # Stem.
    for k in range(0, 61):
        t = k / 60
        prof.append((stem_radius(t), Z_STEM + STEM["h"] * t))
    # Housing: a flared skirt under the plate, flat top for the bearing ring.
    for k in range(1, 13):
        t = k / 12
        r = STEM["r_max"] + (h["r"] - STEM["r_max"]) * math.sin(t * math.pi / 2)
        prof.append((r, Z_HOUSING + h["h"] * 0.55 * t))
    prof += M_arc(h["r"] - 0.003, Z_HOUSING + h["h"] - 0.003, 0.003, 0, 90, 6)
    prof.append((0.0004, Z_HOUSING + h["h"]))
    base = solid("StandBase", prof, at())
    base.data.shade_smooth()
    base.data.set_sharp_from_angle(angle=math.radians(35))
    base["role"] = "static pedestal; never rotates"
    pad = solid("StandPad", [(0.0004, 0.0), (FOOT["r"] - 0.004, 0.0), (FOOT["r"] - 0.004, PAD_T), (0.0004, PAD_T)], at())
    return base, pad


def build_ring():
    r = RING
    prof = [(r["r_in"] + 0.001, Z_RING)]
    prof += [(r["r_out"] - 0.0015, Z_RING)] + M_arc(r["r_out"] - 0.0015, Z_RING + 0.0015, 0.0015, -90, 0, 4)[1:]
    prof += M_arc(r["r_out"] - 0.0015, Z_RING + r["h"] - 0.0015, 0.0015, 0, 90, 4)
    prof += [(r["r_in"] + 0.0015, Z_RING + r["h"])] + M_arc(r["r_in"] + 0.0015, Z_RING + r["h"] - 0.0015, 0.0015, 90, 180, 4)[1:]
    prof.append((r["r_in"], Z_RING + 0.001))
    bm = bmesh.new()
    import moulds as M
    rings = M.lathe(bm, prof, at(), segments=192)
    # Close the ring's inner bottom seam.
    for i in range(len(rings)):
        a, b = rings[i], rings[(i + 1) % len(rings)]
        bm.faces.new((a[-1], b[-1], b[0], a[0]))
    ring = C.mesh_object("BearingRing", bm, origin=at(z=Z_RING))
    ring.data.shade_smooth()
    ring.data.set_sharp_from_angle(angle=math.radians(35))
    ring["role"] = "static; the plate floats 3 mm above it"
    return ring


# ------------------------------------------------------------------ the plate

def build_plate():
    p, g = PLATE, GROOVE
    e = p["edge"]
    zb, zt = Z_PLATE_BOTTOM, Z_PLATE_TOP
    prof = [(0.0004, zb), (p["r"] - e, zb)]
    prof += M_arc(p["r"] - e, zb + e, e, -90, 0, 8)[1:]
    prof += M_arc(p["r"] - e, zt - e, e, 0, 90, 8)
    # Top face with the cloche's seating groove (a soft polished U).
    prof.append((g["r"] + g["w"] / 2 + 0.0008, zt))
    for k in range(13):
        a = math.pi * k / 12
        prof.append((g["r"] + g["w"] / 2 * math.cos(a), zt - g["d"] * math.sin(a)))
    prof.append((g["r"] - g["w"] / 2 - 0.0008, zt))
    prof.append((0.0004, zt))
    plate = solid("TurntablePlate", prof, at(z=Z_PLATE_CENTRE), segments=256)
    plate.data.shade_smooth()
    plate.data.set_sharp_from_angle(angle=math.radians(35))
    plate.lock_location = (True, True, True)
    plate.lock_rotation = (True, True, False)
    plate["role"] = "rotating marble plate; origin at its geometric centre; spins about Z"

    # Brass inlay dot at 12 o'clock (+Y, away from the viewer), flush with the top.
    bm = bmesh.new()
    C.add_cylinder(bm, at(0, MARKER["r"], zt - 0.0006), MARKER["dot_r"], 0.0013, axis="Z", segments=48)
    marker = C.mesh_object("PlateMarker", bm, origin=at(0, MARKER["r"], zt))
    bpy.context.view_layer.update()
    marker.parent = plate
    marker.matrix_parent_inverse = plate.matrix_world.inverted()
    marker.data.shade_smooth()

    slot = C.empty("CakeSlot_Stand", (0, 0, 0), size=0.04, kind="SINGLE_ARROW")
    slot.parent = plate
    bpy.context.view_layer.update()
    slot.matrix_world = C.Matrix.Translation(at(z=zt))
    return plate


# ------------------------------------------------------------------ the switch

def build_switch(base):
    """Brass push button on the front of the foot (facing the camera, -Y), in a satin bezel,
    with an LED ring round it. Origin on the button's axis at the foot's surface."""
    s = SWITCH
    z = Z_FOOT + FOOT["h"] * 0.45
    y_face = -FOOT["r"] + 0.0006
    bm = bmesh.new()
    C.add_cylinder(bm, at(0, y_face - s["depth"] / 2, z), s["r"], s["depth"], axis="Y", segments=96)
    switch = C.mesh_object("StandSwitch", bm, origin=at(0, y_face, z), parent=base)
    C.finish(switch, bevel=0.0008, segments=4, angle=40)
    switch["role"] = "tap target: starts and stops the turntable"
    bm = bmesh.new()
    C.add_ring(bm, at(0, y_face - 0.0008, z), s["led_in"], s["led_out"], 0.0016, axis="Y", segments=96)
    led = C.mesh_object("StandLED", bm, origin=at(0, y_face, z), parent=switch)
    led.data.shade_smooth()
    led["on"] = False
    return switch, led


# ------------------------------------------------------------------ checks

def checks(plate):
    """Origin at the geometric centre, no wobble through a full turn, and the 3 mm gap."""
    out = {}
    lo, hi = C.world_bounds(["TurntablePlate"])
    centre = (lo + hi) / 2
    out["plate_origin_offset_mm"] = round((plate.matrix_world.translation - centre).length * 1000, 3)
    worst_xy = worst_z = 0.0
    for k in range(24):
        plate.rotation_euler.z = 2 * math.pi * k / 24
        bpy.context.view_layer.update()
        l, h = C.world_bounds(["TurntablePlate"])
        c = (l + h) / 2
        worst_xy = max(worst_xy, math.hypot(c.x - centre.x, c.y - centre.y))
        worst_z = max(worst_z, abs(l.z - lo.z), abs(h.z - hi.z))
    plate.rotation_euler.z = 0
    bpy.context.view_layer.update()
    out["wobble_mm"] = {"centre_xy": round(worst_xy * 1000, 3), "top_bottom_z": round(worst_z * 1000, 3)}
    rlo, rhi = C.world_bounds(["BearingRing"])
    out["gap_mm"] = round((lo.z - rhi.z) * 1000, 2)
    blo, bhi = C.world_bounds(["StandBase", "StandPad"])
    out["sizes_mm"] = {"plate_diameter": round((hi - lo).x * 1000, 1), "plate_thickness": round((hi - lo).z * 1000, 1),
                       "foot_diameter": round((bhi - blo).x * 1000, 1), "stem_height": STEM["h"] * 1000,
                       "overall_height": round(hi.z * 1000, 1)}
    return out


def set_plate_angle(angle):
    plate = bpy.data.objects["TurntablePlate"]
    plate.rotation_euler.z = math.radians(angle)
    bpy.context.view_layer.update()


def render_cloche_stage(args, out_dir, objs, cloche_objs):
    """Cloche seated: the station view and a three-quarter; lifted halfway and fully; and a
    cut-away (front half removed) side view to check the real wall and the rim's seating."""
    import cloche as CL
    shots = []
    CL.set_lift(0.0)
    everything = [o.name for o in objs + cloche_objs]
    bounds = C.world_bounds(everything)
    for name, view, lift in (("seated_station", "station", 0.0), ("seated_three_quarter", "three_quarter", 0.0),
                             ("lift_half_station", "station", 0.5), ("lifted_station", "station", 1.0)):
        CL.set_lift(lift)
        studio.camera(view, subject=None if view == "station" else bounds)
        path = os.path.join(out_dir, f"cloche_{name}.png")
        studio.render(path, args)
        shots.append(path)
    CL.set_lift(0.0)
    # Cut-away: the camera clips everything in front of the stand's centre line (y = STATION y).
    cam = bpy.context.scene.camera
    cam.data.type, cam.data.ortho_scale = "ORTHO", 0.52
    cam.data.clip_start = 2.0
    cam.location = Vector(at(0, -2.0, 0.25))
    studio.aim(cam, at(0, 0, 0.25))
    studio.render(os.path.join(out_dir, "cloche_section.png"), args, view_res=(1000, 1000))
    cam.data.ortho_scale = 0.03
    cam.location = Vector(at(-0.134, -2.0, Z_PLATE_TOP + 0.004))
    studio.aim(cam, at(-0.134, 0, Z_PLATE_TOP + 0.004))
    studio.render(os.path.join(out_dir, "cloche_section_rim.png"), args, view_res=(800, 800))
    cam.data.clip_start = 0.005
    I.grid(shots, os.path.join(out_dir, "sheet.png"), columns=4, cell_h=520)


def cake_props():
    """Two stacked turned-out cake layers on the plate (a test load for the glass; not saved
    in the asset), in a plain golden sponge."""
    import random
    import cakes
    rng = random.Random(1)
    mat = bpy.data.materials.new("PropSponge")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.72, 0.45, 0.20, 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Subsurface Weight"].default_value = 0.15
    props = []
    z = Z_PLATE_TOP
    for _ in range(2):
        layer = cakes.build_turnout(at(z=z), rng, 0.62)
        layer.data.materials.append(mat)
        props.append(layer)
        bpy.context.view_layer.update()
        z = C.world_bounds([layer.name])[1].z
    return props


def render_glass_stage(args, out_dir, objs, cloche_objs):
    """The glass cloche over two cake layers: station view, three-quarter, the glass edge and
    rim close, half lifted, and lifted."""
    import cloche as CL
    # Glass that sees the empty background becomes transparent in the alpha, so the cloche
    # layer composites over the app as glass, not over a black backdrop.
    scene = bpy.context.scene
    scene.cycles.film_transparent_glass = True
    scene.cycles.film_transparent_roughness = 0.15
    props = cake_props()
    studio.keep_oven_lights_off(props)
    CL.set_lift(0.0)
    bounds = C.world_bounds([o.name for o in objs + cloche_objs])
    shots = []
    for name, view, lift in (("seated_station", "station", 0.0), ("seated_three_quarter", "three_quarter", 0.0),
                             ("lift_half_station", "station", 0.5), ("lifted_station", "station", 1.0)):
        CL.set_lift(lift)
        studio.camera(view, subject=None if view == "station" else bounds)
        path = os.path.join(out_dir, f"glass_{name}.png")
        studio.render(path, args)
        shots.append(path)
    CL.set_lift(0.0)
    cam = bpy.context.scene.camera
    cam.data.type, cam.data.lens = "PERSP", 90
    cam.location = Vector(at(0.18, -0.36, Z_PLATE_TOP + 0.03))
    studio.aim(cam, at(0.10, -0.08, Z_PLATE_TOP + 0.02))
    studio.render(os.path.join(out_dir, "glass_detail_rim.png"), args, view_res=(1000, 750))
    cam.location = Vector(at(0.10, -0.30, Z_PLATE_TOP + 0.24))
    studio.aim(cam, at(0, 0, Z_PLATE_TOP + 0.17))
    studio.render(os.path.join(out_dir, "glass_detail_finial.png"), args, view_res=(1000, 750))
    I.grid(shots, os.path.join(out_dir, "sheet.png"), columns=4, cell_h=520)
    for p in props:
        bpy.data.objects.remove(p)


def build_stand():
    base, pad = build_base()
    ring = build_ring()
    plate = build_plate()
    switch, led = build_switch(base)
    return [base, pad, ring, plate, switch, led, bpy.data.objects["PlateMarker"]]


def save_assets(args):
    """Each asset in its own file, holding only that asset (no studio, no other asset), the way
    oven.blend does: build/cakestand.blend (the turntable stand) and build/cloche.blend. Both
    keep their world positions at the plating station, so appended together they fit."""
    C.reset_scene()
    build_stand()
    if args.stage >= 2:
        import stand_materials as SM
        SM.assign(args.marble, args.brass == "on")
        SM.set_led(args.led == "on")
    set_plate_angle(args.plate_angle)
    bpy.context.scene["asset"] = "cakestand"
    bpy.ops.wm.save_as_mainfile(filepath=args.out)
    print(f"[cakestand] saved {os.path.relpath(args.out, C.REPO)}")
    if args.stage >= 3:
        import cloche as CL
        C.reset_scene()
        CL.build()
        if args.stage >= 4:
            import stand_materials as SM
            SM.assign_cloche(args.finial)
        lift = args.lift if args.lift is not None else (1.0 if args.cloche_state == "lifted" else 0.0)
        CL.set_lift(lift)
        bpy.context.scene["asset"] = "cloche"
        bpy.ops.wm.save_as_mainfile(filepath=args.out_cloche)
        print(f"[cakestand] saved {os.path.relpath(args.out_cloche, C.REPO)}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--marble", choices=("carrara", "calacatta", "emperador"), default="carrara")
    parser.add_argument("--brass", choices=("on", "off"), default="on")
    parser.add_argument("--finial", choices=("brass", "glass"), default="brass")
    parser.add_argument("--plate-angle", type=float, default=0.0)
    parser.add_argument("--led", choices=("off", "on"), default="off")
    parser.add_argument("--cloche-state", choices=("on", "lifted"), default="lifted")
    parser.add_argument("--lift", type=float, default=None)
    parser.add_argument("--out", default=os.path.join(C.BUILD, "cakestand.blend"), help="the stand alone")
    parser.add_argument("--out-cloche", default=os.path.join(C.BUILD, "cloche.blend"), help="the cloche alone")
    studio.add_render_args(parser)
    args = C.script_args(parser)

    C.reset_scene()
    studio.use(station=True)
    objs = build_stand()
    plate = bpy.data.objects["TurntablePlate"]
    cloche_objs = []
    if args.stage >= 3:
        import cloche as CL
        cl = CL.build()
        cloche_objs = [cl, bpy.data.objects["ClocheRim"], bpy.data.objects["ClocheFinial"]]
    studio.keep_oven_lights_off(objs + cloche_objs)
    report = checks(plate)
    report["triangles"] = C.triangle_count(objs)[0]
    set_plate_angle(args.plate_angle)
    print(f"[cakestand] {json.dumps(report)}")

    out_dir = os.path.join(C.BUILD, "renders", "cakestand", f"stage{args.stage}")
    if args.stage <= 1:
        R.apply_clay(objs)
    else:
        import stand_materials as SM
        SM.assign(args.marble, args.brass == "on")
        SM.set_led(args.led == "on")
    if cloche_objs:
        report["cloche"] = CL.checks()
        report["triangles"] = C.triangle_count(objs + cloche_objs)[0]
        print(f"[cakestand] cloche {json.dumps(report['cloche'])}")
        if args.stage == 3:
            R.apply_clay(cloche_objs)
            render_cloche_stage(args, out_dir, objs, cloche_objs)
        elif args.stage == 4:
            SM.assign_cloche(args.finial)
            render_glass_stage(args, out_dir, objs, cloche_objs)
        else:
            import stand_layers
            SM.assign_cloche(args.finial)
            report["hotspots"] = stand_layers.run(args, out_dir)
        with open(os.path.join(out_dir, "report.json"), "w") as f:
            json.dump(report, f, indent=2)
        save_assets(args)
        return
    bounds = C.world_bounds([o.name for o in objs])
    shots = []
    for view in ("station", "three_quarter", "topdown"):
        studio.camera(view, subject=None if view == "station" else bounds)
        tag = f"{args.marble}_" if args.stage >= 2 else ""
        path = os.path.join(out_dir, f"stand_{tag}{view}.png")
        studio.render(path, args)
        shots.append(path)
    # A close look at the floating gap and the switch.
    cam = bpy.context.scene.camera
    cam.data.type, cam.data.lens = "PERSP", 100
    cam.location = Vector(at(0.10, -0.42, Z_RING + 0.03))
    studio.aim(cam, at(0.05, 0, Z_RING + 0.006))
    studio.render(os.path.join(out_dir, "detail_gap.png"), args, view_res=(1000, 750))
    cam.location = Vector(at(0.05, -0.30, 0.06))
    studio.aim(cam, at(0, -FOOT["r"], Z_FOOT + FOOT["h"] * 0.45))
    studio.render(os.path.join(out_dir, "detail_switch.png"), args, view_res=(1000, 750))
    I.grid(shots, os.path.join(out_dir, f"sheet_{args.marble}.png" if args.stage >= 2 else "sheet.png"), columns=3, cell_h=500)
    with open(os.path.join(out_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=2)
    save_assets(args)


if __name__ == "__main__":
    main()
