"""The glass cloche: Cloche (bell, real 3 mm wall), ClocheRim (rounded bead that seats in the
plate's groove), ClocheFinial (knob on top; brushed brass or clear glass). Origin of Cloche at
the centre of its base (the bead's lowest point, in the groove), so lifting is +Z only.

Sizes (owner's brief): inner diameter ~26 cm, inner height ~24 cm, wall ~3 mm. It seats inboard
on the 30 cm plate, in the groove (owner, 2026-11-02).
"""
import math

import bmesh
import bpy

import cakes
import common as C
import cakestand as S

INNER_R = 0.1297          # inner radius of the body: 25.9 cm inner diameter
# The skirt flares out so the wall's centre lands on the rim bead, which sits in the groove.
INNER_H = 0.240           # inner height above the plate
WALL = 0.003
BEAD_R = 0.0022           # rim bead radius (seats in the 5 mm groove)
FLARE = S.GROOVE["r"] - WALL / 2 - INNER_R   # 3.0 mm: the skirt's outward flare at the rim
SHAPE_P = 2.3             # superellipse: higher is squarer shoulders
LIFT_HEIGHT = 0.60        # fully lifted: out of the station camera's frame
FINIAL = {"collar_r": 0.011, "collar_h": 0.006, "neck_r": 0.0055, "neck_h": 0.010, "ball_r": 0.0145}


def base_z():
    """The bead's lowest point, resting in the bottom of the plate's groove."""
    return S.Z_PLATE_TOP - S.GROOVE["d"]


def bead_join_z():
    """Height (above the base) where the wall's faces meet the rim bead's circle."""
    return BEAD_R + math.sqrt(BEAD_R ** 2 - (WALL / 2) ** 2)


def inner_profile(n=140):
    """Inner surface (r, z) from the rim (z = bead top) up to the top centre."""
    z0 = bead_join_z()
    pts = []
    for k in range(n + 1):
        t = k / n                                   # 0 at the rim, 1 at the top
        a = t * math.pi / 2
        r = INNER_R * math.cos(a) ** (2 / SHAPE_P)
        z = z0 + (INNER_H - z0) * math.sin(a) ** (2 / SHAPE_P)
        r += FLARE * (1 - min(t / 0.18, 1.0)) ** 2  # skirt flare near the rim
        pts.append((max(r, 0.0006), z))
    return pts


def offset_profile(pts, d):
    """Offset an (r, z) curve outward along its 2D normal by d (the real wall thickness)."""
    out = []
    for i, (r, z) in enumerate(pts):
        r0, z0 = pts[max(i - 1, 0)]
        r1, z1 = pts[min(i + 1, len(pts) - 1)]
        tr, tz = r1 - r0, z1 - z0
        length = math.hypot(tr, tz) or 1.0
        nr, nz = tz / length, -tr / length          # outward for a curve going up and inward
        out.append((max(r + nr * d, 0.0006), z + nz * d))
    return out


