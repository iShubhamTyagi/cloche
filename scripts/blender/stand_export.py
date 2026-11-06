"""The cake stand and cloche for the live viewer: one small USDZ per material, in plate-local
metres (the top of the turning plate is the origin), with planar UVs for the marble.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/stand_export.py

Reads build/cakestand.blend and build/cloche.blend (cakestand.py) and changes neither. Run after
export_assets.py, which clears Resources/DecorRender.
"""
import os
import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Packages/ClocheKit/Sources/Features/Resources/DecorRender")
PLATE_TOP, GROOVE_DEPTH = 0.2055, 0.001


def joined(names, name, shift, ratio):
    """One new mesh object from `names`, moved by `shift`, thinned to `ratio` of its faces."""
    deps = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    for n in names:
        o = bpy.data.objects[n]
        part = bmesh.new()
        part.from_object(o.evaluated_get(deps), deps)
        part.transform(Matrix.Translation(shift) @ o.matrix_world)
        scratch = bpy.data.meshes.new("scratch")
        part.to_mesh(scratch)
        bm.from_mesh(scratch)
        part.free()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.clear()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if ratio < 1:
        d = obj.modifiers.new("thin", "DECIMATE")
        d.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        for other in bpy.context.selected_objects:
            other.select_set(False)
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier="thin")
    for poly in obj.data.polygons:
        poly.use_smooth = True
    uv = obj.data.uv_layers.new(name="st")
    for loop in obj.data.loops:
        p = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x / 0.32 + 0.5, p.y / 0.32 + 0.5 + p.z / 0.32)
    return obj


def export(obj):
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, obj.name + ".usdz")
    bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_materials=False,
                          convert_orientation=True, export_global_forward_selection="NEGATIVE_Z",
                          export_global_up_selection="Y", export_uvmaps=True, export_normals=True)
    print("WROTE", obj.name, len(obj.data.vertices), os.path.getsize(path) // 1024, "KB")


bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "build/cakestand.blend"))
centre = bpy.data.objects["TurntablePlate"].matrix_world.translation.copy()
shift = Vector((-centre.x, -centre.y, -PLATE_TOP))
print("PLATE_CENTRE", centre.x, centre.y)
for names, name, ratio in [(["StandBase"], "stand_base", 0.4), (["BearingRing", "StandSwitch"], "stand_brass", 0.5),
                           (["TurntablePlate"], "stand_plate", 0.7), (["PlateMarker"], "stand_marker", 1)]:
    export(joined(names, name, shift, ratio))

# The slab, in the same frame: the oven stands 1.4 m to the left of the plate on this.
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "build/slab.blend"))
slab = joined(["StageSlab"], "stage_slab", shift, 1)
# Longer on the far side of the stand than the rendered slab, for the bowls: the extra length is
# never in the same shot as the oven.
for v in slab.data.vertices:
    if v.co.x > -0.2:
        v.co.x += 0.42
for poly in slab.data.polygons:
    poly.use_smooth = False                 # long flat faces: smooth shading smears them
scale = slab.data.uv_layers["st"]
for loop in slab.data.loops:
    p = slab.data.vertices[loop.vertex_index].co
    scale.data[loop.index].uv = (p.x / 0.9 + 0.5, (p.y + p.z) / 0.9 + 0.5)
export(slab)

bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "build/cloche.blend"))
glass = bpy.data.objects["Cloche"]
low = min((glass.matrix_world @ Vector(c)).z for c in glass.bound_box)
shift = Vector((-glass.matrix_world.translation.x, -glass.matrix_world.translation.y, -low - GROOVE_DEPTH))
# The glass itself is built in the app (ViewerMesh.clocheGlass): thinning it here breaks up its surface.
export(joined(["ClocheFinial"], "cloche_finial", shift, 0.5))
