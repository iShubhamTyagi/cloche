"""Shared helpers for the decorating asset scripts (icing, toppings, tools, cake_maps, toppings3d,
station, focus, export_assets). Keeps each script short and the look consistent.

- Subjects are built at the plating station's plate centre (STATION) so the studio's station
  lights (`studio.use(station=True)`) light them exactly like the stand renders.
- Sprites are top-down orthographic. The camera is rolled 90 degrees so the station key light
  (front-left, above) falls from the top-left of the image and shadows fall to the bottom-right,
  as the station layout rule asks. This is the only camera these scripts add (no lights).
- Every sprite renders at 2x and is box-downsampled, so edges stay clean.
"""
import json
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import common as C
import imaging as I
import studio

STATION = Vector((1.4, 0.15, 0.0))     # camera.json plate_topdown target
OUT = os.path.join(C.BUILD, "renders")
DOCS = os.path.join(C.REPO, "docs")


def setup(ground=True, samples=32):
    """Empty scene with the studio world and the station lights."""
    C.reset_scene()
    studio.use(ground=ground, station=True)
    scene = bpy.context.scene
    scene.cycles.samples = samples
    scene.render.film_transparent = True
    return scene


def sprite_camera(extent_m, centre=STATION, height=1.2, res=512, roll=True):
    """Top-down orthographic camera covering `extent_m` metres, square `res` pixels."""
    scene = bpy.context.scene
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("SpriteCam", bpy.data.cameras.new("SpriteCam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = extent_m
    cam.data.clip_start = 0.001
    cam.data.clip_end = height + 1
    cam.location = (centre.x, centre.y, centre.z + height)
    cam.rotation_euler = (0, 0, math.pi / 2 if roll else 0)
    scene.render.resolution_x = scene.render.resolution_y = res
    bpy.context.view_layer.update()
    return cam


def render(path, res, samples=32, supersample=2, force=False):
    """Render the scene camera to `path` at `res` (int or (w, h)) via a 2x render."""
    if os.path.exists(path) and not force:
        return False
    w, h = (res, res) if isinstance(res, int) else res
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = w * supersample, h * supersample
    scene.cycles.samples = samples
    tmp = path + ".tmp.png"
    scene.render.filepath = tmp
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    arr = I.load(tmp)
    if supersample > 1:
        arr = arr.reshape(h, supersample, w, supersample, 4).mean(axis=(1, 3))
    arr[arr[..., 3] < 1 / 255, :3] = 0
    I.save(arr, path)
    os.remove(tmp)
    return True


def only(objs):
    """Show just `objs` (and the studio) to the camera."""
    keep = {o.name for o in objs}
    for o in bpy.data.objects:
        if o.type in ("MESH", "CURVE") and o.name != "Floor":
            o.hide_render = o.name not in keep


def material(name, color, roughness=0.5, metallic=0.0, specular=0.5, subsurface=0.0,
             sss_radius=(1.0, 0.4, 0.2), coat=0.0, sheen=0.0, transmission=0.0, ior=1.45, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    inp = bsdf.inputs
    inp["Base Color"].default_value = (*color[:3], 1)
    inp["Roughness"].default_value = roughness
    inp["Metallic"].default_value = metallic
    inp["Specular IOR Level"].default_value = specular
    inp["Subsurface Weight"].default_value = subsurface
    inp["Subsurface Radius"].default_value = sss_radius
    inp["Subsurface Scale"].default_value = 0.004
    inp["Coat Weight"].default_value = coat
    inp["Sheen Weight"].default_value = sheen
    inp["Transmission Weight"].default_value = transmission
    inp["IOR"].default_value = ior
    inp["Alpha"].default_value = alpha
    return mat


def noise_bump(mat, scale=400.0, strength=0.15, detail=4.0):
    """Fine surface noise into the normal (icing, matte bodies)."""
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = detail
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.0004
    nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def bm_object(name, bm, location=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    return obj


def smooth(obj, subdiv=0):
    for p in obj.data.polygons:
        p.use_smooth = True
    if subdiv:
        m = obj.modifiers.new("Subsurf", "SUBSURF")
        m.levels = m.render_levels = subdiv
    return obj


def lathe(name, profile, segments=64, location=STATION):
    """Revolve [(r, z), ...] around Z (profile from axis outward/upward)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            try:
                bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return smooth(bm_object(name, bm, location))


def save_blend(path):
    bpy.ops.wm.save_as_mainfile(filepath=path)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def dir_mb(path):
    total = 0
    for root, _, files in os.walk(path):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    return round(total / 1e6, 2)


def sheet(paths, out, columns=6, cell=200):
    paths = [p for p in paths if os.path.exists(p)]
    if paths:
        I.grid(paths, out, columns=columns, cell_h=cell, bg=0.55)
    return out


def gray16(path, arr):
    """Save a 0..1 float array as a 16-bit grayscale PNG."""
    h, w = arr.shape
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False, float_buffer=True)
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = np.clip(arr, 0, 1)[::-1]
    rgba[..., 3] = 1
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene = bpy.context.scene
    settings = scene.render.image_settings
    old = (settings.color_depth, settings.color_mode)
    settings.color_mode, settings.color_depth = "BW", "16"
    img.save_render(path, scene=scene)
    settings.color_mode, settings.color_depth = "RGBA", old[0]
    bpy.data.images.remove(img)
