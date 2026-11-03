"""Decorating step 6: the decorating station's screen-space panels, vessel sprites, layout and
guides (docs/prompts/station.md).

    $B -b -P scripts/blender/station.py [-- --force --samples N --stage layout|panels|vessels]

The layout is computed here first (one source for layout.json, the panels and the checks), then
the bench is built in Blender at 0.25 mm per panel pixel under the station lights, lit from the
top-left. Outputs in build/renders/station/:
  panels_<shape>.png      honed marble, brass rails, seats and cradles, a folded linen cloth,
                          transparent cake window
  vessels/<name>.png      pots (8 icing + 4 ganache), nozzle tray, 8 topping bowls (512 px)
  vessels/<name>_shadow.png and _shadow_lifted.png  (resting and lifted 6 %)
  layout_<shape>.json, guides_<shape>.png, station_manifest.json
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D  # noqa: E402
import icing  # noqa: E402
import imaging as I  # noqa: E402
import topping_models as T  # noqa: E402
import toppings as TP  # noqa: E402

OUT = os.path.join(D.OUT, "station")
MM_PER_PX = 0.25
SCALE = 3                                   # px per pt (iPhone and Duo are @3x)
POTS = list(icing.ICING) + list(icing.GANACHE)
BOWLS = list(TP.HEAPS)
TOOLS = ["PipingCone", "OffsetSpatula", "PourPan", "DrizzleBottle", "Sieve"]
CONTROLS = ["undo", "clear", "turntable", "speed", "plate", "backdrop"]


# ------------------------------------------------------------------ layout

def row(names, y, x0, x1, size, kind, group):
    pitch = (x1 - x0) / len(names)
    return [{"name": n, "kind": kind, "group": group, "centre_px": [round(x0 + pitch * (i + 0.5), 1), y],
             "size_px": [size, size] if kind != "cradle" else [size * 1.2, size * 0.8],
             "tap_radius_px": round(max(size, HIT_PX) / 2, 1)} for i, n in enumerate(names)]


HIT_PX = 44 * SCALE


def layout(shape):
    if shape == "iphone":
        w, h = 1080, 2340
        items = row(POTS[:6], 360, 40, 1040, 140, "seat_pot", "ingredients") + \
            row(POTS[6:], 520, 40, 1040, 140, "seat_pot", "ingredients") + \
            row(["NozzleRound", "NozzleStar", "NozzlePetal"], 660, 330, 750, 120, "seat_nozzle", "nozzles") + \
            row(BOWLS, 1840, 40, 40 + 190 * len(BOWLS), 170, "seat_bowl", "toppings") + \
            row(TOOLS, 2040, 40, 1040, 150, "cradle", "tools") + \
            row(CONTROLS, 2210, 60, 1020, HIT_PX, "control", "controls")
        window = [0, 740, 1080, 1740]
        safe = {"status": [0, 0, 1080, 150], "header": [0, 150, 1080, 280], "home": [0, 2290, 1080, 2340],
                "strip": [40, 720, 1040, 740]}
        fold = None
        scroll = {"toppings": {"visible_px": [40, 1040], "content_px": [40, 40 + 190 * len(BOWLS)]}}
    else:
        w, h = 1500, 2130
        fold = [0, 1005, 1500, 1125]
        items = row(POTS[:6], 270, 60, 1440, 150, "seat_pot", "ingredients") + \
            row(POTS[6:], 430, 60, 1440, 150, "seat_pot", "ingredients") + \
            row(["NozzleRound", "NozzleStar", "NozzlePetal"], 560, 540, 960, 120, "seat_nozzle", "nozzles")
        cols = [(BOWLS[0:2], 160, (700, 880)), (BOWLS[2:4], 1340, (700, 880)),
                (BOWLS[4:6], 160, (1250, 1430)), (BOWLS[6:8], 1340, (1250, 1430))]
        for names, x, ys in cols:
            for n, y in zip(names, ys):
                items.append({"name": n, "kind": "seat_bowl", "group": "toppings", "centre_px": [x, y],
                              "size_px": [170, 170], "tap_radius_px": 85.0})
        items += row(TOOLS, 1960, 60, 1440, 160, "cradle", "tools")
        for i, n in enumerate(CONTROLS):
            x = 160 if i < 3 else 1340
            y = 1560 + (i % 3) * 150
            items.append({"name": n, "kind": "control", "group": "controls", "centre_px": [x, y],
                          "size_px": [HIT_PX, HIT_PX], "tap_radius_px": HIT_PX / 2})
        window = [300, 640, 1200, 1900]
        safe = {"status": [0, 0, 1500, 140], "header": [0, 140, 1500, 200], "home": [0, 2080, 1500, 2130],
                "strip": [300, 610, 1200, 640]}
        scroll = {}
    for it in items:
        cx, cy = it["centre_px"]
        it["centre"] = [round(cx / w, 5), round(cy / h, 5)]
        it["anchor"] = ("Seat_Pot_%02d" % (POTS.index(it["name"]) + 1) if it["kind"] == "seat_pot" else
                        "Seat_Nozzle_%d" % (["NozzleRound", "NozzleStar", "NozzlePetal"].index(it["name"]) + 1) if it["kind"] == "seat_nozzle" else
                        "Seat_Bowl_%02d" % (BOWLS.index(it["name"]) + 1) if it["kind"] == "seat_bowl" else
                        "Cradle_" + {"PipingCone": "Cone", "OffsetSpatula": "Spatula", "PourPan": "Pan",
                                     "DrizzleBottle": "Bottle", "Sieve": "Sieve"}[it["name"]] if it["kind"] == "cradle" else it["name"])
    return {"shape": shape, "size_px": [w, h], "px_per_pt": SCALE, "mm_per_px": MM_PER_PX,
            "cake_window_px": window, "cake_window": [round(window[0] / w, 5), round(window[1] / h, 5),
                                                    round(window[2] / w, 5), round(window[3] / h, 5)],
            "safe_areas_px": safe, "fold_band_px": fold, "scroll_groups": scroll, "items": items,
            "selected": {"lift_scale": 1.06, "glow": "brass"}, "light": "top-left, shadows to the bottom-right"}


def checks(lay):
    issues = []
    by_group = {}
    for it in lay["items"]:
        by_group.setdefault((it["group"], it["centre_px"][1]), []).append(it)
    for key, items in by_group.items():
        xs = sorted(it["centre_px"][0] for it in items)
        gaps = np.diff(xs)
        if len(gaps) > 1 and (gaps.max() - gaps.min()) / gaps.mean() > 0.005:
            issues.append(f"uneven spacing in {key}")
    for it in lay["items"]:
        if it["tap_radius_px"] * 2 < HIT_PX - 0.5:
            issues.append(f"{it['name']} tap target under 44 pt")
        if lay["fold_band_px"]:
            y0, y1 = lay["fold_band_px"][1], lay["fold_band_px"][3]
            cy, r = it["centre_px"][1], it["size_px"][1] / 2
            if cy + r > y0 and cy - r < y1:
                issues.append(f"{it['name']} crosses the fold band")
    return issues


# ------------------------------------------------------------------ bench

def px_to_world(lay, px, py):
    """Panel pixel → world point under the rolled sprite camera (image right = +Y, up = -X)."""
    w, h = lay["size_px"]
    s = MM_PER_PX / 1000
    return Vector((D.STATION.x - (h / 2 - py) * s, D.STATION.y + (px - w / 2) * s, 0))


def brass():
    return D.material("Station_brass", (0.78, 0.56, 0.26), 0.28, metallic=1.0)


def build_bench(lay):
    w, h = lay["size_px"]
    s = MM_PER_PX / 1000
    bm = bmesh.new()
    C.add_box(bm, (-h / 2 * s, -w / 2 * s, -0.02), (h / 2 * s, w / 2 * s, 0.0))
    slab = D.bm_object("Bench", bm, D.STATION)
    slab.data.materials.append(C.marble_material("carrara", finish="honed", large_warp=0.4))
    rim = brass()
    lining = D.material("Station_lining", (0.16, 0.14, 0.12), 0.85, sheen=0.4)
    for it in lay["items"]:
        if it["kind"] == "control":
            continue
        c = px_to_world(lay, *it["centre_px"])
        rw, rh = it["size_px"][0] / 2 * s, it["size_px"][1] / 2 * s
        if it["kind"] == "cradle":
            for dy in (-rw * 0.6, rw * 0.6):          # two brass forks a tool rests on
                bmc = bmesh.new()
                C.add_box(bmc, (-rh * 0.5, dy - 0.0015, 0), (rh * 0.5, dy + 0.0015, 0.004))
                D.assign(D.bm_object(it["anchor"] + "_fork", bmc, c), rim)
            continue
        r = rw * 1.08
        D.assign(D.lathe(it["anchor"] + "_rim", [(r - 0.0012, 0.0), (r - 0.0012, 0.0012), (r, 0.0012), (r, 0.0)], 64, c), rim)
        D.assign(D.lathe(it["anchor"] + "_lining", [(0.0, 0.0004), (r - 0.0012, 0.0004)], 64, c), lining)
    # Brass rails along the cake window's top and bottom edges.
    x0, y0, x1, y1 = lay["cake_window_px"]
    for y in (y0 - 6, y1 + 6):
        a, b = px_to_world(lay, x0 + 30, y), px_to_world(lay, x1 - 30, y)
        bmr = bmesh.new()
        C.add_box(bmr, (min(a.x, b.x) - 0.0015, min(a.y, b.y), 0), (max(a.x, b.x) + 0.0015, max(a.y, b.y), 0.003))
        D.assign(D.bm_object("Rail", bmr), rim)
    # One folded linen cloth at the top-left corner of the shelf band.
    linen = D.noise_bump(D.material("Station_linen", (0.86, 0.84, 0.79), 0.9, sheen=0.5), 600, 0.25)
    corner = px_to_world(lay, 40, lay["safe_areas_px"]["header"][3] + 10)
    bmc = bmesh.new()
    C.add_box(bmc, (0, 0, 0), (0.05, 0.07, 0.006))
    cloth = D.assign(D.bm_object("Linen", bmc, corner + Vector((0.0, -0.035, 0))), linen)
    cloth.rotation_euler.z = 0.12
    mod = cloth.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments = 0.002, 3


def render_panel(lay, args):
    w, h = lay["size_px"]
    path = os.path.join(OUT, f"panels_{lay['shape']}.png")
    if os.path.exists(path) and not args.force:
        return path
    # The rolled sprite camera puts world -X up and +Y right, which is how build_bench lays it out.
    D.sprite_camera(max(w, h) * MM_PER_PX / 1000, res=512)
    D.render(path, (w, h), samples=args.samples, supersample=1, force=True)
    arr = I.load(path)
    x0, y0, x1, y1 = lay["cake_window_px"]
    arr[y0:y1, x0:x1] = 0
    I.save(arr, path)
    return path


def guides(lay):
    w, h = lay["size_px"]
    img = np.zeros((h, w, 4), np.float32)
    img[::60, :, :] = (1, 1, 1, 0.15)
    img[:, ::60, :] = (1, 1, 1, 0.15)
    for name, (x0, y0, x1, y1) in lay["safe_areas_px"].items():
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * 0.5 + np.array((0.2, 0.6, 1.0, 0.5), np.float32) * 0.5
    x0, y0, x1, y1 = lay["cake_window_px"]
    img[y0:y1, x0:x1] = (1, 0.8, 0.3, 0.25)
    if lay["fold_band_px"]:
        _, f0, _, f1 = lay["fold_band_px"]
        img[f0:f1, :] = (1, 0.1, 0.1, 0.45)
    for it in lay["items"]:
        cx, cy = it["centre_px"]
        r = it["tap_radius_px"]
        yy, xx = np.ogrid[:h, :w]
        ring = np.abs(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) - r) < 3
        img[ring] = (0.3, 1, 0.4, 1)
    I.save(img, os.path.join(OUT, f"guides_{lay['shape']}.png"))


# ------------------------------------------------------------------ vessels

def ramekin(name, mat):
    porcelain = D.material("Station_porcelain", (0.93, 0.92, 0.9), 0.12, coat=0.6, subsurface=0.05)
    gold = D.material("Station_gold", (0.95, 0.75, 0.38), 0.2, metallic=1.0)
    body = D.lathe(name, [(0.0, 0.0), (0.019, 0.0), (0.021, 0.002), (0.023, 0.03), (0.0215, 0.03),
                          (0.0195, 0.004), (0.0, 0.004)], 64)
    D.assign(body, porcelain)
    rim = D.lathe(name + "_rim", [(0.0215, 0.0298), (0.0232, 0.0298), (0.0232, 0.0306), (0.0215, 0.0306)], 64)
    D.assign(rim, gold)
    fill = icing.swatch_mesh(name + "_fill", D.STATION + Vector((0, 0, 0.022)), mat)
    fill.scale = (1.15, 1.15, 1.0)
    return [body, rim, fill]


def bowl(name, i):
    mat = (D.material("Station_steel", (0.75, 0.75, 0.76), 0.25, metallic=1.0) if i % 2 == 0 else
           D.material("Station_porcelain", (0.93, 0.92, 0.9), 0.12, coat=0.6))
    body = D.lathe(name, [(0.0, 0.0), (0.016, 0.0), (0.03, 0.016), (0.033, 0.024), (0.0315, 0.024),
                          (0.028, 0.0165), (0.015, 0.003), (0.0, 0.003)], 64)
    return [D.assign(body, mat)]


def nozzle_tray():
    import tools as TL
    tray_mat = brass()
    bm = bmesh.new()
    C.add_box(bm, (-0.012, -0.032, 0), (0.012, 0.032, 0.004))
    tray = D.assign(D.bm_object("NozzleTray", bm, D.STATION), tray_mat)
    parts = [tray]
    for k, n in enumerate(TL.nozzles(TL.tool_mats())):
        n.location = D.STATION + Vector((0, (k - 1) * 0.021, 0.026))
        n.rotation_euler.x = math.pi          # tip up, upright in the tray
        parts.append(n)
    return parts


def render_vessels(args):
    out = os.path.join(OUT, "vessels")
    floor = bpy.data.objects["Floor"]
    mats = icing.materials()
    protos = {}
    jobs = [(f"pot_{n}", lambda n=n: ramekin(f"Pot_{n}", mats[n]), 0.056) for n in POTS]
    jobs.append(("nozzle_tray", nozzle_tray, 0.075))
    tm = T.mats()
    for i, b in enumerate(BOWLS):
        jobs.append((f"bowl_{b}", lambda i=i, b=b: bowl(f"Bowl_{b}", i) + heap_in_bowl(b, protos, tm), 0.074))
    paths = []
    for name, make, extent in jobs:
        parts = make()
        D.sprite_camera(extent, res=512)
        floor.hide_render = True
        path = os.path.join(out, f"{name}.png")
        D.render(path, 512, samples=args.samples, force=args.force)
        paths.append(path)
        floor.hide_render = False
        for p in parts:
            p.visible_camera = False
        D.render(os.path.join(out, f"{name}_shadow.png"), 256, samples=16, force=args.force)
        for p in parts:
            p.location.z += 0.008                    # lifted: a longer, softer shadow
        D.render(os.path.join(out, f"{name}_shadow_lifted.png"), 256, samples=16, force=args.force)
        for p in parts:
            bpy.data.objects.remove(p)
    D.sheet(paths, os.path.join(OUT, "vessels_sheet.png"), columns=7, cell=180)


def heap_in_bowl(topping, protos, materials):
    if not protos:
        for kind in T.MODELS:
            for v in range(5 if kind == "sprinkle" else 3):
                o = T.build(kind, v, hero=True, materials=materials)
                o.hide_render = True
                protos[o.name] = o
    parts, radius = TP.HEAPS[topping]
    placed = TP.heap(topping, parts, radius * 0.95, protos)
    for o in placed:
        o.location.z += 0.006
    return placed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--stage", default="all")
    args = C.script_args(parser)
    lays = {s: layout(s) for s in ("iphone", "duo")}
    report = {}
    for shape, lay in lays.items():
        D.write_json(os.path.join(OUT, f"layout_{shape}.json"), lay)
        report[shape] = checks(lay)
        # No shadow-catcher floor: the bench is the ground (at z = 0 the catcher would hide it).
        D.setup(ground=False, samples=args.samples)
        guides(lay)
        if args.stage in ("all", "panels"):
            build_bench(lay)
            render_panel(lay, args)
    if args.stage in ("all", "vessels"):
        D.setup(samples=args.samples)
        render_vessels(args)
    D.write_json(os.path.join(OUT, "station_manifest.json"), {
        "layouts": [f"layout_{s}.json" for s in lays], "panels": [f"panels_{s}.png" for s in lays],
        "vessel_states": {"resting": "<name>.png + <name>_shadow.png",
                          "lifted": "<name>.png at lift_scale + <name>_shadow_lifted.png",
                          "empty": "no sprite: the panel shows the empty seat"},
        "checks": report, "size_mb": D.dir_mb(OUT), "budget_mb": 15})
    print(f"[station] {D.dir_mb(OUT)} MB, checks {json.dumps(report)}")


if __name__ == "__main__":
    main()
