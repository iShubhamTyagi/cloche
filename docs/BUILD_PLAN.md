# Pocket Oven — Decorating Build Plan for Claude Code (stripped down)

Nov 3, 2026 · @Shubham

## 1. Read this first

This plan covers only the decorating step of Pocket Oven, a French-bakery focus-timer game. Baking, the oven, the hinge door and the bake timer are already built. **Do not rebuild any asset or workflow that already exists.**

**Rule 1: audit before building.** Before writing anything, Claude Code reads the existing app and the existing Blender files and writes `docs/existing_state.md`. It lists what exists, where the finished bake ends and where decorating should plug in. Anything on that list is reused as it is.

**Rule 2: never rebuild or re-render the built items** listed in section 2. If one of them does not match what this plan needs (a name, an origin, a size), write the mismatch to `docs/asset_status.md` and adapt the new work to it. Do not edit the original `.blend` files or the existing Swift baking code unless the change is a small hook that decorating needs, and log every such hook.

**Rule 3: no approvals.** Where a prompt below says to review a stage, Claude Code reviews it itself: render or screenshot the result, compare it with the references, fix what is wrong, write the review to `docs/review/<step>.md`, and move on. Decisions in section 3 use the stated defaults and are logged in `docs/DECISIONS.md`.

**Rule 4: placeholders keep the app running.** Every new asset has a code-drawn placeholder, so the app builds and runs before any Blender output arrives.

**Rule 5: skip, log and continue.** If the same task fails three times, log it in `docs/PROGRESS.md` and go to the next task. Keep a "needs the human" list for anything only the owner can do (real-device tests, taste approval, Apple account).

## 2. Already built: do not build again

| Item | Status | What to do |
| --- | --- | --- |
| Baking flow in the app (prep, armed, baking, ready) and its timers | Built | Reuse. Decorating starts from its "ready" output. |
| Hinge and face-down door handling, the 15-second grace, demo mode | Built | Reuse. Do not touch. |
| Oven asset and its door, tray, knobs, glass reflections | Built | Do not re-render or rebuild. |
| Oven layers, frames, hotspots and the asset loader/manifest | Built | Reuse the loader. Extend its manifest only to add the new decorating entries. |
| `common.py`, `studio.py`, `studio.blend`, `camera.json` | Built (audit) | Reuse for camera and lights. |
| `moulds.py` and the cake and cupcake in four bake states | Built | Reuse as the source for the cake meshes and maps. |
| `cakestand.py`: marble turntable plate, bearing ring, switch, glass cloche | Built | Reuse. The plate origin must be at its exact centre (audit). |
| `slab.py`: floating marble slab, brass rail, anchors | Built | Reuse as the stage and as the source of the marble material. |
| Stage composition and the oven-to-stand transfer (`transition.py`, tray, spatula, carry) | Check `docs/existing_state.md` | If it exists, reuse it. If it does not, build it using section 5 (extra prompt `transition.py`). |
| `splash.py`, the splash video | Not part of this plan | Skip. |
| Watch app, Live Activity, notifications | Not part of this plan | Skip. |

What is new in this plan: icing, toppings, tools, the live 3D cake viewer assets, the decorating station, the focus move, and the decorating screen in the app.

## 3. Decorating design and defaults

**The cake and plate are a live 3D scene; everything else stays pre-rendered.** After the cake lands on the stand, a pre-rendered background plays while the live viewer moves the camera from the stage view to straight top-down. The cake ends centred on screen. The player can then orbit between Top, Angle and Side views and decorate the top and the side of the cake.

