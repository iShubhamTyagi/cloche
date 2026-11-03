# focus.py

Write scripts/blender/focus.py that renders the background of the zoom-to-centre move and
exports its camera path. The cake and plate are NOT rendered here: the live 3D viewer shows
them and plays the move itself. Use build/stage.blend. Follow CLAUDE.md.

THE MOVE (about 0.9 s, 18 frames at 20 fps, ease-in-out)
- Start: the final settle frame of transition.py (cloche already lifted away).
- End: straight top-down, the cake centred on the screen, the cake diameter (200 mm)
  filling --fill 0.78 of the screen width.
- A real Blender camera moves along a smooth Bezier path, tilting from the stage elevation
  (about 38 degrees) to 90 degrees while dollying in. Perspective is correct on every frame.

LAYERS (transparent RGBA, same camera path)
- focus_bg: slab, void and surroundings, WITHOUT the plate and cake, fading into the marble
  surface at the end. Rendered for two screen shapes: iPhone (1080 x 2340) and Duo flat
  (about 1500 x 2130). Soft depth of field as the oven and slab edge drift out of frame.

CAMERA PATH (the important output)
- For every frame: camera position, target, up vector and field of view, in the same
  units and axes as viewer_scene.json from cake_maps.py, so the live viewer's camera can
  replay the move exactly. Include easing names and cue marks (start of push-in, midpoint,
  landing on top-down).
- The first frame's camera equals the stage_wide camera; the last equals the viewer's
  top-down camera. Report any difference.

SCREEN SHAPES AND THE FOLD
- Parameter --center-offset-y per screen shape (default 0). On a horizontally folded Duo the
  screen centre lies on the fold. Keep 0 for now, render a second variant with
  --center-offset-y 0.08 for the Duo, and log both.
- Render renders/studio/guides_focus_duo.png with the approximate fold band overlaid.

METADATA (manifest): per-frame timings, the camera path, the cake centre and radius in
screen pixels in the final frame, and the station panel areas read from station.py.

CHECKS: render the cake and plate (not exported) for 5 sample frames as references, and
report how closely a simple projection of the exported camera path matches them (error in
pixels). Verify with tools/composite_check.py that focus_bg stacks cleanly.

BUDGET: at most 12 MB for focus_bg. If over: 12 frames, then lower resolution, then compress.

STAGES (review after each, no waiting)
 1 Camera path and projection check  2 focus_bg for iPhone  3 focus_bg for Duo and the
 variants  4 Manifest and size report
After each stage render, LOOK at the output, list what is unrealistic compared with a real
photograph, fix it, then continue.
