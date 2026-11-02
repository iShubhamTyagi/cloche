"""Cake stand Stage 5: the app's layers for the turntable and the cloche, the lift frames, the
hotspots, and a composite check. Called by cakestand.py --stage 5.

Station camera layers (camera.json "station", 1000 x 1200, transparent RGBA):
  base_static      StandBase, StandPad, BearingRing, StandSwitch, LED off, contact shadow on the
                   counter; the plate and cloche still cast their shadows but aren't drawn
  base_led_on      the LED ring's glow only (every other surface is a holdout): add it
  plate_station    the plate in this view, static: a reference for the composite check (the app
                   shows the rotating plate by tilting plate_rotating; see Stage 6)
  cloche           the cloche alone, glass see-through, its reflections and highlights
  cloche_lift/     24 frames, seated to lifted, ease-out; lowering plays them in reverse
Top-down layers (camera.json "plate_topdown", 1600 x 1600, circular alpha):
  plate_rotating   the plate in flat, even light with no reflections, so it can turn freely
  plate_reflection the reflections and highlights only (white on transparent), static: add it
  cake_topdown     the turned-out cake, lit like plate_rotating, to turn with the plate
Plus hero.png (a three-quarter beauty with the cake), cakestand_hotspots.json and manifest.json.
"""
import json
import math
import os

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

import cakestand as S
import cloche as CL
import common as C
import imaging as I
import studio

LIFT_FRAMES = 24
STAND = ("StandBase", "StandPad", "BearingRing", "StandSwitch", "StandLED")
PLATE = ("TurntablePlate", "PlateMarker")
CLOCHE = ("Cloche", "ClocheRim", "ClocheFinial")


def objs(names):
    return [bpy.data.objects[n] for n in names if n in bpy.data.objects]


class Visibility:
    """Set per-object camera visibility and holdout for one layer, restoring afterwards.
    `show` are drawn; `holdout` are drawn as holes (they occlude, alpha 0); every other mesh is
    hidden from the camera but still casts shadows and shows in reflections."""

    def __init__(self, show, holdout=(), floor=False, cake=False):
        self.show, self.holdout = set(show), set(holdout)
        self.floor, self.cake = floor, cake

    def __enter__(self):
        self.saved = {}
        # The counter's shadow catcher belongs to the base layer only (one contact shadow), and
        # the test cake is left out unless the layer is about it (else it shades the plate).
        self.floor_obj = bpy.data.objects.get("Floor")
        if self.floor_obj is not None:
            self.floor_was = self.floor_obj.visible_camera
            self.floor_obj.visible_camera = self.floor
        self.cake_obj = bpy.data.objects.get("CakeTurnout")
        if self.cake_obj is not None:
            self.cake_was = self.cake_obj.hide_render
            self.cake_obj.hide_render = not self.cake
        for o in bpy.context.scene.objects:
            if o.type != "MESH" or o.users_collection[0].name.startswith("Studio") or o.name == "CakeTurnout":
                continue
            self.saved[o.name] = (o.visible_camera, o.is_holdout)
            o.visible_camera = o.name in self.show or o.name in self.holdout
            o.is_holdout = o.name in self.holdout

    def __exit__(self, *exc):
        for name, (cam, hold) in self.saved.items():
            o = bpy.data.objects[name]
            o.visible_camera, o.is_holdout = cam, hold
        if self.floor_obj is not None:
            self.floor_obj.visible_camera = self.floor_was
        if self.cake_obj is not None:
            self.cake_obj.hide_render = self.cake_was


class NeutralLight:
    """Flat, even light from every side and no specular: lights off, a uniform white world, and
    the plate's (and cake's) materials with specular, coat and metal turned down."""

    def __init__(self, materials, keep_light=False):
        self.materials = materials
        self.keep_light = keep_light      # specular off only, under the studio's own light

    def __enter__(self):
        scene = bpy.context.scene
        self.world = scene.world
        self.lights = []
        if not self.keep_light:
            self._flat_world()
        self._no_specular()

    def _flat_world(self):
        scene = bpy.context.scene
        neutral = bpy.data.worlds.get("Neutral") or bpy.data.worlds.new("Neutral")
        neutral.use_nodes = True
        neutral.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
        # Matched so the flat plate is as bright as the lit plate in the station view.
        neutral.node_tree.nodes["Background"].inputs["Strength"].default_value = 2.2
        scene.world = neutral
        self.lights = [o for o in scene.objects if o.type == "LIGHT" and not o.hide_render]
        for o in self.lights:
            o.hide_render = True

    def _no_specular(self):
        self.saved = []
        for mat in self.materials:
            for node in mat.node_tree.nodes:
                if node.bl_idname == "ShaderNodeBsdfPrincipled":
                    for key, value in (("Specular IOR Level", 0.0), ("Coat Weight", 0.0), ("Metallic", 0.0)):
                        sock = node.inputs[key]
                        link = sock.links[0] if sock.is_linked else None
                        self.saved.append((mat, sock, sock.default_value, link.from_socket if link else None))
                        if link:
                            mat.node_tree.links.remove(link)
                        sock.default_value = value

    def __exit__(self, *exc):
        bpy.context.scene.world = self.world
        for o in self.lights:
            o.hide_render = False
        for mat, sock, value, source in self.saved:
            sock.default_value = value
            if source is not None:
                mat.node_tree.links.new(source, sock)


