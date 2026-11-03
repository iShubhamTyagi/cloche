"""Decorating step 4: what the live 3D cake viewer needs (docs/prompts/cake_maps.md).

    $B -b -P scripts/blender/cake_maps.py [-- --force --stage dish|plate|scene|check]

Reads the existing dish, stand and slab files without changing them. Per dish (cake = the
turned-out golden cake; cupcake = one hero cupcake, Cupcake_1 + Liner_1, golden):
  top: a polar grid (128 rings x 256 segments), heights ray-cast from the high-detail cake,
       UV u = angle / 2pi, v = radius / R. Maps 1024 x 1024.
  side: a cylinder grid (64 rows x 256 segments), radii ray-cast, UV u = angle / 2pi,
       v = height / H. Maps 1024 x 512. (For the cupcake the side is the paper liner.)
  Baked with Cycles from the high-detail object: albedo (colour only, no lighting), roughness,
  tangent normal, AO; plus height.png (16-bit bare crumb height of the top, range in the
  manifest) and profile.json (the grid heights and radii the app builds its meshes from).
Plate: the marble plate's top baked the same way (polar), the brass collar as constants.
Marble tile: 2048 seamless honed marble. env.hdr: 512 x 256 from the station studio.
viewer_scene.json: lights, exposure, cameras (plate-local metres, +Z up, origin at the plate's
top centre). Checks: preview (exported maps on the low grid, plain Principled) vs the original.
"""
import argparse
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
import imaging as I  # noqa: E402
import studio  # noqa: E402

OUT = os.path.join(D.OUT, "viewer")
PLATE_TOP = Vector((1.4, 0.15, 0.2055))           # asset_status.md: TurntablePlate top centre
RINGS, SEGS, ROWS = 128, 256, 64
DISHES = {
    "cake_golden": ("cake_turnout.blend", ["CakeTurnout"]),
    "cupcake_golden": ("muffin_tin_golden.blend", ["Cupcake_1", "Liner_1"]),
}


def open_blend(name):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(C.BUILD, name))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.device = "GPU"
    for o in list(scene.objects):
        o.hide_render = False


def bounds(objs):
    lo, hi = C.world_bounds([o.name for o in objs])
    return Vector(lo), Vector(hi)


def ray_in(depsgraph, centre, angle, z, r_from, targets):
    d = Vector((-math.cos(angle), -math.sin(angle), 0))
    o = Vector((centre.x + r_from * math.cos(angle), centre.y + r_from * math.sin(angle), z))
    hit, loc, _, _, obj, _ = bpy.context.scene.ray_cast(depsgraph, o, d)
    return (Vector((loc.x, loc.y, 0)) - Vector((centre.x, centre.y, 0))).length if hit and obj.name in targets else None


