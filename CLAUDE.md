# CLAUDE.md — Cloche

Rules for every change in this repo. Read this before writing code. If a rule here conflicts with a request, say so before proceeding.

## Source of truth

| What | Where |
| --- | --- |
| Product requirements (scope, priorities P0/P1/P2, rules) | `Cloche — Product Requirements Document.md` |
| Visual + interaction spec (tokens, layouts, motion, a11y) | `Cloche · Design handoff.md` |
| Design canvas (look, spacing, behaviour — do not port its HTML) | https://claude.ai/artifact/MDSEN2XYYDQnRpU4vM3tsK |
| Phased build plan + App Store compliance checklist | `docs/PLAN.md` |
| Where we are: current state + log of completed slices | `docs/PROGRESS.md` |
| Decisions and the reasoning behind them | `docs/DECISIONS.md` |

**At the start of every session, read `docs/PROGRESS.md` → Current state.** When a slice is finished, in the same commit: add a log entry to `PROGRESS.md` (built, verified with test counts, commit, anything left over), update Current state, and add a dated row to `DECISIONS.md` for every choice the PRD or handoff didn't make. Never rewrite past entries; a later decision supersedes an earlier one by referring to it.

Build only what the PRD marks for the current phase. Boards marked "Reference only, do not build" (Duo landscape, palettes A–D) stay unbuilt. If the spec is silent, pick the calmest option, note it in the PR/commit, and add it to `docs/DECISIONS.md`.

## Stack (fixed)

- Swift 6 (strict concurrency on), SwiftUI, Xcode 27.1+, iOS 27.1 SDK.
- Minimum iOS 18. Anything newer goes behind `if #available(iOS 27.1, *)` (hinge APIs) or similar.
- iPhone only device family (runs on iPad in compatibility mode — must not crash there).
- **No third-party packages, no server, no accounts, no ads, no tracking SDKs.** Apple frameworks only: SwiftUI, SwiftData, StoreKit 2, ActivityKit/WidgetKit, Core Motion, AVFoundation, Core Haptics, UserNotifications.
- Fonts: Instrument Sans + Newsreader (SIL OFL), bundled, with system sans / New York fallback.

## Architecture

```
Cloche/
├── Cloche.xcodeproj
├── App/                    # iOS app target: @main, composition root ONLY (wires concrete types)
├── Packages/ClocheKit/ # local Swift package, all real code lives here
│   ├── Domain/             # pure Swift: models, SessionEngine, GradeCalculator. No SwiftUI, no UIKit.
│   ├── DoorSensing/        # FoldStateService protocol + Hinge / FaceDown / Proximity / Honor / Scripted
│   ├── Persistence/        # SwiftData recipe book, session snapshot store (behind protocols)
│   ├── Services/           # Notifications, Feedback (sound+haptics), Purchases, Share, Analytics, LiveActivity
│   ├── DesignSystem/       # tokens, fonts, reusable views (PrimaryButton, RingClock, Stars, TabBar, Dish, Oven)
│   └── Features/           # Prep, Preheat, Bake, Reveal, Grade, Decorate, Book, Settings (View + ViewModel)
├── Widgets/                # Live Activity extension (Phase 3)
├── Resources/              # Recipes.json, Fonts, Sounds, Localizable.xcstrings, PrivacyInfo.xcprivacy
└── Tests/                  # unit (Swift Testing) + UI smoke tests (XCUITest)
```

Dependency direction: `Features → Services/DoorSensing/Persistence → Domain`. `DesignSystem` depends on nothing but SwiftUI. `Domain` depends on nothing. Never import a Feature from another Feature; route through the app coordinator.

### SOLID, concretely

- **S** — One reason to change per type. Views render; ViewModels map domain state to view state; `SessionEngine` owns phase transitions; services do I/O. A view never schedules a notification or reads the hinge.
- **O** — New dish = new entry in `Recipes.json` + a `DishArt` conformance. New door mode = new `FoldStateService` conformance. Neither edits existing switch statements in the engine.
- **L** — Every `FoldStateService` emits the same `DoorState` contract (`.closed`, `.ajar`, `.open`); the engine cannot tell which one it has. Mocks must honour the same contract.
- **I** — Small protocols: `TimeProviding`, `FoldStateService`, `NotificationScheduling`, `SoundPlaying`, `HapticPlaying`, `EntitlementProviding`, `RecipeBookStoring`, `EventLogging`. No god-protocols.
- **D** — Features receive protocols via init injection, assembled in `App/AppEnvironment.swift`. No singletons except what Apple forces (and those get wrapped).

### Rules that protect the product

- **Time is a stored end timestamp, never a ticking counter.** Every phase (bake, grace, break) stores `endDate` and survives sleep, calls and force-quit. Inject `TimeProviding` so tests control time. Views use `TimelineView`/`Text(timerInterval:)` for display only.
- **Never burn on overtime.** A finished bake keeps warm forever. Only opening early (after the 15 s grace) ends a bake half-baked. Doneness = time baked / target.
- **No guilt.** Nothing is lost, reset or shamed. Half-baked still decorates and saves (max 1 star).
- **The break belongs to the bake.** Decorating is unreachable without a finished or abandoned bake. No extensions, no "one more minute".
- **Decorations are an ordered operation list** (stroke, stamp, plate, backdrop, caption), normalised to the dish square. Never store pixels.
- **One door signal.** Only `SessionEngine` consumes `FoldStateService`. Nothing else asks what device it is on.
- **Hinge angle is for effects only**, never layout. Nothing focusable or textual sits on the hinge band.

