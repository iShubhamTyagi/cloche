"""Decorating step 9: copy the decorating assets into the app, merge the manifest, report sizes.

    python3 scripts/blender/export_assets.py [--budget-mb 150]

Plain Python (no Blender): it uses macOS `sips` to turn opaque images into HEIC. Writes
Packages/ClocheKit/Sources/Features/Resources/DecorRender/ (generated, gitignored). SwiftPM
flattens resources, so every file gets a unique prefixed name. Fails (exit 1) when the whole
app's resources exceed the budget, listing what to trim first.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
R = os.path.join(REPO, "build", "renders")
RES = os.path.join(REPO, "Packages", "ClocheKit", "Sources", "Features", "Resources")
DEST = os.path.join(RES, "DecorRender")
GROUP_BUDGETS = {"viewer": 45, "tools": 15, "topping_icons": 5, "station": 15, "focus": 12}


def heic(src, dst, quality=70):
    subprocess.run(["sips", "-s", "format", "heic", "-s", "formatOptions", str(quality), src, "--out", dst],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def copy(src, name, group, sizes, opaque=False):
    if not os.path.exists(src):
        return False
    if opaque and src.endswith(".png"):
        dst = os.path.join(DEST, os.path.splitext(name)[0] + ".heic")
        heic(src, dst)
    else:
        dst = os.path.join(DEST, name)
        shutil.copy(src, dst)
    sizes[group] = sizes.get(group, 0) + os.path.getsize(dst)
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--budget-mb", type=float, default=150)
    args = parser.parse_args()
    if os.path.exists(DEST):
        shutil.rmtree(DEST)
    os.makedirs(DEST)
    sizes = {}
    missing = []

    def need(ok, what):
        if not ok:
            missing.append(what)

    # Viewer: maps (HEIC), profiles, plate, marble, environment, scene, palette.
    for dish in ("cake_golden", "cupcake_golden"):
        d = os.path.join(R, "viewer", dish)
        for part in ("top", "side"):
            for kind in ("albedo", "roughness", "normal", "ao"):
                need(copy(os.path.join(d, f"{part}_{kind}.png"), f"{dish}_{part}_{kind}.png", "viewer", sizes, opaque=True),
                     f"{dish} {part} {kind}")
        need(copy(os.path.join(d, "profile.json"), f"{dish}_profile.json", "viewer", sizes), f"{dish} profile")
    for kind in ("albedo", "roughness", "normal", "ao"):
        copy(os.path.join(R, "viewer", "plate", f"{kind}.png"), f"plate_{kind}.png", "viewer", sizes, opaque=True)
    copy(os.path.join(R, "viewer", "plate", "plate.json"), "plate.json", "viewer", sizes)
    need(copy(os.path.join(R, "viewer", "marble_tile", "albedo.png"), "marble_albedo.png", "viewer", sizes, opaque=True), "marble tile")
    need(copy(os.path.join(R, "viewer", "env.hdr"), "env.hdr", "viewer", sizes), "environment")
    copy(os.path.join(R, "viewer", "viewer_scene.json"), "viewer_scene.json", "viewer", sizes)
    copy(os.path.join(R, "icing", "palette.json"), "palette.json", "viewer", sizes)
    for f in sorted(glob.glob(os.path.join(R, "viewer", "toppings", "*.usdz"))):
        copy(f, "topping_" + os.path.basename(f), "viewer", sizes)

    # Tools: one rotation (the app turns the sprite) plus its shadow; brushes are generated in code.
    for f in sorted(glob.glob(os.path.join(R, "tools", "sprites", "*_0.png"))):
        copy(f, "tool_" + os.path.basename(f).replace("_0.png", ".png"), "tools", sizes)
    copy(os.path.join(R, "tools", "tools_manifest.json"), "decor_tools.json", "tools", sizes)

    # Topping icons.
    for f in sorted(glob.glob(os.path.join(R, "toppings", "icons", "*.png"))):
        copy(f, "topping_icon_" + os.path.basename(f), "topping_icons", sizes)

    # Station: panels keep alpha (the cake window), vessels and their shadows, layouts.
    for shape in ("iphone", "duo"):
        need(copy(os.path.join(R, "station", f"panels_{shape}.png"), f"decor_panel_{shape}.png", "station", sizes), f"panel {shape}")
        copy(os.path.join(R, "station", f"layout_{shape}.json"), f"decor_layout_{shape}.json", "station", sizes)
    for f in sorted(glob.glob(os.path.join(R, "station", "vessels", "*.png"))):
        copy(f, "vessel_" + os.path.basename(f), "station", sizes)

    # Focus move background frames (opaque) and the camera path.
    for key in ("iphone", "duo", "duo_offset"):
        for f in sorted(glob.glob(os.path.join(R, "focus", key, "bg_*.png"))):
            copy(f, f"focus_{key}_" + os.path.basename(f), "focus", sizes, opaque=True)
    copy(os.path.join(R, "focus", "focus_manifest.json"), "focus_manifest.json", "focus", sizes)

    files = sorted(os.listdir(DEST))
    mb = {k: round(v / 1e6, 2) for k, v in sizes.items()}
    existing = sum(os.path.getsize(os.path.join(root, f)) for root, _, fs in os.walk(RES) for f in fs
                   if not root.startswith(DEST))
    total = round((existing + sum(sizes.values())) / 1e6, 2)
    report = {"groups_mb": mb, "group_budgets_mb": GROUP_BUDGETS,
              "over_group_budget": {k: v for k, v in mb.items() if v > GROUP_BUDGETS.get(k, 1e9)},
              "existing_resources_mb": round(existing / 1e6, 2), "total_resources_mb": total,
              "budget_mb": args.budget_mb, "files": len(files), "missing": missing}
    with open(os.path.join(DEST, "decor_manifest.json"), "w") as f:
        json.dump({"files": files, "report": report}, f, indent=1)
    with open(os.path.join(R, "export_report.json"), "w") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))
    if total > args.budget_mb:
        print("OVER BUDGET. Trim in this order: fewer focus frames, lower map resolution (512 side/AO), "
              "stronger HEIC compression, then On-Demand Resources.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