def grid_top(name, centre, radius, heights):
    """Polar grid: heights[ring][seg] (world z). Centre vertex + RINGS rings."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    for i in range(RINGS + 1):
        r = radius * i / RINGS
        rows.append([bm.verts.new((centre.x + r * math.cos(2 * math.pi * s / SEGS),
                                   centre.y + r * math.sin(2 * math.pi * s / SEGS), heights[i][s % SEGS]))
                     for s in range(SEGS + 1)])            # duplicate seam column for clean UVs
    for i in range(RINGS):
        for s in range(SEGS):
            f = bm.faces.new((rows[i][s], rows[i][s + 1], rows[i + 1][s + 1], rows[i + 1][s]))
            for loop, (ii, ss) in zip(f.loops, ((i, s), (i, s + 1), (i + 1, s + 1), (i + 1, s))):
                loop[uv].uv = (ss / SEGS, ii / RINGS)
    bmesh.ops.remove_doubles(bm, verts=[v for row in rows[:1] for v in row], dist=1e-7)
    return D.bm_object(name, bm)


def grid_side(name, centre, z0, z1, radii):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    for j in range(ROWS + 1):
        z = z0 + (z1 - z0) * j / ROWS
        rows.append([bm.verts.new((centre.x + radii[j][s % SEGS] * math.cos(2 * math.pi * s / SEGS),
                                   centre.y + radii[j][s % SEGS] * math.sin(2 * math.pi * s / SEGS), z))
                     for s in range(SEGS + 1)])
    for j in range(ROWS):
        for s in range(SEGS):
            f = bm.faces.new((rows[j][s], rows[j + 1][s], rows[j + 1][s + 1], rows[j][s + 1]))
            for loop, (jj, ss) in zip(f.loops, ((j, s), (j + 1, s), (j + 1, s + 1), (j, s + 1))):
                loop[uv].uv = (ss / SEGS, jj / ROWS)
    return D.bm_object(name, bm)


def bake(low, high_objs, out_dir, prefix, size, force):
    """Albedo, roughness, normal, AO from the high objects onto `low`'s UVs."""
    mat = bpy.data.materials.new(f"Bake_{low.name}")
    mat.use_nodes = True
    low.data.materials.append(mat)
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = node
    scene = bpy.context.scene
    paths = {}
    for kind, btype, extra in (("albedo", "DIFFUSE", {"pass_filter": {"COLOR"}}), ("roughness", "ROUGHNESS", {}),
                               ("normal", "NORMAL", {}), ("ao", "AO", {})):
        path = os.path.join(out_dir, f"{prefix}{kind}.png")
        paths[kind] = path
        if os.path.exists(path) and not force:
            continue
        img = bpy.data.images.new(f"{low.name}_{kind}", *size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "sRGB" if kind == "albedo" else "Non-Color"
        node.image = img
        bpy.ops.object.select_all(action="DESELECT")
        for o in high_objs:
            o.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        scene.cycles.samples = 32 if kind == "ao" else 1
        scene.render.bake.use_selected_to_active = True
        scene.render.bake.cage_extrusion = 0.003
        scene.render.bake.max_ray_distance = 0.012
        scene.render.bake.margin = 8
        bpy.ops.object.bake(type=btype, **extra)
        img.filepath_raw = path
        img.file_format = "PNG"
        os.makedirs(out_dir, exist_ok=True)
        img.save()
    return paths


def do_dish(key, args):
    blend, names = DISHES[key]
    open_blend(blend)
    high = [bpy.data.objects[n] for n in names]
    for o in bpy.data.objects:                      # bake from the dish alone
        if o.type == "MESH" and o not in high:
            o.hide_render = True
    lo, hi = bounds(high)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    radius = max(hi.x - lo.x, hi.y - lo.y) / 2
    depsgraph = bpy.context.evaluated_depsgraph_get()
    targets_names = {o.name for o in high}
    is_cup = key.startswith("cupcake")
    top_r = radius * (0.985 if not is_cup else 1.0)
    heights = []
    for i in range(RINGS + 1):
        r = top_r * i / RINGS
        row = []
        for s in range(SEGS):
            a = 2 * math.pi * s / SEGS
            hit, loc, _, _, obj, _ = bpy.context.scene.ray_cast(
                depsgraph, Vector((centre.x + r * math.cos(a), centre.y + r * math.sin(a), hi.z + 0.05)), Vector((0, 0, -1)))
            row.append(loc.z if hit and obj.name in targets_names else (row[-1] if row else hi.z))
        heights.append(row)
    if is_cup:
        # The crown starts where the liner ends: the side strip covers the liner, the top the crown.
        liner = bpy.data.objects["Liner_1"]
        side_top = bounds([liner])[1].z
        crown = [[max(z, side_top) for z in row] for row in heights]
        heights = crown
    else:
        side_top = min(min(r) for r in heights[-4:])
    side_lo = lo.z + 0.0005
    radii = []
    for j in range(ROWS + 1):
        z = side_lo + (side_top - side_lo) * j / ROWS
        row = []
        for s in range(SEGS):
            a = 2 * math.pi * s / SEGS
            r = ray_in(depsgraph, centre, a, z, radius * 1.5, targets_names)
            row.append(r if r else radius)
        radii.append(row)
    out_dir = os.path.join(OUT, key)
    top = grid_top(f"{key}_top", centre, top_r, heights)
    side = grid_side(f"{key}_side", centre, side_lo, side_top, radii)
    bake(top, high, out_dir, "top_", (1024, 1024), args.force)
    bake(side, high, out_dir, "side_", (1024, 512), args.force)
    # Bare crumb height (top), 16-bit over the recorded range, polar like the maps.
    h = np.array(heights, dtype=np.float32)
    zmin, zmax = float(h.min()), float(h.max())
    polar = (h - zmin) / max(zmax - zmin, 1e-6)
    D.gray16(os.path.join(out_dir, "height.png"), polar[::-1])
    profile = {
        "units": "metres, dish-local: origin at the centre of the dish's base, +Z up",
        "radius": round(radius, 5), "top_radius": round(top_r, 5), "side_bottom": round(side_lo - lo.z, 5),
        "side_top": round(side_top - lo.z, 5), "height": round(hi.z - lo.z, 5),
        "top_heights_rings": [round(float(np.mean(r)) - lo.z, 5) for r in heights],
        "side_radii_rows": [round(float(np.mean(r)), 5) for r in radii],
        "height_png_range": [round(zmin - lo.z, 5), round(zmax - lo.z, 5)],
        "grid": {"rings": RINGS, "segments": SEGS, "rows": ROWS},
        "decoratable_side": not is_cup,
    }
    D.write_json(os.path.join(out_dir, "profile.json"), profile)
    # Reference mesh for the preview check (not shipped).
    bpy.ops.object.select_all(action="DESELECT")
    top.select_set(True)
    side.select_set(True)
    bpy.ops.wm.usd_export(filepath=os.path.join(out_dir, "mesh.usdz"), selected_objects_only=True)
    print(f"[cake_maps] {key}: r {radius * 1000:.1f} mm, h {(hi.z - lo.z) * 1000:.1f} mm")
    return profile


def do_plate(args):
    open_blend("cakestand.blend")
    plate = bpy.data.objects["TurntablePlate"]
    for o in bpy.data.objects:
        if o.type == "MESH" and o != plate:
            o.hide_render = True
    lo, hi = bounds([plate])
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0))
    radius = (hi.x - lo.x) / 2
    depsgraph = bpy.context.evaluated_depsgraph_get()
    heights = []
    for i in range(RINGS + 1):
        r = radius * 0.995 * i / RINGS
        row = []
        for s in range(SEGS):
            a = 2 * math.pi * s / SEGS
            hit, loc, *_ = bpy.context.scene.ray_cast(depsgraph, Vector((centre.x + r * math.cos(a), centre.y + r * math.sin(a), hi.z + 0.05)), Vector((0, 0, -1)))
            row.append(loc.z if hit else hi.z)
        heights.append(row)
    top = grid_top("plate_top", centre, radius * 0.995, heights)
    paths = bake(top, [plate], os.path.join(OUT, "plate"), "", (1024, 1024), args.force)
    D.write_json(os.path.join(OUT, "plate", "plate.json"), {
        "radius": round(radius, 5), "thickness": round(hi.z - lo.z, 5),
        "top_profile_rings": [round(float(np.mean(r)) - lo.z, 5) for r in heights],
        "collar": {"inner_radius": 0.079, "outer_radius": 0.088, "height": 0.009, "z_below_plate_top": 0.032,
                   "base_colour_linear": [0.78, 0.56, 0.26], "metallic": 1.0, "roughness": 0.3,
                   "note": "BrushedBrass: uniform, so constants instead of maps"}})
    return paths


