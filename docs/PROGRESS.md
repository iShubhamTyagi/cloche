# Progress log

Read the **Current state** first; it says where the next session starts. Then add an entry under **Log** (newest first) each time a slice is finished. Decisions and their reasoning go in `DECISIONS.md`, not here.

## Current state

- **Phase:** Phase 2 on branch `phase-2-gate1`. The Live Activity (Phase 3.2, Watch Layer A) was brought forward on 2026-11-01. Owner-requested Prep rework done (see the 2026-11-01 entry). Next is Phase 2.1 (Recipes.json, recipe picker with locked state). The temperature hint is gone, and the picker must fit "each length bakes its own dish"
- **Tests:** switched off until a stable dev build (owner's call). Verify by running in the simulator and checking screenshots
- **Last green commit:** see the newest log entry; `main` is pushed to github.com/iShubhamTyagi/cloche
- **Blockers:** Apple Developer Program not enrolled (needed by the end of Phase 2 for TestFlight)
- **Simulators:** iPhone 17, 17e, Air, 18 Pro, 18 Pro Max and iPhone Duo on iOS 27.2; iPhone 16 set and SE on iOS 18.2 (minimum-version check); watchOS 27.2 (Series 12, Ultra 4, SE 3), with the Ultra 4 paired to iPhone 17. iOS 17 and older watchOS runtimes removed
- **Gate 0 facts so far:**
  - The Duo hinge reports in the simulator: unfolded is `fullyOpen`, angle `3.141593`, so the angle is in radians and flat open is π.
  - iPhones without a hinge get no hinge update at all, rather than an update with no hinge.
  - The Duo cover display is portrait, 1398 × 2034 px (about 466 × 678 pt), not the handoff's assumed 500 × 400 landscape.
  - XCUITest screenshots on the Duo simulator are black. To see the folded cover, use `xcrun simctl io "iPhone Duo" screenshot --display=primary` (`primary` is the cover, `primary-1` the inner screen).
  - Slow close in the simulator: `fullyOpen` (π) → one `partiallyOpen` reading at 2.82 rad (about 162°) → `closed` (0). A real Duo will likely report more steps; partly open always maps to ajar, never closed.
  - Still open: readings during a slow close and open on a real Duo (needs folding by hand in DeviceHub, then `xcrun simctl spawn <Duo> log show --last 5m --predicate 'subsystem == "com.shubhamtyagi.cloche"'`); face-down on a real iPhone on three surfaces.
- **Known for Phase 1:** the Duo simulator boots folded, showing the cover display (1398 × 2034 px). The system reserves a strip down the cover's right edge, so centred content sits left of centre; cover screens need the reserved-region APIs. `simctl io screenshot` needs `--display=1` on the Duo.

## Log

### 2026-11-01: The bake's Live Activity, mirrored to the Apple Watch (uncommitted)

- **Built:** Phase 3.2's Live Activity, brought forward at the owner's request. A widget extension target `ClocheWidgets` (folder `Widgets/`, embedded in the app) draws `BakeLiveActivity` from the new package product `BakeActivityUI`; the shared model `BakeActivityAttributes` lives in the new `BakeActivity` target. `ActivityKitBakeActivity` (Services) starts the activity when a bake starts (the door first shuts), updates it for door ajar, shut again and ready, and ends it once the bake is out of the oven; `SessionController` calls it after every event. The views: the time left counting down by itself from the stored end time (`Text(timerInterval:)`), one word for the state and a hairline of progress, ivory on black. The Watch gets the `.small` family in its Smart Stack (Always-On dims it and drops the progress line); the lock screen and Dynamic Island get the same content. App Info.plist: `NSSupportsLiveActivities`.
- **Verified:** build green. A throwaway UI test on iPhone 17 (paired with the Apple Watch Ultra 4 simulator; removed afterwards, UI tests switched off again) ran a 15 s demo bake: the log shows the activity started when the door shut, updated to ready and ended at the grade, and the widget renderer subscribed to it.
- **Seen by the owner:** the activity mirrors to the paired Apple Watch Ultra 4 simulator during a bake started on the iPhone 17 simulator. (`simctl io screenshot` doesn't capture the Watch Smart Stack or the Dynamic Island, so it was checked by eye in DeviceHub.) Still to check on a real iPhone and Watch.
- **Left over:** the UI tests' fresh sessions skip the Live Activity unless launched with `-liveActivity`.

### 2026-11-01: The oven is one full-half slot, ready for the 3D asset (uncommitted)

- **Built:** `OvenFrame`, a minimal placeholder oven with no aspect ratio of its own: a black body, a glass door hinged on its bottom edge (handle across the top, two hinge tabs at the bottom, `doorOpen` drops it), and a slim control column with a small timer display and two knobs. The door takes nearly all the space. (A first pass with only a thin rim hid the oven's exterior; the owner asked for the body back.) The door has one fixed size, 520 × 348 pt (`OvenFrame.doorSize`), on both the open screen and the cover, and both keep the same header and caption bands, so on the Duo the interior is the same size folded and unfolded; the black body takes up the difference. Smaller screens (iPhone 17) shrink the door. `OvenStage` gives it the whole top half of the open screen, edge to edge, with the header laid over a top band; `CoverStage` gives it the whole folded cover, with the caption laid over its bottom. `CoverOvenFront` is gone, and Prep's glow behind the oven was removed (the oven now covers it).
- **Verified:** build green; screenshots of Prep on iPhone 17 and of the folded Duo cover (`--display=primary`, turned as held). On the cover the door measures 520 pt wide. The open Duo top half (669 × 475 pt) has room for the same door by arithmetic; not seen on screen, because the simulator stayed folded.
- **Then:** the unfolded Duo's ajar and grade screens (`DuoAjarScreen`, `DuoGradeScreen`) drew the cavity full-bleed across the top half, so the dish jumped in size on unfolding. Both now put `OvenFrame` (with `showsDoor: false`, since the door lies on the bottom half) in `OvenStage`'s top slot, with the door panel full width below (`isContentFullBleed`). Measured on the Duo simulator: door 519 pt wide on the cover and 518 pt open; cupcakes 98 pt and 97 pt.
- **Left over:** on the iPhone (not Duo), Preheat, Ajar and Reveal still use the older `OvenView` (door-drop animation) in their own layouts. The 3D asset has to fill two shapes: about 402 × 437 pt portrait on the open screen and 678 × 466 pt landscape on the cover, keeping the top 60 pt (header) and bottom 40 pt (caption) quiet.

### 2026-11-01: Every state has a folded cover screen (uncommitted)

- **Built:** `CoverPhaseScreen` and `CoverMessageScreen`; `SessionRootView` picks the cover for every phase while the hinge reports closed, and otherwise the open-screen layout (`phaseScreen`).
- **Verified:** build green. All nine phases rendered at the cover's 466 × 678 and turned as held (throwaway render, not kept). Live on the folded Duo simulator, a half-baked grade (the state the owner reported) shows the upright oven front.
- **Left over:** the debug door readout still draws unrotated on the cover (debug builds only).

### 2026-11-01: Leaving the app mid-bake opens the oven (uncommitted)

- **Built:** `AppAwayMonitor` (scene phase plus lock detection) drives `AdaptiveDoorSensor.isAppAway`; `SessionEngine` cancels the ready notification when the door opens mid-bake and reschedules it when it shuts.
- **Verified:** build green; throwaway UI tests on iPhone 17 (not kept; UI tests switched off again): Home for 3 s then back → door ajar, "Close the door" resumes; Home for 20 s → graded "Opened early". Both passed.
- **Not verified:** the lock exception (needs a passcode; check on a real device); the engine notification change has no unit test (tests are off).

### 2026-11-01: Start a bake without turning the phone over (uncommitted)

- **Built:** `ManualDoorButton`; "Start without turning over" on Preheat (face-down only), a dim "Open the oven" on the face-down bake screen and "Close the door" on the ajar screen while the door is worked by hand; `SessionRootView` sets and releases `AdaptiveDoorSensor.manualOverride`.
- **Verified:** build green; a throwaway UI test on iPhone 17 (not kept; the scheme's UI tests are switched off again) went Bake → Start without turning over → baking → Open the oven → door ajar → Close the door → baking, with screenshots of each step.

### 2026-11-01: Duo cover shows the oven front in the open screen's place (uncommitted)

- **Built:** `CoverOvenFront` (board Duo 3: handle, glass door with the dish, display and three knobs) at the open-screen oven's 1.4 aspect, placed by `OvenStage` on `CoverBakeScreen` (baking, ready) and `CoverIdleScreen` (folded before a bake); `CoverCaption` for the line and progress below. Cupcakes on the rack are a little larger everywhere.
- **Verified:** build green; on the folded iPhone Duo simulator, a screenshot of the cover (`simctl io screenshot --display=primary`; `primary` is the cover, `primary-1` the inner screen) shows the oven upright and wide in the top half with the caption below.
- **Learned:** the cover panel draws in portrait but is mounted sideways; folded, the panel's top edge is on the viewer's left (seen in the owner's DeviceHub screenshot). `CoverDisplay` lays the cover out landscape and turns it a fixed quarter clockwise; the reported device orientation flips between launches, so it isn't used. To view a cover screenshot as held: `sips -r 270`.
- **Then:** the status bar is hidden app-wide and the Prep header moves up into the freed band (checked by screenshot on iPhone 17 and the Duo's inner screen).
- **Left over:** the Duo ajar and grade screens still use their older layouts; on a real Duo, confirm which way the cover panel is mounted.

### 2026-11-01: Duo cover shows the oven from outside

- **Built:** `OvenStage`, the shared half-and-half layout used by `PrepScreen`, `CoverBakeScreen` (rebuilt: dish baking behind the glass, timer below, ready glow) and the new `CoverIdleScreen` (folded on Prep). The length choice now lives in `SessionRootView`, so it survives a fold.
- **Verified:** build green on iPhone Duo and iPhone 17; installed on both. Inner Prep (669 × 951) and the cover idle, baking and ready screens (466 × 678) checked through a throwaway `ImageRenderer` render (not kept): the oven is the same width on both screens and sits in the top half.
- **Left over:** the cover's reserved strip on the right edge still isn't accounted for; the Duo's ajar and grade screens still use their older layouts.

### 2026-11-01: Prep rework: Bake button, bake lengths, dish per length, splash

- **Built:**
  - `BakeLength` (Quick 25, Medium 50, Long 90; breaks 5, 8, 10) replaces `Temperature`. `Recipe` drops `bakeMinutes` and `idealTemperature`. The grade drops the temperature star, so the maximum is 2 stars; `Stars` shows two
  - `BakeLengthPicker` replaces `TemperaturePicker`; the Prep button reads "Bake · N min"; the Preheat eyebrow reads "Ready to bake"; the browning bar is gone from the grade screens
  - Prep split in halves: `OvenView` with its door shut and clear glass in the top half, the dish and controls in the bottom. Each length loads its dish onto the rack with a slide (cupcakes, `CakeView` one tier, two tiers); `Dish`, `DishView` and `RackDishView` carry the dish through the ajar, reveal and grade screens
  - `SplashScreen`: 1 s, empty, on every cold launch
  - Tests switched off: `test.sh` gate (`RUN_TESTS=1` to run them), UI test target skipped in the scheme
- **Verified:** `build.sh` green on iPhone 17 (warnings as errors). Prep checked by screenshot on iPhone 17 with Quick and Long selected; the splash checked by screenshot. Portrait-only confirmed in the built Info.plist (it was already set). Before tests were switched off, the updated unit tests were green except four break tests still expecting 3 stars; those were fixed but not re-run.
- **Left over:** the Duo layout of Prep (it follows the iPhone layout for now); the PRD still describes temperature (DECISIONS supersedes it); the local folder is now `Desktop/My Dev/Cloche`.

### 2026-10-31: Renamed to Cloche; pushed to GitHub

- **Built:** the game is now Cloche everywhere: display name and wordmark, Xcode project, targets and scheme, `ClocheKit` package, bundle ID `com.shubhamtyagi.cloche`, logging subsystem, scripts, docs and the PRD and handoff file names. `origin` is github.com/iShubhamTyagi/cloche and `main` is pushed.
- **Verified:** on iPhone 17 and iPhone Duo, 81 of 81 unit tests and 8 of 8 UI tests; the Prep screen shows "Cloche".
- **Left over:** the local folder is still `Desktop/My Dev/PocketBakery`.

### 2026-10-31: Phase 1.8, notification, chime and demo bake (Gate 0 complete)

- **Built:**
  - `UserNotificationScheduler` (local only; generic text; Notification Centre only while in the foreground), `NotificationContent`
  - `AVSoundPlayer` (`.ambient`) and the synthesized `ready-chime.wav`; `FeedbackPlan` gains sounds; `SessionEffectRouter` now schedules and cancels notifications and plays the chime when Sounds is on
  - `AppSettings` (keep-awake, sounds, door mode, asked-for-notifications); a minimal `SettingsScreen` with the 15 s demo bake; the `NotificationPrePrompt` on the first Preheat
  - Demo labels on Preheat, the bake screen and the grade; door mode from Settings drives the sensor; keep-awake follows the setting
  - `FeatureDependencies` bundles what the screens need; `AppEnvironment` builds it
- **Verified:** on iPhone 17 and iPhone Duo, 81 of 81 unit tests (new: router notifications and the sound switch, notification text, settings defaults and persistence) and 8 of 8 UI tests. New UI tests: the whole loop through a real 15 s demo bake (Settings → demo → preheat → close → ready → open → reveal → 0 stars → serve), and the pre-prompt's "Not now" still preheating. Settings, pre-prompt and reveal screenshots checked.
- **Gate 0 status:** the close-and-reveal loop runs end to end in the simulator on iPhone and Duo. Still to settle on real devices: face-down on three surfaces, the cover screen staying live while shut, timer correctness through lock, call and force-quit, haptics and the chime.
- **Left over:** filming the Gate 0 clips (needs a device or a simulator recording); the dropped oven door is a little wider than the oven body (refine with the art in 2.2).

### 2026-10-31: Phase 1.7, reveal and grade

- **Built:**
  - `RevealScreen` (board 4): "Prêt.", the oven door dropping open (700 ms; a cross-fade under Reduce Motion), steam over the dish, "See how it turned out"
  - `GradeScreen` (boards 5 and S2 8): eyebrow, dish on plate, stars, voice line, doneness and browning bars, "Decorate · 5 min" and "Serve plain"
  - `DuoGradeScreen` (boards Duo 5 and Duo 6): cavity with steam on top; the grade inside the door's glass on the bottom half
  - `GradedFlow`, `SteamView`, `GradeCopy`, `DonenessBar`, `BrowningBar`; `DuoDoorPanel` now hosts content
  - Feedback: `FeedbackPlan` (cue → haptic and announcement), `UIKitHaptics`, `VoiceOverAnnouncer`, wired through `SessionEffectRouter`
- **Verified:** on iPhone 17 and iPhone Duo, 75 of 75 unit tests (new: feedback plan per cue, router; grade percent rounding and browning marker) and 6 of 6 UI tests. The half-baked UI test now checks "Opened early", "1 of 3 stars" and Serve plain moving on. Reveal, grade and both Duo grades were checked through `ImageRenderer`; the half-baked iPhone grade through a UI-test screenshot.
- **Fixed during the slice:**
  - Steam floated below the oven and stretched the layout; it now overlays the cavity.
  - The dropped door rendered as a band above the hinge; it now swings past vertical and lies below it.
  - `Grade` and `FeedbackPlan` needed public initializers for tests.
- **Left over:** a UI test of the full reveal needs the 15 s demo bake (1.8). Haptics need the real-device pass.

### 2026-10-31: Phase 1.6, door ajar

- **Built:**
  - `AjarScreen` (board S2 7): open oven at 38% behind a dark gradient, "Door ajar" pill, 190 pt ring counting 15 to 0, "Shut the door.", helper
  - `DuoAjarScreen` (board Duo 2): dimmed oven cavity with the countdown on the top half; the door on the bottom half tilts with the real hinge angle; crease and fixed hinge barrels
  - `OvenView` now has a door hinged on its bottom edge and a dish in the cavity (reused by the reveal in 1.7); `OvenCavityView`; `DoorGeometry`; `RingClock` numeral size option; `CountdownFormat.seconds`
- **Verified:** on iPhone 17 and iPhone Duo, 68 of 68 unit tests (new: hinge-to-door mapping, seconds format, bake progress) and 6 of 6 UI tests. New UI tests: opening mid-bake shows the grace and closing resumes; leaving it open for the full 15 s ends the bake half-baked. The iPhone screen was checked through a UI-test screenshot and the Duo through `ImageRenderer` at 669 × 951 (34° and flat).
- **Fixed during the slice:**
  - The Duo top half drew a second oven door and the control column; it now shows the cavity alone.
  - The tilted door spilled past its half; perspective softened and the door is clipped.
  - UI tests failed on a folded Duo because the door read closed and Preheat started the bake at once; the tests now open the door themselves.
- **Left over:** none for 1.6.

### 2026-10-31: Phase 1.5, bake screens

- **Built:**
  - `FaceDownBakeScreen` (board 3): pure black, eyebrow, dim countdown, breathing line, burn-in drift; shows "Prêt." when Ready
  - `CoverBakeScreen` (boards Duo 3 and Duo 4): closed oven with the timer on its display plate, rods brightening with progress, progress line; Ready shows "Prêt." in italic sand, the lift-the-lid line and a breathing glow
  - `KeepAwakePolicy` with `IdleTimerScreenAwake` (screen stays on only while baking or ajar); `BurnInDrift` in the design system; `StarterRecipes.recipe(id:)`
- **Verified:** on iPhone 17 and iPhone Duo, 62 of 62 unit tests (new: drift range, ends, steps and invalid input; keep-awake per phase and setting) and 4 of 4 UI tests (the flow now ends on the real bake timer). Checked against the boards: the iPhone bake screen through a UI-test screenshot, and the Duo cover baking and ready screens through `ImageRenderer` at 466 × 678.
- **Fixed during the slice:** the Ready glow was clipped to the oven's frame, leaving a hard-edged band; it now covers the whole screen and fades out.
- **Left over:** the Settings switch for keep-awake (2.10); whether the cover keeps rendering while shut and the app stays active is a real-device Gate 0 check.

### 2026-10-31: Phase 1.4, Prep and Preheat

- **Built:**
  - `PrepScreen` (hard-coded cupcake on a plate, temperature picker, Preheat with door-aware note) and `PreheatScreen` (oven with "Ready", headline, helper, status pill, summary cells)
  - `SessionController`: drives the engine with the door, the clock and app lifecycle; saves after every event; wakes at the next deadline
  - `SessionRootView` routes each phase to its screen; a temporary stand-in covers phases without screens
  - `FileSessionSnapshotStore` and `InMemorySessionSnapshotStore`, `SessionEffectRouter` (logs effects until 1.7 and 1.8)
  - Code-drawn `CupcakeView` and `OvenView` (first pass), `StatusPill`
- **Verified:** on iPhone 17 and iPhone Duo, 56 of 56 unit tests (new: controller start, save, restore with catch-up, back, door source; file store round trip) and 4 of 4 UI tests (new: Prep → Preheat → door closed → baking; back from Preheat). Screenshots from the UI test checked against boards 1 Prep and 2 Preheat; colours sampled exactly.
- **Fixed during the slice:**
  - The debug panel's identifier hid its buttons' identifiers, and the panel covered the Preheat button; it is now a collapsible chip.
  - VoiceOver read "Preheat, · 25 min"; it now reads "Preheat, 25 minutes".
  - The plate was clipped; the dish now scales so the plate fits.
- **Left over:** the Duo inner-display layout for armed (board Duo 1) comes with the Duo screens.

### 2026-10-31: Phase 1.3, door sensing

- **Built:**
  - `FoldStateService` (now `@MainActor`) and a shared state broadcaster
  - `HingeFoldStateService` (`UIHingeInteraction`, behind `#available(iOS 27.1, *)`), `HingeReading` with the status-to-door mapping
  - `FaceDownDetector` (pure, with hysteresis and settle time) and `FaceDownFoldStateService` (Core Motion)
  - `DoorModeResolver`, `AdaptiveDoorSensor` (picks hinge or face-down and forwards one signal), `HingeSensorAnchor`
  - Debug door readout (`-doorDebug`); `AppEnvironment` composition root in the app target
- **Verified:** on iPhone 17 and iPhone Duo, 50 of 50 unit tests (11 new: face-down settle, tilt, wobble, hysteresis, flip-up; hinge mapping; resolver; adaptive sensor streams and de-duplication) and 2 of 2 UI tests. On the Duo the hinge logs `fullyOpen` at π; on the iPhone 17 the readout shows face-down, no hinge, no motion sensor.
- **Fixed during the slice:** a test checked the settle time at exactly 0.8 s, which floating point puts just under the threshold; the check is now at 1.5 s.
- **Left over:** the Gate 0 slow-close readings and the real-device face-down test (see Current state).

### 2026-10-31: Phase 1.2, domain

- **Built:**
  - `Recipe`, `Temperature`, `BakeRequest`, `Bake`, `BakeOutcome`, `Grade`, `Browning`, `GradeCalculator`
  - `SessionEngine`, the state machine: idle → armed → baking ⇄ ajar → ready → graded → decorating → served. It takes `now` with each event, returns effects (notifications, cues), and exposes `nextDeadline`
  - `DoorState` is now `Codable`
- **Verified:** on iPhone 17 and iPhone Duo, 39 of 39 unit tests (25 new domain tests) and 2 of 2 UI tests. The tests cover:
  - Keep-warm, with hours of overtime
  - The 15 s grace: resume, expiry, ajar counted as open, timer running out during the grace
  - Half-baked doneness, measured at the moment the door opened
  - Relaunch long after an expired grace
  - Break auto-serve after time away, Serve now, Serve plain
  - Decorating unreachable without a bake
  - Encode and decode for force-quit recovery
  - Demo bake with no stars
  - Star and browning rules, and break lengths
- **Left over:** none. Wiring the engine to the app comes with the screens in 1.4 to 1.8.

### 2026-10-31: Phase 1.1, design system

- **Built:**
  - Bundled Instrument Sans and Newsreader (OFL), registered automatically on first use
  - Text styles: eyebrow, body, note, button, control, hero, title, name, numeral, voice
  - Colour, food colour, spacing, radius and button-size tokens; the grain texture and screen background
  - Primary, outline, locked and text button styles; `EyebrowLabel`; `Stars`; `RingClock` (amber state, pulse respects Reduce Motion); `CountdownFormat`
  - Debug-only component gallery (`scripts/run.sh "iPhone 17" -componentGallery`)
- **Verified:** on iPhone 17 and iPhone Duo, 14 of 14 unit tests (fonts register, tracking, line spacing, no text under 11 pt, countdown rounding, ring fraction, star clamping) and 2 of 2 UI tests. The new UI test checks the VoiceOver labels on stars and ring clocks. Build has no warnings, and a deliberate warning was confirmed to fail the build. Compared by eye against the handoff tokens.
- **Fixed during the slice:** the primary button's glow was ghosting its label; the glow is now on the pill only.
- **Left over:** none.

### 2026-10-31: Phase 0 finished on iOS 27

- **Built:** no new code. The iOS 27.2 runtimes are installed (a general one and a Duo-specific `iPhone19-4` one). The simulator setup script now creates the iPhone 17e instead of the 16e, which isn't on iOS 27.
- **Verified:** `test.sh` passes on iPhone 17 and iPhone Duo (package unit tests and the UI smoke test). The app runs on the Duo cover display.
- **Left over:** nothing for Phase 0.

### 2026-10-31: Phase 0, project setup

- **Built:**
  - Xcode project (app and UI-test targets, folders that sync automatically) and the local `ClocheKit` package with six modules
  - Starting code: `DoorState`, `FoldStateService` with a scripted test version, colour, spacing and type tokens, a placeholder start screen
  - Privacy manifest, export-compliance key, string catalogs
  - Scripts: `build.sh`, `test.sh`, `run.sh`, `setup-simulators.sh`
  - Docs: CLAUDE.md, PLAN, DECISIONS, LICENSES
- **Verified:** build passes with warnings treated as errors. `test.sh` passes on iPhone 16: 4 unit tests and 1 UI test, checked in the test results. The app runs in DeviceHub.
- **Commit:** `c4b1e2b`
- **Left over:** create the iPhone 17 and iPhone Duo simulators once the iOS 27 runtime is installed, then run `test.sh` on both