- **Camera:** elevation from 90 degrees (top) to about 10 degrees (side), with Top, Angle and Side snap buttons. One finger decorates. Two fingers tilt and a pinch zooms. The turntable turns the plate and cake; the camera's azimuth stays fixed.
- **Turntable:** the brass collar ring around the plate starts and stops the rotation with eased motion and a speed setting.
- **Strokes** are stored as operations in plate-local coordinates: a surface (top or side), radius and angle on the top, angle and height on the side, plus the turntable start and stop times. Replaying them rebuilds the cake for the recipe book, the share card and the time-lapse.
- **Icing:** two height fields (a polar grid for the top, an unrolled strip for the side). Brush height maps stamp into them, a fine mesh is displaced by the field, and a live shader lights and tints the result.
- **Toppings:** low-poly 3D models placed by hit point and surface normal, with a spring drop. Sprinkles are instanced rods.
- **Minimal tool kit, unlimited and free:** piping cone (round, star, petal), offset spatula, pour, drizzle, dust, plus toppings and sprinkles. No guilt mechanics.
- **Station:** a pastry chef's mise en place of screen-space panels over a live marble surface, with every ingredient, tool and control one tap away. iPhone: ingredients in a band above the cake, toppings and tools below. Duo flat: toppings in two columns beside the turntable, nothing across the fold band.
- **Viewer technology:** decided by a spike (Phase D1): RealityKit with custom materials versus a small custom Metal renderer. SceneKit is soft-deprecated and is not used.
- **Art rules:** no text, logos or brand marks in any model. No music. Original or CC0 sounds only. Keep `LICENSES.md` current.

**Defaults Claude Code uses without asking** (log in `docs/DECISIONS.md`): Carrara marble; one hero cupcake carried to the stand; golden bake state first for maps; a centre offset of 0 for the Duo with a 0.08 variant rendered for later choice; eight icing colours, four ganaches, eight toppings and five tools.

**Size budget:** the whole app targets 150 MB. The decorating share is viewer assets 45 MB (meshes, maps, 3D toppings), icing and tool sprites 15 MB, topping icons 5 MB, station panels 15 MB and focus background frames 12 MB per dish. Measure real sizes after each asset step and trim in this order: fewer frames, lower resolution, stronger compression, then On-Demand Resources. Golden state first; add other states only if the total stays within budget.

## 4. Blender scripts to run, in order

Run only the new scripts. Each is parametric and resumable and uses the shared `studio.blend` camera and lights. Save each prompt in section 5 as `docs/prompts/<script>.md` before building it.

| Step | Script | Produces | Needs |
| --- | --- | --- | --- |
| 0 | `scripts/verify_assets.py` | Audit of the existing .blend files; writes `docs/asset_status.md` and a contact sheet | Nothing |
| 1 | `icing.py` | Icing and ganache materials, palette | moulds, studio |
| 2 | `toppings.py` | Small icon sprites for the HUD bowls only | studio |
| 3 | `tools.py` | Tool sprites, brush height maps, reference renders, `palette.json` | studio, icing |
| 4 | `cake_maps.py` | Viewer meshes, texture maps, plate, collar, marble tile, environment, `viewer_scene.json` | moulds, cakestand, slab |
| 5 | `toppings3d.py` | Low-poly 3D toppings and sprinkle rod | toppings |
| 6 | `station.py` | Screen-space station panels, vessel sprites, `layout.json` | tools, cake\_maps |
| 7 | `transition.py` | Only if the oven-to-stand transfer does not already exist | oven, cakestand, slab |
| 8 | `focus.py` | Background frames and the camera path for the zoom-to-centre move | cake\_maps, station, transition |
| 9 | `export_assets.py` | HEIC or PNG, USDZ and map copies, merged manifest, size report | All |

Master script `scripts/build_assets.sh`: audit first, use `build_once` so existing files are skipped, run the steps above in order, then `export_assets.py --budget-mb 150`. Adapt each line to the real command line of the script Claude Code wrote. `export_assets.py` must fail if the total exceeds the budget and list what to trim first.

## 5. Prompts for the new asset scripts

Each prompt goes into `docs/prompts/<script>.md` and is the spec for one script. Every prompt ends with a stage list. Wherever it says "review", Claude Code looks at its own output, lists what is unrealistic compared with a real photograph, fixes it, writes `docs/review/<step>.md` and continues without waiting.

### 5.1 `icing.py` and `toppings.py` (short specs)

