# transition.py

Write scripts/blender/transition.py: the sequence in which the baked cake leaves the oven
tray, is lifted by a spatula, carried to the turntable stand and settles on the plate, with
the camera easing from the oven view to the stand view and the cloche already lifted away.
Reuse oven.blend, cakestand.blend, slab.blend and moulds_<state>.blend; do not rebuild them.
Layered transparent frames (--dish cupcake|cake, --state golden), 20 fps, ease-in-out, with
Holdout so occlusion is baked in. Write the final cake screen position and scale to the
manifest so the live viewer can cross-fade from it. Verify with tools/composite_check.py.
Review after each stage and continue without waiting.
