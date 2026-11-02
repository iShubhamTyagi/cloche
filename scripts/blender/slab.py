"""The stage slab under the oven and the turntable stand: build/slab.blend.

    Blender -b -P scripts/blender/slab.py -- [--stage 1] [--slab-size 2.20 0.62 0.06]
        [--oven-offset 0] [--stand-offset 0] [--marble carrara|calacatta|emperador]
        [--preview | --final] [--res W H] [--samples N] [--force]

One thick honed marble slab, floating (nothing under it), top at z = 0. Side by side (owner,
2026-11-02): the oven on the left with its front at the slab's front edge, so its door swings to
180 and hangs in front of the slab; the turntable stand on the right at layout.STATION; the
camera slides along the slab between them. Edge: a 3 mm round on top, a 4 mm chamfer under it,
so the thickness reads.

Objects: StageSlab, and empties OvenAnchor, StandAnchor, RailStart, RailEnd, DropZone,
SpatulaRest (world positions also in build/slab_anchors.json). Later stages: SlabRail (brass
inlay), the shared marble, the clearance check and layout renders.
--oven-offset / --stand-offset move the oven or the stand along x (metres) to change spacing.
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(__file__))
import cakestand as S  # noqa: E402
import common as C  # noqa: E402
import imaging as I  # noqa: E402
import render as R  # noqa: E402
import studio  # noqa: E402
from layout import (DOOR_X1, OVEN_ANCHOR, SLAB_FRONT_Y, SLAB_LEFT_X, SLAB_SIZE, STATION, W)  # noqa: E402

TOP_ROUND = 0.003         # radius on the top edge
UNDER_CHAMFER = 0.004     # chamfer on the bottom edge
RAIL_INSET = 0.05         # the rail's line, behind the front edge
RAIL_W = 0.006            # brass inlay width
RAIL_DEPTH = 0.004        # set this deep into the slab, top flush
STOP_LEN = 0.030          # cross marks at the rail's ends, across it
STOP_W = 0.004


def edge_profile(t):
    """(inset, z) round the slab's edge, from the top face down to the bottom face."""
    pts = []
    for k in range(9):
        a = math.radians(90 * k / 8)
        pts.append((TOP_ROUND - TOP_ROUND * math.sin(a), -TOP_ROUND + TOP_ROUND * math.cos(a)))
    pts.append((0.0, -(t - UNDER_CHAMFER)))
    pts.append((UNDER_CHAMFER, -t))
    return pts


