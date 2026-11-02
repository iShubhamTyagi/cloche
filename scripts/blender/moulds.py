"""Baking moulds with their cakes, fitted to the oven's Tray1, in any bake state.

    Blender -b -P scripts/blender/moulds.py -- --dish cupcake|cake|both --state raw|half|golden|dark
        [--rise 0..1] [--browning 0..1] [--seed 1] [--stage 1] [--out build/moulds_<state>.blend]
        [--preview | --final] [--res W H] [--samples N] [--force]

Reads build/oven.blend first: Tray1's floor and the CakeSlot_A..D empties place everything (the
cupcake tin's cups sit on the slots; the round tin sits at Tray1's centre). Objects keep oven
coordinates, origin at the centre of each object's base: MuffinTin, Liner_1..4, Cupcake_1..4,
RoundTin, Cake, CakeTurnout. Sizes are fitted to the oven (owner, 2026-11-02): 60 mm cups on
the slots' 72 mm pitch, and a 200 mm x 44 mm round tin so a full dome clears the top tubes.

Stages: 1 tins and liners (clay); 2 cakes with rise (clay, cakes.py). Later: materials and
browning, lit renders and contact sheet, fit check in the oven tray.
Renders go to build/renders/moulds/stage<N>/, from camera.json's fitted views.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402

STATES = {"raw": (0.00, 0.00), "half": (0.50, 0.15), "golden": (1.00, 0.62), "dark": (1.00, 0.92)}

# Muffin tin (metres). z is measured from the cup's outer base.
CUP = {"top_r": 0.030, "wall_r": 0.0225, "depth": 0.030, "corner": 0.004, "fillet": 0.0025,
       "plate_margin": 0.009, "plate_t": 0.0008, "rim_r": 0.0024, "wall_t": 0.0008}
# Round tin: 200 mm top, 5 degree flare, 44 mm deep.
TIN = {"top_r": 0.100, "depth": 0.044, "flare_deg": 5.0, "corner": 0.004, "rim_r": 0.0022,
       "wall_t": 0.0008, "ring_r": 0.068}
LINER = {"pleats": 40, "pleat_a": 0.00045, "gap": 0.0006, "paper_t": 0.00012, "lip": 0.0015}


# ------------------------------------------------------------------ reading the oven

def read_oven():
    """Tray1 floor height, its centre, and the four cake slots, from build/oven.blend."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, "oven.blend"))
    missing = [n for n in ("Tray1", "CakeSlot_A", "CakeSlot_B", "CakeSlot_C", "CakeSlot_D") if n not in bpy.data.objects]
    if missing:
        raise SystemExit(f"oven.blend is missing {missing}: ask the owner before changing anything")
    lo, hi = C.world_bounds(["Tray1"])
    slots = [tuple(bpy.data.objects[f"CakeSlot_{n}"].matrix_world.translation) for n in "ABCD"]
    floor_z = slots[0][2]
    return {"slots": slots, "floor_z": floor_z, "centre": ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, floor_z),
            "tray_lo": tuple(lo), "tray_hi": tuple(hi)}


# ------------------------------------------------------------------ geometry helpers

