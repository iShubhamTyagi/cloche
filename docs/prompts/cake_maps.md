# cake_maps.py

Write scripts/blender/cake_maps.py that exports everything the live 3D cake viewer needs,
from the existing moulds, cake stand and slab assets. Follow CLAUDE.md. No text, logos or
brand marks. Audit the existing .blend files first and report mismatches instead of
changing them. Do not rebuild the cakes, the plate or the slab.

EXPORTS (per dish: cupcake and cake; per bake state: raw, half, golden, dark; the cupcake
dish exports ONE hero cupcake unless DECISIONS.md says otherwise; golden first)
- Mesh: a clean, low-poly cake mesh with an even polar grid on the top face (128 rings x
  256 segments) and a cylinder grid on the side (64 rows x 256 segments), so icing
  displacement works. UVs: top = polar (radius, angle), side = (angle, height). For the
  cupcake: the sponge dome, the liner as a separate mesh, and a flat-ish crown region for icing.
- Texture maps, 1024 x 1024 (the side strip 1024 x 512): base colour (albedo, with NO baked
  lighting or shadows), roughness, tangent-space normal, ambient occlusion. One set per state.
  Bake them from the high-detail Blender cake with Cycles baking, and verify the seams.
- A height map of the bare crumb surface (16-bit, with the mm range recorded).
- Units: metres. Origin at the centre of the base. Z up. Sizes match the oven tray and the stand.

PLATE AND COLLAR
- Marble plate: disc mesh and PBR maps (albedo, roughness, normal) with polar UVs, rotation
  axis Z at the exact centre, veins visible so the rotation reads clearly.
- Brass collar ring: mesh and PBR maps. It is the tap target that starts and stops the spin.
- A seamless, tileable honed marble texture (2048, PBR) for the surface under the plate.

LIGHTING AND CAMERA METADATA (so the live scene matches the Blender look)
- A small environment map (equirectangular HDR, 512 x 256) baked from the studio.blend world.
- viewer_scene.json: key light direction, colour and intensity; exposure and colour-management
  settings; the stage_wide camera intrinsics and extrinsics from camera.json; the top-down,
  angle (about 55 degrees) and side (about 10 degrees) cameras; units and dimensions.

CHECKS
- For each state, render a Blender preview using ONLY the exported meshes and maps with a plain
  Principled shader and the exported environment, and compare it with the original Blender
  render. Report the error and fix visible seams or map mistakes.
- Confirm the polar UV seam is invisible and the side strip is seamless left to right.

OUTPUT AND BUDGET
- renders/viewer/<dish>_<state>/ with mesh.usdz, albedo.png, roughness.png, normal.png, ao.png
  and height.png; plus plate/, collar/, marble_tile/, env.hdr, viewer_scene.json and
  viewer_manifest.json.
- Budget 45 MB for all viewer assets including toppings3d. If over: 512 maps for the side strip
  and AO, pack roughness and AO into one map, share maps between states where identical,
  compress. Report the sizes.

STAGES (review after each, no waiting)
 1 Meshes and UV layout (clay)  2 Bake albedo, normal, AO and roughness for one state
 3 All states  4 Plate, collar, marble tile, environment and metadata
 5 Preview-versus-original checks  6 Size report
After each stage, LOOK at the output, list what is unrealistic or wrong compared with the
original Blender render, fix it, then continue.
