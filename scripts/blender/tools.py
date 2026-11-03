"""Decorating step 3: the minimal tool kit, sprites, brush maps and reference results
(docs/prompts/tools.md).

    $B -b -P scripts/blender/tools.py [-- --force --samples N --stage sprites|brushes|reference]

Outputs in build/renders/tools/:
  sprites/<tool>_<state>_<rot>.png, <tool>_shadow_<rot>.png  512 px, 4 rotations (0/90/180/270)
  brushes/<name>.png (16-bit) + brushes.json                  from brushes.py
  reference/<pattern>_<colour>.png                              Cycles renders of stamped fields
  ring_check.json                                              Python stamping vs a Blender ring
  palette.json, tools_manifest.json, sheets
build/tools.blend keeps the tool and nozzle objects (station.py uses the nozzles).
"""
import argparse
import math
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import brushes as B  # noqa: E402
import common as C  # noqa: E402
import deco_common as D  # noqa: E402
import icing  # noqa: E402

OUT = os.path.join(D.OUT, "tools")
ROTATIONS = (0, 90, 180, 270)
STATES = {
    "PipingCone": ("idle", "active", "idle_clean", "active_clean"),
    "OffsetSpatula": ("idle", "active", "idle_iced", "active_iced"),
    "PourPan": ("idle", "active"),
    "DrizzleBottle": ("idle", "active"),
    "Sieve": ("idle", "active"),
}
# Tools lie tilted with the working end touching z = 0 at the origin (the anchor).
TILT = {"PipingCone": 35, "OffsetSpatula": 8, "PourPan": 0, "DrizzleBottle": 30, "Sieve": 0}


# ------------------------------------------------------------------ materials

def tool_mats():
    m = D.material
    return {
        "parchment": m("Tool_parchment", (0.9, 0.88, 0.84), 0.35, transmission=0.7, ior=1.4),
        "steel": m("Tool_steel", (0.75, 0.75, 0.76), 0.22, metallic=1.0),
        "brushed_steel": D.noise_bump(m("Tool_brushed_steel", (0.7, 0.7, 0.71), 0.32, metallic=1.0), 2000, 0.05),
        "brass": m("Tool_brass", (0.78, 0.56, 0.26), 0.25, metallic=1.0),
        "copper": m("Tool_copper", (0.85, 0.42, 0.25), 0.22, metallic=1.0),
        "tin": m("Tool_tin", (0.8, 0.8, 0.82), 0.2, metallic=1.0),
        "wood": D.noise_bump(m("Tool_wood", (0.12, 0.05, 0.02), 0.45), 300, 0.1),
        "frosted": m("Tool_frosted", (0.95, 0.95, 0.93), 0.3, transmission=0.9, ior=1.46),
        "cap": m("Tool_cap", (0.08, 0.08, 0.08), 0.4),
        "mesh": m("Tool_mesh", (0.6, 0.45, 0.25), 0.4, metallic=1.0, alpha=0.35),
        "powder": m("Tool_powder", (0.97, 0.96, 0.94), 0.9),
    }


# ------------------------------------------------------------------ models

