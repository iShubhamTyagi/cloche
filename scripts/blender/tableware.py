"""The decorating station's fine things, for the live viewer: gilded china bowls, a stainless
offset spatula, a piping bag, and serving tongs. New objects only; nothing else is rebuilt.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/tableware.py

Writes into Resources/DecorRender: USDZ per material (bowl_china, spatula_blade, spatula_ferrule,
spatula_handle, bag_cloth, bag_tip) with UVs, the china and walnut maps, and Cycles renders of the
tongs (tongs_open.png, tongs_closed.png). Run after export_assets.py. Origins: a bowl stands on
its foot at the origin; the spatula's blade centre and the bag's tip are at the origin, with the
handle along +X, so the app can place the working end on the finger.
"""
import math
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
import deco_common as D  # noqa: E402

OUT = os.path.join(C.REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources", "DecorRender")
TMP = os.path.join(C.BUILD, "renders", "tableware")


def mesh_object(name, verts, faces, uvs=None, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = smooth
    if uvs is not None:
        layer = mesh.uv_layers.new(name="st")
        for loop in mesh.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    return obj


def revolve(name, line, segments=192, lobes=0, depth=0.0):
    """Turns a (radius, height) line about Z, from the top of the inside round to the foot.
    `lobes` flutes the upper part. UVs: u round, v along the line."""
    total = [0.0]
    for a, b in zip(line, line[1:]):
        total.append(total[-1] + math.dist(a, b))
    verts, uvs = [], []
    top = max(p[1] for p in line)
    for (r, z), t in zip(line, total):
        flute = depth * max(0.0, (z / top - 0.45) / 0.55) ** 1.5
        for s in range(segments + 1):
            a = 2 * math.pi * s / segments
            rr = r * (1 + flute * math.cos(lobes * a)) if lobes else r
            verts.append((rr * math.cos(a), rr * math.sin(a), z))
            uvs.append((s / segments, t / total[-1]))
    faces, cols = [], segments + 1
    for j in range(len(line) - 1):
        for i in range(segments):
            a = j * cols + i
            faces.append((a, a + 1, a + cols + 1, a + cols))
    return mesh_object(name, verts, faces, uvs)


def bowl_line():
    """A thin, footed bowl: 110 mm across, 52 mm tall, its lip turned gently out."""
    outer = []
    for i in range(49):
        t = i / 48
        r = 0.0305 + 0.0245 * math.sin(t * math.pi / 2) ** 0.8
        z = 0.008 + 0.044 * t ** 1.5
        outer.append((r, z))
    lip = [(0.0556, 0.0525), (0.0553, 0.0532), (0.0547, 0.0528)]
    inner = [(r - 0.0022, z + 0.0012) for r, z in reversed(outer)][1:]
    foot = [(0.0305, 0.0070), (0.0300, 0.0005), (0.0296, 0.0), (0.0270, 0.0), (0.0268, 0.003), (0.0, 0.0035)]
    bottom = [(0.0, inner[-1][1])]
    # From the middle of the inside, up the wall, over the lip, down the outside, under the foot.
    return bottom + list(reversed(inner)) + lip + list(reversed(outer)) + foot


def china_maps():
    """White porcelain with a gilded band: a guilloche of interlaced arcs between two fine lines,
    and a gilded lip and foot. v runs along the line from the middle of the inside to the foot."""
    w, h = 2048, 1024
    u = (np.arange(w) + 0.5) / w
    v = 1 - (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(u, v)
    gold = np.zeros((h, w), dtype=np.float32)

    def band(c, half):
        return np.clip((half - np.abs(V - c)) / 0.0009, 0, 1)

    lip = 0.485
    gold = np.maximum(gold, band(lip, 0.0125))                 # the gilded lip
    gold = np.maximum(gold, band(0.430, 0.0016))               # inside fine line
    outside = 0.555
    gold = np.maximum(gold, band(outside, 0.0016))
    gold = np.maximum(gold, band(outside + 0.078, 0.0016))
    centre, half = outside + 0.039, 0.030
    for phase in (0.0, 0.5):                                   # two waves, interlaced
        wave = centre + half * np.sin((U * 48 + phase) * 2 * np.pi)
        gold = np.maximum(gold, np.clip((0.0022 - np.abs(V - wave)) / 0.0009, 0, 1))
    dots = (np.abs(((U * 48) % 1) - 0.25) < 0.05) & (np.abs(V - centre) < 0.0042)
    gold = np.maximum(gold, dots.astype(np.float32))
    gold = np.maximum(gold, band(0.955, 0.012))                # the gilded foot
    wear = 0.86 + 0.14 * np.sin(U * 311) * np.sin(V * 907)     # hand gilding isn't perfectly even
    porcelain = np.array([0.965, 0.955, 0.93], dtype=np.float32)
    leaf = np.array([0.95, 0.74, 0.36], dtype=np.float32)
    albedo = porcelain * (1 - gold[..., None]) + leaf * gold[..., None]
    return albedo, gold * wear, 0.16 + gold * 0.1


def walnut_map():
    w, h = 1024, 256
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    grain = np.sin((y * 34 + np.sin(x * 5 + y * 9) * 1.6) * 2 * np.pi) * 0.5 + 0.5
    fine = np.sin((y * 190 + np.sin(x * 21) * 0.7) * 2 * np.pi) * 0.5 + 0.5
    t = (grain * 0.7 + fine * 0.3) ** 1.5
    dark, light = np.array([0.11, 0.055, 0.03]), np.array([0.33, 0.18, 0.10])
    return (dark * (1 - t[..., None]) + light * t[..., None]).astype(np.float32)


def write_image(name, data):
    os.makedirs(TMP, exist_ok=True)
    if data.ndim == 2:
        data = np.repeat(data[..., None], 3, axis=2)
    h, w, _ = data.shape
    image = bpy.data.images.new(name, w, h)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(data, 0, 1)
    image.pixels = rgba[::-1].ravel()
    path = os.path.join(OUT, name + ".png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def sweep(name, path, section, segments=None):
    """A closed `section` of (x, z) offsets swept along a list of (centre, side, up, scale)."""
    verts, faces = [], []
    n = len(section)
    for centre, side, up, scale in path:
        for a, b in section:
            verts.append(tuple(Vector(centre) + Vector(side) * a * scale + Vector(up) * b * scale))
    for j in range(len(path) - 1):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range((len(path) - 1) * n, len(path) * n)))
    uvs = [(j / max(len(path) - 1, 1), i / n) for j in range(len(path)) for i in range(n)]
    return mesh_object(name, verts, faces, uvs)


def spatula():
    """A 180 mm blade, 32 mm wide with a rounded tip, cranked up at the neck into a brass ferrule
    and an oiled walnut handle."""
    blade_len, half_w, t = 0.18, 0.016, 0.0009
    n = 72
    top, bottom = [], []
    rows = []
    for i in range(n + 1):
        x = -blade_len / 2 + blade_len * i / n
        from_tip = (x + blade_len / 2) / half_w
        w = half_w * (math.sqrt(max(1 - (1 - min(from_tip, 1)) ** 2, 0)) if from_tip < 1 else 1)
        taper = 1 - 0.28 * max(0, (x + 0.02) / (blade_len / 2 + 0.02)) ** 1.4
        rows.append((x, max(w * taper, 0.0002)))
    verts, faces, uvs = [], [], []
    across = 8
    for x, w in rows:
        for k in range(across + 1):
            y = -w + 2 * w * k / across
            flex = 0.0016 * ((x + blade_len / 2) / blade_len) ** 2
            verts.append((x, y, t / 2 + flex))
            uvs.append((x / blade_len + 0.5, k / across))
    base = len(verts)
    for x, w in rows:
        for k in range(across + 1):
            y = -w + 2 * w * k / across
            flex = 0.0016 * ((x + blade_len / 2) / blade_len) ** 2
            verts.append((x, y, -t / 2 + flex))
            uvs.append((x / blade_len + 0.5, k / across))
    c = across + 1
    for i in range(n):
        for k in range(across):
            a = i * c + k
            faces.append((a, a + c, a + c + 1, a + 1))
            b = base + a
            faces.append((b, b + 1, b + c + 1, b + c))
        faces.append((i * c, base + i * c, base + (i + 1) * c, (i + 1) * c))
        e = i * c + across
        faces.append((e, (i + 1) * c + across, base + (i + 1) * c + across, base + e))
    blade = mesh_object("spatula_blade", verts, faces, uvs)

    # The crank: from the blade's root up to the handle's line.
    section = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    start, rise = blade_len / 2, 0.026
    path = []
    for i in range(25):
        s = i / 24
        ease = s * s * (3 - 2 * s)
        x = start - 0.004 + 0.042 * s
        z = 0.0016 + rise * ease
        slope = rise * 6 * s * (1 - s) / 0.042
        up = Vector((-slope, 0, 1)).normalized()
        path.append(((x, 0, z), (0, 1, 0), tuple(up), 1))
    neck = sweep("spatula_neck", [(c0, sd, u, 1) for c0, sd, u, _ in path],
                 [(a * (0.0095 - 0.0), b * 0.0011) for a, b in section])
    hx = start + 0.038
    hz = 0.0016 + rise
    ferrule = revolve("spatula_ferrule", [(0.0, 0.0), (0.0085, 0.0), (0.0092, 0.002), (0.0092, 0.016), (0.0098, 0.0172),
                                          (0.0098, 0.019), (0.0092, 0.0205), (0.0, 0.0205)], segments=64)
    ferrule.matrix_world = Matrix.Translation((hx, 0, hz)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    profile = [(0.0, 0.0)]
    for i in range(41):
        s = i / 40
        r = 0.0092 + 0.0052 * math.sin(s * math.pi) ** 0.7 + 0.0016 * s
        profile.append((r * (1 - max(0, (s - 0.94) / 0.06) ** 2 * 0.5), 0.118 * s))
    profile.append((0.0, 0.118))
    handle = revolve("spatula_handle", profile, segments=64)
    handle.matrix_world = Matrix.Translation((hx + 0.0205, 0, hz)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Scale(1, 4)
    for o in (ferrule, handle):
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
        o.select_set(False)
    return [blade, neck, ferrule, handle]


def piping_bag():
    """A soft linen bag gathered at the top, ending in a steel star tip at the origin."""
    line = [(0.0, 0.0), (0.0025, 0.0), (0.0038, 0.002), (0.0048, 0.009), (0.0075, 0.022), (0.0095, 0.0245), (0.0095, 0.03), (0.0, 0.03)]
    tip = revolve("bag_tip", line, segments=8 * 12, lobes=8, depth=0.12)
    cloth = []
    for i in range(61):
        s = i / 60
        swell = 0.0095 + 0.05 * s ** 0.8 * (1 - 0.72 * max(0, (s - 0.68) / 0.32) ** 1.6)
        cloth.append((swell, 0.028 + 0.2 * s))
    cloth = [(0.0, 0.028)] + cloth + [(0.0, 0.228)]
    bag = revolve("bag_cloth", cloth, segments=96, lobes=11, depth=0.05)
    for o in (tip, bag):                    # the axis lies along +X, tip at the origin
        o.matrix_world = Matrix.Rotation(math.pi / 2, 4, "Y")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        o.select_set(False)
    return [tip, bag]


def tongs(open_angle):
    """Two stainless strips sprung from a brass-capped hinge, each widening into a scalloped head
    that curls in to grip. One sweep per arm, so the head can't part from it."""
    parts = []
    length = 0.30
    n = 96
    for side in (-1, 1):
        path = []
        points = []
        for i in range(n + 1):
            s = i / n
            bow = 0.012 * math.sin(s * math.pi)
            curl = 0.03 * max(0.0, (s - 0.88) / 0.12) ** 2     # the head turns in
            points.append(Vector((side * (0.006 + math.sin(open_angle) * length * s + bow - curl), 0, -length * s * math.cos(open_angle))))
        for i, c in enumerate(points):
            s = i / n
            forward = (points[min(i + 1, n)] - points[max(i - 1, 0)]).normalized()
            up = Vector((0, 1, 0)).cross(forward).normalized()
            head = max(0.0, (s - 0.8) / 0.2) ** 0.6
            w = 0.0095 - 0.0022 * math.sin(s * math.pi) + 0.0135 * head
            path.append((tuple(c), (0, 1, 0), tuple(up), w))
        section = []
        for a in np.linspace(0, 2 * math.pi, 40, endpoint=False):
            section.append((math.cos(a), math.sin(a) * 0.1))
        arm = sweep(f"tongs_arm_{side}", path, section)
        # Scallops along the head's end: shape the last rows.
        cols = len(section)
        for j in range(n - 7, n + 1):
            depth = (j - (n - 7)) / 7
            for k in range(cols):
                v = arm.data.vertices[j * cols + k]
                v.co.z += 0.0035 * depth * math.cos(v.co.y * 620)
        parts.append(arm)
    cap = revolve("tongs_cap", [(0.0, -0.016), (0.0125, -0.016), (0.0145, -0.013), (0.0145, 0.013), (0.0125, 0.016), (0.0, 0.016)], segments=64)
    cap.matrix_world = Matrix.Rotation(math.pi / 2, 4, "X")
    parts.append(cap)
    return parts


def export(objs, name):
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT, name + ".usdz")
    bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_materials=False,
                          convert_orientation=True, export_global_forward_selection="NEGATIVE_Z",
                          export_global_up_selection="Y", export_uvmaps=True, export_normals=True)
    print("WROTE", name, sum(len(o.data.vertices) for o in objs), os.path.getsize(path) // 1024, "KB")


def render_tongs():
    steel = D.material("Tongs_steel", (0.86, 0.86, 0.87), 0.3, metallic=1.0)
    brass = D.material("Tongs_brass", (0.8, 0.6, 0.32), 0.28, metallic=1.0)
    scene = bpy.context.scene
    # Steel is what it reflects: give it a soft bright room rather than a black one.
    world = bpy.data.worlds.new("TongsRoom")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0.03, 0.025, 0.02, 1)
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = (1.0, 0.96, 0.9, 1)
    links.new(coords.outputs["Generated"], split.inputs[0])
    links.new(split.outputs["X"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], nodes["Background"].inputs[0])
    nodes["Background"].inputs[1].default_value = 1.1
    scene.world = world
    azimuth = math.radians(32)                  # turned, so the strips' faces show
    for name, angle in (("tongs_open", math.radians(21.5)), ("tongs_closed", math.radians(18))):
        for o in list(scene.objects):
            if o.type == "MESH":
                bpy.data.objects.remove(o)
        for o in tongs(angle):
            D.assign(o, brass if o.name == "tongs_cap" else steel)
        cam = bpy.data.objects.get("TongsCam") or bpy.data.objects.new("TongsCam", bpy.data.cameras.new("TongsCam"))
        if cam.name not in scene.collection.objects:
            scene.collection.objects.link(cam)
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 0.38
        cam.location = (math.sin(azimuth), -math.cos(azimuth), -0.165)
        cam.rotation_euler = (math.pi / 2, 0, azimuth)
        scene.camera = cam
        scene.render.resolution_x = scene.render.resolution_y = 1400
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.cycles.samples = 128
        path = os.path.join(OUT, name + ".png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("WROTE", name, os.path.getsize(path) // 1024, "KB")


def main():
    D.setup(ground=False, samples=96)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o)
    albedo, metal, rough = china_maps()
    write_image("china_albedo", albedo)
    write_image("china_metal", metal)
    write_image("china_rough", rough)
    write_image("walnut_albedo", walnut_map())
    bowl = revolve("bowl_china", bowl_line(), lobes=16, depth=0.012)
    export([bowl], "bowl_china")
    bpy.data.objects.remove(bowl)
    parts = spatula()
    export([parts[0], parts[1]], "spatula_blade")
    export([parts[2]], "spatula_ferrule")
    export([parts[3]], "spatula_handle")
    tip, bag = piping_bag()
    export([tip], "bag_tip")
    export([bag], "bag_cloth")
    for o in parts + [tip, bag]:
        bpy.data.objects.remove(o)
    render_tongs()


main()
