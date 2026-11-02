"""Procedural materials for the cake stand: polished marble (three presets), brushed brass,
cork and the switch's LED. Principled BSDF only, no image textures.

Marble works in 3D object space, so veins run through the solid (the plate's edge shows the same
veins as its top) and they turn with the plate. Veins: noise-warped coordinates feed a wave
texture (long, branching, sharp veins) and a second finer one, through a colour ramp, over a
few broad soft clouds. Polished: roughness 0.08-0.15 with variation, a clear coat, a very small
subsurface weight, and hairline scratches that only show in raking light.
"""
import bpy

from materials import Nodes

# name: base, cloud tint, main vein, fine vein, vein strength, scale (veins per metre)
MARBLE = {
    "carrara": {"base": (0.80, 0.80, 0.79), "cloud": (0.66, 0.67, 0.69), "vein": (0.22, 0.24, 0.27),
                "fine": (0.45, 0.47, 0.50), "contrast": 0.95, "scale": 3.2, "core": 0.035, "halo": 0.16},
    "calacatta": {"base": (0.86, 0.85, 0.82), "cloud": (0.82, 0.80, 0.75), "vein": (0.36, 0.30, 0.22),
                  "fine": (0.66, 0.58, 0.44), "contrast": 1.0, "scale": 1.7, "core": 0.075, "halo": 0.26},
    "emperador": {"base": (0.20, 0.12, 0.07), "cloud": (0.13, 0.08, 0.05), "vein": (0.72, 0.60, 0.45),
                  "fine": (0.45, 0.33, 0.22), "contrast": 0.95, "scale": 3.0, "core": 0.035, "halo": 0.16},
}


def _veins(n, vector, scale, distortion, sharp, warp_amount=0.22):
    """0 on a vein, 1 away from it: a gently noise-warped wave texture (veins drift in one
    direction, as in real Carrara) through a narrow valley."""
    warp = n.node("ShaderNodeTexNoise")
    warp.inputs["Scale"].default_value = scale * 0.45
    warp.inputs["Detail"].default_value = 3.0
    warp.inputs["Roughness"].default_value = 0.5
    n.link(vector, warp.inputs["Vector"])
    mix = n.node("ShaderNodeMix", data_type="VECTOR")
    ins = {i.identifier: i for i in mix.inputs}
    ins["Factor_Float"].default_value = warp_amount
    n.link(vector, ins["A_Vector"])
    n.link(warp.outputs["Color"], ins["B_Vector"])
    wave = n.node("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = distortion
    wave.inputs["Detail"].default_value = 6.0
    wave.inputs["Detail Scale"].default_value = 1.2
    wave.inputs["Detail Roughness"].default_value = 0.55
    n.link(next(o for o in mix.outputs if o.identifier == "Result_Vector"), wave.inputs["Vector"])
    dist = n.math("ABSOLUTE", n.math("SUBTRACT", wave.outputs["Fac"], 0.5), 0)
    return n.remap(dist, 0.0, sharp, 0.0, 1.0)


def marble(preset="carrara"):
    p = MARBLE[preset]
    n = Nodes(f"Marble_{preset}")
    vec = n.coords((1, 1, 1))
    clouds = n.remap(n.noise(1.6, 4.0, vec, roughness=0.5), 0.35, 0.7, 0.0, 1.0)
    # A feathered halo round each main vein, its darker core, and fine secondary veins.
    halo = _veins(n, vec, p["scale"], 3.5, p["halo"])
    core = _veins(n, vec, p["scale"], 3.5, p["core"])
    fine = _veins(n, n.coords((1.7, 1.3, 2.1)), p["scale"] * 2.6, 5.0, 0.025, warp_amount=0.3)
    # Veins fade in and out along their length, as real ones do.
    presence = n.remap(n.noise(2.2, 2.0, n.coords((1.3, 0.9, 1.1))), 0.38, 0.62, 0.15, 1.0)
    colour = n.mix_color(clouds, p["base"], p["cloud"])
    colour = n.mix_color(n.math("MULTIPLY", n.math("SUBTRACT", 1.0, fine), 0.45 * p["contrast"]), colour, p["fine"])
    colour = n.mix_color(n.math("MULTIPLY", n.math("MULTIPLY", n.math("SUBTRACT", 1.0, halo), 0.35 * p["contrast"]), presence), colour, p["fine"])
    colour = n.mix_color(n.math("MULTIPLY", n.math("MULTIPLY", n.math("SUBTRACT", 1.0, core), p["contrast"]), presence), colour, p["vein"])
    n.link(colour, n.bsdf.inputs["Base Color"])
    rough = n.remap(n.noise(12.0, 3.0, vec), 0.3, 0.7, 0.08, 0.13)
    scratch = n.scratches(0.08)
    n.link(n.math("ADD", rough, n.math("MULTIPLY", scratch, 0.10)), n.bsdf.inputs["Roughness"])
    n.set(Coat_Weight=0.6, Coat_Roughness=0.03, Subsurface_Weight=0.04, Subsurface_Radius=(0.004, 0.003, 0.002),
          Subsurface_Scale=0.02, Specular_IOR_Level=0.5)
    n.bump(scratch, 0.02, 0.0001)
    return n.mat


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