def lathe(name, profile, mat, segments=48, ripple=0):
    """Revolve [(r, z)] around Z at the origin; `ripple` adds that many pleats."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            rr = r * (1 + (0.04 * math.cos(ripple * a) if ripple and r > 0.006 else 0))
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    obj = D.smooth(D.bm_object(name, bm))
    return D.assign(obj, mat)


def box(name, lo, hi, mat, bevel=0.0):
    obj = C.box_object(name, lo, hi)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments = bevel, 3
    return D.assign(obj, mat)


def nozzles(M):
    """NozzleRound, NozzleStar, NozzlePetal: 22 mm tall, tip at the origin."""
    prof = [(0.002, 0.0), (0.0035, 0.0005), (0.0055, 0.012), (0.009, 0.022)]
    round_ = lathe("NozzleRound", prof, M["steel"], 32)
    star = lathe("NozzleStar", [(0.004, 0.0), (0.0055, 0.0005), (0.0065, 0.012), (0.009, 0.022)], M["steel"], 48, ripple=8)
    petal = lathe("NozzlePetal", prof, M["steel"], 32)
    for v in petal.data.vertices:          # flatten the tip into a slit
        if v.co.z < 0.006:
            v.co.y *= 0.35 + 0.65 * v.co.z / 0.006
    return [round_, star, petal]


def piping_cone(M, iced=True):
    profile = [(0.0085, 0.02), (0.012, 0.05), (0.03, 0.17), (0.036, 0.23), (0.02, 0.27), (0.008, 0.285)]
    bag = lathe("PipingCone", profile, M["parchment"], 64, ripple=14)
    coupler = lathe("PipingCone_Coupler", [(0.009, 0.019), (0.0105, 0.021), (0.0105, 0.027), (0.009, 0.029)], M["steel"], 32)
    nozzle = lathe("PipingCone_Nozzle", [(0.002, 0.0), (0.0035, 0.0005), (0.0055, 0.012), (0.009, 0.021)], M["steel"], 32)
    parts = [bag, coupler, nozzle]
    if iced:
        fill = lathe("PipingCone_Icing", [(0.007, 0.03), (0.011, 0.06), (0.026, 0.16), (0.0, 0.17)], icing.materials()["rose"], 32)
        bead = lathe("PipingCone_Bead", [(0.0, -0.003), (0.002, -0.0025), (0.0022, 0.0)], icing.materials()["rose"], 16)
        parts += [fill, bead]
    return parts


def offset_spatula(M, iced=False):
    bm = bmesh.new()
    # Rounded tip (a semicircle centred 12.5 mm up), then straight sides to the neck.
    outline = [(0.0125 * math.cos(a), 0.0125 + 0.0125 * math.sin(a))
               for a in [math.pi + math.pi * k / 12 for k in range(13)]]
    outline += [(0.0125, 0.15), (-0.0125, 0.15)]
    top = [bm.verts.new((x, y, 0.0008)) for x, y in outline]
    bot = [bm.verts.new((x, y, 0.0)) for x, y in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    blade = D.assign(D.bm_object("OffsetSpatula", bm), M["brushed_steel"])
    neck = box("OffsetSpatula_Neck", (-0.005, 0.15, 0.0), (0.005, 0.17, 0.0008), M["brushed_steel"])
    neck.rotation_euler = (math.radians(-35), 0, 0)
    handle = lathe("OffsetSpatula_Handle", [(0.0, 0.0), (0.009, 0.004), (0.011, 0.06), (0.01, 0.105), (0.0, 0.11)], M["wood"], 24)
    handle.rotation_euler = (math.radians(-90), 0, 0)
    handle.location = (0, 0.175, 0.012)
    parts = [blade, neck, handle]
    if iced:
        smear = box("OffsetSpatula_Icing", (-0.011, 0.004, 0.0008), (0.011, 0.05, 0.0028), icing.materials()["ivory"], 0.001)
        parts.append(smear)
    return parts


def pour_pan(M, active=False):
    body = lathe("PourPan", [(0.0, 0.0), (0.045, 0.0), (0.05, 0.004), (0.05, 0.05), (0.052, 0.052), (0.05, 0.053)], M["copper"], 64)
    for v in body.data.vertices:           # the pouring lip
        if v.co.z > 0.045 and v.co.x > 0.03 and abs(v.co.y) < 0.02:
            v.co.x += 0.006 * (1 - abs(v.co.y) / 0.02)
    handle = box("PourPan_Handle", (-0.2, -0.007, 0.04), (-0.05, 0.007, 0.048), M["brass"], 0.002)
    ganache = lathe("PourPan_Ganache", [(0.0, 0.03), (0.048, 0.03), (0.0, 0.031)], icing.materials()["ganache_dark"], 48)
    parts = [body, handle, ganache]
    if active:
        stream = lathe("PourPan_Stream", [(0.003, -0.06), (0.0035, 0.0), (0.004, 0.04)], icing.materials()["ganache_dark"], 16)
        stream.location = (0.058, 0, 0.0)
        parts.append(stream)
    return parts


def drizzle_bottle(M, active=False):
    squeeze = 0.85 if active else 1.0
    body = lathe("DrizzleBottle", [(0.0, 0.03), (0.024, 0.03), (0.025, 0.035), (0.025 * squeeze, 0.11), (0.025, 0.17), (0.0, 0.172)], M["frosted"], 48)
    cap = lathe("DrizzleBottle_Cap", [(0.0, 0.0), (0.0012, 0.0), (0.004, 0.02), (0.012, 0.026), (0.013, 0.031), (0.0, 0.031)], M["cap"], 32)
    sauce = lathe("DrizzleBottle_Sauce", [(0.0, 0.035), (0.022, 0.035), (0.022, 0.09), (0.0, 0.09)], icing.materials()["ganache_caramel"], 32)
    return [body, cap, sauce]


def sieve(M, active=False):
    rim = lathe("Sieve", [(0.044, 0.03), (0.046, 0.03), (0.046, 0.045), (0.044, 0.045)], M["brass"], 64)
    bowl = lathe("Sieve_Mesh", [(0.0, 0.006), (0.02, 0.008), (0.038, 0.018), (0.044, 0.03)], M["mesh"], 64)
    handle = box("Sieve_Handle", (0.046, -0.004, 0.04), (0.15, 0.004, 0.044), M["brass"], 0.0015)
    sugar = lathe("Sieve_Powder", [(0.0, 0.009), (0.025, 0.012), (0.0, 0.016)], M["powder"], 32)
    parts = [rim, bowl, handle, sugar]
    if active:
        bm = bmesh.new()
        rng = np.random.default_rng(3)
        for _ in range(400):
            r, a = 0.04 * math.sqrt(rng.random()), rng.random() * 6.283
            bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.0004,
                                       matrix=Matrix.Translation((r * math.cos(a), r * math.sin(a), rng.random() * 0.006)))
        parts.append(D.assign(D.bm_object("Sieve_Dust", bm), M["powder"]))
    return parts


BUILDERS = {
    "PipingCone": lambda M, s: piping_cone(M, iced="clean" not in s),
    "OffsetSpatula": lambda M, s: offset_spatula(M, iced="iced" in s),
    "PourPan": lambda M, s: pour_pan(M, active=s == "active"),
    "DrizzleBottle": lambda M, s: drizzle_bottle(M, active=s == "active"),
    "Sieve": lambda M, s: sieve(M, active=s == "active"),
}
REAL_MM = {"PipingCone": 285, "OffsetSpatula": 285, "PourPan": 252, "DrizzleBottle": 172, "Sieve": 196}


def rig(tool, parts, state):
    """Parent the parts to an empty at the anchor (working end) and pose the tool."""
    root = bpy.data.objects.new(f"{tool}_rig", None)
    bpy.context.scene.collection.objects.link(root)
    for p in parts:
        p.parent = root
    tilt = TILT[tool]
    if tool == "PipingCone" and "active" in state:
        tilt += 15
    if tool == "PourPan":
        tilt = 25 if state == "active" else 0
        root.rotation_euler = Euler((0, math.radians(tilt), 0))
    elif tool == "Sieve":
        root.rotation_euler = Euler((0, math.radians(12 if state == "active" else 0), 0))
    else:
        root.rotation_euler = Euler((math.radians(90 - tilt) if tool in ("PipingCone", "DrizzleBottle") else math.radians(tilt), 0, 0))
    root.location = D.STATION
    return root


def render_sprites(args):
    M = tool_mats()
    manifest = {}
    paths = []
    floor = bpy.data.objects.get("Floor")
    for tool, states in STATES.items():
        force = args.force or (args.only is not None and tool in args.only)
        manifest[tool] = {"real_length_mm": REAL_MM[tool], "sprites": {}}
        for state in states:
            parts = BUILDERS[tool](M, state)
            root = rig(tool, parts, state)
            for rot in ROTATIONS:
                root.rotation_euler.z = math.radians(rot)
                bpy.context.view_layer.update()
                lo, hi = C.world_bounds([p.name for p in parts])
                extent = max(hi[0] - lo[0], hi[1] - lo[1]) * 1.08
                centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, 0))
                cam = D.sprite_camera(extent, centre=centre, res=512)
                anchor = _project(cam, D.STATION, 512)
                name = f"{tool}_{state}_{rot}"
                floor.hide_render = True
                path = os.path.join(OUT, "sprites", name + ".png")
                D.render(path, 512, samples=args.samples, force=force)
                paths.append(path)
                manifest[tool]["sprites"][name] = {"anchor_px": anchor, "mm_per_px": round(extent * 1000 / 512, 4),
                                                   "rotation_deg": rot}
                if state == states[0]:
                    floor.hide_render = False
                    for p in parts:
                        p.visible_camera = False
                    D.render(os.path.join(OUT, "sprites", f"{tool}_shadow_{rot}.png"), 512, samples=args.samples, force=force)
                    for p in parts:
                        p.visible_camera = True
            if state == states[0] and rot == 270:
                pass
            for p in parts:
                p.parent = None
            keep = state == states[0]
            if keep:
                root.rotation_euler.z = 0
                bpy.data.objects.remove(root)
                for p in parts:
                    p.location = p.location     # stays for tools.blend
                    p.hide_render = True
                    p["tool"] = tool
            else:
                for p in [root] + parts:
                    bpy.data.objects.remove(p)
    floor.hide_render = False
    D.sheet([p for p in paths if p.endswith("_0.png")], os.path.join(OUT, "sprites_sheet.png"), columns=7, cell=220)
    return manifest


def _project(cam, point, res):
    from bpy_extras.object_utils import world_to_camera_view
    co = world_to_camera_view(bpy.context.scene, cam, Vector(point))
    return [round(co.x * res, 1), round((1 - co.y) * res, 1)]


# ------------------------------------------------------------------ brushes and references

def write_brushes():
    os.makedirs(os.path.join(OUT, "brushes"), exist_ok=True)
    for name, arr in B.MAPS.items():
        D.gray16(os.path.join(OUT, "brushes", f"{name}.png"), arr)
    D.write_json(os.path.join(OUT, "brushes", "brushes.json"), B.manifest())


def field_object(name, field, colour, mat=None):
    """A grid mesh displaced by `field` (mm), on a 200 mm cake top, at the station."""
    res = 160
    idx = np.linspace(0, field.res - 1, res).astype(int)
    hs = field.h[np.ix_(idx, idx)]
    bm = bmesh.new()
    size = field.size / 1000
    verts = []
    for j in range(res):
        row = []
        for i in range(res):
            x, y = (i + 0.5) / res * size - size / 2, (j + 0.5) / res * size - size / 2
            row.append(bm.verts.new((x, -y, hs[j, i] / 1000)))
        verts.append(row)
    for j in range(res - 1):
        for i in range(res - 1):
            if max(hs[j, i], hs[j, i + 1], hs[j + 1, i], hs[j + 1, i + 1]) > 0.02:
                bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    obj = D.smooth(D.bm_object(name, bm, D.STATION + Vector((0, 0, 0.001))))
    return D.assign(obj, mat or icing.materials()[colour])


def patterns():
    """name -> Field (100 mm square, 0.25 mm/px), made with the same engine as the app."""
    out = {}
    c = 50.0

    def ring(r, n=72):
        return [(c + r * math.cos(2 * math.pi * k / n), c + r * math.sin(2 * math.pi * k / n)) for k in range(n + 1)]

    f = B.Field(100, 400); f.stroke("bead_round", ring(32)); out["ring"] = f
    f = B.Field(100, 400); f.stroke("bead_star", [(c + 1.4 * t * math.cos(t), c + 1.4 * t * math.sin(t)) for t in np.linspace(0, 4 * math.pi, 160)], scale=1.3); out["rosette"] = f
    f = B.Field(100, 400)
    for k in range(9):
        x = 10 + k * 10
        f.stroke("bead_star", [(x, 50), (x + 6, 50)], scale=1.3)
    out["shell_border"] = f
    f = B.Field(100, 400); f.stroke("bead_round", [(10 + 10 * k, 40 + (k % 2) * 20) for k in range(9)]); out["zigzag"] = f
    f = B.Field(100, 400); f.stroke("bead_round", [(c + 1.6 * t * math.cos(t), c + 1.6 * t * math.sin(t)) for t in np.linspace(0.5, 6 * math.pi, 200)], scale=0.8); out["spiral"] = f
    f = B.Field(100, 400)
    for k in range(6):
        f.stroke("drizzle", [(5, 12 + 15 * k), (95, 18 + 15 * k)], tail=False)
    out["drizzle_lines"] = f
    f = B.Field(100, 400); f.pour(c, c, level_mm=2.5, scale=1.4); out["poured_pool"] = f
    f = B.Field(100, 400)
    for k in range(9):
        f.stroke("dollop", [(15 + 9 * k, 30 + (k * 37) % 40)], scale=1.4, tail=False)
    for y in range(10, 95, 6):
        f.spread([(0, y), (100, y)], target_mm=3.0, scale=1.0)
    out["spatula_smoothed"] = f
    f = B.Field(100, 400); f.pour(c, c, level_mm=3.0, scale=1.6); out["dusted_top"] = f
    return out


def render_references(args):
    D.sprite_camera(0.11, res=512)
    floor = bpy.data.objects.get("Floor")
    floor.hide_render = False
    paths = []
    powder = tool_mats()["powder"]
    for name, field in patterns().items():
        for colour in ("rose", "chocolate") if name != "poured_pool" else ("ganache_dark", "ganache_white"):
            obj = field_object(f"Ref_{name}", field, colour)
            extra = []
            if name == "dusted_top":
                bm = bmesh.new()
                rng = np.random.default_rng(5)
                for _ in range(6000):
                    r, a = 0.036 * math.sqrt(rng.random()), rng.random() * 6.283
                    bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.0004,
                                               matrix=Matrix.Translation((r * math.cos(a), r * math.sin(a), 0.0042)))
                extra.append(D.assign(D.bm_object("Dust", bm, D.STATION), powder))
            path = os.path.join(OUT, "reference", f"{name}_{colour}.png")
            D.render(path, 512, samples=args.samples, force=args.force)
            paths.append(path)
            for o in [obj] + extra:
                bpy.data.objects.remove(o)
    D.sheet(paths, os.path.join(OUT, "reference_sheet.png"), columns=6, cell=220)


def ring_check():
    """Stamp a ring in Python, build the same ring in Blender as real geometry (a swept bead),
    render its height top-down via ray casts, and compare."""
    f = B.Field(100, 400)
    pts = [(50 + 32 * math.cos(2 * math.pi * k / 120), 50 + 32 * math.sin(2 * math.pi * k / 120)) for k in range(121)]
    f.stroke("bead_round", pts, tail=False)
    # Blender: a torus-like swept bead with the bead_round cross-section (dome^0.6).
    fp, hmax, _ = B.SPECS["bead_round"]
    profile = [((fp / 2) * (k / 12 * 2 - 1), hmax * max(0, 1 - (k / 12 * 2 - 1) ** 2) ** 0.6) for k in range(13)]
    bm = bmesh.new()
    rings = []
    for s in range(240):
        a = 2 * math.pi * s / 240
        rings.append([bm.verts.new(((32 + dx) * math.cos(a) / 1000, (32 + dx) * math.sin(a) / 1000, h / 1000)) for dx, h in profile])
    for s in range(240):
        r0, r1 = rings[s], rings[(s + 1) % 240]
        for k in range(12):
            bm.faces.new((r0[k], r0[k + 1], r1[k + 1], r1[k]))
    obj = D.bm_object("RingRef", bm)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    errs = []
    for j in range(0, 400, 4):
        for i in range(0, 400, 4):
            x, y = (i + 0.5) / 4 - 50, (j + 0.5) / 4 - 50
            hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, Vector((x / 1000, y / 1000, 0.05)), Vector((0, 0, -1)))
            ref = loc.z * 1000 if hit and obj.name in bpy.data.objects else 0.0
            errs.append(abs(ref - f.h[j, i]))
    bpy.data.objects.remove(obj)
    errs = np.array(errs)
    report = {"mean_error_mm": round(float(errs.mean()), 4), "max_error_mm": round(float(errs.max()), 3),
              "p99_error_mm": round(float(np.percentile(errs, 99)), 3), "bead_height_mm": hmax}
    D.write_json(os.path.join(OUT, "ring_check.json"), report)
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--stage", default="all")
    parser.add_argument("--only", nargs="*", default=None, help="re-render just these tools")
    args = C.script_args(parser)
    D.setup(samples=args.samples)
    if args.stage in ("all", "brushes"):
        write_brushes()
        print("[tools] ring check", ring_check())
    if args.stage in ("all", "sprites"):
        manifest = render_sprites(args)
        M = tool_mats()
        nozzles(M)
        D.write_json(os.path.join(OUT, "tools_manifest.json"),
                     {"tools": manifest, "rotations": list(ROTATIONS), "cake_diameter_mm": 200,
                      "sprite_px": 512, "brushes": "brushes/brushes.json", "palette": "palette.json"})
        for o in bpy.data.objects:
            if o.type == "MESH" and o.name != "Floor":
                o.hide_render = False
        D.save_blend(os.path.join(C.BUILD, "tools.blend"))
    if args.stage in ("all", "reference"):
        render_references(args)
    shutil.copy(os.path.join(D.OUT, "icing", "palette.json"), os.path.join(OUT, "palette.json"))
    print(f"[tools] sprites {D.dir_mb(os.path.join(OUT, 'sprites'))} MB, brushes {D.dir_mb(os.path.join(OUT, 'brushes'))} MB")


if __name__ == "__main__":
    main()
