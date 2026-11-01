"""Procedural materials (Principled BSDF, no image textures) and their assignment by part name.

Each material is built from small node helpers: subtle noise-driven roughness, fine scratches and
a whisper of dust on up-facing surfaces, so nothing looks CG-perfect and nothing looks dirty.
Two controls are left for the render script: the `Heat` value node in `QuartzElement` (0 off,
1 full glow) and the `Glow` value node in `Display` (0 black glass).
"""
import math

import bpy

from layout import CAV_X0, CAV_X1, CAV_Y1, CAV_Z0, CAV_Z1, CAV_XC


class Nodes:
    """Tiny builder over a material's node tree."""

    def __init__(self, name):
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        if mat.node_tree is None:
            mat.use_nodes = True
        self.mat = mat
        self.tree = mat.node_tree
        self.tree.nodes.clear()
        self.out = self.node("ShaderNodeOutputMaterial", location=(600, 0))
        self.bsdf = self.node("ShaderNodeBsdfPrincipled", location=(300, 0))
        self.link(self.bsdf.outputs["BSDF"], self.out.inputs["Surface"])

    def node(self, kind, location=(0, 0), **props):
        n = self.tree.nodes.new(kind)
        n.location = location
        for key, value in props.items():
            setattr(n, key, value)
        return n

    def link(self, a, b):
        self.tree.links.new(a, b)

    def set(self, **inputs):
        for key, value in inputs.items():
            self.bsdf.inputs[key.replace("_", " ")].default_value = value

    def coords(self, scale=(1, 1, 1), space="Object"):
        tc = self.node("ShaderNodeTexCoord")
        mapping = self.node("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = scale
        self.link(tc.outputs[space], mapping.inputs["Vector"])
        return mapping.outputs["Vector"]

    def noise(self, scale, detail=4.0, vector=None, roughness=0.5):
        n = self.node("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        if vector is not None:
            self.link(vector, n.inputs["Vector"])
        return n.outputs["Fac"]

    def remap(self, value, from_min, from_max, to_min, to_max, clamp=True):
        m = self.node("ShaderNodeMapRange")
        m.clamp = clamp
        self.link(value, m.inputs["Value"])
        m.inputs["From Min"].default_value = from_min
        m.inputs["From Max"].default_value = from_max
        m.inputs["To Min"].default_value = to_min
        m.inputs["To Max"].default_value = to_max
        return m.outputs["Result"]

    def math(self, op, a, b):
        m = self.node("ShaderNodeMath", operation=op)
        for sock, val in ((m.inputs[0], a), (m.inputs[1], b)):
            if isinstance(val, (int, float)):
                sock.default_value = val
            else:
                self.link(val, sock)
        return m.outputs["Value"]

    def mix_color(self, factor, a, b):
        m = self.node("ShaderNodeMix", data_type="RGBA")
        ins = {s.identifier: s for s in m.inputs}
        self.link(factor, ins["Factor_Float"])
        for key, val in (("A_Color", a), ("B_Color", b)):
            if isinstance(val, tuple):
                ins[key].default_value = (*val, 1) if len(val) == 3 else val
            else:
                self.link(val, ins[key])
        return next(s for s in m.outputs if s.identifier == "Result_Color")

    def bump(self, height, strength, distance=0.0002):
        b = self.node("ShaderNodeBump")
        b.inputs["Strength"].default_value = strength
        b.inputs["Distance"].default_value = distance
        self.link(height, b.inputs["Height"])
        self.link(b.outputs["Normal"], self.bsdf.inputs["Normal"])

    def value(self, name, default):
        v = self.node("ShaderNodeValue")
        v.name = v.label = name
        v.outputs[0].default_value = default
        return v.outputs[0]

    # ------------------------------------------------------------ shared wear

    def scratches(self, density=0.5):
        """Sparse, fine straight scratches in two directions, 0..1."""
        lines = None
        for scale in ((4, 900, 900), (900, 900, 4)):
            n = self.noise(1.0, detail=1.0, vector=self.coords(scale))
            line = self.remap(n, 0.615, 0.63, 0.0, 1.0)
            line = self.math("MULTIPLY", line, self.remap(self.noise(1.0, 2.0, self.coords((1, 1, 1))), 0.62, 0.72, 0.0, 1.0))
            mask = self.remap(self.noise(9.0, 2.0), 0.55, 0.7, 0.0, density)
            line = self.math("MULTIPLY", line, mask)
            lines = line if lines is None else self.math("MAXIMUM", lines, line)
        return lines

    def dust(self, amount=0.05):
        """A whisper of dust on up-facing surfaces only."""
        geo = self.node("ShaderNodeNewGeometry")
        sep = self.node("ShaderNodeSeparateXYZ")
        self.link(geo.outputs["Normal"], sep.inputs["Vector"])
        up = self.remap(sep.outputs["Z"], 0.6, 1.0, 0.0, 1.0)
        speck = self.remap(self.noise(60.0, 6.0), 0.45, 0.75, 0.0, amount)
        return self.math("MULTIPLY", up, speck)


# ---------------------------------------------------------------- materials

def black_enamel():
    n = Nodes("BlackEnamel")
    rough = n.remap(n.noise(35.0, 4.0), 0.3, 0.7, 0.33, 0.38)
    scratch = n.scratches(0.12)
    dust = n.dust(0.03)
    rough = n.math("ADD", rough, n.math("MULTIPLY", scratch, 0.08))
    rough = n.math("ADD", rough, n.math("MULTIPLY", dust, 2.0))
    n.link(rough, n.bsdf.inputs["Roughness"])
    n.link(n.mix_color(dust, (0.012, 0.012, 0.013), (0.20, 0.19, 0.18)), n.bsdf.inputs["Base Color"])
    n.set(Coat_Weight=0.15, Coat_Roughness=0.12)
    n.bump(n.noise(450.0, 2.0), 0.015)          # faint orange-peel of sprayed enamel
    return n.mat


def cavity_enamel():
    """Oven-interior enamel: dark charcoal with fine light flecks, satin."""
    n = Nodes("CavityEnamel")
    fleck = n.remap(n.noise(900.0, 1.0), 0.70, 0.73, 0.0, 1.0)
    n.link(n.mix_color(fleck, (0.012, 0.012, 0.014), (0.16, 0.16, 0.17)), n.bsdf.inputs["Base Color"])
    n.link(n.remap(n.noise(20.0, 3.0), 0.3, 0.7, 0.62, 0.75), n.bsdf.inputs["Roughness"])
    n.bump(n.noise(600.0, 2.0), 0.04)
    return n.mat


def brushed_steel(name="BrushedSteel", grain_axis=(1, 0, 0), base=0.62):
    """Metallic, anisotropic along `grain_axis` (object space), with streaks from noise stretched
    along the grain."""
    n = Nodes(name)
    stretch = tuple(4 if g else 600 for g in grain_axis)
    streak = n.noise(1.0, 3.0, n.coords(stretch))
    n.link(n.remap(streak, 0.35, 0.65, 0.25, 0.35), n.bsdf.inputs["Roughness"])
    n.set(Base_Color=(base, base, base * 1.01, 1), Metallic=1.0, Anisotropic=0.7)
    tangent = n.node("ShaderNodeCombineXYZ")
    for i, g in enumerate(grain_axis):
        tangent.inputs[i].default_value = g
    world = n.node("ShaderNodeVectorTransform", vector_type="VECTOR", convert_from="OBJECT", convert_to="WORLD")
    n.link(tangent.outputs["Vector"], world.inputs["Vector"])
    n.link(world.outputs["Vector"], n.bsdf.inputs["Tangent"])
    n.bump(streak, 0.01)
    return n.mat


def spun_steel():
    """Satin knob finish: concentric spun grain around the knob's axis (object Y)."""
    n = Nodes("SpunSteel")
    n.set(Base_Color=(0.64, 0.64, 0.65, 1), Metallic=1.0, Anisotropic=0.55)
    tangent = n.node("ShaderNodeTangent", direction_type="RADIAL", axis="Y")
    n.link(tangent.outputs["Tangent"], n.bsdf.inputs["Tangent"])
    n.link(n.remap(n.noise(60.0, 3.0), 0.3, 0.7, 0.32, 0.40), n.bsdf.inputs["Roughness"])
    return n.mat


def chrome_wire():
    n = Nodes("ChromeWire")
    n.set(Base_Color=(0.78, 0.78, 0.79, 1), Metallic=1.0)
    n.link(n.remap(n.noise(30.0, 3.0), 0.3, 0.7, 0.10, 0.18), n.bsdf.inputs["Roughness"])
    return n.mat


def dark_steel():
    n = Nodes("DarkSteel")
    n.set(Base_Color=(0.18, 0.18, 0.19, 1), Metallic=1.0, Roughness=0.35)
    return n.mat


def satin_aluminium():
    n = Nodes("SatinAluminium")
    n.set(Base_Color=(0.50, 0.50, 0.51, 1), Metallic=1.0)
    n.link(n.remap(n.noise(25.0, 3.0), 0.3, 0.7, 0.40, 0.50), n.bsdf.inputs["Roughness"])
    return n.mat


def smoked_glass():
    """Tempered smoke glass: clear transmission with a faint grey-bronze tint and the barest
    smudges in the roughness."""
    n = Nodes("SmokedGlass")
    n.set(Base_Color=(0.62, 0.60, 0.57, 1), Transmission_Weight=1.0, IOR=1.5)
    smudge = n.remap(n.noise(5.0, 8.0, roughness=0.65), 0.58, 0.78, 0.0, 0.06)
    n.link(smudge, n.bsdf.inputs["Roughness"])
    return n.mat


def frit():
    n = Nodes("CeramicFrit")
    n.set(Base_Color=(0.008, 0.008, 0.008, 1), Roughness=0.5)
    return n.mat


def rubber():
    n = Nodes("Rubber")
    n.set(Base_Color=(0.018, 0.018, 0.018, 1), Roughness=0.8)
    n.bump(n.noise(250.0, 2.0), 0.06)
    return n.mat


def tray_enamel():
    n = Nodes("TrayEnamel")
    n.set(Base_Color=(0.010, 0.010, 0.011, 1), Coat_Weight=0.5, Coat_Roughness=0.05)
    n.link(n.remap(n.noise(18.0, 3.0), 0.3, 0.7, 0.20, 0.28), n.bsdf.inputs["Roughness"])
    return n.mat


def ceramic():
    n = Nodes("Ceramic")
    n.set(Base_Color=(0.86, 0.84, 0.79, 1), Roughness=0.42, Subsurface_Weight=0.1)
    return n.mat


def quartz_element(half_length):
    """Frosted quartz tube. Glow: hotter orange in the middle, redder toward the ends, scaled by
    the `Heat` value node (0..1)."""
    n = Nodes("QuartzElement")
    n.set(Base_Color=(0.92, 0.90, 0.86, 1), Transmission_Weight=0.4, Roughness=0.35, IOR=1.46)
    tc = n.node("ShaderNodeTexCoord")
    sep = n.node("ShaderNodeSeparateXYZ")
    n.link(tc.outputs["Object"], sep.inputs["Vector"])
    along = n.math("ABSOLUTE", n.math("DIVIDE", sep.outputs["X"], half_length), 0)
    ramp = n.node("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (1.0, 0.36, 0.05, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.75, 0.07, 0.01, 1)
    n.link(along, ramp.inputs["Fac"])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Emission Color"])
    heat = n.value("Heat", 0.0)
    falloff = n.remap(along, 0.7, 1.0, 1.0, 0.45)
    n.link(n.math("MULTIPLY", n.math("MULTIPLY", heat, 7.0), falloff), n.bsdf.inputs["Emission Strength"])
    return n.mat


def display():
    """Blank black glass screen; `Glow` lifts a faint warm backlight (the app draws all text)."""
    n = Nodes("Display")
    n.set(Base_Color=(0.004, 0.004, 0.005, 1), Roughness=0.05, Coat_Weight=1.0, Coat_Roughness=0.02,
          Emission_Color=(1.0, 0.62, 0.32, 1))
    n.link(n.math("MULTIPLY", n.value("Glow", 0.0), 0.15), n.bsdf.inputs["Emission Strength"])
    return n.mat


# ---------------------------------------------------------------- assignment

def build_all():
    tube = bpy.data.objects["HeatingElement_Top1"]
    half = max(v.co.x for v in tube.data.vertices)
    return {
        "enamel": black_enamel(), "cavity": cavity_enamel(), "steel": brushed_steel(),
        "steel_y": brushed_steel("BrushedSteelY", (0, 1, 0)), "spun": spun_steel(),
        "chrome": chrome_wire(), "dark_steel": dark_steel(), "alu": satin_aluminium(),
        "glass": smoked_glass(), "frit": frit(), "rubber": rubber(), "tray": tray_enamel(),
        "ceramic": ceramic(), "quartz": quartz_element(half), "display": display(),
    }


ASSIGN = {
    "Body": ("enamel", "cavity"), "ControlPanel": ("enamel",), "Door": ("enamel",),
    "Display": ("display",), "KnobRings": ("spun",), "Knob1": ("spun",), "Knob2": ("spun",),
    "Knob3": ("spun",), "DoorGlass": ("glass",), "DoorFrit": ("frit",), "DoorHandle": ("steel",),
    "DoorHingeArms": ("dark_steel",), "HingeKnuckles": ("dark_steel",), "BodyScrews": ("dark_steel",),
    "Gasket": ("rubber",), "Feet": ("rubber",), "FeetRings": ("steel",), "RackRails": ("cavity",),
    "CrumbTray": ("alu",), "CrumbTrayTab": ("enamel",), "Rack1": ("chrome",), "Rack2": ("chrome",),
    "Tray1": ("tray",), "Tray1Rim": ("tray",), "Tray2": ("tray",), "Tray2Rim": ("tray",),
}


def assign():
    mats = build_all()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if obj.name.startswith("HeatingElement_"):
            keys = ("ceramic",) if obj.name.endswith("_Caps") else ("quartz",)
        else:
            keys = ASSIGN.get(obj.name, ("enamel",))
        obj.data.materials.clear()
        for key in keys:
            obj.data.materials.append(mats[key])
    mark_cavity_faces(bpy.data.objects["Body"])
    return mats


def mark_cavity_faces(body):
    """Body faces lining the cavity get the interior enamel (material index 1)."""
    eps = 0.0015
    mw = body.matrix_world
    for poly in body.data.polygons:
        c = mw @ poly.center
        inside = (CAV_X0 - eps < c.x < CAV_X1 + eps and eps < c.y < CAV_Y1 + eps
                  and CAV_Z0 - eps < c.z < CAV_Z1 + eps)
        poly.material_index = 1 if inside else 0


def set_heat(level):
    """0 off, 1 full: the tubes' emission and their area lights together."""
    bpy.data.materials["QuartzElement"].node_tree.nodes["Heat"].outputs[0].default_value = level
    for obj in bpy.data.objects:
        if obj.type == "LIGHT" and "watts_at_full" in obj:
            obj.data.energy = level * obj["watts_at_full"]


def set_display_glow(level):
    bpy.data.materials["Display"].node_tree.nodes["Glow"].outputs[0].default_value = level


__all__ = ["assign", "set_heat", "set_display_glow", "CAV_XC", "math"]
