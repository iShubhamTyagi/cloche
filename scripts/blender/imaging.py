"""PNG tools for sheets and checks (numpy, top-left origin): load, save, composite, compare."""
import os

import bpy
import numpy as np

import common as C

# Oven bounding boxes in the reference images, in pixels (x0, y0, x1, y1), top-left origin.
REF_CLOSED = ("oven_ref_closed.png", (7, 3, 229, 163))     # body only, door shut
REF_OPEN = ("oven_ref.png", (30, 224, 374, 584))           # body + dropped door + handle


def load(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1].copy()


def save(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save()
    bpy.data.images.remove(img)
    print(f"[image] {os.path.relpath(path, C.REPO)}")


def over_background(arr, bg=0.07):
    a = arr[..., 3:4]
    out = arr.copy()
    out[..., :3] = arr[..., :3] * a + bg * (1 - a)
    out[..., 3] = 1
    return out


def resize(arr, w, h):
    ys = (np.arange(h) * arr.shape[0] / h).astype(int)
    xs = (np.arange(w) * arr.shape[1] / w).astype(int)
    return arr[ys][:, xs]


def to_height(arr, h):
    return resize(arr, max(1, round(arr.shape[1] * h / arr.shape[0])), h)


def alpha_bbox(arr, threshold=0.9):
    ys, xs = np.nonzero(arr[..., 3] > threshold)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def clean_transparent(path):
    """Zero the colour of fully transparent pixels (bloom leaves stray colour there)."""
    arr = load(path)
    arr[arr[..., 3] < 1 / 255, :3] = 0
    save(arr, path)


def comparison(ref_spec, render_path, out_path, height=600):
    """[reference | render | 50% overlay of the reference oven scaled onto the render's oven]."""
    ref_name, (rx0, ry0, rx1, ry1) = ref_spec
    ref = load(os.path.join(C.REFERENCE, ref_name))
    ref[..., 3] = 1
    rendered = load(render_path)
    bx0, by0, bx1, by1 = alpha_bbox(rendered)
    flat = over_background(rendered)
    overlay = flat.copy()
    patch = resize(ref[ry0:ry1, rx0:rx1], bx1 - bx0, by1 - by0)
    overlay[by0:by1, bx0:bx1, :3] = 0.5 * overlay[by0:by1, bx0:bx1, :3] + 0.5 * patch[..., :3]
    gap = np.full((height, 12, 4), 1.0, dtype=np.float32)
    save(np.concatenate([to_height(ref, height), gap, to_height(flat, height), gap,
                         to_height(overlay, height)], axis=1), out_path)
    return {"reference_ratio": round((rx1 - rx0) / (ry1 - ry0), 3),
            "render_ratio": round((bx1 - bx0) / (by1 - by0), 3)}


def grid(paths, out_path, columns, cell_h=240, bg=0.07, labels_gap=0):
    """Contact sheet: each image composited on a dark background, scaled to cell_h."""
    tiles = [to_height(over_background(load(p), bg), cell_h) for p in paths]
    cell_w = max(t.shape[1] for t in tiles)
    rows = -(-len(tiles) // columns)
    sheet = np.full((rows * cell_h, columns * cell_w, 4), bg, dtype=np.float32)
    sheet[..., 3] = 1
    for i, tile in enumerate(tiles):
        r, c = divmod(i, columns)
        x = c * cell_w + (cell_w - tile.shape[1]) // 2
        sheet[r * cell_h:(r + 1) * cell_h, x:x + tile.shape[1]] = tile
    save(sheet, out_path)
