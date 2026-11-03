# tools.py

Write scripts/blender/tools.py that builds the minimal decorating tool kit and renders
sprites and brush maps for a turntable decorating game. Follow CLAUDE.md. Hyperrealistic,
to real-world size, matching the oven's premium French patisserie look. No text or logos.
Use studio.blend lighting and camera.json. Do not rebuild any existing asset.

THE KIT (exact object names)
- PipingCone: a pleated parchment or silicone piping bag with a metal coupler and three
  interchangeable nozzles: NozzleRound (about 4 mm opening), NozzleStar (open star, about
  8 mm), NozzlePetal (flat petal or leaf tip). Icing visible through the bag near the tip.
- OffsetSpatula: stainless offset spatula, blade about 15 cm, warm wood or brushed brass handle.
- PourPan: a small copper saucepan with a pouring lip, with a thin ganache stream.
- DrizzleBottle: a squeeze bottle with a fine tip and a matte frosted body.
- Sieve: a fine round brass-rimmed sieve shown tilted, with a dusting of powder.
- Toppings and sprinkles come from toppings.py. A small bowl sprite per topping type is optional.

SPRITES (transparent, top-down orthographic, 512 px, render at 2x then downsample,
8 rotations each)
- For each tool: idle and active (cone squeezed, pan tilted, bottle pressed, sieve tapped),
  with and without icing at the working end. A soft contact shadow as a separate sprite.
  Record the anchor point at the working end in pixels, and the real size in mm so the
  app can scale it against a 200 mm cake.

BRUSH MAPS (for the height-field engine)
- For each nozzle, model a real piped bead cross-section and render a top-down depth pass
  as a 16-bit grayscale PNG, 256 x 256, normalised 0..1. Record the real maximum height in
  mm and the millimetres per pixel in brushes.json. Provide: bead stamp (round, star, petal),
  start dollop, and tail (the small peak where you lift off).
- Other footprints: spatula contact mask (soft ellipse), pour blob mask (organic edge),
  drizzle line profile (thin and round, with slight sag), dust particle texture (tileable alpha noise).
- Three sizes of each bead are scale values in brushes.json, not extra images.

REFERENCE RESULTS (for tuning the shader, not shipped)
- Top-down renders of: a piped ring, a rosette, a shell border, a zigzag, a spiral,
  drizzle lines, a poured pool with a drip edge, a spatula-smoothed top, a dusted top.
  Each in two icing colours.
- palette.json: 8 icing colours (ivory, rose, pistachio, chocolate, caramel, white,
  raspberry, blue-grey) with base colour, roughness and specular, consistent with icing.py.

OUTPUT
- renders/tools/sprites/<tool>_<state>_<rotation>.png and _shadow.png
- renders/tools/brushes/<name>.png and brushes.json (mm per pixel, max height, anchors)
- renders/tools/reference/<pattern>_<colour>.png and tools_manifest.json
- Size budget 15 MB for tools. Report the size; if over, cut rotations to 4 and resolution to 384.

STAGES (review after each, no waiting)
 1 Piping cone and nozzles (clay)  2 Other tools (clay)  3 Materials and lit sprites
 4 Brush height maps, plus a check: stamp them along a ring in Python and compare the
   result with the Blender reference ring
 5 Reference results, palette, manifest, size report
After each stage render, LOOK at the output, list what is unrealistic compared with real
kitchen tools and real piped icing, fix it, then continue.
