"""The cakes inside the moulds, driven continuously by `rise` and `browning` (0..1).

Each cake is one mesh with two shapes on the same vertices: the basis is raw batter (a low fill
with a smooth meniscus), the "Rise" shape key is fully risen (filled to the rim, a muffin-top
spill for cupcakes, a dome). The object's `rise` property drives that shape key, a "Cracks"
shape key (seeded crack paths on the crown, fading in above rise 0.7) and a crumb displacement. `browning` is stored for the
materials. Cupcakes vary slightly per seed (dome height, lean, crack pattern).

Names: Cupcake_1..4 (on CakeSlot_A..D), Cake (in RoundTin), CakeTurnout (levelled and flipped,
flat side up, for the decorating canvas).
"""
import math

import bmesh
import bpy

import common as C
import moulds as M


# ------------------------------------------------------------------ revolve with poles

def revolve(profile, centre, segments):
    """World coordinates of an (r, z) profile revolved about the vertical axis, plus faces.
    The profile runs from just off the axis at the bottom to just off the axis at the top;
    poles close both ends. Same profile length -> same vertex order (for shape keys)."""
    x0, y0, z0 = centre
    coords = [(x0, y0, z0 + profile[0][1])]                         # bottom pole
    for i in range(segments):
        a = 2 * math.pi * i / segments
        ca, sa = math.cos(a), math.sin(a)
        coords += [(x0 + r * ca, y0 + r * sa, z0 + z) for r, z in profile]
    coords.append((x0, y0, z0 + profile[-1][1]))                     # top pole
    n = len(profile)
    faces = []
    ring = lambda i, j: 1 + (i % segments) * n + j  # noqa: E731
    for i in range(segments):
        faces.append((0, ring(i + 1, 0), ring(i, 0)))
        for j in range(n - 1):
            faces.append((ring(i, j), ring(i + 1, j), ring(i + 1, j + 1), ring(i, j + 1)))
        faces.append((ring(i, n - 1), ring(i + 1, n - 1), len(coords) - 1))
    return coords, faces


def make_cake_object(name, raw, risen, centre, segments, origin):
    coords, faces = revolve(raw, centre, segments)
    risen_coords, _ = revolve(risen, centre, segments)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(c[k] - origin[k] for k in range(3)) for c in coords], [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    obj.location = origin
    C.link(obj)
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name="Rise")
    for v, c in zip(key.data, risen_coords):
        v.co = tuple(c[k] - origin[k] for k in range(3))
    me.shade_smooth()
    return obj, risen_coords


def drive(obj, owner, path, expression, index=-1):
    fcurve = owner.driver_add(path, index) if index >= 0 else owner.driver_add(path)
    driver = fcurve.driver
    driver.type = "SCRIPTED"
    var = driver.variables.new()
    var.name, var.type = "r", "SINGLE_PROP"
    var.targets[0].id = obj
    var.targets[0].data_path = '["rise"]'
    driver.expression = expression


def crown_group(obj, risen_coords, z_from, z_to):
    """Vertex weights 0 below the rim, 1 on the crown, eased between (by the risen shape)."""
    group = obj.vertex_groups.new(name="Crown")
    weights = []
    for i, c in enumerate(risen_coords):
        t = min(max((c[2] - z_from) / (z_to - z_from), 0.0), 1.0)
        weights.append(t * t * (3 - 2 * t))
        group.add([i], weights[-1], "REPLACE")
    return weights


def texture(name, kind, **props):
    tex = bpy.data.textures.get(name) or bpy.data.textures.new(name, kind)
    for k, v in props.items():
        setattr(tex, k, v)
    return tex


def add_surface(obj, crumb_scale, crumb_depth, coords_object, subdiv=2):
    """Subdivide for detail, then a lumpy crumb on the crown that grows with rise."""
    sub = obj.modifiers.new("Smooth", "SUBSURF")
    sub.levels, sub.render_levels = 1, subdiv
    crumb = obj.modifiers.new("Crumb", "DISPLACE")
    crumb.texture = texture(f"{obj.name}_Crumb", "CLOUDS", noise_scale=crumb_scale, noise_depth=3)
    crumb.texture_coords = "OBJECT"
    crumb.texture_coords_object = coords_object
    crumb.mid_level = 0.5
    crumb.vertex_group = "Crown"
    drive(obj, crumb, "strength", f"r * {crumb_depth}")


