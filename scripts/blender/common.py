"""Shared helpers for the oven scripts: paths, argument parsing, mesh primitives.

Run every script through Blender, e.g.
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/oven.py -- --stage 1
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUILD = os.path.join(REPO, "build")
REFERENCE = os.path.join(REPO, "reference")


def script_args(parser: argparse.ArgumentParser):
    """Parse the arguments after Blender's `--`."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return parser.parse_args(argv)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- objects

def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def empty(name, location=(0, 0, 0), parent=None, size=0.02, kind="PLAIN_AXES"):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = kind
    obj.empty_display_size = size
    obj.location = location
    return link(obj, parent)


def mesh_object(name, bm, origin=(0, 0, 0), parent=None):
    """Make an object from a bmesh built in world coordinates; `origin` becomes its pivot."""
    bmesh.ops.translate(bm, vec=-Vector(origin), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    obj.location = origin
    link(obj)
    if parent is not None:
        # Keep the world placement: parent without moving.
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def add_box(bm, lo, hi):
    """Axis-aligned box from corner `lo` to corner `hi`."""
    lo, hi = Vector(lo), Vector(hi)
    size = hi - lo
    geom = bmesh.ops.create_cube(bm, size=1.0)
    verts = geom["verts"]
    bmesh.ops.scale(bm, vec=size, verts=verts)
    bmesh.ops.translate(bm, vec=(lo + hi) / 2, verts=verts)
    return verts


def add_cylinder(bm, center, radius, length, axis="Z", segments=32, radius2=None):
    """Cylinder (or cone with radius2) centred on `center` along an axis."""
    geom = bmesh.ops.create_cone(
        bm, cap_ends=True, segments=segments, radius1=radius,
        radius2=radius if radius2 is None else radius2, depth=length)
    verts = geom["verts"]
    rot = {"X": Matrix.Rotation(math.radians(90), 4, "Y"),
           "Y": Matrix.Rotation(math.radians(90), 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=verts)
    return verts


def box_object(name, lo, hi, origin=None, parent=None):
    bm = bmesh.new()
    add_box(bm, lo, hi)
    if origin is None:
        origin = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
    return mesh_object(name, bm, origin, parent)


def boolean_difference(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    mod.use_self = True
    with bpy.context.temp_override(object=target, active_object=target, selected_objects=[target]):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


# ---------------------------------------------------------------- stats

def triangle_count(objects=None):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    per = {}
    for obj in objects or bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        per[obj.name] = len(me.loop_triangles)
        total += per[obj.name]
        ev.to_mesh_clear()
    return total, per


def world_bounds(obj_names):
    """World-space min/max over the evaluated meshes of the named objects."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for name in obj_names:
        obj = bpy.data.objects[name]
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def descendants(obj):
    out = [obj]
    for child in obj.children:
        out += descendants(child)
    return out


# ---------------------------------------------------------------- detail helpers

def add_sphere(bm, center, radius, segments=16):
    geom = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments // 2, radius=radius)
    bmesh.ops.translate(bm, vec=Vector(center), verts=geom["verts"])
    return geom["verts"]


def add_ring(bm, center, r_in, r_out, thickness, axis="Z", segments=64):
    """Flat annulus (washer) centred on `center`, `thickness` along the axis."""
    verts = []
    rings = []
    for z in (-thickness / 2, thickness / 2):
        for r in (r_in, r_out):
            ring = []
            for i in range(segments):
                a = 2 * math.pi * i / segments
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
            verts += ring
    bot_in, bot_out, top_in, top_out = rings
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((top_in[i], top_out[i], top_out[j], top_in[j]))
        bm.faces.new((bot_in[j], bot_out[j], bot_out[i], bot_in[i]))
        bm.faces.new((bot_out[i], bot_out[j], top_out[j], top_out[i]))
        bm.faces.new((bot_in[j], bot_in[i], top_in[i], top_in[j]))
    rot = {"X": Matrix.Rotation(math.radians(90), 4, "Y"),
           "Y": Matrix.Rotation(math.radians(90), 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=verts)
    return verts


def add_knurled_cylinder(bm, center, radius, length, axis="Y", ridges=60, depth=0.0006):
    """Cylinder whose side alternates between two radii: fine straight knurling."""
    segments = ridges * 2
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    step = 2 * math.pi / segments
    for v in geom["verts"]:
        i = round(math.atan2(v.co.y, v.co.x) / step)
        if i % 2:
            k = (radius - depth) / radius
            v.co.x *= k
            v.co.y *= k
    rot = {"X": Matrix.Rotation(math.radians(90), 4, "Y"),
           "Y": Matrix.Rotation(math.radians(90), 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=geom["verts"])
    bmesh.ops.translate(bm, vec=Vector(center), verts=geom["verts"])
    return geom["verts"]


def cut(target, bm):
    """Boolean-subtract everything in `bm` (world coordinates) from `target`."""
    cutter = mesh_object("cutter", bm)
    boolean_difference(target, cutter)


def finish(obj, bevel=0.0, segments=3, angle=30, smooth=True):
    """Real-world rounded edges (bevel modifier, kept live) and smooth shading with sharp edges
    above `angle`, so cylinders read round and boxes stay crisp but never razor-sharp."""
    me = obj.data
    if smooth:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(angle))
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        mod.harden_normals = True
        mod.use_clamp_overlap = True
        mod.miter_outer = "MITER_ARC"
    return obj
