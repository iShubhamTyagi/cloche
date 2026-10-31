# Decisions log

Choices made during the build that the PRD or design handoff don't settle. Newest first.

| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-31 | The bake timer keeps running during the 15 s grace; if the grace expires, doneness is measured at the moment the door opened | The PRD says a short open changes nothing and a long one ends the bake half-baked "at time baked"; counting the open seconds as baking makes the first true and the second fair |
| 2026-10-31 | If the timer runs out during the grace, the bake counts as fully baked | No guilt: the player didn't cut the bake short, the clock simply finished |
| 2026-10-31 | A half-baked dish always shows Pale browning | Matches the handoff's S2 8 board ("Pale" at 62%); temperature browning only applies to finished bakes |
| 2026-10-31 | A finished bake is revealed only when the door is fully open; a Duo opened partway stays in Ready | Handoff Duo 4: "Lift the lid to open the door". Prevents a reveal from a slight wobble of the hinge |
| 2026-10-31 | Demo bake: 15 s bake, 60 s break, no stars | The PRD fixes 15 s and no stars but not the break; 60 s lets a reviewer see the decorating flow end by itself |
| 2026-10-31 | The engine uses stored wall-clock dates; the handoff's proposed monotonic-clock check is deferred | Keeps 1.2 pure and fully testable. Revisit before TestFlight; it needs `systemUptime`, which means adding reason 35F9.1 to the privacy manifest |
| 2026-10-31 | `SessionEngine` is a pure value type: callers pass `now`, and it returns effects (notifications, cues) instead of doing I/O | Single responsibility and full testability without devices or waiting. Its state is `Codable`, so force-quit recovery is just save and restore |
| 2026-10-31 | Fonts are bundled in the `DesignSystem` package and registered with CoreText the first time a text style is used, not listed in the app's Info.plist | Previews and package tests get the real fonts too, and no launch-time call can be forgotten. If a font is missing, text falls back to system sans or New York instead of crashing |
| 2026-10-31 | The Instrument Sans italic file is not bundled | The design never uses sans italic; it would add about 200 KB |
| 2026-10-31 | Dynamic Type is capped at `xxxLarge` at the app root | The handoff asks for about 130%; `xxxLarge` is the nearest step (about 135%). Numerals, hero lines and headlines use fixed sizes and don't scale at all |
| 2026-10-31 | Line heights are approximated: the extra line spacing is the design line height minus 1.2 × the font size | SwiftUI has no direct line-height setting; single-line text is unaffected, and multi-line body text matches the 15/22 spec closely |
| 2026-10-31 | Empty stars are drawn as `color-subtle` outlines | The handoff says "empty outline" without a colour; subtle keeps 4.9:1 or better contrast, and filled versus outline means the state never relies on colour alone |
| 2026-10-31 | `RingClock` was built in slice 1.1 instead of 1.6 | It is a shared component (break clock and ajar countdown); doing it with the rest of the design system keeps 1.6 small |
| 2026-10-31 | The component gallery is compiled only into debug builds and opened with the `-componentGallery` launch argument | Gives a quick on-device check against the canvas without shipping a hidden feature (Guideline 2.5.19) |
| 2026-10-31 | CLI derived data lives in `~/Library/Developer/Xcode/DerivedData/PocketOven-cli`, outside the repo | Xcode 27.2 can't load hostless package test bundles from a path containing a space ("My Dev"); verified by running the same tests from a path without spaces |
| 2026-10-31 | `test.sh` runs the package's unit tests through the `PocketOvenKit` scheme, then the app's UI tests | Package testables added to the app scheme were silently skipped |
| 2026-10-31 | Scripts open `DeviceHub.app` | Xcode 27 replaced Simulator.app with DeviceHub |
| 2026-10-31 | Primary App Store category is **Games › Casual**; Productivity is secondary | Lowers the risk of a Guideline 4.3(b) "simple timer" rejection; the decorating game and collection are the product |
| 2026-10-31 | Bundle ID `com.shubhamtyagi.pocketoven` | Placeholder until the App Store Connect record exists; change before the first archive if needed |
| 2026-10-31 | The time protocol is `TimeProviding`, not `Clock` | `Clock` clashes with the Swift standard library |
| 2026-10-31 | Portrait only on iPhone | The design covers portrait only; Duo landscape is reference-only |
| 2026-10-31 | Xcode project uses folder-synchronized groups; all logic lives in the local `PocketOvenKit` package | New files need no project edits; module boundaries enforce the dependency rules in CLAUDE.md |
