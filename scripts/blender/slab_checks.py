"""Stage 4 of the slab: the oven door's clearance against the slab, the stand and the rail;
the layout outlines for the top-down render; and the void shadow layer under the floating slab.
"""
import math
import os

import bmesh
import bpy

import common as C
import render as R
import studio
import cakestand as S
from layout import SLAB_FRONT_Y, SLAB_LEFT_X

SWEEP = [a for a in range(0, 181, 4)] + [88]
OUTLINE_Z = 1.0                 # overlays float above everything (top-down ortho only)


def _door_vertices():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in C.descendants(bpy.data.objects["Door"]):
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        pts += [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    return pts


def clearance(points, slab_size, rail_dims):
    """Sweep the door 0..180 and measure it against the slab's solid, the stand's plate and foot
    (plan distance), and the rail's end stops. Returns the report; changes nothing."""
    w, d, t = slab_size
    x0, x1, y0, y1 = SLAB_LEFT_X, SLAB_LEFT_X + w, SLAB_FRONT_Y, SLAB_FRONT_Y + d
    sx, sy = points["StandAnchor"][0], points["StandAnchor"][1]
    plate_r, foot_r = S.PLATE["r"], S.FOOT["r"]
    rail_w, rail_depth, stop_len = rail_dims
    stops = [points["RailStart"], points["RailEnd"]]
    out = {"per_angle": {}}
    worst = {"in_slab": 0, "in_stop": 0, "gap_to_plate_rim_mm": 1e9, "gap_to_slab_front_mm": 1e9}
    for angle in sorted(set(SWEEP)):
        R.set_door(angle)
        verts = _door_vertices()
        in_slab = sum(1 for v in verts if x0 < v.x < x1 and y0 + 1e-4 < v.y < y1 and -t < v.z < -1e-4)
        in_stop = sum(1 for v in verts for p in stops
                      if abs(v.x - p[0]) < stop_len / 2 and abs(v.y - p[1]) < stop_len / 2 and -rail_depth < v.z < 0.001)
        plan = min(math.hypot(v.x - sx, v.y - sy) for v in verts)
        # Gap to the slab's front face, across its thickness only; anything lower hangs in the
        # void and may tuck under the floating slab (the handle does at 180).
        below = [y0 - v.y for v in verts if -t <= v.z < 0 and x0 < v.x < x1]
        under = [v.y - y0 for v in verts if v.z < -t and x0 < v.x < x1 and v.y > y0]
        row = {"in_slab": in_slab, "touches_rail_stops": in_stop > 0,
               "gap_to_plate_rim_mm": round((plan - plate_r) * 1000, 1),
               "gap_to_foot_mm": round((plan - foot_r) * 1000, 1),
               "door_past_front_edge_mm": round((y0 - min(v.y for v in verts)) * 1000, 1),
               "lowest_point_mm": round(min(v.z for v in verts) * 1000, 1)}
        if under:
            row["tucks_under_slab_mm"] = round(max(under) * 1000, 1)
            row["clearance_below_slab_mm"] = round((-t - max(v.z for v in verts if v.z < -t and v.y > y0)) * 1000, 1)
        if below:
            row["gap_to_slab_front_mm"] = round(min(below) * 1000, 1)
            worst["gap_to_slab_front_mm"] = min(worst["gap_to_slab_front_mm"], row["gap_to_slab_front_mm"])
        worst["in_slab"] = max(worst["in_slab"], in_slab)
        worst["in_stop"] = max(worst["in_stop"], in_stop)
        worst["gap_to_plate_rim_mm"] = min(worst["gap_to_plate_rim_mm"], row["gap_to_plate_rim_mm"])
        if angle in (0, 88, 180):
            out["per_angle"][str(angle)] = row
    R.set_door(0)
    out["sweep_0_to_180"] = {
        "door_enters_slab": worst["in_slab"] > 0,
        "door_touches_rail_stops": worst["in_stop"] > 0,
        "min_gap_to_plate_rim_mm": worst["gap_to_plate_rim_mm"],
        "min_gap_to_slab_front_mm": None if worst["gap_to_slab_front_mm"] == 1e9 else worst["gap_to_slab_front_mm"],
        "meets_250mm_to_stand_rim": worst["gap_to_plate_rim_mm"] >= 250,
    }
    return out


# ------------------------------------------------------------------ outlines (layout_top)

def _emission(name, colour, strength=3.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(em.outputs[0], out.inputs[0])
    return mat


def _polyline(name, pts, colour, closed=True, width=0.003):
    """A flat ribbon along the points, at OUTLINE_Z."""
    bm = bmesh.new()
    n = len(pts)
    segs = n if closed else n - 1
    for i in range(segs):
        (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length * width / 2, dx / length * width / 2
        vs = [bm.verts.new((ax + nx, ay + ny, OUTLINE_Z)), bm.verts.new((bx + nx, by + ny, OUTLINE_Z)),
              bm.verts.new((bx - nx, by - ny, OUTLINE_Z)), bm.verts.new((ax - nx, ay - ny, OUTLINE_Z))]
        bm.faces.new(vs)
    obj = C.mesh_object(name, bm, origin=(pts[0][0], pts[0][1], OUTLINE_Z))
    obj.data.materials.append(_emission(f"Outline_{name}", colour))
    obj.visible_shadow = False
    return obj


def _circle(cx, cy, r, steps=96):
    return [(cx + r * math.cos(2 * math.pi * k / steps), cy + r * math.sin(2 * math.pi * k / steps)) for k in range(steps)]


def _rect(lo, hi):
    return [(lo[0], lo[1]), (hi[0], lo[1]), (hi[0], hi[1]), (lo[0], hi[1])]


def outlines(points, slab_size):
    """Footprints for the top-down layout test: slab, oven body, the 88-degree door, stand foot
    and plate, the rail, and a cross at every anchor."""
    sand, honey, ivory, steel = (0.80, 0.70, 0.54), (0.89, 0.75, 0.49), (0.96, 0.94, 0.90), (0.55, 0.62, 0.70)
    ink = (0.0, 0.0, 0.0)          # reads on white marble (black emission = unlit black)
    w, d, _ = slab_size
    objs = [_polyline("OutlineSlab", _rect((SLAB_LEFT_X, SLAB_FRONT_Y), (SLAB_LEFT_X + w, SLAB_FRONT_Y + d)), ivory)]
    lo, hi = C.world_bounds(["Body"])
    objs.append(_polyline("OutlineOven", _rect((lo.x, lo.y), (hi.x, hi.y)), sand))
    R.set_door(88)
    dl, dh = C.world_bounds([o.name for o in C.descendants(bpy.data.objects["Door"]) if o.type == "MESH"])
    objs.append(_polyline("OutlineDoor88", _rect((dl.x, dl.y), (dh.x, dh.y)), steel))
    R.set_door(0)
    sx, sy = points["StandAnchor"][0], points["StandAnchor"][1]
    objs.append(_polyline("OutlinePlate", _circle(sx, sy, S.PLATE["r"]), honey))
    objs.append(_polyline("OutlineFoot", _circle(sx, sy, S.FOOT["r"]), honey, width=0.002))
    a, b = points["RailStart"], points["RailEnd"]
    objs.append(_polyline("OutlineRail", [(a[0], a[1]), (b[0], b[1])], honey, closed=False, width=0.004))
    arm = 0.025
    for name, p in points.items():
        objs.append(_polyline(f"Cross{name}", [(p[0] - arm, p[1]), (p[0] + arm, p[1])], ink, closed=False))
        objs.append(_polyline(f"Cross{name}V", [(p[0], p[1] - arm), (p[0], p[1] + arm)], ink, closed=False))
    return objs


# ------------------------------------------------------------------ void shadow layer

def void_shadow(out_dir, args, slab_size, views):
    """A soft shadow on the void under the floating slab, as its own layer: a shadow catcher
    below the slab, everything else invisible to the camera but still casting."""
    _, _, t = slab_size
    lo, hi = C.world_bounds(["StageSlab"])
    pad = 4.0                       # past every camera's frame: no visible plane edge
    bm = bmesh.new()
    C.add_box(bm, (lo.x - pad, lo.y - pad, -t - 0.15 - 0.001), (hi.x + pad, hi.y + pad, -t - 0.15))
    catcher = C.mesh_object("VoidCatcher", bm, origin=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, -t - 0.15))
    catcher.is_shadow_catcher = True
    hidden = [o for o in bpy.context.scene.objects if o.type == "MESH" and o is not catcher and o.visible_camera]
    for o in hidden:
        o.visible_camera = False
    paths = []
    for name, view, subject in views:
        studio.camera(view, subject=subject)
        path = os.path.join(out_dir, f"void_shadow_{name}.png")
        studio.render(path, args)
        paths.append(path)
    for o in hidden:
        o.visible_camera = True
    bpy.data.objects.remove(catcher)
    return paths
