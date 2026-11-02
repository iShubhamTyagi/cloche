"""Materials for the bakeware and the cakes (moulds Stage 3, first pass). Procedural.

Batter and crumb read a `Browning` value (0 raw .. 1 burnt; `set_browning`), so one material
covers every bake state: raw is pale, glossy, faintly
translucent batter; as browning rises it turns matte golden then deep brown, the crown and edges
first, unevenly, with fine pores. Liners: thin white pleated paper that greases near the base as
it bakes. Tins: matte dark non-stick.
"""
import bpy

from materials import Nodes


def _browning(n):
    """A `Browning` value node: set_browning() writes the bake state into it."""
    return n.value("Browning", 0.0)


def set_browning(value):
    for name in ("BatterCrumb", "PaperLiner"):
        mat = bpy.data.materials.get(name)
        if mat is not None:
            mat.node_tree.nodes["Browning"].outputs[0].default_value = float(value)


def batter():
    n = Nodes("BatterCrumb")
    b = _browning(n)
    # Where it browns first: higher up (the crown) plus noise for unevenness.
    geo = n.node("ShaderNodeTexCoord")
    sep = n.node("ShaderNodeSeparateXYZ")
    n.link(geo.outputs["Object"], sep.inputs["Vector"])
    crown = n.remap(sep.outputs["Z"], 0.0, 0.06, 0.75, 1.25)
    uneven = n.remap(n.noise(90.0, 4.0), 0.3, 0.7, 0.8, 1.2)
    local = n.math("MINIMUM", n.math("MULTIPLY", n.math("MULTIPLY", b, crown), uneven), 1.0)
    ramp = n.node("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.93, 0.84, 0.62, 1)       # raw batter
    els[1].position, els[1].color = 1.0, (0.22, 0.10, 0.04, 1)       # burnt edge
    for pos, col in ((0.18, (0.94, 0.80, 0.50, 1)), (0.45, (0.86, 0.60, 0.28, 1)),
                     (0.65, (0.66, 0.38, 0.15, 1)), (0.85, (0.40, 0.20, 0.08, 1))):
        e = els.new(pos)
        e.color = col
    n.link(local, ramp.inputs["Fac"])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    # Raw batter is wet and glossy; baked crumb is matte.
    n.link(n.remap(b, 0.0, 0.25, 0.18, 0.78), n.bsdf.inputs["Roughness"])
    n.link(n.remap(b, 0.0, 0.2, 0.25, 0.0), n.bsdf.inputs["Coat Weight"])
    n.set(Subsurface_Weight=0.12, Subsurface_Radius=(0.006, 0.004, 0.002), Subsurface_Scale=0.01)
    # Pores: a fine cellular bump that appears as it bakes.
    vor = n.node("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 900.0
    n.link(n.coords((1, 1, 1)), vor.inputs["Vector"])
    pores = n.math("MULTIPLY", vor.outputs["Distance"], n.remap(b, 0.05, 0.4, 0.0, 1.0))
    n.bump(pores, 0.25, 0.0003)
    return n.mat


def liner():
    n = Nodes("PaperLiner")
    b = _browning(n)
    geo = n.node("ShaderNodeTexCoord")
    sep = n.node("ShaderNodeSeparateXYZ")
    n.link(geo.outputs["Object"], sep.inputs["Vector"])
    low = n.remap(sep.outputs["Z"], 0.004, 0.022, 1.0, 0.0)                 # grease near the base
    grease = n.math("MULTIPLY", n.math("MULTIPLY", low, b), n.remap(n.noise(60.0, 3.0), 0.3, 0.7, 0.6, 1.0))
    n.link(n.mix_color(grease, (0.95, 0.94, 0.90), (0.80, 0.70, 0.52)), n.bsdf.inputs["Base Color"])
    n.set(Roughness=0.7, Subsurface_Weight=0.3, Subsurface_Radius=(0.003, 0.003, 0.003), Subsurface_Scale=0.003)
    return n.mat


def nonstick():
    n = Nodes("NonStick")
    n.set(Base_Color=(0.035, 0.035, 0.038, 1), Metallic=0.6)
    n.link(n.remap(n.noise(40.0, 3.0), 0.3, 0.7, 0.38, 0.5), n.bsdf.inputs["Roughness"])
    return n.mat


def assign(objects):
    mats = {"crumb": batter(), "liner": liner(), "tin": nonstick()}
    for o in objects:
        if o.type != "MESH":
            continue
        key = ("crumb" if o.name.startswith(("Cupcake", "Cake")) else
               "liner" if o.name.startswith("Liner") else
               "tin" if o.name.startswith(("MuffinTin", "RoundTin")) else None)
        if key:
            o.data.materials.clear()
            o.data.materials.append(mats[key])
            if key == "liner" and "browning" not in o:
                o["browning"] = 0.0