def arc(cx, cz, r, a0, a1, steps):
    """Points (r, z) along a circular arc in the profile plane, angles in degrees."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


def densify(profile, step=0.004):
    """Insert points along long segments so smooth shading stays local to real curvature."""
    out = [profile[0]]
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        n = max(1, int(math.hypot(r1 - r0, z1 - z0) / step))
        out += [(r0 + (r1 - r0) * k / n, z0 + (z1 - z0) * k / n) for k in range(1, n + 1)]
    return out


def lathe(bm, profile, centre, segments=128):
    """Revolve an open (r, z) profile about the vertical axis through `centre`."""
    profile = densify(profile)
    rings = []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        ring = []
        for r, z in profile:
            ring.append(bm.verts.new((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), centre[2] + z)))
        rings.append(ring)
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    return rings


def torus(bm, centre, major, minor, segments=128, sides=16):
    profile = [(major + minor * math.cos(2 * math.pi * k / sides), minor * math.sin(2 * math.pi * k / sides))
               for k in range(sides + 1)]
    lathe(bm, profile, centre, segments)


def solidify(obj, thickness, offset=0.0):
    mod = obj.modifiers.new("Thickness", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = offset
    mod.use_even_offset = True
    return mod


def bake_modifiers(obj):
    """Apply modifiers into the mesh (so later joins and booleans see the real shape)."""
    for mod in list(obj.modifiers):
        with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
            bpy.ops.object.modifier_apply(modifier=mod.name)


def join(target, others):
    for o in others:
        o.select_set(True)
    target.select_set(True)
    with bpy.context.temp_override(active_object=target, selected_editable_objects=[target, *others],
                                   selected_objects=[target, *others]):
        bpy.ops.object.join()
    return target


# ------------------------------------------------------------------ muffin tin and liners

def cup_profile():
    """Outer surface of one cup, base centre up to where it meets the plate (z = depth)."""
    c = CUP
    pts = [(0.0, 0.0), (0.0125, 0.0), (0.0128, 0.00025), (0.0131, 0.0)]          # tiny base seam
    flat_r = c["wall_r"] - c["corner"]
    pts.append((flat_r, 0.0))
    pts += arc(flat_r, c["corner"], c["corner"], -90, 0, 8)[1:]                     # base corner
    top_wall = (c["top_r"], c["depth"] - c["fillet"])
    pts.append(top_wall)
    pts += arc(c["top_r"] + c["fillet"], c["depth"] - c["fillet"], c["fillet"], 180, 90, 6)[1:]  # into plate
    return pts


def build_muffin_tin(oven):
    slots = oven["slots"]
    c = CUP
    base_z = oven["floor_z"]
    top_z = base_z + c["depth"]
    xs = [s[0] for s in slots]
    y = slots[0][1]
    hole_r = c["top_r"] + c["fillet"]
    half_x = (max(xs) - min(xs)) / 2 + hole_r + c["plate_margin"]
    half_y = hole_r + c["plate_margin"]
    cx = (max(xs) + min(xs)) / 2

    # Plate with rounded corners (built from its outline) and four holes.
    bm = bmesh.new()
    outline = rounded_rect(cx, y, half_x, half_y, 0.010, 10)
    top = [bm.verts.new((px, py, top_z)) for px, py in outline]
    bottom = [bm.verts.new((px, py, top_z - c["plate_t"])) for px, py in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    n = len(outline)
    for k in range(n):
        bm.faces.new((bottom[k], bottom[(k + 1) % n], top[(k + 1) % n], top[k]))
    tin = C.mesh_object("MuffinTin", bm, origin=(cx, y, base_z))
    holes = bmesh.new()
    for x in xs:
        C.add_cylinder(holes, (x, y, top_z), hole_r - 0.0002, 0.01, axis="Z", segments=128)
    C.cut(tin, holes)

    # Cups: the outer surface revolved, given its sheet-metal thickness.
    parts = []
    for i, x in enumerate(xs):
        bm = bmesh.new()
        lathe(bm, cup_profile(), (x, y, base_z))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
        cup = C.mesh_object(f"cup_{i}", bm, origin=(x, y, base_z))
        solidify(cup, c["wall_t"], offset=-1.0)
        bake_modifiers(cup)
        parts.append(cup)

    # Rolled stiffening rim round the plate edge (a tube following the rounded rectangle).
    curve = bpy.data.curves.new("rim", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = c["rim_r"]
    curve.bevel_resolution = 6
    spline = curve.splines.new("POLY")
    outline = rounded_rect(cx, y, half_x - 0.0004, half_y - 0.0004, 0.010, 10)
    spline.points.add(len(outline) - 1)
    for p, (px, py) in zip(spline.points, outline):
        p.co = (px, py, top_z - c["rim_r"] * 0.55, 1)
    spline.use_cyclic_u = True
    rim_obj = bpy.data.objects.new("rim", curve)
    C.link(rim_obj)
    rim_mesh = bpy.data.meshes.new_from_object(rim_obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(rim_obj)
    rim = bpy.data.objects.new("rim_mesh", rim_mesh)
    C.link(rim)
    parts.append(rim)
    join(tin, parts)
    C.finish(tin, bevel=0.0003, segments=2, angle=50)
    tin["fits"] = "Tray1, cups on CakeSlot_A..D"
    return tin


def rounded_rect(cx, cy, hx, hy, r, steps):
    pts = []
    for (sx, sy, a0) in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        ox, oy = cx + sx * (hx - r), cy + sy * (hy - r)
        for k in range(steps + 1):
            a = math.radians(a0 + 90 * k / steps)
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a)))
    return pts


def liner_radius(z):
    """Liner wall radius at height z above the cup's outer base: the cup's inner wall, less a
    small gap."""
    c = CUP
    z0, z1 = c["corner"], c["depth"] - c["fillet"]
    t = min(max((z - z0) / (z1 - z0), 0.0), 1.0)
    return c["wall_r"] + (c["top_r"] - c["wall_r"]) * t - c["wall_t"] - LINER["gap"]


def build_liner(index, slot):
    """Pleated paper cup: flat base, ~40 radial pleats fading out toward the base, and a small
    outward rim fold at the top."""
    c, L = CUP, LINER
    x, y, z_base = slot
    base_z = c["wall_t"] + 0.0003
    top_z = c["depth"] - 0.0008
    rings, steps = 44, L["pleats"] * 6
    bm = bmesh.new()
    grid = []
    for j in range(rings + 1):
        t = j / rings
        z = base_z + 0.0035 + (top_z - base_z - 0.0035) * t
        r = liner_radius(z)
        lip = max(0.0, (t - 0.94) / 0.06)                         # flare over the last 6%
        r += L["lip"] * lip ** 2
        z -= 0.0006 * lip ** 3                                     # the fold turns slightly down
        fade = min(1.0, max(0.0, (z - base_z - 0.002) / 0.005))
        row = []
        for k in range(steps):
            a = 2 * math.pi * k / steps
            pr = r + L["pleat_a"] * fade * math.sin(L["pleats"] * a)
            row.append(bm.verts.new((x + pr * math.cos(a), y + pr * math.sin(a), z_base + z)))
        grid.append(row)
    for j in range(rings):
        for k in range(steps):
            k2 = (k + 1) % steps
            bm.faces.new((grid[j][k], grid[j][k2], grid[j + 1][k2], grid[j + 1][k]))
    # Base: a rounded crease from the flat bottom into the wall, then a fan to the centre.
    bottom = []
    r_flat = liner_radius(base_z) - 0.0035
    for k in range(steps):
        a = 2 * math.pi * k / steps
        bottom.append(bm.verts.new((x + r_flat * math.cos(a), y + r_flat * math.sin(a), z_base + base_z)))
    for k in range(steps):
        k2 = (k + 1) % steps
        bm.faces.new((bottom[k], bottom[k2], grid[0][k2], grid[0][k]))
    centre = bm.verts.new((x, y, z_base + base_z))
    for k in range(steps):
        bm.faces.new((centre, bottom[(k + 1) % steps], bottom[k]))
    liner = C.mesh_object(f"Liner_{index}", bm, origin=(x, y, z_base))
    solidify(liner, L["paper_t"], offset=0.0)
    liner.data.shade_smooth()
    return liner


# ------------------------------------------------------------------ round tin

def build_round_tin(oven):
    t = TIN
    x, y, z = oven["centre"]
    flare = math.tan(math.radians(t["flare_deg"]))
    base_r = t["top_r"] - t["depth"] * flare
    flat_r = base_r - t["corner"]
    pts = [(0.0, 0.0), (t["ring_r"] - 0.0006, 0.0), (t["ring_r"], 0.0003), (t["ring_r"] + 0.0006, 0.0),
           (flat_r, 0.0)]
    pts += arc(flat_r, t["corner"], t["corner"], -90, 0, 8)[1:]
    pts.append((t["top_r"], t["depth"] - t["rim_r"]))
    bm = bmesh.new()
    lathe(bm, pts, (x, y, z), segments=192)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    tin = C.mesh_object("RoundTin", bm, origin=(x, y, z))
    solidify(tin, t["wall_t"], offset=-1.0)
    bake_modifiers(tin)
    # Rolled rim curling outward at the top.
    bm = bmesh.new()
    torus(bm, (x, y, z + t["depth"] - t["rim_r"]), t["top_r"] + t["rim_r"] * 0.6, t["rim_r"], segments=192)
    rim = C.mesh_object("tin_rim", bm, origin=(x, y, z))
    join(tin, [rim])
    C.finish(tin, bevel=0.0003, segments=2, angle=50)
    tin["fits"] = "Tray1 centre"
    return tin


# ------------------------------------------------------------------ checks and renders

def fit_report(oven, tin, round_tin):
    lo, hi = C.world_bounds([tin.name])
    rlo, rhi = C.world_bounds([round_tin.name])
    tlo, thi = Vector(oven["tray_lo"]), Vector(oven["tray_hi"])
    return {
        "muffin_tin_mm": [round((hi - lo).x * 1000, 1), round((hi - lo).y * 1000, 1), round((hi - lo).z * 1000, 1)],
        "muffin_tin_inside_tray_footprint": bool(lo.x >= tlo.x and hi.x <= thi.x and lo.y >= tlo.y and hi.y <= thi.y),
        "round_tin_mm": [round((rhi - rlo).x * 1000, 1), round((rhi - rlo).z * 1000, 1)],
        "round_tin_inside_tray_footprint": bool(rlo.x >= tlo.x and rhi.x <= thi.x and rlo.y >= tlo.y and rhi.y <= thi.y),
        "headroom_above_tins_mm": {"muffin": round((0.2745 - hi.z) * 1000, 1), "round": round((0.2745 - rhi.z) * 1000, 1)},
    }


TOP_TUBE_BOTTOM = 0.2745   # from oven.blend: HeatingElement_Top* lowest point (layout ELEMENT_ZS)


def set_rise(objs, rise, browning=None):
    for o in objs:
        if "rise" in o and o.data.shape_keys is not None:
            o["rise"] = float(rise)
        if browning is not None and "browning" in o:
            o["browning"] = float(browning)
    bpy.context.view_layer.update()


def isolate(objs):
    for other in bpy.context.scene.objects:
        if other.type == "MESH" and other.name != "Floor":
            other.hide_render = other not in objs


class OnCounter:
    """Temporarily drop a dish from oven height onto the studio counter for an isolated render."""

    def __init__(self, objs):
        self.objs = [o for o in objs if o.parent is None]
        self.dz = C.world_bounds([o.name for o in objs if o.type == "MESH"])[0].z

    def __enter__(self):
        for o in self.objs:
            o.location.z -= self.dz
        bpy.context.view_layer.update()

    def __exit__(self, *exc):
        for o in self.objs:
            o.location.z += self.dz
        bpy.context.view_layer.update()


def render_dish(name, objs, cakes, out_dir, args, states):
    """Three-quarter view per state, top-down at the last state, all from camera.json."""
    isolate(objs)
    with OnCounter(objs):
        set_rise(cakes, 1.0)
        bounds = C.world_bounds([o.name for o in objs if o.type == "MESH"])
        paths = []
        for state in states:
            set_rise(cakes, *STATES[state])
            studio.camera("three_quarter", subject=bounds)
            path = os.path.join(out_dir, f"{name}_{state}_three_quarter.png")
            studio.render(path, args)
            paths.append(path)
        studio.camera("topdown", subject=bounds)
        studio.render(os.path.join(out_dir, f"{name}_{states[-1]}_topdown.png"), args)
    return paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dish", choices=("cupcake", "cake", "both"), default="both")
    parser.add_argument("--state", choices=tuple(STATES), default="golden")
    parser.add_argument("--rise", type=float, default=None)
    parser.add_argument("--browning", type=float, default=None)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--stage", type=int, default=2)
    parser.add_argument("--turnout", choices=("flipped", "upright"), default="flipped")
    parser.add_argument("--states", default=",".join(STATES), help="comma list to render, e.g. golden")
    parser.add_argument("--out", default=None)
    studio.add_render_args(parser)
    args = C.script_args(parser)
    rise, browning = STATES[args.state]
    rise = args.rise if args.rise is not None else rise
    browning = args.browning if args.browning is not None else browning

    import cakes  # noqa: E402  (imports this module; keep the import here)
    import random
    rng = random.Random(args.seed)
    oven = read_oven()
    C.reset_scene()
    studio.use()
    tin = build_muffin_tin(oven)
    liners = [build_liner(i + 1, s) for i, s in enumerate(oven["slots"])]
    round_tin = build_round_tin(oven)
    report = fit_report(oven, tin, round_tin)
    cupcakes, cake, turnout = [], None, None
    if args.stage >= 2:
        cupcakes = [cakes.build_cupcake(i + 1, s, rng, rise, browning) for i, s in enumerate(oven["slots"])]
        cake = cakes.build_cake(oven["centre"], rng, rise, browning)
        turnout = cakes.build_turnout(oven["centre"], rng, browning, flipped=args.turnout == "flipped")
        set_rise(cupcakes + [cake], 1.0)
        top_cup = C.world_bounds([o.name for o in cupcakes])[1].z
        top_cake = C.world_bounds([cake.name])[1].z
        report["full_rise_clearance_to_top_tubes_mm"] = {
            "cupcakes": round((TOP_TUBE_BOTTOM - top_cup) * 1000, 1),
            "cake": round((TOP_TUBE_BOTTOM - top_cake) * 1000, 1)}
        set_rise(cupcakes + [cake], rise, browning)
    everything = [tin, *liners, round_tin, *cupcakes] + ([cake, turnout] if cake else [])
    print(f"[moulds] fit {report}")
    print(f"[moulds] triangles {C.triangle_count(everything)[0]}")

    out_dir = os.path.join(C.BUILD, "renders", "moulds", f"stage{args.stage}")
    if args.stage <= 2:
        R.apply_clay(everything)
    states = args.states.split(",") if args.stage >= 2 else ["raw"]
    strips = []
    if args.dish in ("cupcake", "both"):
        strips += render_dish("cupcake", [tin, *liners, *cupcakes], cupcakes, out_dir, args, states)
    if args.dish in ("cake", "both"):
        strips += render_dish("cake", [round_tin, cake] if cake else [round_tin], [cake] if cake else [],
                              out_dir, args, states)
        if turnout:
            isolate([turnout])
            with OnCounter([turnout]):
                bounds = C.world_bounds([turnout.name])
                for view in ("three_quarter", "topdown"):
                    studio.camera(view, subject=bounds)
                    studio.render(os.path.join(out_dir, f"cake_turnout_{view}.png"), args)
    if strips:
        import imaging as I
        I.grid(strips, os.path.join(out_dir, "states.png"), columns=len(states), cell_h=300)
    for o in bpy.context.scene.objects:
        o.hide_render = False
    set_rise([o for o in everything if "rise" in o], rise, browning)
    out = args.out or os.path.join(C.BUILD, f"moulds_{args.state}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print(f"[moulds] saved {os.path.relpath(out, C.REPO)}")


if __name__ == "__main__":
    main()
