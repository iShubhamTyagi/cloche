# Cloche

A focus timer where your phone is the oven. Prep a bake, close the phone (or lay it face down) and work while it bakes, then open it to a short decorating break that ends with a dish you made.

*Closed to commit, open to create.*

- **iPhone Duo:** the fold is the oven door. Closing the phone starts the bake, and the outer screen keeps the time.
- **Every other iPhone:** place the phone face down. Turn it over when the time is up.
- **No guilt:** a finished bake keeps warm however long you keep working. Opening early still gives you a dish, just half-baked.
- **Private by design:** no account, no server, no tracking. Everything stays on the phone.

Native Swift 6 and SwiftUI, with no third-party dependencies.

## Status

**Phase 1 (Gate 0 prototype) is complete.** The full close-and-reveal loop runs on iPhone and iPhone Duo: Prep → Preheat → Bake → Door ajar (15 s grace) → Reveal → Grade, plus the ready notification, the end chime and a 15-second demo bake.

**Next is Phase 2**, the playable loop for testers: five dishes, the decorating game, the recipe book, share cards and TestFlight.

The plan is in [`docs/PLAN.md`](docs/PLAN.md) and the latest state in [`docs/PROGRESS.md`](docs/PROGRESS.md).

## Requirements

- An Apple silicon Mac
- Xcode 27.1 or later (iOS 27.1 SDK; the hinge APIs need it)
- The iOS 27 simulator runtime, which includes the iPhone Duo
- The minimum deployment target is iOS 18

## Getting started

```sh
git clone https://github.com/iShubhamTyagi/cloche.git
cd cloche
./scripts/setup-simulators.sh   # creates the iPhone 17, 17e and iPhone Duo simulators if missing
./scripts/run.sh "iPhone 17"     # builds, installs and launches in DeviceHub
```

Or open `Cloche.xcodeproj` in Xcode and run the **Cloche** scheme. Signing is automatic; choose your team in the target's Signing & Capabilities tab before running on a device.

| Script | What it does |
| --- | --- |
| `scripts/build.sh ["Simulator"]` | Debug build for a simulator; warnings are errors |
| `scripts/test.sh ["Simulator" …]` | Package unit tests, then UI tests; defaults to iPhone 17 and iPhone Duo |
| `scripts/run.sh ["Simulator"] [args…]` | Build, install and launch, passing any launch arguments |
| `scripts/setup-simulators.sh` | Creates the simulators the test matrix uses |

### Debug launch arguments (debug builds only)

| Argument | Effect |
| --- | --- |
| `-doorDebug` | Door readout chip: the active sensor, door state, hinge angle and gravity, plus Closed / Ajar / Open buttons that stand in for sensors in the simulator |
| `-componentGallery` | Every design-system component on one screen |
| `-freshSession` | Starts from a clean Prep screen with default settings (used by UI tests) |

Example: `./scripts/run.sh "iPhone 17" -doorDebug`. Then open Settings → **Demo bake · 15 seconds**, tap **Closed**, wait, and tap **Open**.

## Project structure

```
App/                    App target: entry point and composition root only
Packages/ClocheKit/     All app code, as a local Swift package
  Sources/Domain/         Pure Swift: SessionEngine state machine, grading, models
  Sources/DoorSensing/    One "is the door closed?" signal: hinge, face-down, debug override
  Sources/Persistence/    Session snapshot store (force-quit recovery)
  Sources/Services/       Notifications, sound, haptics, VoiceOver announcements, keep-awake
  Sources/DesignSystem/   Tokens, bundled fonts, buttons, stars, ring clock
  Sources/Features/       Screens and their wiring
  Tests/                  Unit tests (Swift Testing)
UITests/                End-to-end flows (XCUITest)
docs/                   Plan, progress log, decisions log
scripts/                Build, test and run helpers
```

### How it fits together

- **`SessionEngine`** is a pure, `Codable` state machine: idle → armed → baking ⇄ ajar → ready → graded → decorating → served. It receives door events and the current time, and returns effects such as "schedule a notification" or "play a cue". It does no I/O itself, so every rule is unit-tested without a device.
- **Time is always a stored end date, never a ticking counter.** A bake survives sleep, calls and force-quit.
- **`FoldStateService`** is the only source of the door state. `AdaptiveDoorSensor` uses the Duo's hinge when there is one and face-down detection everywhere else. The engine never knows which one it has.
- **Dependencies point inward:** Features → Services / DoorSensing / Persistence → Domain. Concrete types are created in one place, `App/AppEnvironment.swift`.

## Testing

```sh
./scripts/test.sh
```

This runs 81 unit tests and 8 UI tests on the iPhone 17 and iPhone Duo simulators. The UI tests include a full 15-second demo bake. The tests use a scripted door and an injected clock, so they never depend on sensors or the simulator's fold position.

Haptics, sound, face-down detection on real surfaces and heat can only be checked on a real device.

## Documentation

| File | Contents |
| --- | --- |
| [`CLAUDE.md`](CLAUDE.md) | Rules for every change: architecture, design-system use, accessibility, App Store compliance, workflow |
| [`docs/PLAN.md`](docs/PLAN.md) | Phases and slices, testing strategy, App Store approval checklist |
| [`docs/PROGRESS.md`](docs/PROGRESS.md) | Current state and a log of every finished slice |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Every decision the specs didn't make, with the reasoning |
| [`Cloche — Product Requirements Document.md`](<Cloche — Product Requirements Document.md>) | The product requirements |
| [`Cloche · Design handoff.md`](<Cloche · Design handoff.md>) | Visual and interaction spec: tokens, layouts, motion, accessibility |
| [`LICENSES.md`](LICENSES.md) | Sources and licences for bundled fonts and sounds |

## Accessibility

VoiceOver labels and announcements, Reduce Motion alternatives for every animation, Dynamic Type for helper text and controls, 44 pt minimum hit targets, and no colour-only signals.

## Credits

Fonts: [Instrument Sans](https://github.com/google/fonts/tree/main/ofl/instrumentsans) and [Newsreader](https://github.com/google/fonts/tree/main/ofl/newsreader), both under the SIL Open Font License 1.1. All art is drawn in code and all sounds are original. See [`LICENSES.md`](LICENSES.md).

© 2026 Shubham Tyagi. All rights reserved.
