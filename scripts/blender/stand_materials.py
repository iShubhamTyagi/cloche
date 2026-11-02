"""Procedural materials for the cake stand: polished marble (three presets, shared with the stage
slab: `common.marble_material`), brushed brass,
cork and the switch's LED. Principled BSDF only, no image textures.

Marble works in 3D object space, so veins run through the solid (the plate's edge shows the same
veins as its top) and they turn with the plate. Veins: noise-warped coordinates feed a wave
texture (long, branching, sharp veins) and a second finer one, through a colour ramp, over a
few broad soft clouds. Polished: roughness 0.08-0.15 with variation, a clear coat, a very small
subsurface weight, and hairline scratches that only show in raking light.
"""
import bpy

import common as C
from materials import Nodes

def marble(preset="carrara"):
    """The stand's polished marble: the shared material in common.py."""
    return C.marble_material(preset, "polished")


def brushed_brass(name="BrushedBrass", axis="Z"):
    """Warm brushed brass, brushed round `axis` (object space): the bearing ring is brushed
    round its circumference; the switch is spun on a lathe, so its face shows concentric rings.
    Grain: fine noise varying only with distance from the axis and height along it, so streaks
    run round, never across."""
    n = Nodes(name)
    n.set(Base_Color=(0.80, 0.58, 0.32, 1), Metallic=1.0, Anisotropic=0.7)
    tangent = n.node("ShaderNodeTangent", direction_type="RADIAL", axis=axis)
    n.link(tangent.outputs["Tangent"], n.bsdf.inputs["Tangent"])
    tc = n.node("ShaderNodeTexCoord")
    sep = n.node("ShaderNodeSeparateXYZ")
    n.link(tc.outputs["Object"], sep.inputs["Vector"])
    a, b, along = {"Z": ("X", "Y", "Z"), "Y": ("X", "Z", "Y")}[axis]
    radius = n.math("SQRT", n.math("ADD", n.math("POWER", sep.outputs[a], 2), n.math("POWER", sep.outputs[b], 2)), 0)
    combine = n.node("ShaderNodeCombineXYZ")
    n.link(n.math("MULTIPLY", radius, 900.0), combine.inputs[0])
    n.link(n.math("MULTIPLY", sep.outputs[along], 900.0), combine.inputs[1])
    grain = n.node("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 1.0
    grain.inputs["Detail"].default_value = 3.0
    n.link(combine.outputs["Vector"], grain.inputs["Vector"])
    n.link(n.remap(grain.outputs["Fac"], 0.35, 0.65, 0.26, 0.34), n.bsdf.inputs["Roughness"])
    n.bump(grain.outputs["Fac"], 0.004)
    return n.mat


def brushed_brass_linear(name="BrushedBrassLinear"):
    """Brass brushed in straight lines along object X (the slab's rail): the grain varies only
    across the rail, so streaks run along it."""
    n = Nodes(name)
    n.set(Base_Color=(0.80, 0.58, 0.32, 1), Metallic=1.0, Anisotropic=0.7)
    tangent = n.node("ShaderNodeCombineXYZ")
    tangent.inputs[0].default_value = 1.0
    world = n.node("ShaderNodeVectorTransform", vector_type="VECTOR", convert_from="OBJECT", convert_to="WORLD")
    n.link(tangent.outputs["Vector"], world.inputs["Vector"])
    n.link(world.outputs["Vector"], n.bsdf.inputs["Tangent"])
    grain = n.noise(1.0, 3.0, n.coords((4, 1500, 1500)))
    n.link(n.remap(grain, 0.35, 0.65, 0.24, 0.34), n.bsdf.inputs["Roughness"])
    n.bump(grain, 0.004)
    return n.mat


def cork():
    n = Nodes("Cork")
    grain = n.noise(900.0, 2.0)
    n.link(n.mix_color(grain, (0.42, 0.28, 0.17), (0.58, 0.42, 0.27)), n.bsdf.inputs["Base Color"])
    n.set(Roughness=0.85)
    n.bump(grain, 0.3)
    return n.mat


def led():
    """Warm white LED ring; `Glow` 0 off (a faint frosted ring), 1 on."""
    n = Nodes("StandLED")
    n.set(Base_Color=(0.85, 0.82, 0.76, 1), Roughness=0.35, Transmission_Weight=0.3,
          Emission_Color=(1.0, 0.80, 0.55, 1))
    n.link(n.math("MULTIPLY", n.value("Glow", 0.0), 12.0), n.bsdf.inputs["Emission Strength"])
    return n.mat


def assign(preset="carrara", brass=True):
    stone = marble(preset)
    metal = brushed_brass() if brass else marble(preset)
    spun = brushed_brass("SpunBrass", axis="Y") if brass else marble(preset)
    table = {"StandBase": stone, "TurntablePlate": stone, "BearingRing": metal, "PlateMarker": metal,
             "StandSwitch": spun, "StandLED": led(), "StandPad": cork()}
    for name, mat in table.items():
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.data.materials.clear()
            obj.data.materials.append(mat)


def set_led(on):
    bpy.data.materials["StandLED"].node_tree.nodes["Glow"].outputs[0].default_value = 1.0 if on else 0.0
