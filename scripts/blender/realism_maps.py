"""Sponge and liner maps for the live viewer (no scene needed, numpy only).

Replaces the baked albedo, normal and roughness of the cake and cupcake with maps generated from
one 3D noise field sampled at each texel's real position, so crumb is the right size everywhere
and the top and the side match where they meet. Reads <dish>_golden_profile.json for the shape.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/blender/realism_maps.py

Run after export_assets.py (it writes into Resources/DecorRender). The first run keeps the
originals in build/renders/realism_backup.
"""
import json, os, shutil, struct, subprocess, zlib
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Packages/ClocheKit/Sources/Features/Resources/DecorRender")
TMP = os.path.join(ROOT, "build/renders/realism")
BACKUP = os.path.join(ROOT, "build/renders/realism_backup")
PLEATS = 44  # ViewerMesh.linerPleats


def lattice(ix, iy, iz, seed):
    h = (ix.astype(np.uint32) * np.uint32(374761393) + iy.astype(np.uint32) * np.uint32(668265263)
         + iz.astype(np.uint32) * np.uint32(2147483647) + np.uint32(seed * 2654435761 % 2**32))
    h = (h ^ (h >> np.uint32(13))) * np.uint32(1274126177)
    return ((h ^ (h >> np.uint32(16))) & np.uint32(0xFFFF)).astype(np.float32) / 65535.0


def noise3(x, y, z, seed=1):
    """Smooth value noise in 0..1."""
    ix, iy, iz = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
    fx, fy, fz = x - ix, y - iy, z - iz
    fx, fy, fz = [(f * f * (3 - 2 * f)).astype(np.float32) for f in (fx, fy, fz)]
    out = 0
    for dx in (0, 1):
        wx = fx if dx else 1 - fx
        for dy in (0, 1):
            wy = fy if dy else 1 - fy
            for dz in (0, 1):
                wz = fz if dz else 1 - fz
                out = out + lattice(ix + dx, iy + dy, iz + dz, seed) * wx * wy * wz
    return out


def fbm(x, y, z, scale, octaves=4, seed=1):
    total, amp, norm = 0, 1.0, 0.0
    for o in range(octaves):
        total = total + noise3(x / scale, y / scale, z / scale, seed + o) * amp
        norm += amp
        amp *= 0.5
        scale *= 0.5
    return total / norm


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def rgb(hexv):
    c = np.array([(hexv >> 16) & 255, (hexv >> 8) & 255, hexv & 255], dtype=np.float32) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)  # linear


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def write_png(path, data):
    data = np.clip(data * 255 + 0.5, 0, 255).astype(np.uint8)
    if data.ndim == 2:
        data = np.repeat(data[..., None], 3, axis=2)
    h, w, c = data.shape
    raw = b"".join(b"\x00" + data[i].tobytes() for i in range(h))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def publish(name, data):
    """PNG -> HEIC in the app, keeping the first original."""
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(BACKUP, exist_ok=True)
    target = os.path.join(OUT, name + ".heic")
    keep = os.path.join(BACKUP, name + ".heic")
    if os.path.exists(target) and not os.path.exists(keep):
        shutil.copy(target, keep)
    png = os.path.join(TMP, name + ".png")
    write_png(png, data)
    subprocess.run(["sips", "-s", "format", "heic", "-s", "formatOptions", "85", png, "--out", target],
                   check=True, stdout=subprocess.DEVNULL)


def normal_map(h, du, dv, strength=1.0):
    """Height in mm; du, dv mm per texel (du may vary by row). Rows run top to bottom, v upward."""
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / (2 * du)
    gy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / (2 * dv)
    gy[0] = gy[-1] = 0
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def sponge(px, py, pz, crust):
    """Colour, height and roughness at real positions (mm). `crust` 0..1: how baked the skin is."""
    cells = fbm(px, py, pz, 1.5, 3, seed=11)                 # the crumb itself, about 1.5 mm
    pores = smooth(0.60, 0.42, fbm(px, py, pz, 0.9, 2, seed=23))
    large = smooth(0.70, 0.52, noise3(px / 2.6, py / 2.6, pz / 2.6, seed=31))
    drift = fbm(px, py, pz, 34, 2, seed=41) - 0.5           # gentle, never blotchy
    crumb, skin = rgb(0xE9CD93), rgb(0xBF8340)
    colour = mix(np.broadcast_to(crumb, px.shape + (3,)), np.broadcast_to(skin, px.shape + (3,)),
                 np.clip(crust + drift * 0.28, 0, 1))
    shade = 1 - 0.20 * pores - 0.16 * large + (cells - 0.5) * 0.12
    height = cells * 0.32 - pores * 0.22 - large * 0.34
    rough = np.clip(0.74 - crust * 0.12 + pores * 0.1, 0, 1)
    return colour * shade[..., None], height, rough


