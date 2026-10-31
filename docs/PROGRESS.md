# Progress log

Read the **Current state** first; it says where the next session starts. Then add an entry under **Log** (newest first) each time a slice is finished. Decisions and their reasoning go in `DECISIONS.md`, not here.

## Current state

- **Phase:** 1.3 done; next is 1.4 (Prep screen with a hard-coded cupcake, then Preheat)
- **Last green commit:** see the log entry below
- **Blockers:** Apple Developer Program not enrolled (needed by the end of Phase 2 for TestFlight); watchOS 27 runtime not installed (needed in Phase 3)
- **Simulators:** iPhone 17, iPhone 17e and iPhone Duo on iOS 27.2; iPhone 16 on iOS 18.2 (minimum-version check)
- **Gate 0 facts so far:**
  - The Duo hinge reports in the simulator: unfolded is `fullyOpen`, angle `3.141593`, so the angle is in radians and flat open is π.
  - iPhones without a hinge get no hinge update at all, rather than an update with no hinge.
  - Still open: readings during a slow close and open (needs folding by hand in DeviceHub, then `xcrun simctl spawn <Duo> log show --last 5m --predicate 'subsystem == "com.shubhamtyagi.pocketoven"'`); face-down on a real iPhone on three surfaces.
- **Known for Phase 1:** the Duo simulator boots folded, showing the cover display (1398 × 2034 px). The system reserves a strip down the cover's right edge, so centred content sits left of centre; cover screens need the reserved-region APIs. `simctl io screenshot` needs `--display=1` on the Duo.

## Log

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
  - Xcode project (app and UI-test targets, folders that sync automatically) and the local `PocketOvenKit` package with six modules
  - Starting code: `DoorState`, `FoldStateService` with a scripted test version, colour, spacing and type tokens, a placeholder start screen
  - Privacy manifest, export-compliance key, string catalogs
  - Scripts: `build.sh`, `test.sh`, `run.sh`, `setup-simulators.sh`
  - Docs: CLAUDE.md, PLAN, DECISIONS, LICENSES
- **Verified:** build passes with warnings treated as errors. `test.sh` passes on iPhone 16: 4 unit tests and 1 UI test, checked in the test results. The app runs in DeviceHub.
- **Commit:** `c4b1e2b`
- **Left over:** create the iPhone 17 and iPhone Duo simulators once the iOS 27 runtime is installed, then run `test.sh` on both
