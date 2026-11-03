# Review: cake_maps.py (step 4)

Pass 1:
- Albedo came out flat grey: the dish `.blend` files carry no materials; they're assigned at render time.
- Normal maps came out olive: the low-poly grids were wound inward, so the cage pointed into the cake.
- The cupcake liner strip was black: the same winding problem, plus ray casts hitting the tin.

Fixes:
- `bake_materials.assign()` at golden browning (0.62).
- Counter-clockwise winding for the top (+Z) and the side (outward).
- Other meshes hidden from the ray casts.
- The marble tile cast to float32.

Pass 2 (`docs/review/cake_maps_check.png`): the preview from the exported grid and maps alone (plain Principled) against the original high-detail cake gives a mean error of 0.003 (cake) and 0.0038 (cupcake). Side-strip seam error 0.030 and 0.007 (column 2 vs column −3, within the crumb noise). Accepted.

Golden state only: the app darkens the golden maps for the dark state (see DECISIONS). Viewer exports total 1.3 MB as HEIC against 45 MB.
