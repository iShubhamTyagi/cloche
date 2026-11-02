"""The one studio: lighting, ground, bloom, render settings, and every named camera.

    Blender -b -P scripts/blender/studio.py          # writes build/studio.blend + build/camera.json

Pipeline rule: build/studio.blend (lights, world, ground, bloom) and build/camera.json (cameras)
are the source of truth. No other script creates lights or cameras; they call `use()` to bring
the studio into their scene and `camera(view)` to place the camera from camera.json.

Camera views are either fixed (location, target, lens or ortho scale; the oven's own views and
the app's door-frame camera "frames") or fitted (direction and lens fixed here, distance fitted to
the subject's bounds), for props such as the moulds rendered on their own.

Shared CLI flags (add_render_args): --res W H, --samples N, --preview (= --res 400 300
--samples 16), --final (256 samples, OpenImageDenoise always on), --force (re-render outputs that
already exist; otherwise every script skips them, so a stopped run resumes).
"""
import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common as C  # noqa: E402
from layout import COUNTER_EDGE_Y, COUNTER_T, STATION  # noqa: E402

STUDIO_BLEND = os.path.join(C.BUILD, "studio.blend")
CAMERA_JSON = os.path.join(C.BUILD, "camera.json")

# ------------------------------------------------------------------ cameras (written to camera.json)
# Fixed views: location, target, lens (mm) or ortho_scale. Fitted views: direction (from the
# subject toward the camera), lens or ortho, margin; distance or ortho scale fits the subject.
CAMERAS = {
    # The app's camera: every door frame, knob sprite and in-oven dish render uses it.
    "frames": {"location": [0.0, -2.30, 0.36], "target": [0.0, -0.05, 0.05], "lens": 110, "resolution": [1000, 1200]},
    # The plating station: the "frames" camera slid along the counter to the cake stand.
    # Same lens, distance and resolution as "frames", tilted up (the oven's view looks down to
    # fit a door hanging below the counter; the stand with its cloche is ~49 cm tall instead).
    "station": {"location": [STATION[0], -2.30, 0.36], "target": [STATION[0], -0.05, 0.25], "lens": 110,
                "resolution": [1000, 1200]},
    # Straight down on the turntable plate, filling a 1600 px square (circular alpha): the
    # rotating plate and the cake on it, for the app to rotate and tilt. +Y (12 o'clock) is up.
    "plate_topdown": {"location": [STATION[0], STATION[1], 1.2], "target": [STATION[0], STATION[1], 0.0],
                      "ortho_scale": 0.306, "resolution": [1600, 1600]},
    # The whole stage: the slab with the oven and the stand, three-quarter from front-right.
    "stage": {"location": [2.15, -2.35, 1.30], "target": [0.65, 0.22, 0.08], "lens": 35, "resolution": [1600, 1200]},
    # Oven review views.
    "front_closed": {"location": [0.0, -1.90, 0.42], "target": [0.0, 0.12, 0.17], "lens": 85, "resolution": [1200, 900]},
    "open_34": {"location": [1.05, -1.40, 0.62], "target": [0.0, -0.05, 0.13], "lens": 70, "resolution": [1200, 900]},
    "refmatch_open": {"location": [0.0, -1.25, 0.62], "target": [0.0, -0.06, 0.12], "lens": 45, "resolution": [1200, 900]},
    "ortho_front": {"location": [0.0, -2.0, 0.175], "target": [0.0, 0.0, 0.175], "ortho_scale": 0.62, "resolution": [1200, 900]},
    "detail_controls": {"location": [0.48, -0.42, 0.34], "target": [0.21, 0.0, 0.20], "lens": 90, "resolution": [1200, 900]},
    "detail_cavity": {"location": [0.22, -0.70, 0.40], "target": [-0.05, 0.18, 0.17], "lens": 45, "resolution": [1200, 900]},
    "detail_hinge": {"location": [-0.50, -0.42, 0.16], "target": [-0.24, -0.03, 0.05], "lens": 90, "resolution": [1200, 900]},
    "detail_back": {"location": [-0.55, 1.10, 0.62], "target": [0.0, 0.25, 0.20], "lens": 55, "resolution": [1200, 900]},
    "racks_out": {"location": [0.85, -1.25, 0.70], "target": [0.0, -0.12, 0.14], "lens": 50, "resolution": [1200, 900]},
    "hinge_side": {"location": [1.6, -0.10, 0.04], "target": [0.0, -0.10, 0.04], "ortho_scale": 0.95, "resolution": [480, 480]},
    # Props on their own (moulds, dishes): fitted to the subject.
    "three_quarter": {"direction": [0.62, -0.62, 0.48], "lens": 85, "margin": 1.15, "resolution": [1200, 900]},
    "topdown": {"direction": [0.0, 0.0, 1.0], "ortho": True, "margin": 1.12, "resolution": [1024, 1024]},
}

