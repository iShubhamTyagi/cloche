# Existing state (decorating plan, Phase D0 audit, 2026-11-03)

What already exists and is reused as it is. The `.blend` object-level audit is in `docs/asset_status.md`.

## App

| Piece | Where | Notes for decorating |
| --- | --- | --- |
| Phase engine | `Domain/SessionEngine.swift` | Phases `idle → armed → baking ⇄ ajar → ready → graded → decorating(outcome, breakEndsAt) → served`. Event `.decorate` from `graded` starts the break; `.serveNow` serves decorated. The break end is a stored date. |
| Where a bake ends | `graded(BakeOutcome)` → `GradeScreen` (Decorate / Serve plain) | Decorating plugs in at `.decorating`, already routed in `Features/Session/SessionRootView.swift` to `DecorateScreen`. |
| Decorate shell | `Features/Decorate/DecorateScreen.swift` | Header (recipe, "Finishing table", Serve now), `StationMoveView` in the oven slot, break `RingClock` below. **The hook:** once the dish has settled on the stand, the decorating viewer and station take over this screen. |
| Oven → stand transfer | `StationMoveView.swift`, `TongsView.swift`, `RenderedStation.swift` | Tongs lift the rendered dish out of the oven, pan to the stand, set it down, cloche lifts. This **is** the plan's `transition.py` step, so that script is skipped. Its final state (dish on the stand, cloche lifted) is the start of the focus move. |
| Asset loader / manifests | `RenderedOven` reads `OvenRender/oven_layout.json`; `RenderedStation` reads `StationRender/station_layout.json` (`StationRenderLayout.shared`), all from `Bundle.module` | Generated, gitignored folders written by `scripts/blender/*_export.py`. Decorating adds one more generated folder, `Resources/DecorRender/`, with a merged `decor_manifest.json`, read the same way (`Bundle.module`, `static let shared`, nil → code-drawn placeholder). |
| Fold / device | `DoorSensing` (`FoldStateService`), `FoldEnvironment.swift` (`hingeDoorAngle`, cover layout), `OvenStage` | The station layout reads only the window size (iPhone vs Duo flat). Nothing sits on the fold band. |
| Dish model | `Art/Dish.swift`, `Domain/Recipe.swift`, `Domain/Bake.swift` (`BakeOutcome`, doneness), `Grade` (browning) | Dish (cupcake vs cake) and bake state come from these. |
| Serve | `.serveNow` → `served(outcome, grade)` → `InterimPhaseView` | No recipe book or share card yet (Phase 2.x). D6 adds a served screen with a share image. |

## Blender

| Asset | File | Reused by |
| --- | --- | --- |
| Studio, lights, cameras | `build/studio.blend`, `build/camera.json` (`station`, `plate_topdown`, `stage`, `topdown`) | every new script via `studio.use()` |
| Cupcake and cake, four states | `build/muffin_tin_<state>.blend`, `build/cake_tin_<state>.blend`, `build/cake_turnout.blend` | `cake_maps.py` |
| Stand, plate, ring, switch | `build/cakestand.blend` (`TurntablePlate`, `BearingRing`, …) | `cake_maps.py`, `station.py` |
| Cloche | `build/cloche.blend` | not needed (lifted away before decorating) |
| Slab, marble | `build/slab.blend`, `common.marble_material()` | `cake_maps.py` (marble tile), `station.py`, `focus.py` |
| Oven | `build/oven.blend`, door frames | `focus.py` (background only) |

## Gaps the plan fills

Icing, toppings, tools, viewer meshes and maps, 3D toppings, station panels, the focus move, and the decorating screen itself.