def marble_tile(args):
    path = os.path.join(OUT, "marble_tile", "albedo.png")
    if os.path.exists(path) and not args.force:
        return
    C.reset_scene()
    bm = bmesh.new()
    C.add_box(bm, (-0.25, -0.25, -0.01), (0.25, 0.25, 0.0))
    obj = D.bm_object("Tile", bm)
    obj.data.materials.append(C.marble_material("carrara", finish="honed", large_warp=0.4))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.data.uv_layers.new(name="UVMap")
    # Top face only: planar UV from x, y.
    me = obj.data
    uv = me.uv_layers.active
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = ((co.x + 0.25) / 0.5, (co.y + 0.25) / 0.5)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    node = obj.active_material.node_tree.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.new("tile", 2048, 2048, alpha=False)
    node.image = img
    obj.active_material.node_tree.nodes.active = node
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=0)
    tmp = path + ".raw.png"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.filepath_raw = tmp
    img.file_format = "PNG"
    img.save()
    arr = I.load(tmp)
    os.remove(tmp)
    # Seamless: cross-fade with a half-offset copy under a mask that is 1 in the middle and 0 at
    # the edges, so the edges come from the copy (whose edges are the original's middle).
    n = arr.shape[0]
    t = np.abs(np.linspace(-1, 1, n))
    m = np.clip((1 - np.maximum(t[None, :], t[:, None])) * 3, 0, 1)[..., None]
    shifted = np.roll(np.roll(arr, n // 2, axis=0), n // 2, axis=1)
    out = arr * m + shifted * (1 - m)
    out[..., 3] = 1
    I.save(out, path)


def env_map(args):
    path = os.path.join(OUT, "env.hdr")
    if os.path.exists(path) and not args.force:
        return
    D.setup(ground=True, samples=64)
    scene = bpy.context.scene
    cam = bpy.data.objects.new("Env", bpy.data.cameras.new("Env"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "PANO"
    cam.data.panorama_type = "EQUIRECTANGULAR"
    cam.location = PLATE_TOP + Vector((0, 0, 0.05))
    cam.rotation_euler = (math.pi / 2, 0, -math.pi / 2)
    scene.render.film_transparent = False
    scene.render.resolution_x, scene.render.resolution_y = 512, 256
    scene.render.image_settings.file_format = "HDR"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def scene_json():
    views = studio.views()
    with bpy.data.libraries.load(studio.STUDIO_BLEND) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("Station")]
    lights = []
    for o in dst.objects:
        if o and o.type == "LIGHT":
            d = (o.matrix_world.to_quaternion() @ Vector((0, 0, -1))).normalized()
            lights.append({"name": o.name, "type": o.data.type, "direction": [round(v, 4) for v in d],
                           "position_plate_local": [round(v, 4) for v in (o.location - PLATE_TOP)],
                           "energy_w": o.data.energy, "colour": list(o.data.color), "size": [o.data.size, o.data.size_y]})
    st = views["station"]
    stage = {"position": [round(a - b, 4) for a, b in zip(st["location"], PLATE_TOP)],
             "target": [round(a - b, 4) for a, b in zip(st["target"], PLATE_TOP)],
             "lens_mm": st["lens"], "sensor_mm": 36, "resolution": st["resolution"]}

    def orbit(elev_deg, distance):
        e = math.radians(elev_deg)
        return {"position": [0.0, round(-distance * math.cos(e), 4), round(distance * math.sin(e), 4)],
                "target": [0.0, 0.0, 0.02], "elevation_deg": elev_deg, "fov_deg": 30.0}

    # 200 mm cake filling 78% of the width at 30 degrees vertical fov on a 9:19.5 screen.
    dist = 0.1 / 0.78 / math.tan(math.radians(15) * 9 / 19.5 * 1.0) * 0.5
    return {
        "units": "metres; plate-local: origin at the plate's top centre, +Z up, front of the station = -Y",
        "exposure": D.EXPOSURE, "view_transform": "AgX", "look": "AgX - Medium High Contrast",
        "lights": lights, "environment": "env.hdr",
        "cameras": {"stage_wide": stage, "top": orbit(90, dist), "angle": orbit(55, dist), "side": orbit(10, dist)},
        "elevation_range_deg": [10, 90],
    }


def preview_check(key, profile):
    """Original high-detail dish vs the exported grid + maps, top-down, same light."""
    blend, names = DISHES[key]
    out_dir = os.path.join(OUT, key)
    results = {}
    for which in ("original", "preview"):
        D.setup(samples=32)
        with bpy.data.libraries.load(os.path.join(C.BUILD, blend)) as (src, dst):
            dst.objects = list(src.objects)
        objs = [o for o in dst.objects if o]
        for o in objs:
            bpy.context.scene.collection.objects.link(o)
            o.hide_render = which == "preview" or o.name not in names
        lo, hi = bounds([o for o in objs if o.name in names])
        centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        if which == "preview":
            bpy.ops.wm.usd_import(filepath=os.path.join(out_dir, "mesh.usdz"))
            for o in bpy.context.scene.objects:
                if o.type == "MESH" and ("top" in o.name or "side" in o.name) and o.name not in names:
                    part = "top" if "top" in o.name else "side"
                    mat = bpy.data.materials.new(f"Prev_{o.name}")
                    mat.use_nodes = True
                    nt = mat.node_tree
                    bsdf = nt.nodes["Principled BSDF"]
                    for kind, sock in (("albedo", "Base Color"), ("roughness", "Roughness")):
                        tex = nt.nodes.new("ShaderNodeTexImage")
                        tex.image = bpy.data.images.load(os.path.join(out_dir, f"{part}_{kind}.png"))
                        if kind != "albedo":
                            tex.image.colorspace_settings.name = "Non-Color"
                        nt.links.new(tex.outputs["Color"], bsdf.inputs[sock])
                    ntex = nt.nodes.new("ShaderNodeTexImage")
                    ntex.image = bpy.data.images.load(os.path.join(out_dir, f"{part}_normal.png"))
                    ntex.image.colorspace_settings.name = "Non-Color"
                    nmap = nt.nodes.new("ShaderNodeNormalMap")
                    nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
                    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
                    o.data.materials.clear()
                    o.data.materials.append(mat)
                    o.hide_render = False
        D.sprite_camera((hi.x - lo.x) * 1.1, centre=centre + Vector((0, 0, hi.z - lo.z)), res=512)
        path = os.path.join(out_dir, f"check_{which}.png")
        D.render(path, 512, samples=32, force=True)
        results[which] = I.load(path)
    a, b = results["original"], results["preview"]
    mask = (a[..., 3] > 0.5) & (b[..., 3] > 0.5)
    err = float(np.abs(a[..., :3] - b[..., :3])[mask].mean())
    alb = I.load(os.path.join(out_dir, "side_albedo.png"))
    seam = float(np.abs(alb[:, 2, :3] - alb[:, -3, :3]).mean())
    gap = np.full((512, 8, 4), 1.0, dtype=np.float32)
    I.save(np.concatenate([I.over_background(a), gap, I.over_background(b)], axis=1), os.path.join(out_dir, "check.png"))
    return {"mean_abs_error": round(err, 4), "side_seam_error": round(seam, 4)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--stage", default="all")
    args = C.script_args(parser)
    manifest_path = os.path.join(OUT, "viewer_manifest.json")
    profiles = {}
    if args.stage in ("all", "dish"):
        for key in DISHES:
            profiles[key] = do_dish(key, args)
    if args.stage in ("all", "plate"):
        do_plate(args)
        marble_tile(args)
        env_map(args)
    if args.stage in ("all", "scene"):
        D.write_json(os.path.join(OUT, "viewer_scene.json"), scene_json())
    checks = {}
    if args.stage in ("all", "check"):
        for key in DISHES:
            import json
            with open(os.path.join(OUT, key, "profile.json")) as f:
                checks[key] = preview_check(key, json.load(f))
        D.write_json(os.path.join(OUT, "checks.json"), checks)
    D.write_json(manifest_path, {
        "dishes": {k: {"dir": k, "maps": ["top_albedo", "top_roughness", "top_normal", "top_ao", "side_albedo",
                                         "side_roughness", "side_normal", "side_ao", "height"], "profile": "profile.json"}
                   for k in DISHES},
        "plate": "plate/", "marble_tile": "marble_tile/albedo.png", "environment": "env.hdr",
        "scene": "viewer_scene.json", "size_mb": D.dir_mb(OUT), "budget_mb": 45,
        "states": "golden only; the app tints for half and dark (see DECISIONS 2026-11-03)"})
    print(f"[cake_maps] viewer {D.dir_mb(OUT)} MB", checks)


if __name__ == "__main__":
    main()