def crack_paths(rng, count, length, start_radius, step=0.0008):
    """Seeded wandering crack lines across the crown (local xy), some with a branch."""
    segments = []

    def walk(x, y, a, steps):
        for _ in range(steps):
            a += rng.gauss(0, 0.11)
            nx, ny = x + step * math.cos(a), y + step * math.sin(a)
            segments.append(((x, y), (nx, ny)))
            if rng.random() < 0.025 and steps > 8:
                walk(nx, ny, a + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1), int(steps * 0.4))
            x, y = nx, ny

    for _ in range(count):
        r, t = start_radius * math.sqrt(rng.random()), rng.uniform(0, 2 * math.pi)
        a = rng.uniform(0, 2 * math.pi)
        n = int(rng.uniform(*length) / step)
        x0, y0 = r * math.cos(t), r * math.sin(t)
        walk(x0, y0, a, n // 2)
        walk(x0, y0, a + math.pi, n // 2)          # cracks open both ways from where they start
    return segments


def add_cracks(obj, weights, rng, count, length, start_radius, width, depth):
    """A "Cracks" shape key on top of "Rise": narrow grooves along seeded paths with a slightly
    raised torn edge, only on the crown; it fades in from rise 0.7 to 1."""
    import numpy as np
    keys = obj.data.shape_keys.key_blocks
    rise = keys["Rise"]
    crack = obj.shape_key_add(name="Cracks", from_mix=False)
    crack.relative_key = rise
    co = np.array([v.co[:] for v in rise.data])
    segs = crack_paths(rng, count, length, start_radius)
    a = np.array([s[0] for s in segs])
    b = np.array([s[1] for s in segs])
    ab = b - a
    ab2 = np.maximum((ab ** 2).sum(1), 1e-12)
    w = np.array(weights)
    out = co.copy()
    for i in np.nonzero(w > 0.02)[0]:
        p = co[i, :2]
        t = np.clip(((p - a) * ab).sum(1) / ab2, 0, 1)
        d = np.sqrt(((a + ab * t[:, None] - p) ** 2).sum(1)).min()
        if d < width:
            dz = -depth * (1 - (d / width) ** 2)
        elif d < 2.4 * width:
            dz = 0.22 * depth * math.sin(math.pi * (d - width) / (1.4 * width))
        else:
            continue
        out[i, 2] += dz * w[i]
    for v, c in zip(crack.data, out):
        v.co = c
    drive(obj, crack, "value", "max(0, (r - 0.7) / 0.3)")


def texture_space(obj, rng):
    """A child empty, randomly offset per cake, so each crack pattern is its own."""
    e = bpy.data.objects.new(f"{obj.name}_TexSpace", None)
    C.link(e)
    e.parent = obj
    e.location = (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))
    e.rotation_euler = (0, 0, rng.uniform(0, math.pi))
    e.hide_render = e.hide_viewport = True
    return e


def finish_cake(obj, rise, browning, rise_shape_key=True):
    obj["rise"], obj["browning"] = float(rise), float(browning)
    for prop in ("rise", "browning"):
        obj.id_properties_ui(prop).update(min=0.0, max=1.0, soft_min=0.0, soft_max=1.0)
    if rise_shape_key:
        drive(obj, obj.data.shape_keys.key_blocks["Rise"], "value", "r")


# ------------------------------------------------------------------ cupcakes

def ease(t):
    return t * t * (3 - 2 * t)


def cupcake_profiles(rng):
    """(raw, risen) profiles of one cupcake, z from the cup's outer base. Same point counts."""
    c = M.CUP
    z_b = c["wall_t"] + 0.0003 + M.LINER["paper_t"] + 0.0002     # resting on the liner base
    wall = lambda z: M.liner_radius(z) - 0.0003                   # noqa: E731
    r_flat = wall(z_b) - 0.0035
    z_rim = c["depth"] - 0.0008
    h_raw = z_b + 0.60 * (z_rim - z_b)
    dome = 0.021 * (1 + 0.07 * rng.uniform(-1, 1))
    spill = 0.0036 * (1 + 0.15 * rng.uniform(-1, 1))
    n_base, n_wall, n_top = 8, 22, 64

    base = [(0.0006 + (r_flat - 0.0006) * k / (n_base - 1), z_b) for k in range(n_base)]

    def wall_to(top):
        pts = []
        for k in range(1, n_wall + 1):
            z = z_b + (top - z_b) * k / n_wall
            corner = min(1.0, (z - z_b) / 0.0035)
            pts.append((r_flat + (wall(z) - r_flat) * math.sin(corner * math.pi / 2), z))
        return pts

    raw = base + wall_to(h_raw)
    r_edge = wall(h_raw)
    for k in range(1, n_top + 1):
        u = k / n_top
        meniscus = 0.0009 * (1 - ease(min(1.0, u / 0.12)))         # batter climbs the paper a little
        raw.append((max(0.0004, r_edge * (1 - u)), h_raw + meniscus - 0.0003 * u))

    risen = base + wall_to(z_rim)
    r_rim = wall(z_rim) + 0.0004
    n_spill = 10
    for k in range(1, n_spill + 1):                                # spill over the rim
        t = k / n_spill * math.pi / 2
        risen.append((r_rim + spill * math.sin(t), z_rim + 0.006 * (1 - math.cos(t))))
    r_max = r_rim + spill
    z0 = z_rim + 0.006
    p = 1.85
    for k in range(1, n_top - n_spill + 1):                        # superellipse dome
        t = k / (n_top - n_spill) * math.pi / 2
        r = r_max * math.cos(t) ** (2 / p)
        z = z0 + (dome - 0.006) * math.sin(t) ** (2 / p)
        risen.append((max(0.0004, r), z))
    return raw, risen, z_rim, z_rim + dome


def build_cupcake(index, slot, rng, rise, browning):
    raw, risen, z_rim, z_top = cupcake_profiles(rng)
    x, y, z = slot
    obj, risen_coords = make_cake_object(f"Cupcake_{index}", raw, risen, slot, 160, slot)
    # A slight lean of the crown, different for each cupcake.
    lean = (rng.uniform(-0.0012, 0.0012), rng.uniform(-0.0012, 0.0012))
    key = obj.data.shape_keys.key_blocks["Rise"]
    for v in key.data:
        h = max(0.0, (v.co.z - (z_rim + 0.004)) / (z_top - z_rim))
        v.co.x += lean[0] * h
        v.co.y += lean[1] * h
    weights = crown_group(obj, risen_coords, z + z_rim + 0.003, z + z_rim + 0.010)
    add_cracks(obj, weights, rng, count=rng.choice((1, 2, 2, 3)), length=(0.012, 0.024),
               start_radius=0.008, width=0.0011, depth=0.0018)
    space = texture_space(obj, rng)
    add_surface(obj, crumb_scale=0.004, crumb_depth=0.0007, coords_object=space)
    finish_cake(obj, rise, browning)
    return obj


# ------------------------------------------------------------------ round cake

def tin_inner(z):
    t = M.TIN
    flare = math.tan(math.radians(t["flare_deg"]))
    base_r = t["top_r"] - t["depth"] * flare
    return base_r + max(z - t["corner"], 0) * flare - t["wall_t"] - 0.0002


def cake_profiles(dome=0.015):
    t = M.TIN
    z_b = t["wall_t"] + 0.0002
    z_rim = t["depth"] - t["rim_r"] - 0.0006
    h_raw = z_b + 0.55 * (z_rim - z_b)
    r_flat = tin_inner(z_b) - 0.0038
    n_base, n_wall, n_top = 30, 26, 120
    base = [(0.0008 + (r_flat - 0.0008) * k / (n_base - 1), z_b) for k in range(n_base)]

    def wall_to(top):
        pts = []
        for k in range(1, n_wall + 1):
            z = z_b + (top - z_b) * k / n_wall
            corner = min(1.0, (z - z_b) / 0.004)
            pts.append((r_flat + (tin_inner(z) - r_flat) * math.sin(corner * math.pi / 2), z))
        return pts

    raw = base + wall_to(h_raw)
    r_edge = tin_inner(h_raw)
    for k in range(1, n_top + 1):
        u = k / n_top
        raw.append((max(0.0006, r_edge * (1 - u)), h_raw + 0.0012 * (1 - ease(min(1.0, u / 0.06))) - 0.0004 * u))
    risen = base + wall_to(z_rim)
    r_rim = tin_inner(z_rim)
    p = 2.0
    for k in range(1, n_top + 1):
        tt = k / n_top * math.pi / 2
        # A sponge rises flat near the tin wall and domes in the middle.
        r = r_rim * math.cos(tt) ** (2 / 3.2)
        z = z_rim + 0.002 * math.sin(tt) + (dome - 0.002) * math.sin(tt) ** (2 / p) * (1 - math.cos(tt)) ** 0.6
        risen.append((max(0.0006, r), z))
    return raw, risen, z_rim, z_rim + dome


def build_cake(centre, rng, rise, browning):
    raw, risen, z_rim, z_top = cake_profiles()
    obj, risen_coords = make_cake_object("Cake", raw, risen, centre, 320, centre)
    crown_group(obj, risen_coords, centre[2] + z_rim + 0.001, centre[2] + z_rim + 0.006)
    # The sponge's crown is wide and flat: weight cracks by distance from the centre instead.
    r_in = tin_inner(z_rim)
    weights = [1 - ease(min(max((math.hypot(c[0] - centre[0], c[1] - centre[1]) - 0.45 * r_in) / (0.3 * r_in), 0), 1))
               if c[2] > centre[2] + z_rim + 0.002 else 0.0 for c in risen_coords]
    add_cracks(obj, weights, rng, count=1, length=(0.07, 0.10), start_radius=0.012,
               width=0.0018, depth=0.0022)
    space = texture_space(obj, rng)
    add_surface(obj, crumb_scale=0.006, crumb_depth=0.0008, coords_object=space)
    finish_cake(obj, rise, browning)
    return obj


def build_turnout(centre, rng, browning, flipped=True):
    """The baked cake out of its tin, the dome levelled off and the cake turned over, so its
    former base is the flat, smooth top: the decorating canvas. Flat base, no tin."""
    t = M.TIN
    height = t["depth"] - t["rim_r"] - 0.0006 - (t["wall_t"] + 0.0002)
    corner = 0.004
    n_wall = 30
    # Bottom (the levelled cut, wide) up the wall to the top (the old base, narrow, rounded edge).
    r_bottom = tin_inner(height)
    r_top = tin_inner(0.0) - 0.0038
    prof = [(0.0008 + (r_bottom - 0.0012) * k / 39, 0.0) for k in range(40)]
    for k in range(1, n_wall + 1):
        z = height * k / n_wall
        r = r_bottom + (r_top + corner - r_bottom) * (z / height)
        round_in = max(0.0, (z - (height - corner)) / corner)
        r -= corner * (1 - math.cos(round_in * math.pi / 2))
        prof.append((r, z))
    prof += [(r_top * (1 - k / 40) + 0.0008 * (k / 40), height) for k in range(1, 41)]
    if not flipped:
        prof = [(r, height - z) for r, z in reversed(prof)]
    coords, faces = revolve(prof, centre, 192)
    me = bpy.data.meshes.new("CakeTurnout")
    me.from_pydata([tuple(c[k] - centre[k] for k in range(3)) for c in coords], [], faces)
    me.update()
    me.shade_smooth()
    obj = bpy.data.objects.new("CakeTurnout", me)
    obj.location = centre
    C.link(obj)
    sub = obj.modifiers.new("Smooth", "SUBSURF")
    sub.levels, sub.render_levels = 1, 2
    obj["browning"] = float(browning)
    obj["rise"] = 1.0
    obj["turned"] = "flipped, levelled" if flipped else "upright"
    return obj
