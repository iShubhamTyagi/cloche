# Blender asset pipeline

Every art asset is built and rendered by these scripts. Blender 5.2.3 LTS (`/Applications/Blender.app/Contents/MacOS/Blender`), headless:

```sh
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P scripts/blender/studio.py                   # build/studio.blend + build/camera.json (run first)
$B -b -P scripts/blender/oven.py                     # build/oven.blend
$B -b -P scripts/blender/render.py -- --stage 4      # oven review renders + checks
$B -b -P scripts/blender/frames.py                   # door frames, manifest, USDZ
```

## Rules (owner, 2026-11-02)

- **Units and axes:** metres, Z up, the camera looks along +Y, the oven front is the y = 0 plane.
- **One studio:**
  - `build/studio.blend` (lights, world, counter shadow catcher, bloom) and `build/camera.json` (every named camera) are the source of truth. Both are written by `studio.py`.
  - No other script creates lights or cameras. They call `studio.use()` and `studio.camera(view)`.
- **Fixed names:**
  - Oven: `Body`, `Door`, `Rack1`/`Rack2`, `Tray1`/`Tray2`, `Knob1`–`Knob3`, `HeatingElement_*`.
  - Cake markers: `CakeSlot_A`–`CakeSlot_D` on Tray1 and `CakeSlot_E`–`CakeSlot_H` on Tray2.
  - Each brief adds its own names. Never rename anything without asking the owner.
- **Bake states:** shared `rise` and `browning` parameters, each 0 to 1.

  | State | rise | browning |
  | --- | --- | --- |
  | raw | 0.00 | 0.00 |
  | half | 0.50 | 0.15 |
  | golden | 1.00 | 0.62 |
  | dark | 1.00 | 0.92 |
- **Content:**
  - No text, logos or brand marks.
  - No external assets or AI textures.
  - Procedural materials only.
- **Resumable and parametric:** every script skips outputs that already exist unless `--force`.
- **Render flags:**
  - Shared: `--res W H`, `--samples N`, `--preview` (= `--res 400 300 --samples 16`) and `--final` (256 samples).
  - OpenImageDenoise is always on.
- **Stages:** work in stages. After each render, look at the images, list what still looks unrealistic against a real product photo, fix it, then show the owner and wait for approval.
- **One asset per file:** each `.blend` holds one asset and nothing else (no studio, no other asset), so it can be appended by name. Assets keep their world positions, so appended together they line up.
- **Git:**
  - Commit the scripts, `build/camera.json`, manifests and reports.
  - Keep `.blend` files, renders and exports out of git (see `.gitignore`).
- **Ambiguity:** if anything is ambiguous, ask before building.

## Files

| Script | What it does |
| --- | --- |
| `studio.py` | Studio and cameras (`build/studio.blend`, `build/camera.json`), the shared render flags, `render()` with skip-existing |
| `layout.py` | Oven dimensions, rack and tray positions, knob detents |
| `oven.py`, `door.py`, `interior.py`, `materials.py` | Builds `build/oven.blend` |
| `render.py` | Oven review renders per stage, the hinge test (0 to 180°), rack clearance, reference comparisons |
| `frames.py` | 48 door frames (0 to 180°), `manifest.json`, the contact sheet, `oven.usdz` |
| `cakestand.py`, `stand_materials.py`, `cloche.py` | The marble turntable stand → `build/cakestand.blend`, and the glass cloche → `build/cloche.blend`. Each file holds only its own asset, positioned at the plating station; renders bring both into the studio |
| `imaging.py` | PNG tools (load, save, composite, compare, grid) |
| `watch.py` | Keeps an open Blender window in sync with `build/oven.blend` |
| `common.py` | Mesh helpers, arguments, stats |