If `docs/prompts/icing.md` and `docs/prompts/toppings.md` already exist from the earlier design chat, use them. Otherwise use these.

```
icing.py: build the icing and ganache materials and the palette, reusing the existing
moulds and studio files (do not change them). Follow CLAUDE.md. No text or logos.
- Eight icing colours: ivory, rose, pistachio, chocolate, caramel, white, raspberry,
  blue-grey. Four ganaches: dark, milk, white, caramel. Each has base colour, roughness,
  specular and subsurface, with a soft sheen that reads as buttercream (icing) or glossy
  (ganache).
- Export palette.json with the colour values used by the app shader.
- Render a contact sheet of every material on a sphere and on a flat swatch under the
  studio lighting, and compare it with a real photograph.

toppings.py: build the topping models once and render small icon sprites only.
- Eight toppings for the HUD bowls: berries, mint, chocolate shavings, gold flakes,
  sprinkles, sugar pearls, crushed pistachio, flower petals. Real size in mm.
- Output one 256 px transparent icon per topping (bowl-style heap) with a soft shadow, and
  keep the models in toppings.blend for toppings3d.py. Do not build the ganache section
  here and do not render placement sprites.
Budget: 5 MB for the icons.
```

### 5.2 `tools.py` (the minimal tool kit)

Five tools plus toppings are enough for every cake to be unique, because uniqueness comes from combining free-form gestures, not from the number of tools.

| Tool | What it does in the app |
| --- | --- |
| Piping cone (round, star, petal tips) | Lays raised beads along the finger path: rings, rosettes, borders, swirls |
| Offset spatula | Spreads and smooths icing as the plate turns; the base coat |
| Pour (saucepan) | Pools ganache or glaze with a drip edge |
| Drizzle (squeeze bottle) | Thin lines and zigzags |
| Dust (sieve) | Soft cocoa or sugar powder |

```
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
```

### 5.3 `cake_maps.py` (live viewer meshes and maps)

```
Write scripts/blender/cake_maps.py that exports everything the live 3D cake viewer needs,
from the existing moulds, cake stand and slab assets. Follow CLAUDE.md. No text, logos or
brand marks. Audit the existing .blend files first and report mismatches instead of
changing them. Do not rebuild the cakes, the plate or the slab.

EXPORTS (per dish: cupcake and cake; per bake state: raw, half, golden, dark; the cupcake
dish exports ONE hero cupcake unless DECISIONS.md says otherwise; golden first)
- Mesh: a clean, low-poly cake mesh with an even polar grid on the top face (128 rings x
  256 segments) and a cylinder grid on the side (64 rows x 256 segments), so icing
  displacement works. UVs: top = polar (radius, angle), side = (angle, height). For the
  cupcake: the sponge dome, the liner as a separate mesh, and a flat-ish crown region for icing.
- Texture maps, 1024 x 1024 (the side strip 1024 x 512): base colour (albedo, with NO baked
  lighting or shadows), roughness, tangent-space normal, ambient occlusion. One set per state.
  Bake them from the high-detail Blender cake with Cycles baking, and verify the seams.
- A height map of the bare crumb surface (16-bit, with the mm range recorded).
- Units: metres. Origin at the centre of the base. Z up. Sizes match the oven tray and the stand.

PLATE AND COLLAR
- Marble plate: disc mesh and PBR maps (albedo, roughness, normal) with polar UVs, rotation
  axis Z at the exact centre, veins visible so the rotation reads clearly.
- Brass collar ring: mesh and PBR maps. It is the tap target that starts and stops the spin.
- A seamless, tileable honed marble texture (2048, PBR) for the surface under the plate.

LIGHTING AND CAMERA METADATA (so the live scene matches the Blender look)
- A small environment map (equirectangular HDR, 512 x 256) baked from the studio.blend world.
- viewer_scene.json: key light direction, colour and intensity; exposure and colour-management
  settings; the stage_wide camera intrinsics and extrinsics from camera.json; the top-down,
  angle (about 55 degrees) and side (about 10 degrees) cameras; units and dimensions.

CHECKS
- For each state, render a Blender preview using ONLY the exported meshes and maps with a plain
  Principled shader and the exported environment, and compare it with the original Blender
  render. Report the error and fix visible seams or map mistakes.
- Confirm the polar UV seam is invisible and the side strip is seamless left to right.

OUTPUT AND BUDGET
- renders/viewer/<dish>_<state>/ with mesh.usdz, albedo.png, roughness.png, normal.png, ao.png
  and height.png; plus plate/, collar/, marble_tile/, env.hdr, viewer_scene.json and
  viewer_manifest.json.
- Budget 45 MB for all viewer assets including toppings3d. If over: 512 maps for the side strip
  and AO, pack roughness and AO into one map, share maps between states where identical,
  compress. Report the sizes.

STAGES (review after each, no waiting)
 1 Meshes and UV layout (clay)  2 Bake albedo, normal, AO and roughness for one state
 3 All states  4 Plate, collar, marble tile, environment and metadata
 5 Preview-versus-original checks  6 Size report
After each stage, LOOK at the output, list what is unrealistic or wrong compared with the
original Blender render, fix it, then continue.
```