def materials_of(names):
    out = []
    for o in objs(names):
        for m in o.data.materials:
            if m and m not in out:
                out.append(m)
    return out


def ease_out(t):
    return 1 - (1 - t) ** 3


def project(cam, point, res):
    v = world_to_camera_view(bpy.context.scene, cam, C.Vector(point))
    return [round(v.x * res[0], 1), round((1 - v.y) * res[1], 1)]


def circle_px(cam, centre, r, res):
    """A horizontal circle's projection: centre, half-width and half-height in pixels."""
    c = project(cam, centre, res)
    xs = [project(cam, (centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), centre[2]), res)
          for a in np.linspace(0, 2 * math.pi, 64, endpoint=False)]
    return {"centre": c, "radius_x": round((max(p[0] for p in xs) - min(p[0] for p in xs)) / 2, 1),
            "radius_y": round((max(p[1] for p in xs) - min(p[1] for p in xs)) / 2, 1)}


def hotspots():
    out = {}
    for view in ("station", "plate_topdown"):
        cam = studio.camera(view)
        res = tuple(studio.views()[view]["resolution"])
        plate_top = S.at(z=S.Z_PLATE_TOP)
        h = {"resolution": list(res), "pixel_origin": "top-left",
             "plate": circle_px(cam, plate_top, S.PLATE["r"], res),
             "plate_marker_at_0": project(cam, bpy.data.objects["PlateMarker"].matrix_world.translation, res)}
        if view == "station":
            sw = bpy.data.objects["StandSwitch"].matrix_world.translation
            edge = project(cam, (sw.x + S.SWITCH["r"], sw.y, sw.z), res)
            centre = project(cam, sw, res)
            h["switch"] = {"centre": centre, "radius": round(abs(edge[0] - centre[0]), 1)}
            h["bearing_ring"] = circle_px(cam, S.at(z=S.Z_RING + S.RING["h"]), S.RING["r_out"], res)
            lo, hi = C.world_bounds(["ClocheFinial"])
            h["cloche_finial"] = project(cam, (lo + hi) / 2, res)
        out[view] = h
    return out


def reflection_only(gloss_path, out_path):
    """The black-based render holds reflections only: keep their strength as alpha and their
    hue (white to soft grey) as colour, to be added over the rotating plate."""
    gloss = I.load(gloss_path)
    refl = gloss[..., :3] * gloss[..., 3:4]
    alpha = np.clip(refl.max(axis=2), 0, 1)
    rgb = np.where(alpha[..., None] > 1e-4, refl / np.maximum(alpha[..., None], 1e-4), 0)
    I.save(np.dstack([np.clip(rgb, 0, 1), alpha]).astype(np.float32), out_path)


class GlossOnly:
    """The plate's colour set to black, its polish (roughness, coat) unchanged, subsurface off:
    under the studio light it renders nothing but its reflections."""

    def __init__(self, materials):
        self.materials = materials

    def __enter__(self):
        self.saved = []
        for mat in self.materials:
            for node in mat.node_tree.nodes:
                if node.bl_idname == "ShaderNodeBsdfPrincipled":
                    for key, value in (("Base Color", (0, 0, 0, 1)), ("Subsurface Weight", 0.0)):
                        sock = node.inputs[key]
                        link = sock.links[0] if sock.is_linked else None
                        self.saved.append((mat, sock, tuple(sock.default_value) if key == "Base Color" else sock.default_value,
                                           link.from_socket if link else None))
                        if link:
                            mat.node_tree.links.remove(link)
                        sock.default_value = value

    def __exit__(self, *exc):
        for mat, sock, value, source in self.saved:
            sock.default_value = value
            if source is not None:
                mat.node_tree.links.new(source, sock)


def append_turnout():
    path = os.path.join(C.BUILD, "cake_turnout.blend")
    if not os.path.exists(path):
        return None
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = ["CakeTurnout"]
    cake = dst.objects[0]
    bpy.context.scene.collection.objects.link(cake)
    cake.location = bpy.data.objects["CakeSlot_Stand"].matrix_world.translation
    if not cake.data.materials:
        mat = bpy.data.materials.new("TurnoutPlaceholder")      # until moulds Stage 3's sponge
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.78, 0.55, 0.30, 1)
        bsdf.inputs["Roughness"].default_value = 0.8
        cake.data.materials.append(mat)
    studio.keep_oven_lights_off([cake])
    return cake


