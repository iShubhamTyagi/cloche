# Review: icing.py (step 1)

Contact sheet: `docs/review/icing_contact.png` (sphere + piped swatch per material, station lights).

Pass 1 against real buttercream and ganache photos:
- Buttercream too pale and milky; chocolate read as milk coffee, raspberry as pink. Cause: subsurface 0.3–0.4 plus sheen, and the station lights clipping a top-down subject.

Fixes: subsurface 0.06–0.15, sheen 0.08, deeper base colours, and a shared exposure of −0.6 for every decorating render (`deco_common.EXPOSURE`).

Pass 3: buttercreams are matte with a fine grain and true colour; ganaches are glossy with clear-coat highlights and read as poured chocolate. Accepted.

Remaining: the swatch swirl is regular, unlike a hand-spread swirl. That's fine for a swatch; the app's icing comes from the brush maps anyway.