### 5.4 `toppings3d.py` (3D toppings)

```
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
```

### 5.5 `station.py` (the decorating station)

The station is a pastry chef's mise en place on honed marble with brass rails and recessed seats. Everything has a place, in ordered rows, symmetrical about the turntable, and nothing hides in a menu.

| Zone | Items | Tap behaviour |
| --- | --- | --- |
| Ingredient shelf (top) | Eight icing pots, four ganache pots, a nozzle tray (round, star, petal) | Tap a pot to load that colour or ganache into the active tool. Tap a nozzle to mount it. The chosen item lifts and glows brass. |
| Turntable (centre) | The live cake and plate inside a brass collar ring | Drag on the cake to apply the active tool. Tap the brass ring to start or stop the rotation. |
| Toppings shelf (bottom, upper row) | Eight bowls, scrolling for more | Tap a bowl, then tap the cake to place it. |
| Tool rail (bottom, lower row) | Cone, spatula, pour pan, drizzle bottle, sieve, each in a brass cradle | Tap to pick a tool up; its sprite follows the finger. |
| Controls | Undo, clear, turntable speed, plate and backdrop, brass Serve button | Tap. |
| Break clock | A ring timer | Display only. |

Layout rules: an even grid grouped by kind; every tap target at least 44 points; labels are drawn by the app, never baked into art; light from the top-left so shadows fall to the bottom-right; a selected item lifts about 6 percent and glows brass; a slim strip shows the current tool, colour, nozzle and topping. When the focus move ends the shelf, rail and controls slide into their seats in that order over about 0.6 seconds (Reduce Motion: a fade).

```
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
```

### 5.6 `transition.py` (only if it does not already exist)

Check `docs/existing_state.md`. If the tray, spatula, carry and settle sequences from the oven to the cake stand already exist, skip this script.

```
Write scripts/blender/transition.py: the sequence in which the baked cake leaves the oven
tray, is lifted by a spatula, carried to the turntable stand and settles on the plate, with
the camera easing from the oven view to the stand view and the cloche already lifted away.
Reuse oven.blend, cakestand.blend, slab.blend and moulds_<state>.blend; do not rebuild them.
Layered transparent frames (--dish cupcake|cake, --state golden), 20 fps, ease-in-out, with
Holdout so occlusion is baked in. Write the final cake screen position and scale to the
manifest so the live viewer can cross-fade from it. Verify with tools/composite_check.py.
Review after each stage and continue without waiting.
```

### 5.7 `focus.py` (background frames and camera path)

The cake and plate are not rendered here. The live viewer shows them and performs the move itself.

```
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
```

## 6. App phases for decorating

