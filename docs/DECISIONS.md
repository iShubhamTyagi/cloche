# Decisions log

Choices made during the build that the PRD or design handoff don't settle. Newest first.

| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-31 | Prep shows no recipe book or settings icons, recipe circles or work label yet | Guideline 2.1: no dead buttons. Each arrives with its feature (2.1, 2.6, 2.10, 3.4); Gate 0 is one hard-coded cupcake |
| 2026-10-31 | Preheat leaves out "Close the door another way" for now | It opens the honor door (DR-10, P1), which isn't built yet |
| 2026-10-31 | The session is saved as JSON in Application Support after every event | Force-quit recovery (BK-1). A file keeps the privacy manifest free of extra required-reason APIs; file protection is "until first unlock" so a bake can finish while the phone is locked |
| 2026-10-31 | `SessionController` runs a single timer task to the engine's next deadline and catches up on returning to the foreground | No ticking counter: the engine's dates are the truth, and the timer only wakes it |
| 2026-10-31 | Phases without screens yet (baking to served) show a plain stand-in with the right actions | Lets the whole loop be walked through in the simulator now; each is replaced in 1.5 to 1.7 and 2.3, before TestFlight |
| 2026-10-31 | Copy depends on the door source: "Then close the phone" and "Waiting for the fold" on a Duo; face-down wording elsewhere | Matches the Duo boards and DR-1 without a second screen |
| 2026-10-31 | The debug door readout collapses to a chip in the top-right corner | When always open it covered the Preheat button, which a UI test caught |
| 2026-10-31 | UI tests launch with `-freshSession` (in-memory store) | Saved sessions would otherwise carry over between test runs |
| 2026-10-31 | The hinge is read with UIKit's `UIHingeInteraction` on an invisible anchor view, not with a SwiftUI modifier | The iOS 27.2 SDK headers show `UIHingeInteraction` (status plus angle, hinge nil without one). No SwiftUI hinge API was found in the SwiftUI interface, so the UIKit API is the one verified to exist |
| 2026-10-31 | `FoldStateService` is `@MainActor` | Both real sensors (UIKit and Core Motion) deliver on the main thread, and the session coordinator lives there too; this avoids unsafe crossings between actors |
| 2026-10-31 | Face-down closes at gravity z ≥ 0.92 (within about 23° of flat) held for 0.8 s, and opens below 0.80 | Requires a flat surface as the PRD asks, ignores small wobbles while closed (hysteresis), and rejects tilted books and sofas. Tune on a real iPhone at Gate 0 |
| 2026-10-31 | Face-down uses Core Motion device motion (gravity), which needs no permission prompt or usage string | Only motion activity, pedometer and altimeter APIs need permission; keeps first launch free of prompts |
| 2026-10-31 | Motion sensors run only while face-down is the active door source | Battery (Guideline 2.4.2) |
| 2026-10-31 | Door mode preference has two values for now: Automatic and Face-down | DR-8 only needs Duo owners to choose face-down; covered and honor door join in P1 |
| 2026-10-31 | Debug builds have a door readout (`-doorDebug`) with manual Closed/Ajar/Open buttons, and the hinge sensor logs each reading at notice level | The simulator has no motion sensors and the Duo posture can't be scripted; this is how Gate 0 records what the hinge reports |
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