def dish(key, liner):
    p = json.load(open(os.path.join(OUT, f"{key}_profile.json")))
    top_r, rings = p["top_radius"] * 1000, np.array(p["top_heights_rings"]) * 1000
    # Top: polar. u = angle, v = radius / R; row 0 of the image is v = 1.
    w, h = 2048, 1024
    a = (np.arange(w, dtype=np.float32) + 0.5) / w * 2 * np.pi
    v = 1 - (np.arange(h, dtype=np.float32) + 0.5) / h
    r = v * top_r
    z = np.interp(v, np.linspace(0, 1, len(rings)), rings)
    A, R = np.meshgrid(a, r)
    Z = np.broadcast_to(z[:, None], A.shape)
    # Browner toward the shoulder, where the heat reached first.
    crust = 0.52 + 0.46 * smooth(0.55, 1.0, R / top_r)
    colour, height, rough = sponge(R * np.cos(A), R * np.sin(A), Z, crust)
    du = np.maximum(R * 2 * np.pi / w, 0.03)
    dv = top_r / h
    publish(f"{key}_top_albedo", to_srgb(colour))
    publish(f"{key}_top_normal", normal_map(height, du, dv, 1.2))
    publish(f"{key}_top_roughness", rough)

    # Side: u = angle, v = height share.
    w, h = 2048, 512
    a = (np.arange(w, dtype=np.float32) + 0.5) / w * 2 * np.pi
    v = 1 - (np.arange(h, dtype=np.float32) + 0.5) / h
    z0, z1 = p["side_bottom"] * 1000, p["side_top"] * 1000
    zz = z0 + (z1 - z0) * v
    radii = np.array(p["side_radii_rows"]) * 1000
    rr = np.interp(v, np.linspace(0, 1, len(radii)), radii)
    A, Zs = np.meshgrid(a, zz)
    Rs = np.broadcast_to(rr[:, None], A.shape)
    du = float(rr.mean()) * 2 * np.pi / w
    dv = (z1 - z0) / h
    if liner:
        paper(A, Zs, Rs, v, du, dv, key)
        return
    crust = 0.98 - 0.1 * smooth(0.9, 0.3, v)
    crust = np.broadcast_to(np.asarray(crust, dtype=np.float32)[:, None], A.shape)
    colour, height, rough = sponge(Rs * np.cos(A), Rs * np.sin(A), Zs, crust)
    publish(f"{key}_side_albedo", to_srgb(colour))
    publish(f"{key}_side_normal", normal_map(height, du, dv, 1.2))
    publish(f"{key}_side_roughness", rough)


def paper(A, Z, R, v, du, dv, key):
    """A pleated paper case: crisp folds, fine fibres, grease coming through near the base."""
    x, y = R * np.cos(A), R * np.sin(A)
    phase = (A / (2 * np.pi) * PLEATS) % 1.0
    tri = np.abs(phase * 2 - 1)                       # 0 at a valley, 1 at a ridge
    fold = smooth(0.0, 0.09, tri) * smooth(1.0, 0.91, tri)
    fibres = fbm(x * 3, y * 3, Z * 0.6, 0.8, 3, seed=61)
    grease = smooth(0.56, 0.72, fbm(x, y, Z, 9, 3, seed=71)) * smooth(0.62, 0.05, np.broadcast_to(v[:, None], A.shape))
    paper_c, ochre = rgb(0xF0E5CF), rgb(0xBC9358)
    colour = mix(np.broadcast_to(paper_c, A.shape + (3,)), np.broadcast_to(ochre, A.shape + (3,)), grease * 0.62)
    shade = (0.9 + 0.1 * fold) * (0.97 + (fibres - 0.5) * 0.1)
    publish(f"{key}_side_albedo", to_srgb(colour * shade[..., None]))
    height = tri * 1.1 + fibres * 0.05
    publish(f"{key}_side_normal", normal_map(height, du, dv, 0.3))
    publish(f"{key}_side_roughness", np.clip(0.56 - grease * 0.2 + (fibres - 0.5) * 0.1, 0, 1))


dish("cake_golden", liner=False)
dish("cupcake_golden", liner=True)
print("realism maps written")
