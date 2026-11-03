# station.py

Write scripts/blender/station.py that builds and renders the decorating station panels and
vessel sprites for a live 3D decorating screen. Follow CLAUDE.md. Hyperrealistic, premium
French patisserie, organised and symmetrical. No text, logos or brand marks.

REUSE EXISTING ASSETS (audit first, report mismatches, do not change or rebuild them)
- cakestand.blend, slab.blend (the honed marble), icing.py materials, toppings.blend and
  tools.py nozzles. The plate, collar and marble surface now come from cake_maps.py.

THE BENCH PANELS (screen-space, drawn around a transparent centre window where the live
3D cake appears)
- iPhone (1080 x 2340): a top band for the ingredient shelf and a bottom band for toppings
  and tools. Duo flat (about 1500 x 2130): top band plus two side columns for toppings, with
  nothing across the fold band.
- Same honed marble as the slab, brushed-brass edge rails, one folded linen cloth at a corner,
  no other clutter.
- Seats (shallow, thin brass rim, satin lining): Seat_Pot_01..12 in two rows,
  Seat_Nozzle_1..3 in a small brass tray, Seat_Bowl_01..08, and brass cradles Cradle_Cone,
  Cradle_Spatula, Cradle_Pan, Cradle_Bottle, Cradle_Sieve. An empty named anchor for each.

VESSELS (separate objects with contents)
- 12 white porcelain ramekins with a fine gold rim, filled with the eight icing colours and
  four ganaches (reuse icing.py materials so the colours match exactly).
- A small brass nozzle tray holding NozzleRound, NozzleStar and NozzlePetal upright.
- 8 bowls (alternating brushed steel and porcelain) with natural heaps built from the
  toppings.blend models; settle each heap with a rigid-body simulation.
- The tools themselves come from tools.py sprites; the cradles stay empty in the background.

RENDERS (orthographic top-down, light from the top-left, shadows to the bottom-right)
 1 panels per screen shape (PNG with transparency in the centre window).
 2 vessel sprites (transparent, 512 px, soft contact shadow as a separate sprite): each pot,
   the nozzle tray and each bowl, in three states: resting, lifted (about 6 percent larger,
   longer softer shadow) and empty seat.
 3 layout.json per screen shape: anchor (normalised and pixels), size and tap radius of every
   seat, cradle and control; shelf groupings and scroll groups; safe areas for the break clock,
   Serve button, undo, clear, speed control, plate and backdrop buttons; the cake window
   rectangle. Minimum tap target 44 points at iPhone scale.
 4 guides: renders/station/guides_<shape>.png showing the grid, safe areas and the approximate
   fold band on the Duo shape.

CHECKS: seat spacing equal within 0.5 percent, no vessel crossing its seat boundary, nothing
inside the fold band on the Duo shape.

OUTPUT AND BUDGET: renders/station/panels_<shape>.png, vessels/<name>_<state>.png and
_shadow.png, layout.json, guides and station_manifest.json. Budget 15 MB. If over: 384 px
vessels, merge states, compress. Report the sizes.

STAGES (review after each, no waiting)
 1 Panels, seats, rails (clay)  2 Vessels and contents (clay)  3 Materials and lighting
 4 Panels, layout.json and guides  5 Vessel sprites in three states  6 Checks and size report
After each stage render, LOOK at the output, list what looks unrealistic or disorganised
compared with a real professional pastry bench, fix it, then continue.
