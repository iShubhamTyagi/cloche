# Review: focus.py (step 8)

The camera path's exported frames, projected with a simple pinhole camera, match Blender's camera within 0.02 px on 5 sample frames (`build/renders/focus/check.json`). The first frame is the station camera; the last is the viewer's top camera (the same fit as `CameraRig`).

Background (`focus_sheet.png`): the slab, the stand and the void, with the plate and cake left out (the live viewer draws them). Depth of field softens the slab's edge as it drifts out. The bearing ring shows in the last frame and sits under the live plate.

Rendered for the iPhone, the Duo, and the Duo with a 0.08 centre offset, 18 frames each at half resolution (soft background). Exported as HEIC: 0.55 MB against 12 MB.