def run(args, out_dir):
    scene = bpy.context.scene
    scene.cycles.film_transparent_glass = True
    scene.cycles.film_transparent_roughness = 0.15
    import stand_materials as SM
    layers = os.path.join(out_dir, "layers")
    os.makedirs(os.path.join(layers, "cloche_lift"), exist_ok=True)
    path = lambda name: os.path.join(layers, name)  # noqa: E731
    station_res = tuple(studio.views()["station"]["resolution"])
    top_res = tuple(studio.views()["plate_topdown"]["resolution"])
    CL.set_lift(0.0)
    cake = append_turnout()
    if cake:
        cake.hide_render = True

    # --- station view
    studio.camera("station")
    SM.set_led(False)
    with Visibility(STAND, floor=True):
        studio.render(path("base_static.png"), args, view_res=station_res)
    SM.set_led(True)
    with Visibility(["StandLED"], holdout=[n for n in STAND + PLATE + CLOCHE if n != "StandLED"]):
        studio.render(path("base_led_on.png"), args, view_res=station_res)
    SM.set_led(False)
    with Visibility(PLATE):
        studio.render(path("plate_station.png"), args, view_res=station_res)
    # Not a holdout for the plate: the plate seen through the glass must stay in the layer's
    # alpha as glass. The one seam left is the rim bead's lower 1 mm, hidden in the groove in
    # the beauty but drawn in this layer (a hairline ring; see composite_check.json).
    with Visibility(CLOCHE):
        studio.render(path("cloche.png"), args, view_res=station_res)
        frames = []
        for i in range(LIFT_FRAMES):
            lift = ease_out(i / (LIFT_FRAMES - 1))
            CL.set_lift(lift)
            name = f"cloche_lift/lift_{i:02d}.png"
            studio.render(path(name), args, view_res=station_res)
            frames.append({"index": i, "file": name, "lift": round(lift, 4),
                           "height_m": round(lift * CL.LIFT_HEIGHT, 4)})
        CL.set_lift(0.0)
    with Visibility(STAND + PLATE + CLOCHE, floor=True):
        studio.render(path("beauty_station.png"), args, view_res=station_res)

    # --- top-down, plate and cake: decorating happens with the cloche lifted away, so it is left
    # out entirely (it would otherwise show in the polished plate's reflection).
    studio.camera("plate_topdown")
    for o in objs(CLOCHE):
        o.hide_render = True
    with Visibility(PLATE):
        with NeutralLight(materials_of(PLATE)):
            studio.render(path("plate_rotating.png"), args, view_res=top_res)
        with GlossOnly(materials_of(["TurntablePlate"])):
            studio.render(path("_plate_gloss.png"), args, view_res=top_res)
    reflection_only(path("_plate_gloss.png"), path("plate_reflection.png"))
    if cake:
        with Visibility([], holdout=PLATE, cake=True):
            with NeutralLight(materials_of(["CakeTurnout"])):
                studio.render(path("cake_topdown.png"), args, view_res=top_res)

    for o in objs(CLOCHE):
        o.hide_render = False

    # --- hero: three-quarter beauty with the cake under the cloche
    if cake:
        cake.hide_render = False
    lo, hi = C.world_bounds([o.name for o in objs(STAND + PLATE + CLOCHE)])
    studio.camera("three_quarter", subject=(lo, hi))
    studio.render(os.path.join(out_dir, "hero.png"), args)

    spots = hotspots()
    with open(os.path.join(C.BUILD, "renders", "cakestand_hotspots.json"), "w") as f:
        json.dump(spots, f, indent=2)
    manifest = {
        "camera": {"station": "camera.json views.station", "topdown": "camera.json views.plate_topdown"},
        "layers": [
            {"name": "base_static", "file": "base_static.png", "view": "station", "z": 0, "blend": "normal"},
            {"name": "base_led_on", "file": "base_led_on.png", "view": "station", "z": 1, "blend": "plusLighter",
             "when": "StandLED on"},
            {"name": "plate_rotating", "file": "plate_rotating.png", "view": "topdown", "z": 2, "blend": "normal",
             "rotates": True, "pivot": "image centre", "angle_0": "PlateMarker at top (12 o'clock)"},
            {"name": "cake_topdown", "file": "cake_topdown.png", "view": "topdown", "z": 3, "blend": "normal",
             "rotates": True},
            {"name": "plate_reflection", "file": "plate_reflection.png", "view": "topdown", "z": 4,
             "blend": "plusLighter", "rotates": False},
            {"name": "cloche", "file": "cloche.png", "view": "station", "z": 5, "blend": "normal"},
            {"name": "cloche_lift", "files": "cloche_lift/lift_NN.png", "view": "station", "z": 5,
             "blend": "normal", "frames": frames, "lowering": "the same frames in reverse"},
            {"name": "plate_station", "file": "plate_station.png", "view": "station", "z": 2, "blend": "normal",
             "note": "reference for composite_check; the app tilts plate_rotating instead (Stage 6)"},
        ],
        "resolution": {"station": list(station_res), "topdown": list(top_res)},
        "hotspots": "build/renders/cakestand_hotspots.json",
    }
    with open(os.path.join(layers, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    for tmp in ("_plate_gloss.png",):
        if os.path.exists(path(tmp)):
            os.remove(path(tmp))
    return spots