Every phase ends with the same check: the project builds with `xcodebuild`, the tests pass, simulator screenshots of the new work are saved to `docs/review/`, what could not be checked without a real device goes on the "needs the human" list, the asset size is reported, and the work is committed. Then the next phase starts. Hour figures are estimates of hands-on time.

**New Swift folder** inside the existing project, beside the baking code:

```
Viewer3D/   CakeViewerView.swift, CameraRig.swift, SurfaceMapper.swift,
            HeightFieldRenderer.swift, ToppingInstances.swift, Shaders.metal
Decorate/   StationView.swift, ToolBelt.swift, TurntableEngine.swift, ToolEngine.swift, DecorOp.swift
Resources/  viewer/ (meshes, maps, toppings), station/, focus/
Tests/      SurfaceMapperTests, ReplayTests, TurntableTests
docs/       existing_state.md, viewer_decision.md, review/
```

### Phase D0: Audit and hook (3–6 h)

- Read the existing app and write `docs/existing_state.md`: the phase engine, the point where a finished bake ends, the asset loader and manifest, the fold service.
- Add a decorating phase entry point after "ready" with a code-drawn placeholder screen (a flat cylinder cake and plain panels), so the whole bake-to-decorate-to-serve path runs before any new asset exists.
- Extend the existing asset manifest for the new decorating entries instead of creating a second loader.
- Done when: the app builds, the bake still works unchanged, and finishing a bake opens the placeholder decorating screen.

### Phase D1: Viewer technology spike (8–12 h)

- Build the same minimal scene in RealityKit (custom material and geometry modifier) and in a small custom Metal renderer: plate and cake meshes, normal and AO maps, the environment, a displaced height field, and one topping instance.
- Compare displacement quality, frame rate and heat (on the simulator, flagged for a real-device recheck), code size and testability. Write `docs/viewer_decision.md` and take the better option.
- Done when: the decision is written with the measured numbers and the winning prototype builds.

### Phase D2: Viewer shell (10–16 h)

- Load meshes and maps from `viewer_manifest.json`: plate with collar, the cake in the current bake state, the marble surface, the environment. Placeholder geometry until the real files arrive.
- Camera rig with Top, Angle and Side snaps, two-finger tilt and pinch zoom. Reduce Motion snaps instead of animating. VoiceOver labels on every control.
- Done when: the cake can be viewed from top to side on iPhone and Duo simulators.

### Phase D3: Focus move and station (12–18 h)

- Replay the exported camera path from the stage view to top-down, with the background frames and a cross-fade from the pre-rendered cake to the live cake. Forward and reverse.
- Build `StationView` and `ToolBelt` from `layout.json` for iPhone and Duo flat. Seat positions and tap radii come from the file, never hard-coded. Scrolling groups snap to the grid with haptic ticks. The station unfolds in about 0.6 seconds when the move ends.
- Done when: the move lands on the top-down view and the station appears around it without a visible jump.

### Phase D4: Surface mapping and turntable (8–12 h)

- Ray from the finger to the top disc or the side cylinder, giving plate-local coordinates and back, with unit tests.
- Turntable: the brass collar ring starts and stops rotation with eased motion and a speed setting. A fixed fingertip lays a ring.
- Done when: tests pass and a held finger draws a clean circle on the top and a clean band on the side.

### Phase D5: Height fields, tools and toppings (24–36 h, the largest)

- Stamp the brush maps into the top and side height fields, displace the mesh, compute normals, light with the live shader, and tint with the palette.
- Tools: piping cone with three tips, spatula smoothing, pour, drizzle, dust. One tap on the station picks a tool, a colour pot, a nozzle or a topping bowl.
- Toppings: 3D models placed by hit point and normal with a spring drop; instanced sprinkles; plate and backdrop choices.
- Start with one tool, tune the shader against the reference renders in `renders/tools/reference/`, then add the rest.
- Done when: the live look is close to the Blender references and the same icing is visible on the top edge and the side wall.

### Phase D6: Flow, performance and serve (12–20 h)

