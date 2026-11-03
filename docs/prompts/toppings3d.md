# toppings3d.py

Write scripts/blender/toppings3d.py that exports the toppings as low-poly 3D models for the
live cake viewer. Follow CLAUDE.md. Reuse the models in toppings.blend. No text or logos.

MODELS (3 variants each, real size in mm)
- raspberry, blueberry, strawberry slice, cherry with stem, mint leaf, chocolate shard,
  chocolate curl, gold flake, sugar pearl, pistachio crumb, almond flake, flower petal.
- Sprinkles: ONE small rod mesh designed for instancing, in five colours (the colour is set
  at runtime).
- Each model under 1,500 triangles (the sprinkle rod under 100), with PBR textures from one
  shared atlas per group (1024 x 1024 at most).
- Pivot at the contact point with the surface, and the local up axis equal to the surface
  normal, so the app can place a topping with a hit point and a normal.
- A collision radius and height for each in the manifest, so overlapping toppings can be
  spaced and stacked naturally.

OUTPUT: renders/viewer/toppings/<name>_<variant>.usdz, the atlases, and toppings3d_manifest.json
(real size in mm, pivot, radius, height, triangle count). Budget 8 MB in total.

CHECKS: render each model from the top, from 45 degrees and from the side with the viewer
environment, compare with the original topping renders, and list the differences.

STAGES (review after each, no waiting)
 1 Berries and cherry  2 Leaves, flakes, shards and curls  3 Sprinkle rod and pearls
 4 Atlases, manifest, size report
After each stage, LOOK at the output, list what is unrealistic compared with real
toppings, fix it, then continue.