# Where a prop sits when rendered on its own: on the counter, clear of its front edge.
PROP_ORIGIN = (0.0, 0.30, 0.0)


# ------------------------------------------------------------------ building studio.blend

def _area(name, location, target, size, energy, collection):
    data = bpy.data.lights.new(name, "AREA")
    data.shape = "RECTANGLE"
    data.size, data.size_y = size
    data.energy = energy
    light = bpy.data.objects.new(name, data)
    collection.objects.link(light)
    light.location = location
    aim(light, target)
    return light


def _world():
    """Dark floor to soft ceiling gradient so steel and glass reflect something."""
    world = bpy.data.worlds.new("Studio")
    if world.node_tree is None:
        world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputWorld")
    bg = nodes.new("ShaderNodeBackground")
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -1
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[0].color = (0.004, 0.004, 0.004, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.09, 0.09, 0.095, 1)
    links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    links.new(sep.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    links.new(bg.outputs["Background"], out.inputs["Surface"])
    world.use_fake_user = True
    return world


def _bloom_group():
    """Bloom for the glow: only the glare is added, masked by the render's alpha, so transparent
    pixels stay zero and shadows stay untinted."""
    tree = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    layers = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Bloom"
    glare.inputs["Threshold"].default_value = 2.5
    glare.inputs["Strength"].default_value = 0.6
    glare.inputs["Size"].default_value = 0.35
    mask = tree.nodes.new("CompositorNodeSetAlpha")
    mask.inputs["Type"].default_value = "Apply Mask"
    add = tree.nodes.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    ins = {i.identifier: i for i in add.inputs}
    ins["Factor_Float"].default_value = 1.0
    keep_alpha = tree.nodes.new("CompositorNodeSetAlpha")
    keep_alpha.inputs["Type"].default_value = "Replace Alpha"
    out = tree.nodes.new("NodeGroupOutput")
    link = tree.links.new
    link(layers.outputs["Image"], glare.inputs["Image"])
    link(glare.outputs["Glare"], mask.inputs["Image"])
    link(layers.outputs["Alpha"], mask.inputs["Alpha"])
    link(layers.outputs["Image"], ins["A_Color"])
    link(mask.outputs["Image"], ins["B_Color"])
    link(next(o for o in add.outputs if o.identifier == "Result_Color"), keep_alpha.inputs["Image"])
    link(layers.outputs["Alpha"], keep_alpha.inputs["Alpha"])
    link(keep_alpha.outputs["Image"], out.inputs[0])
    tree.use_fake_user = True
    return tree


def build():
    C.reset_scene()
    lights = bpy.data.collections.new("StudioLights")
    ground = bpy.data.collections.new("StudioGround")
    for coll in (lights, ground):
        bpy.context.scene.collection.children.link(coll)
    _area("SoftboxKey", (-1.1, -1.3, 1.3), (0, 0.1, 0.15), (1.6, 1.0), 120, lights)
    _area("SoftboxFill", (1.4, -0.9, 0.7), (0, 0.1, 0.15), (1.6, 1.6), 16, lights)
    _area("Rim", (1.3, 0.9, 0.55), (0, 0.2, 0.2), (1.2, 0.3), 110, lights)
    # The plating station along the counter gets the same kind of light, aimed at the stand:
    # a large soft key from the front-left above (long clean highlights on marble and glass),
    # a dim fill from the right, and a narrow rim behind. Loaded only for station renders.
    station = bpy.data.collections.new("StudioStationLights")
    bpy.context.scene.collection.children.link(station)
    sx, sy = STATION[0], STATION[1]
    _area("StationKey", (sx - 0.9, sy - 1.1, 1.2), (sx, sy, 0.15), (1.4, 0.9), 8, station)
    _area("StationFill", (sx + 1.0, sy - 0.8, 0.5), (sx, sy, 0.15), (1.4, 1.4), 1.5, station)
    _area("StationRim", (sx + 0.4, sy + 1.0, 0.7), (sx, sy, 0.2), (1.0, 0.25), 12, station)
    _area("StationTop", (sx, sy, 1.4), (sx, sy, 0.0), (0.9, 0.9), 5, station)
    # Counter: shadow catcher, top at z = 0, front edge just behind the oven door's hinge.
    bm = C.bmesh.new()
    C.add_box(bm, (-3, COUNTER_EDGE_Y, -COUNTER_T), (3, 3, 0))
    me = bpy.data.meshes.new("Floor")
    bm.to_mesh(me)
    bm.free()
    floor = bpy.data.objects.new("Floor", me)
    floor.is_shadow_catcher = True
    ground.objects.link(floor)
    bpy.context.scene.world = _world()
    _bloom_group()
    os.makedirs(C.BUILD, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=STUDIO_BLEND)
    with open(CAMERA_JSON, "w") as f:
        json.dump({"convention": "metres, Z up, camera looks along +Y, oven front y = 0; written by "
                                 "scripts/blender/studio.py, do not edit by hand",
                   "prop_origin": list(PROP_ORIGIN), "views": CAMERAS}, f, indent=2)
    print(f"[studio] wrote {os.path.relpath(STUDIO_BLEND, C.REPO)} and {os.path.relpath(CAMERA_JSON, C.REPO)}")


# ------------------------------------------------------------------ using the studio

def aim(obj, target):
    direction = C.Vector(target) - C.Vector(obj.location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def views():
    with open(CAMERA_JSON) as f:
        return json.load(f)["views"]


def use(ground=True, station=False):
    """Bring studio.blend's lights, world, ground and bloom into the current scene. `station`
    adds the plating station's lights (the cake stand and cloche)."""
    if not os.path.exists(STUDIO_BLEND):
        raise SystemExit("build/studio.blend is missing: run scripts/blender/studio.py first")
    with bpy.data.libraries.load(STUDIO_BLEND, link=False) as (src, dst):
        dst.collections = ["StudioLights", "StudioGround"] + (["StudioStationLights"] if station else [])
        dst.worlds = ["Studio"]
        dst.node_groups = ["Bloom"]
    scene = bpy.context.scene
    for coll in dst.collections:
        if coll.name.startswith("StudioGround") and not ground:
            continue
        scene.collection.children.link(coll)
    scene.world = dst.worlds[0]
    scene["bloom_group"] = dst.node_groups[0].name
    render_settings((1200, 900), 32)


def render_settings(resolution, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.refresh_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except Exception as exc:
        print(f"[studio] GPU unavailable ({exc}); using CPU")
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.max_bounces = 12
    scene.cycles.transmission_bounces = 12
    scene.cycles.sample_clamp_indirect = 10
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"


def bloom(enabled):
    scene = bpy.context.scene
    if enabled:
        group = bpy.data.node_groups[scene["bloom_group"]]
        # Appended from studio.blend, its Render Layers node still points at that file's scene.
        for node in group.nodes:
            if node.bl_idname == "CompositorNodeRLayers":
                node.scene = scene
        scene.compositing_node_group = group
    scene.render.use_compositing = enabled


def camera(view, subject=None):
    """Place the scene camera from camera.json. Fitted views need `subject`: (min, max) world
    bounds. Returns the camera object."""
    spec = views()[view]
    scene = bpy.context.scene
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam.data.clip_start = 0.005
    scene.render.resolution_x, scene.render.resolution_y = spec["resolution"]
    if "location" in spec:
        cam.location = spec["location"]
        aim(cam, spec["target"])
        if "ortho_scale" in spec:
            cam.data.type, cam.data.ortho_scale = "ORTHO", spec["ortho_scale"]
        else:
            cam.data.type, cam.data.lens = "PERSP", spec["lens"]
        bpy.context.view_layer.update()       # projections read matrix_world right away
        return cam
    lo, hi = (C.Vector(v) for v in subject)
    centre = (lo + hi) / 2
    direction = C.Vector(spec["direction"]).normalized()
    w, h = spec["resolution"]
    if spec.get("ortho"):
        cam.data.type = "ORTHO"
        extent = hi - lo
        cam.data.ortho_scale = max(extent.x, extent.y * w / h) * spec["margin"]
        cam.location = centre + direction * 2.0
        cam.rotation_euler = (0, 0, 0) if direction.z > 0.99 else (-direction).to_track_quat("-Z", "Y").to_euler()
    else:
        cam.data.type, cam.data.lens = "PERSP", spec["lens"]
        radius = (hi - lo).length / 2
        # The sensor width spans the longer side; fit to the narrower field of view.
        wide = 2 * math.atan(cam.data.sensor_width / 2 / cam.data.lens)
        fov = 2 * math.atan(math.tan(wide / 2) * min(w, h) / max(w, h))
        cam.location = centre + direction * (radius / math.sin(fov / 2) * spec["margin"])
        aim(cam, centre)
    bpy.context.view_layer.update()
    return cam


def add_render_args(parser, res=(1200, 900), samples=32):
    parser.add_argument("--res", type=int, nargs=2, metavar=("W", "H"), default=None)
    parser.add_argument("--samples", type=int, default=None)
    parser.add_argument("--preview", action="store_true", help="--res 400 300 --samples 16")
    parser.add_argument("--final", action="store_true", help="256 samples")
    parser.add_argument("--force", action="store_true", help="re-render outputs that already exist")
    parser.set_defaults(_default_res=res, _default_samples=samples)


def resolved(args, view_res=None):
    """(resolution, samples) from the shared flags; view_res is the camera's own resolution."""
    res = args.res or ((400, 300) if args.preview else (view_res or args._default_res))
    samples = args.samples or (16 if args.preview else 256 if args.final else args._default_samples)
    return tuple(res), samples


def render(path, args, view_res=None):
    """Render the current camera to `path`, unless it exists and --force wasn't given."""
    if os.path.exists(path) and not args.force:
        print(f"[skip] {os.path.relpath(path, C.REPO)}")
        return False
    res, samples = resolved(args, view_res)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.cycles.samples = samples
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"[render] {os.path.relpath(path, C.REPO)}")
    return True


if __name__ == "__main__":
    build()


def keep_oven_lights_off(objects):
    """Light linking: the oven's softboxes and rim (aimed at the oven; the rim stands right
    beside the plating station) don't light these objects; the station lights do."""
    receivers = bpy.data.collections.new("OvenLightsExclude")
    for obj in objects:
        receivers.objects.link(obj)
    for item in receivers.collection_objects:
        item.light_linking.link_state = "EXCLUDE"
    for name in ("SoftboxKey", "SoftboxFill", "Rim"):
        light = bpy.data.objects.get(name)
        if light is not None:
            light.light_linking.receiver_collection = receivers