- Break timer, auto-serve, undo and clear, operation persistence (including surface and side height), time-lapse replay.
- Performance: a smooth frame rate on a recent iPhone (measure on the simulator, flag for a real-device check), a thermal check, and a lower-resolution fallback without displacement.
- Serve: hand the finished cake to the existing serve flow (cloche, share card, recipe book) if it exists; if not, a simple served screen with a share image.
- Done when: a first-time tester can make a unique cake in under five minutes without help, a replay reproduces the cake exactly, and the cake can be decorated from at least three camera views.

**Total:** about 77–120 hours of hands-on work for the app side, plus the Blender asset steps in section 4. The D5 and D1 figures are the least certain, so re-estimate after the spike.

## 7. Running it unattended, quality gates and risks

**Start prompt for Claude Code**

```
Read CLAUDE.md, docs/BUILD_PLAN.md and docs/PROGRESS.md. Baking is already built: do not
rebuild any asset or workflow listed in section 2. Audit the existing app and Blender files
first (Phase D0 and verify_assets.py), then work in this order: icing, toppings, tools,
cake_maps, toppings3d, station, transition (only if missing), focus, then Phases D1 to D6.
Never wait for me. Log decisions in docs/DECISIONS.md, reviews in docs/review/, and progress
in docs/PROGRESS.md. Write ALL PHASES DONE there when finished or blocked.
```

**Loop** (each run starts fresh and continues from `PROGRESS.md`; the cap stops a bug from looping forever):

```bash
for i in $(seq 1 15); do
  grep -q "ALL PHASES DONE" docs/PROGRESS.md && break
  claude -p "Read CLAUDE.md and docs/PROGRESS.md, then continue. Write ALL PHASES DONE when finished or blocked." \
    --dangerously-skip-permissions --max-turns 200
  git add -A && git commit -qm "loop checkpoint" || true
done
```

Run it only inside the project folder, in a git repo, and ideally on a spare user account, because the flag lets Claude run any command.

**Quality gates**

| Check | What it covers | Who |
| --- | --- | --- |
| Build and unit tests | `xcodebuild` passes; surface mapping, replay determinism, side-strip seam, turntable | Claude Code |
| Existing flow regression | The bake still works exactly as before | Claude Code |
| Preview versus original | Every exported mesh and map set matches the Blender render, with the error reported | Claude Code |
| Composite check | Stacked background frames match a full render | Claude Code |
| Naming and art rules | Required object names; no text, logos or brand marks | Claude Code |
| Size report | Each group against its budget, total against 150 MB | Claude Code |
| Simulator screenshots | Each new screen on iPhone and Duo, in the Top, Angle and Side cameras | Claude Code shows |
| Real iPhone checklist | Touch feel, frame rate, a 10-minute thermal check, tilt reflections | You |
| Look approval | Realism and taste compared with a real photograph | You |
| Accessibility | VoiceOver, Reduce Motion, Dynamic Type, 44-point targets | Claude Code and you |

**Risks**

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Claude Code rebuilds something that already exists | Medium | Rule 1 and 2, the audit file, and a regression check on the bake |
| The live displacement shader looks less rich than the Blender references | Medium | The D1 spike, tuned normal and AO maps, a lower-resolution fallback |
| Heat and frame rate on a real iPhone over long sessions | Medium | Adjustable mesh and map sizes; real-device check on your list |
| Premium realism is hard to reach by script | High | Self-review at each stage, your look approval at the end |
| Assets exceed the size budget | Medium | Budgets per group, ordered trimming, golden state first |
| On a horizontally folded Duo the centred cake sits on the crease | Medium | Render the 0.08 offset variant and choose after simulator testing |
| The side decorating strip shows a seam | Low | Seam unit test and preview check |
| The oven-to-stand hand-off does not join cleanly | Medium | Audited in D0; cross-fade from the transition manifest |

**Needs the human** (Claude Code logs these and carries on): real-device frame rate and heat, touch feel, the look approval, the Duo centre offset choice, and confirming the viewer technology on a real iPhone after the spike.
