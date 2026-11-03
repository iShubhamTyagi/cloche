"""Decorating step 1: icing and ganache materials and the palette (docs/prompts/icing.md).

    $B -b -P scripts/blender/icing.py [-- --force --samples N]

Other scripts call `icing.materials()` to get the same materials (no appending needed).
Outputs: build/icing.blend (materials only), build/renders/icing/contact.png,
build/renders/icing/palette.json (also copied to the app by export_assets.py).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D

# name: (sRGB hex, roughness, specular, subsurface, sheen, coat)
ICING = {
    "ivory": (0xEADBB8, 0.62, 0.35, 0.12, 0.08, 0.0),
    "rose": (0xE8908E, 0.6, 0.35, 0.12, 0.08, 0.0),
    "pistachio": (0xA6C47E, 0.6, 0.35, 0.1, 0.08, 0.0),
    "chocolate": (0x3F2318, 0.55, 0.4, 0.06, 0.08, 0.0),
    "caramel": (0xB06A2A, 0.55, 0.4, 0.08, 0.08, 0.0),
    "white": (0xF4F1EA, 0.64, 0.35, 0.15, 0.08, 0.0),
    "raspberry": (0xA8203E, 0.58, 0.35, 0.08, 0.08, 0.0),
    "bluegrey": (0x7F93A6, 0.6, 0.35, 0.1, 0.08, 0.0),
}
GANACHE = {
    "ganache_dark": (0x2E1A12, 0.14, 0.6, 0.05, 0.0, 0.7),
    "ganache_milk": (0x6A3F26, 0.16, 0.6, 0.1, 0.0, 0.6),
    "ganache_white": (0xEFE3C8, 0.2, 0.55, 0.3, 0.0, 0.5),
    "ganache_caramel": (0xA8652C, 0.15, 0.6, 0.15, 0.0, 0.6),
}
ALL = {**ICING, **GANACHE}
OUT = os.path.join(D.OUT, "icing")


def srgb_to_linear(hex_value):
    rgb = [((hex_value >> s) & 0xFF) / 255 for s in (16, 8, 0)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]


def materials():
    """Create (or reuse) every icing and ganache material. Returns {name: material}."""
    out = {}
    for name, (hexv, rough, spec, sss, sheen, coat) in ALL.items():
        mat_name = f"Icing_{name}"
        if mat_name in bpy.data.materials:
            out[name] = bpy.data.materials[mat_name]
            continue
        lin = srgb_to_linear(hexv)
        mat = D.material(mat_name, lin, roughness=rough, specular=spec, subsurface=sss,
                         sss_radius=(1.0, 0.45, 0.25), sheen=sheen, coat=coat)
        if name in ICING:
            D.noise_bump(mat, scale=900, strength=0.12)      # buttercream: fine matte grain
        else:
            D.noise_bump(mat, scale=120, strength=0.02)      # ganache: nearly mirror-smooth
        mat.use_fake_user = True
        out[name] = mat
    return out


def palette():
    rows = []
    for name, (hexv, rough, spec, sss, sheen, coat) in ALL.items():
        rows.append({"name": name, "kind": "ganache" if name in GANACHE else "icing",
                     "srgb": f"#{hexv:06X}", "linear": [round(v, 5) for v in srgb_to_linear(hexv)],
                     "roughness": rough, "specular": spec, "subsurface": sss, "sheen": sheen,
                     "clearcoat": coat})
    return {"units": "linear RGB, Principled BSDF values", "colours": rows}


def swatch_mesh(name, location, mat):
    """A spread of icing: a soft disc 36 mm wide with a gently domed, wavy top."""
    bm = C.bmesh.new()
    rings, segs = 14, 64
    centre = bm.verts.new((0, 0, 0.0045))
    prev = None
    for r in range(1, rings + 1):
        rad = 0.018 * r / rings
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs
            z = 0.0045 * math.cos(r / rings * math.pi / 2) ** 0.6 + 0.0006 * math.sin(a * 5 + r)
            ring.append(bm.verts.new((rad * math.cos(a), rad * math.sin(a), max(z, 0))))
        for s in range(segs):
            t = (s + 1) % segs
            if prev is None:
                bm.faces.new((centre, ring[s], ring[t]))
            else:
                bm.faces.new((prev[s], prev[t], ring[t], ring[s]))
        prev = ring
    obj = D.bm_object(name, bm, location)
    D.smooth(obj, subdiv=1)
    return D.assign(obj, mat)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--samples", type=int, default=48)
    args = C.script_args(parser)
    D.setup(samples=args.samples)
    mats = materials()
    names = list(ALL)
    pitch = 0.05
    x0 = D.STATION.x - pitch * (len(names) / 2 - 0.5) / 2
    for i, name in enumerate(names):
        col, row = i % 6, i // 6
        base = Vector((D.STATION.x + (col - 2.5) * pitch, D.STATION.y + (0.5 - row) * 0.11, 0))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.016, location=base + Vector((0, 0.025, 0.016)),
                                             segments=48, ring_count=24)
        sphere = bpy.context.object
        D.smooth(sphere)
        D.assign(sphere, mats[name])
        swatch_mesh(f"Swatch_{name}", base + Vector((0, -0.02, 0)), mats[name])
    del x0
    cam = D.sprite_camera(0.34, centre=D.STATION + Vector((0, 0.0, 0)), roll=False)
    cam.data.type = "PERSP"
    cam.data.lens = 70
    cam.location = D.STATION + Vector((0, -0.62, 0.62))
    cam.rotation_euler = (math.radians(45), 0, 0)
    D.render(os.path.join(OUT, "contact.png"), (1400, 700), samples=args.samples, force=args.force)
    D.write_json(os.path.join(OUT, "palette.json"), palette())
    D.save_blend(os.path.join(C.BUILD, "icing.blend"))
    print("[icing] done")


if __name__ == "__main__":
    main()
