"""Topping models shared by toppings.py (HUD bowl icons) and toppings3d.py (viewer models).

Every builder makes one object at the world origin, real size in metres, pivot at the contact
point with the surface (base at z = 0), local +Z = the surface normal. `hero=True` adds a
subdivision level for close renders; the base mesh stays low-poly for the viewer.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import deco_common as D

MODELS = ("raspberry", "blueberry", "strawberry_slice", "cherry", "mint_leaf", "chocolate_shard",
          "chocolate_curl", "gold_flake", "sugar_pearl", "pistachio_crumb", "almond_flake",
          "flower_petal", "sprinkle")
SPRINKLE_COLOURS = {"pink": 0xE04A82, "mint": 0x2FB08F, "lemon": 0xF0B820, "periwinkle": 0x5A6CD8,
                    "white": 0xF4F1EA}


def lin(hexv):
    rgb = [((hexv >> s) & 0xFF) / 255 for s in (16, 8, 0)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]


def mats():
    m = D.material
    return {
        "raspberry": m("Top_raspberry", lin(0x8E0F2A), 0.4, subsurface=0.12, sss_radius=(1, .2, .2), coat=0.2),
        "blueberry": m("Top_blueberry", lin(0x1C2240), 0.5, sheen=0.25),
        "strawberry": m("Top_strawberry", lin(0xD8293A), 0.3, subsurface=0.3, sss_radius=(1, .3, .3), coat=0.4),
        "cherry": m("Top_cherry", lin(0x6E0A16), 0.12, coat=0.8),
        "stem": m("Top_stem", lin(0x6B7A3A), 0.6),
        "mint": m("Top_mint", lin(0x2A5E24), 0.45, subsurface=0.08, sss_radius=(.3, 1, .3)),
        "chocolate": m("Top_chocolate", lin(0x2E1A12), 0.3, specular=0.6),
        "gold": m("Top_gold", lin(0xE8C26A), 0.18, metallic=1.0),
        "pearl": m("Top_pearl", lin(0xF1ECE4), 0.12, metallic=0.35, coat=0.6),
        "pistachio": m("Top_pistachio", lin(0x6A8A2A), 0.6),
        "pistachio_skin": m("Top_pistachio_skin", lin(0x6B4A3A), 0.6),
        "almond": m("Top_almond", lin(0xEAD8B5), 0.55, subsurface=0.1),
        "petal": m("Top_petal", lin(0xD9708E), 0.5, subsurface=0.15, sss_radius=(1, .5, .6)),
        **{f"sprinkle_{k}": m(f"Top_sprinkle_{k}", lin(v), 0.35, coat=0.3) for k, v in SPRINKLE_COLOURS.items()},
    }


def _obj(name, bm, mat, hero, subdiv=1, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = D.bm_object(name, bm)
    if smooth:
        D.smooth(obj, subdiv=subdiv if hero else 0)
    D.assign(obj, mat)
    return obj


def _ico(bm, centre, radius, subdiv=1, scale=(1, 1, 1)):
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in res["verts"]:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(centre)
    return res["verts"]


def _uv_sphere(bm, centre, radius, u=12, v=8, scale=(1, 1, 1)):
    res = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    for vert in res["verts"]:
        vert.co = Vector((vert.co.x * scale[0], vert.co.y * scale[1], vert.co.z * scale[2])) + Vector(centre)
    return res["verts"]


def _slab(bm, outline, thickness, curve=0.0, jitter=0.0, rng=None):
    """Extrude a 2D outline [(x, y)] into a thin slab with an optional cup (z += curve * r^2)."""
    top, bottom = [], []
    for x, y in outline:
        z = curve * (x * x + y * y) + (rng.uniform(-jitter, jitter) if rng else 0)
        bottom.append(bm.verts.new((x, y, z)))
        top.append(bm.verts.new((x, y, z + thickness)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))


def build(kind, variant=0, hero=False, materials=None):
    """One topping object named `<kind>_<variant>`."""
    M = materials or mats()
    rng = random.Random(f"{kind}-{variant}")
    bm = bmesh.new()
    name = f"{kind}_{variant}"
    if kind == "raspberry":
        # Drupelets on a rounded cone, open hollow at the base. ~18 x 20 mm.
        rows = [(0.0042, 7), (0.0068, 11), (0.0078, 13), (0.0076, 13), (0.0062, 11), (0.0036, 7), (0.0, 1)]
        for i, (r, count) in enumerate(rows):
            z = 0.0022 + i * 0.0026
            for k in range(count):
                a = 2 * math.pi * (k + 0.5 * (i % 2)) / count + rng.uniform(-.1, .1)
                _ico(bm, (r * math.cos(a), r * math.sin(a), z), 0.0026 * rng.uniform(.9, 1.1), subdiv=1, scale=(1, 1, 1.15))
        return _obj(name, bm, M["raspberry"], hero)
    if kind == "blueberry":
        s = rng.uniform(.9, 1.1)
        verts = _uv_sphere(bm, (0, 0, 0.0047 * s), 0.0055 * s, 14, 10, scale=(1, 1, 0.85))
        for v in verts:      # the crown: a small star-shaped dimple on top
            if v.co.z > 0.0047 * s + 0.0043 * s:
                v.co.z -= 0.0012 * s
        return _obj(name, bm, M["blueberry"], hero)
    if kind == "strawberry_slice":
        outline = []
        for i in range(28):
            t = 2 * math.pi * i / 28
            x = 0.011 * math.sin(t) * (1 - 0.15 * math.cos(t))
            y = -0.013 * math.cos(t) - 0.003 * math.cos(2 * t)
            outline.append((x * rng.uniform(.97, 1.03), y))
        _slab(bm, outline, 0.0035)
        obj = _obj(name, bm, M["strawberry"], hero, smooth=False)
        return obj
    if kind == "cherry":
        verts = _uv_sphere(bm, (0, 0, 0.0105), 0.011, 16, 12, scale=(1, 0.95, 0.95))
        for v in verts:
            if v.co.z > 0.018 and abs(v.co.x) < 0.004 and abs(v.co.y) < 0.004:
                v.co.z -= 0.002
        cherry = _obj(name, bm, M["cherry"], hero)
        stem = bmesh.new()
        prev = None
        for i in range(7):
            t = i / 6
            c = Vector((0.006 * t * t, 0, 0.019 + 0.032 * t))
            ring = [stem.verts.new(c + Vector((0.0007 * math.cos(a), 0.0007 * math.sin(a), 0)))
                    for a in [2 * math.pi * k / 6 for k in range(6)]]
            if prev:
                for k in range(6):
                    stem.faces.new((prev[k], prev[(k + 1) % 6], ring[(k + 1) % 6], ring[k]))
            prev = ring
        stem_obj = _obj(name + "_stem", stem, M["stem"], hero)
        _join(cherry, [stem_obj])
        return cherry
    if kind == "mint_leaf":
        outline = []
        for i in range(32):
            t = 2 * math.pi * i / 32
            r = 1 + 0.06 * math.sin(t * 14)       # serrated edge
            outline.append((0.0068 * math.sin(t) * r, 0.0125 * math.cos(t) * r * (1 + 0.15 * math.cos(t))))
        _slab(bm, outline, 0.0004)
        for v in bm.verts:                         # fold along the midrib
            v.co.z += abs(v.co.x) * 0.35 + 0.0004
        return _obj(name, bm, M["mint"], hero, smooth=False)
    if kind == "chocolate_shard":
        n = rng.randint(5, 7)
        outline = []
        for i in range(n):
            a = 2 * math.pi * i / n + rng.uniform(-.25, .25)
            r = rng.uniform(0.008, 0.014)
            outline.append((r * math.cos(a), r * math.sin(a) * 0.7))
        _slab(bm, outline, 0.0018)
        return _obj(name, bm, M["chocolate"], hero, smooth=False)
    if kind == "chocolate_curl":
        turns, steps, width = 1.6 + 0.2 * variant, 40, 0.012
        prev = None
        for i in range(steps + 1):
            a = 2 * math.pi * turns * i / steps
            r = 0.0045 - 0.0015 * i / steps
            p = Vector((r * math.cos(a), 0, r * math.sin(a) + 0.0045))
            pair = (bm.verts.new(p + Vector((0, -width / 2, 0))), bm.verts.new(p + Vector((0, width / 2, 0))))
            if prev:
                bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
            prev = pair
        obj = _obj(name, bm, M["chocolate"], hero)
        mod = obj.modifiers.new("Thick", "SOLIDIFY")
        mod.thickness = 0.0007
        return obj
    if kind == "gold_flake":
        outline = [(rng.uniform(.6, 1.0) * 0.004 * math.cos(2 * math.pi * i / 9),
                    rng.uniform(.6, 1.0) * 0.004 * math.sin(2 * math.pi * i / 9)) for i in range(9)]
        _slab(bm, outline, 0.00008, jitter=0.00015, rng=rng)
        return _obj(name, bm, M["gold"], hero, smooth=False)
    if kind == "sugar_pearl":
        _uv_sphere(bm, (0, 0, 0.002), 0.002 * (1 + 0.15 * variant), 10, 7)
        return _obj(name, bm, M["pearl"], hero)
    if kind == "pistachio_crumb":
        verts = _ico(bm, (0, 0, 0.002), 0.0025, subdiv=1, scale=(rng.uniform(1, 1.5), 1, 0.7))
        for v in verts:
            v.co += Vector((rng.uniform(-.0006, .0006) for _ in range(3)))
        return _obj(name, bm, M["pistachio_skin"] if variant == 2 else M["pistachio"], hero, smooth=False)
    if kind == "almond_flake":
        outline = [(0.009 * math.cos(2 * math.pi * i / 20), 0.006 * math.sin(2 * math.pi * i / 20)
                    * (1 + 0.2 * math.cos(2 * math.pi * i / 20))) for i in range(20)]
        _slab(bm, outline, 0.0011, curve=8.0)
        return _obj(name, bm, M["almond"], hero, smooth=False)
    if kind == "flower_petal":
        outline = []
        for i in range(24):
            t = 2 * math.pi * i / 24
            outline.append((0.0095 * math.sin(t), 0.011 * math.cos(t) * (1 + 0.25 * math.cos(t)) - 0.002 * abs(math.sin(t * 3))))
        _slab(bm, outline, 0.0003, curve=22.0)
        return _obj(name, bm, M["petal"], hero)
    if kind == "sprinkle":
        # A capsule rod 1.2 mm across, 6 mm long, lying along X: under 100 triangles.
        seg, r, half = 6, 0.0006, 0.0024
        rings = []
        for x, rr in [(-half - r, 0.0001), (-half - r * .6, r * .8), (-half, r), (half, r), (half + r * .6, r * .8), (half + r, 0.0001)]:
            rings.append([bm.verts.new((x, rr * math.cos(2 * math.pi * k / seg), r + rr * math.sin(2 * math.pi * k / seg)))
                          for k in range(seg)])
        for a, b in zip(rings, rings[1:]):
            for k in range(seg):
                bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        colour = list(SPRINKLE_COLOURS)[variant % len(SPRINKLE_COLOURS)]
        return _obj(name, bm, M[f"sprinkle_{colour}"], hero)
    raise ValueError(kind)


def _join(target, others):
    bpy.ops.object.select_all(action="DESELECT")
    for o in others + [target]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target
