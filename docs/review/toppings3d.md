# Review: toppings3d.py (step 5)

37 USDZ files (12 toppings × 3 variants plus one sprinkle rod), all within their triangle budgets (raspberries use icosphere drupelets at subdivision 0 for the viewer), 0.43 MB against 8 MB. Pivot at the contact point, +Y up.

Check renders (top, 45°, side): `docs/review/toppings3d_check.png`. Shapes read at viewer scale. They are smaller and plainer than the hero icons, which is expected for low-poly models.

Materials are constant UsdPreviewSurface values (the models have no textures), so there are no atlases.