## Design system rules

- Use tokens from `DesignSystem/Tokens.swift` only. **No raw hex, font sizes or spacing literals in feature code.**
- The interface has no hue: ivory on near-black. Colour lives on food only, plus `color-honey` for the last-30-seconds ring. Ember orange and raspberry must never appear in UI chrome.
- Minimum text 11 pt; minimum hit target 44 × 44 pt; ≥ 8 pt between adjacent controls; timers use tabular figures.
- Every animation has a Reduce Motion alternative as listed in the handoff motion table.
- Build each screen against the matching canvas board and name the SwiftUI view after it (e.g. `PrepScreen` ↔ "1 Prep"). Add a `#Preview` for every screen and component, with iPhone and Duo variants where relevant.

## Accessibility (required, not polish)

VoiceOver labels on every control (use the handoff's label strings), no colour-only signals, Dynamic Type on body/controls (numerals and hero lines fixed), Reduce Motion, tap-to-place instead of drag, the focus order in the handoff, and the four announcements (bake started, door ajar, bake ready, served).

## App Store compliance — non-negotiable

Full checklist with guideline numbers lives in `docs/PLAN.md §5`. The rules that touch code every day:

1. **2.5.4 background modes:** do NOT add background audio, location or fake VoIP to keep the app alive face-down. Correctness comes from stored timestamps + local notifications. Only `UIApplication.isIdleTimerDisabled` while baking in the foreground.
2. **2.5.1:** public APIs only. No private selectors, no KVC into system views.
3. **2.5.9 / BK-7:** audio session category `.ambient` so the silent switch is respected. Never change system volume.
4. **4.5.4 / notifications:** the app must fully work if notifications are denied. Ask for permission in context (first Preheat), with a pre-prompt explaining why.
5. **3.1.1:** unlocks only via StoreKit 2 non-consumables. Visible **Restore Purchases** in Settings and on the unlock sheet. No external purchase links, no paywall during a bake or break.
6. **4.10:** never charge for the door sensors (face-down, hinge, proximity). They work in the free tier.
7. **5.1.1 / 5.1.2:** no data leaves the device in v1. Event log stays local. No ATT prompt, no IDFA, no fingerprinting. Privacy policy link in Settings.
8. **Privacy manifest:** update `PrivacyInfo.xcprivacy` whenever a required-reason API is used (`UserDefaults` → CA92.1, `ProcessInfo.systemUptime`/boot time → 35F9.1, file timestamps → C617.1).
9. **2.1:** no placeholder text, no dead buttons, no "coming soon". Locked items always explain how to get them.
10. **2.4.2:** keep-awake bake screen is pure black with a faint drifting line; no high-brightness static art for 90 minutes.
11. **4.1 / 5.2:** all art and sound original or licensed and logged in `LICENSES.md`. No music, no brand names, nothing resembling Toastie.
12. **2.5.16:** Live Activity shows only bake state. No ads, no promos.
13. Info.plist: `ITSAppUsesNonExemptEncryption = NO`; usage strings only for permissions actually requested.

## Workflow

- Work in **vertical slices**, one per prompt (see `docs/PLAN.md`). Each slice ends building, tested, and visible in the simulator.
- Before saying a slice is done:
  ```sh
  ./scripts/build.sh   # xcodebuild build, iPhone simulator, warnings treated as errors
  ./scripts/test.sh    # unit + UI smoke tests on iPhone and iPhone Duo simulators
  ```
  Both must pass. Report failures verbatim; never hide or skip a failing test.
- Then launch on the simulator so the user can see it (`./scripts/run.sh "iPhone 17"` / `"iPhone Duo"`). Xcode 27's simulator app is **DeviceHub**, not Simulator.
- Never move CLI derived data back inside the repo: the space in "My Dev" breaks package test loading (see `docs/DECISIONS.md`).
- Tests use `ScriptedFoldStateService` and a `TestTimeProvider`. Never `sleep` in tests.
- Every domain rule in this file gets a unit test (grace expiry, keep-warm, half-baked doneness, star math, break auto-serve, relaunch recovery).
- Commit after each green slice with a clear message. Branch per phase (`phase-1-gate0`, …); never force-push `main`.
- Signing: automatic, team set in Xcode. If a signing/entitlement error appears, show it verbatim to the user.
- All user-facing strings in `Localizable.xcstrings` (Hindi ships later). No string literals in views except via `LocalizedStringKey`.
- Real-device pass required before submission for haptics, sound, face-down, proximity and heat (simulator cannot test these).

## Code style

- Swift API Design Guidelines. Types `UpperCamelCase`, members `lowerCamelCase`, protocols describe capability (`…ing`/`…Providing`) or role (`…Service`, `…Store`).
- `@Observable` view models, `@MainActor` on UI types, value types for models, `Sendable` everywhere across actors.
- No force unwraps outside tests and previews. Errors are typed and handled; `Save failure on serve` follows the handoff rule (silent retry, then a one-line note + Retry).
- Comments explain *why*, not what. Keep files under ~300 lines; split views into subviews when they grow.