def build(stand_centre_z=None):
    """Build the three cloche objects seated on the plate. Returns the Cloche object."""
    zb = base_z()
    origin = S.at(z=zb)
    inner = inner_profile()
    outer = offset_profile(inner, WALL)
    # One watertight glass solid: top-inner pole, down the inner wall, round the rim bead under
    # the wall, up the outer wall, top-outer pole. No overlapping shells (they refract black).
    cr, cz = S.GROOVE["r"], BEAD_R
    ri, zi = inner[0]
    ro, zo = outer[0]
    ai, ao = math.atan2(zi - cz, ri - cr), math.atan2(zo - cz, ro - cr)
    if ao < ai:
        ao += 2 * math.pi
    di, do = math.hypot(ri - cr, zi - cz), math.hypot(ro - cr, zo - cz)
    steps = 28
    bead = []
    for k in range(1, steps):
        t = k / steps
        a = ai + (ao - ai) * t
        d = di + (do - di) * t
        bead.append((cr + d * math.cos(a), cz + d * math.sin(a)))
    prof = list(reversed(inner)) + bead + outer
    coords, faces = cakes.revolve(prof, S.at(z=zb), 256)
    me = bpy.data.meshes.new("Cloche")
    me.from_pydata([tuple(c[k] - origin[k] for k in range(3)) for c in coords], [], faces)
    me.update()
    me.shade_smooth()
    cloche = bpy.data.objects.new("Cloche", me)
    cloche.location = origin
    C.link(cloche)
    cloche.lock_rotation = (True, True, True)
    cloche.lock_location = (True, True, False)
    cloche["role"] = "glass dome; origin at the centre of its base; lifts along +Z"
    cloche["lift_height_m"] = LIFT_HEIGHT

    # ClocheRim: the bead's faces split off into their own object (shared edges, no overlap),
    # so the rim can carry its own finish (a ground, slightly frosted contact band).
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)      # outward: glass needs it
    rim_top = bead_join_z() + 1e-6
    rim_faces = [f for f in bm.faces if all(v.co.z <= rim_top for v in f.verts)]
    rim_bm = bmesh.new()
    vmap = {}
    for f in rim_faces:
        rim_bm.faces.new([vmap.setdefault(v.index, rim_bm.verts.new(v.co)) for v in f.verts])
    bmesh.ops.delete(bm, geom=rim_faces, context="FACES_ONLY")
    bm.to_mesh(me)
    bm.free()
    rim_me = bpy.data.meshes.new("ClocheRim")
    rim_bm.to_mesh(rim_me)
    rim_bm.free()
    rim_me.shade_smooth()
    rim = bpy.data.objects.new("ClocheRim", rim_me)
    rim.location = origin
    C.link(rim)
    bpy.context.view_layer.update()
    rim.parent = cloche
    rim.matrix_parent_inverse = cloche.matrix_world.inverted()

    # Finial: collar, neck, ball, on the outer top.
    f = FINIAL
    top = zb + outer[-1][1]
    prof = [(0.0004, top - 0.002), (f["collar_r"], top - 0.002)]
    prof += S.M_arc(f["collar_r"] - 0.002, top + f["collar_h"] - 0.002, 0.002, 0, 90, 6)
    prof += [(f["neck_r"], top + f["collar_h"] + 0.001), (f["neck_r"], top + f["collar_h"] + f["neck_h"] * 0.6)]
    cz = top + f["collar_h"] + f["neck_h"] + f["ball_r"] * 0.85
    a0 = math.degrees(math.asin(max(-1.0, min(1.0, (top + f["collar_h"] + f["neck_h"] - cz) / f["ball_r"]))))
    for k in range(25):
        a = math.radians(a0 + (90 - a0) * k / 24)
        prof.append((max(f["ball_r"] * math.cos(a), 0.0004), cz + f["ball_r"] * math.sin(a)))
    coords, faces = cakes.revolve(prof, S.at(), 128)
    me = bpy.data.meshes.new("ClocheFinial")
    fo = S.at(z=top)
    me.from_pydata([tuple(c[k] - fo[k] for k in range(3)) for c in coords], [], faces)
    me.update()
    me.shade_smooth()
    finial = bpy.data.objects.new("ClocheFinial", me)
    finial.location = fo
    C.link(finial)
    bpy.context.view_layer.update()
    finial.parent = cloche
    finial.matrix_parent_inverse = cloche.matrix_world.inverted()
    return cloche


def set_lift(lift):
    """0 seated on the plate, 1 lifted out of frame. Straight up, ease handled by the caller."""
    cloche = bpy.data.objects["Cloche"]
    cloche.location.z = base_z() + LIFT_HEIGHT * max(0.0, min(1.0, lift))
    bpy.context.view_layer.update()


def checks():
    """Real wall thickness, inner size, seating, and room for the dishes under the dome."""
    inner = inner_profile()
    outer = offset_profile(inner, WALL)
    def inner_height_at(r):
        best = 0.0
        for (r0, z0) in inner:
            if r0 >= r:
                best = max(best, z0)
        return best
    lo, hi = C.world_bounds(["Cloche", "ClocheRim", "ClocheFinial"])
    wall = min(math.hypot(o[0] - i[0], o[1] - i[1]) for i, o in zip(inner, outer))
    return {
        "inner_diameter_mm": round(INNER_R * 2000, 1),
        "rim_opening_mm": round(inner[0][0] * 2000, 1),
        "wall_centre_on_bead_mm": round(((inner[0][0] + WALL / 2) - S.GROOVE["r"]) * 1000, 2),
        "inner_height_mm": round(inner[-1][1] * 1000, 1),
        "wall_mm": round(wall * 1000, 2),
        "outer_diameter_mm": round((hi - lo).x * 1000, 1),
        "overall_height_mm": round((hi - lo).z * 1000, 1),
        "seats_in_groove": abs(lo.z - base_z()) < 1e-4,
        # A 20 cm cake (r 100 mm) and a 70 mm cupcake: inner height available above them.
        "headroom_at_cake_edge_mm": round(inner_height_at(0.100) * 1000, 1),
        "headroom_at_cupcake_edge_mm": round(inner_height_at(0.035) * 1000, 1),
    }
