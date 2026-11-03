# Viewer technology decision (Phase D1 spike, 2026-11-03)

**Decision: RealityKit** (`RealityView` with a virtual camera, `LowLevelMesh` for the icing, `PhysicallyBasedMaterial`), iOS 18+. SceneKit is not used.

## The spike

DEBUG builds only, launched with `-viewerSpike metal` or `-viewerSpike realitykit` (`Features/Viewer3D/Spike/ViewerSpike.swift`). Both draw the same demo cake, built with the same ops and the same `ViewerMesh.icingTop` grid (121 × 385 = 46.6k vertices, 92k triangles). Both rebuild and re-upload the icing mesh **every frame** to stress the update path, while the plate turns.

| Measure (iPhone 17 simulator, Debug, `Decorating` built -O) | RealityKit | Custom Metal |
| --- | --- | --- |
| Frame time, median / p95 | 16.67 / 17.26 ms (60 fps, vsync) | 16.67 / 17.26 ms (60 fps, vsync) |
| Re-mesh + upload per frame, median | 3.07 ms | 2.81 ms |
| Lighting | PBR, image-based light, directional shadow, clear coat, sheen, cut-out | One Lambert light (everything else would be hand-written) |
| Textures and toppings | Baked maps, dynamic icing texture, USDZ toppings with no extra code | Loaders, samplers, a USDZ parser and instancing all to write |
| Code (spike) | about 250 lines (`ViewerScene`) | about 150 lines for one unlit-ish mesh |
| Testability | Mesh and field logic stay in pure `Decorating` (unit-tested). Rendering is thin | The same, plus shader code with no tests |

Screenshots: `docs/review/d1_spike_realitykit.png`, `docs/review/d1_spike_metal.png`.

## Why

- Frame rate and update cost are equal within measurement noise. The re-mesh cost is dominated by the shared Swift code, not the renderer.
- RealityKit already gives the look the Blender references need: PBR, IBL from the exported `env.hdr`, and shadows. Matching it in Metal would mean writing a PBR renderer.
- Displacement comes from CPU-written `LowLevelMesh` vertices in both cases, so neither renderer has a quality edge. Fine relief can later come from a normal texture built from the field (D5) without changing the technology.

## Risks and follow-ups

- **Needs the human:** frame rate and heat on a real iPhone with the spike (`-viewerSpike realitykit`). The simulator caps at 60 fps and has no thermal throttling.
- If a real device misses its frame budget, the icing grid can drop from 384 to 256 segments (a one-line change in `ViewerMesh`). The lower-resolution fallback without displacement is planned in D6.