def build_slab(w, d, t):
    """Rings of inset rectangles following the edge profile, capped top and bottom. Square
    corners in plan (mitred profile), the eased edge all round."""
    x0, y0 = SLAB_LEFT_X, SLAB_FRONT_Y
    bm = bmesh.new()
    rings = []
    for inset, z in edge_profile(t):
        rings.append([bm.verts.new(c) for c in ((x0 + inset, y0 + inset, z), (x0 + w - inset, y0 + inset, z),
                                                 (x0 + w - inset, y0 + d - inset, z), (x0 + inset, y0 + d - inset, z))])
    bm.faces.new(rings[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((a[k], b[k], b[j], a[j]))
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    slab = C.mesh_object("StageSlab", bm, origin=(x0 + w / 2, y0 + d / 2, 0.0))
    slab.data.shade_smooth()
    slab.data.set_sharp_from_angle(angle=math.radians(30))
    slab["role"] = "floating honed marble stage; top at z = 0"
    return slab


def capsule(bm, x0, y0, x1, y1, width, depth, steps=12):
    """A flat stadium (rounded ends) from (x0, y0) to (x1, y1), top at z = 0, `depth` deep."""
    ang = math.atan2(y1 - y0, x1 - x0)
    r = width / 2
    outline = []
    for cx, cy, a0 in ((x1, y1, ang - math.pi / 2), (x0, y0, ang + math.pi / 2)):
        for k in range(steps + 1):
            a = a0 + math.pi * k / steps
            outline.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    top = [bm.verts.new((x, y, 0.0)) for x, y in outline]
    bottom = [bm.verts.new((x, y, -depth)) for x, y in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    n = len(outline)
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((bottom[k], bottom[j], top[j], top[k]))


def build_rail(slab, start, end):
    """SlabRail: the rail and its two end stops as one brass inlay, flush with the slab top; the
    slab gets the matching groove."""
    (x0, y0, _), (x1, y1, _) = start, end
    pieces = []
    for kind in ("rail", "stop0", "stop1"):
        bm = bmesh.new()
        if kind == "rail":
            capsule(bm, x0, y0, x1, y1, RAIL_W, RAIL_DEPTH)
        else:
            x = x0 if kind == "stop0" else x1
            capsule(bm, x, y0 - STOP_LEN / 2, x, y0 + STOP_LEN / 2, STOP_W, RAIL_DEPTH)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        pieces.append(C.mesh_object(f"_rail_{kind}", bm, origin=((x0 + x1) / 2, y0, 0.0)))
    rail = pieces[0]
    for other in pieces[1:]:
        mod = rail.modifiers.new("join", "BOOLEAN")
        mod.operation, mod.solver, mod.object = "UNION", "EXACT", other
        with bpy.context.temp_override(object=rail, active_object=rail, selected_objects=[rail]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(other, do_unlink=True)
    rail.name = rail.data.name = "SlabRail"
    # The groove: the same shape, cut from the slab.
    cutter = rail.copy()
    cutter.data = rail.data.copy()
    C.link(cutter)
    C.boolean_difference(slab, cutter)
    C.finish(rail, bevel=0.0003, segments=2, angle=40)
    rail["role"] = "brass inlay the tray slides along, RailStart to RailEnd, with end stops"
    return rail


def anchors(oven_offset, stand_offset):
    ox = OVEN_ANCHOR[0] + oven_offset
    sx, sy = STATION[0] + stand_offset, STATION[1]
    rail_y = SLAB_FRONT_Y + RAIL_INSET
    plate_r = S.PLATE["r"]
    rim_x = sx - math.sqrt(max(plate_r ** 2 - (rail_y - sy) ** 2, 0.0))
    start_x = DOOR_X1 + oven_offset
    return {
        "OvenAnchor": (ox, OVEN_ANCHOR[1], 0.0),
        "StandAnchor": (sx, sy, 0.0),
        "RailStart": (start_x, rail_y, 0.0),
        "RailEnd": (rim_x, rail_y, 0.0),
        "DropZone": (sx, sy, S.Z_PLATE_TOP),
        "SpatulaRest": (((ox + W / 2) + (sx - plate_r)) / 2, rail_y + 0.16, 0.0),
    }


def place_anchors(points):
    for name, p in points.items():
        C.empty(name, p, size=0.05, kind="ARROWS" if name.endswith("Anchor") else "SPHERE")


def append_all(path):
    """Append every object from an asset file (one asset per file). Returns the new objects."""
    if not os.path.exists(path):
        return []
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    objs = [o for o in dst.objects if o is not None]
    for o in objs:
        bpy.context.scene.collection.objects.link(o)
    return objs


def roots(objs):
    return [o for o in objs if o.parent is None]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--slab-size", type=float, nargs=3, default=SLAB_SIZE, metavar=("W", "D", "T"))
    parser.add_argument("--oven-offset", type=float, default=0.0)
    parser.add_argument("--stand-offset", type=float, default=0.0)
    parser.add_argument("--marble", choices=("carrara", "calacatta", "emperador"), default="carrara")
    parser.add_argument("--out", default=os.path.join(C.BUILD, "slab.blend"))
    studio.add_render_args(parser)
    args = C.script_args(parser)
    w, d, t = args.slab_size

    # The asset file: the slab and its anchors only.
    C.reset_scene()
    slab = build_slab(w, d, t)
    if args.stage >= 2:
        # The same marble as the stand (common.marble_material), honed, darker underneath.
        slab.data.materials.append(C.marble_material(args.marble, "honed", darker_underside=True, large_warp=0.22))
    points = anchors(args.oven_offset, args.stand_offset)
    place_anchors(points)
    if args.stage >= 3:
        import stand_materials as SM
        rail = build_rail(slab, points["RailStart"], points["RailEnd"])
        rail.data.materials.clear()
        rail.data.materials.append(SM.brushed_brass_linear())
    bpy.ops.wm.save_as_mainfile(filepath=args.out)
    with open(os.path.join(C.BUILD, "slab_anchors.json"), "w") as f:
        json.dump({k: [round(c, 4) for c in v] for k, v in points.items()}, f, indent=2)
    print(f"[slab] saved {os.path.relpath(args.out, C.REPO)} and build/slab_anchors.json")

    # The layout scene: slab + oven + stand + cloche, in the studio (the slab is the ground).
    studio.use(ground=False, station=True)
    oven = append_all(os.path.join(C.BUILD, "oven.blend"))
    stand = append_all(os.path.join(C.BUILD, "cakestand.blend"))
    cloche = append_all(os.path.join(C.BUILD, "cloche.blend"))
    for o in roots(oven):
        o.location.x += args.oven_offset
    for o in roots(stand) + roots(cloche):
        o.location.x += args.stand_offset
    import cloche as CL
    if cloche:
        CL.set_lift(0.0)
    bpy.context.view_layer.update()
    lo, hi = C.world_bounds(["StageSlab"])
    report = {"slab_mm": [round((hi - lo).x * 1000, 1), round((hi - lo).y * 1000, 1), round((hi - lo).z * 1000, 1)],
              "anchors": {k: [round(c, 3) for c in v] for k, v in points.items()},
              "missing": [n for n, objs in (("oven", oven), ("stand", stand), ("cloche", cloche)) if not objs]}
    print(f"[slab] {json.dumps(report)}")

    out_dir = os.path.join(C.BUILD, "renders", "slab", f"stage{args.stage}")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.users_collection[0].name.startswith("Studio")]
    if args.stage <= 1:
        R.apply_clay(meshes)
    else:
        # The cloche's glass comes with cake stand Stage 4; until then it renders as clay.
        R.apply_clay([o for o in meshes if o.name.startswith("Cloche")])
        studio.keep_oven_lights_off([o for o in meshes if o.name.startswith(("Stand", "Bearing", "Turntable", "Plate", "Cloche"))])
    studio.camera("topdown", subject=(lo, hi))
    studio.render(os.path.join(out_dir, "layout_top.png"), args, view_res=(1600, 1000))
    studio.camera("stage")
    studio.render(os.path.join(out_dir, "layout_stage.png"), args)
    # A close look at the eased edge and the chamfer, at the slab's front-left corner.
    cam = bpy.context.scene.camera
    cam.data.type, cam.data.lens = "PERSP", 100
    cam.location = C.Vector((SLAB_LEFT_X - 0.25, SLAB_FRONT_Y - 0.45, 0.10))
    studio.aim(cam, (SLAB_LEFT_X + 0.02, SLAB_FRONT_Y, -0.03))
    studio.render(os.path.join(out_dir, "detail_edge.png"), args, view_res=(1000, 750))
    if args.stage >= 3:
        # The rail's end and its stop, close, with the oven in the background.
        cam.data.lens = 100
        end = points["RailEnd"]
        cam.location = C.Vector((end[0] - 0.12, end[1] - 0.20, 0.07))
        studio.aim(cam, (end[0] - 0.01, end[1], 0.0))
        studio.render(os.path.join(out_dir, "detail_rail_end.png"), args, view_res=(1000, 750))
        start = points["RailStart"]
        cam.location = C.Vector((start[0] + 0.25, start[1] - 0.22, 0.06))
        studio.aim(cam, (start[0] + 0.02, start[1], 0.0))
        studio.render(os.path.join(out_dir, "detail_rail_start.png"), args, view_res=(1000, 750))
    # Raking light across the honed top: satin sheen, the faint scratches, veins through the edge.
    cam.data.lens = 60
    cam.location = C.Vector((0.70, SLAB_FRONT_Y - 0.55, 0.06))
    studio.aim(cam, (0.75, SLAB_FRONT_Y + 0.30, 0.0))
    studio.render(os.path.join(out_dir, "detail_surface.png"), args, view_res=(1000, 750))
    with open(os.path.join(out_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=2)


if __name__ == "__main__":
    main()
