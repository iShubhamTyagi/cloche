# Review: tools.py (step 3)

## Sprites (`docs/review/tools_sprites.png`)

Pass 1 against real kitchen tools:
- **Spatula:** the blade rendered as a bow-tie (the tip taper was applied to a whole 8-vertex box), and the walnut read as pale pine.
- **Piping bag:** no icing visible through the parchment.
- **Squeeze bottle:** looked like a plain white roll.

Fixes:
- The blade is now an extruded outline with a semicircular tip.
- Darker walnut.
- Parchment transmission 0.7.
- Frosted bottle transmission 0.9, so the caramel shows.

Pass 2: the pan, sieve and spatula read as real tools; the bag shows the rose icing faintly; the bottle shows its caramel. Accepted.

## Brush maps

`brushes.py` builds them; the app generates the same maps in code. Ring check (Python stamping vs a swept Blender bead, ray-cast heights): mean error 0.007 mm, p99 0.155 mm, max 0.357 mm on a 3.2 mm bead (`build/renders/tools/ring_check.json`). Pass.

## Reference results (`docs/review/tools_reference_pass1.png`)

Pass 1:
- The ring was cropped (the field was down-sampled with a stride that covered 80 of 100 mm).
- The rosette was too small.
- The dusting was too sparse to read.

Fixed (`np.ix_` resampling, 1.4 mm/rad spiral, 6000 grains at 0.4 mm), queued for a rerender. Shell border, zigzag, spiral, drizzle and poured pool read like piped icing.

## Size

Sprites 5.6 MB for 4 rotations against a 15 MB budget. The app ships rotation 0 only and turns it in 2D.
