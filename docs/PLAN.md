# Pocket Oven: development plan

Oct 31, 2026. Covers the work from an empty folder to App Store submission. Inputs: the PRD, the design handoff, and the design canvas. Rules for each change are in `CLAUDE.md`.

## 1. Where we are

| Item | Status | Blocking? |
| --- | --- | --- |
| Mac | Apple silicon, macOS 27.2 | OK |
| Xcode | **Not installed.** Only Command Line Tools are present. | **Yes, blocks everything.** Install Xcode 27.1+ from the Mac App Store, then run `sudo xcode-select -s /Applications/Xcode.app` |
| Simulator runtimes | None | Yes: iOS 27.1 (includes iPhone Duo) and watchOS 27 |
| Apple Developer Program | Not enrolled | Blocks TestFlight and submission, not local builds. **Enroll today**, because approval can take days. |
| Real iPhone Duo | None | Gate 0 uses the simulator. Clips must say so. |
| Design 3D stills (cupcake, oven) | Only on the canvas; can't be downloaded with tools | No. We code-draw first (PRD §10). Export the PNGs from the canvas into `Resources/ArtReference/` if you want them as a fallback. |

## 2. Architecture summary

- **One Xcode project.** `App` (iOS), `Widgets` (Live Activity, Phase 3) and, after launch, `WatchApp`.
- **One local Swift package, `PocketOvenKit`,** holds all the logic in layers: `Domain → DoorSensing / Persistence / Services → DesignSystem → Features`. The app target is only a composition root. The package layout makes the dependency rules enforceable, keeps builds fast, and lets the domain be tested without the UI.
- **Core seams (protocols):** `FoldStateService` (door), `TimeProviding` (time; not `Clock`, which clashes with the Swift standard library), `NotificationScheduling`, `SoundPlaying`, `HapticPlaying`, `RecipeBookStoring`, `SessionSnapshotStoring`, `EntitlementProviding`, `EventLogging`, `LiveActivityControlling`.
- **`SessionEngine`** is a pure state machine: `idle → preheat → baking ⇄ ajar(grace) → ready | halfBaked → reveal → grade → decorating → served → saved`. It takes door events and clock ticks as input and emits phase plus side-effect commands (schedule notification, play sound, start Live Activity). Services carry the commands out, so the engine can be tested end to end without a device.
- **Door adapters:** `HingeFoldStateService` (`onHingeChange`, behind `#available(iOS 27.1, *)`), `FaceDownFoldStateService` (Core Motion gravity z > 0.9 for ≥ 1 s, with a flatness tolerance and a flicker counter), `ProximityFoldStateService` (P1, only if Gate 0 proves it works), `HonorDoorService` (drag to close, P1), and `ScriptedFoldStateService` (tests and a debug menu). `DoorModeResolver` picks one: hinge if one is present, otherwise face-down, unless the player overrides it in Settings.

## 3. Phases (vertical slices)

Every slice ends with `build.sh` and `test.sh` passing, the app running in the iPhone and iPhone Duo simulators for you to look at, and a commit.

### Phase 0: setup (day 0 to 1)

1. Install Xcode 27.1+, the iOS 27.1 and watchOS runtimes, and create the simulators: iPhone 17, iPhone 16e (small screen), iPhone Duo, and Apple Watch Series (45 mm).
2. `git init` in this folder, add `.gitignore` for Xcode, and push to a private remote if you want one.
3. Create `PocketOven.xcodeproj` (App target, iOS 18 minimum, Swift 6, iPhone only) and the local `PocketOvenKit` package, then wire them together.
4. Write `scripts/build.sh`, `test.sh` and `run.sh` (xcodebuild plus `simctl boot`, `install` and `launch`, with Simulator.app opened).
5. Add `PrivacyInfo.xcprivacy`, set `ITSAppUsesNonExemptEncryption` to NO in Info.plist, and add `LICENSES.md` (fonts: OFL), `docs/DECISIONS.md` and `Localizable.xcstrings`.
6. Smoke test: an empty app launches in both simulators.

### Phase 1: Gate 0 prototype (week 1, from Nov 2)

Goal: film the close-and-reveal moment and settle four technical facts.

| # | Slice | PRD / handoff refs |
| --- | --- | --- |
| 1.1 | DesignSystem: tokens (colour, type, spacing, radius), bundled fonts, grain overlay, PrimaryButton, OutlineButton, EyebrowLabel, Stars | Handoff "Design tokens" |
| 1.2 | Domain: `Recipe`, `Temperature`, `BakeSession`, `SessionEngine` (timestamp-based), `GradeCalculator`, `TimeProviding`. Full unit tests for grace, keep-warm, half-baked, stars and relaunch recovery | PRD §5, §9; BK-1, BK-4, BK-5, BK-6 |
| 1.3 | DoorSensing: protocol, face-down, hinge (gated), scripted mock, plus a debug overlay showing hinge status, angle and gravity | PL-1, BK-2, DR-1, DR-2 |
| 1.4 | Prep screen (hard-coded cupcake) → Preheat ("Waiting for a flat, face-down phone") | Boards 1 Prep, 2 Preheat |
| 1.5 | Bake face-down screen (black, glow line, drift) with keep-awake; Duo cover-display baking and ready screens | Boards 3, Duo 3, Duo 4; DR-3 |
| 1.6 | Door ajar with a 15 s ring countdown, on iPhone and Duo | S2 7, Duo 2 |
| 1.7 | Reveal (door drop, steam, haptic) → Grade card, plus the half-baked grade | 4 Reveal, 5 Grade, S2 8, Duo 5, Duo 6 |
| 1.8 | Ready local notification and end chime; a 15 s demo bake | BK-6, DR-4, DR-6 |

**Facts to settle and write down in `docs/DECISIONS.md`:**

- Does the cover display keep rendering while the Duo is closed? (simulator)
- What does the hinge report during a slow close and a slow open?
- Is face-down detection reliable on three surfaces? (real iPhone)
- Does the timer stay correct through a lock, a call and a force-quit?

### Phase 2: Gate 1 playable loop (weeks 2 and 3, in testers' hands by the end of week 3)

| # | Slice | Refs |
| --- | --- | --- |
| 2.1 | `Recipes.json` with 5 dishes; recipe picker with locked state; temperature hint | PR-1, PR-2, PR-3 |
| 2.2 | Code-drawn `DishArt` for all 5 dishes, with bake progress and browning as parameters; Wide OTG oven view | Handoff Dish and Oven components |
| 2.3 | Decorate shell: header, ring clock, tab bar, canvas, break timer (5, 8 or 10 min), Serve now, auto-serve | DC-1, DC-2; S2 1 to S2 4 |
| 2.4 | Base tab (icing strokes) and Toppings tab (tap to place, pinch, 12 cap, sprinkles); undo and clear within each tab | DC-3; tray specs |
| 2.5 | Plate and finish tab (6 plates, 6 backdrops, 40-character caption); last-30-seconds state | S2 3, S2 4 |
| 2.6 | Served → Saved; recipe book on SwiftData (grid, silhouettes, entries rendered from the operation list) | S2 5, S2 6; CL-1, CL-2 |
| 2.7 | Share card (1080 × 1350) through `ImageRenderer` and the share sheet | SH-1, SH-2 |
| 2.8 | Duo inner layouts for decorating; the hinge band kept clear | Duo S2 1 to Duo S2 5; PL-2 |
| 2.9 | Sounds (original recordings) and haptics; ambient audio session | BK-7; PRD §10 |
| 2.10 | Settings: door mode, keep awake, sound, demo bake, privacy policy, Restore Purchases placeholder hidden until 3.1 | DR-3, DR-6, DR-8 |
| 2.11 | Local event log tagged with door source; accessibility pass (VoiceOver, Dynamic Type, Reduce Motion) | AN-1, DR-7, PL-3 |
| 2.12 | **TestFlight internal and external build** (needs the ADP account) | Gate 1 |

Retention for Gate 1: use App Store Connect / TestFlight analytics, which need no SDK and send nothing from our code, plus an on-device log that testers can export with the share sheet in TestFlight builds only.

### Phase 3: launch build and submission (weeks 4 to 6)

| # | Slice | Refs |
| --- | --- | --- |
| 3.1 | StoreKit 2: Full Kitchen non-consumable, Restore, a StoreKit configuration file for tests, unlock sheet shown once after the first fully baked and shared dish | MO-1; PRD §12 |
| 3.2 | Live Activity and Watch Smart Stack (compact view, Always-On, one haptic on ready) | BK-8, WT-1 to WT-3 |
| 3.3 | Honor door; covered mode only if Gate 0 proved it | DR-9, DR-10 |
| 3.4 | Work label, variants, completion percentage per pack | PR-4, CL-3, CL-4 |
| 3.5 | Clip export (time-lapse replay of the operation list) | SH-3 |
| 3.6 | Run Xcode's resizable-layout agent skill; test on iPad compatibility mode, iPhone 16e and the Duo | PRD §11 |
| 3.7 | Store assets: screenshots (standard iPhone, Duo inner and cover), privacy policy and support pages, review notes, age rating, IAP metadata | §5 below |
| 3.8 | Real-device pass for haptics, sound, heat and battery over a 90-minute soak; fix; submit with a limited-territory release | Gate 2 |

### Phase 4: after launch (P2)

A native watchOS app and complication, iCloud sync of the recipe book, custom session lengths, regional packs and oven skins, and the Hindi localization.

## 4. Testing strategy

- **Unit tests (Swift Testing)** for the domain and services, with `TestTimeProvider` and `ScriptedFoldStateService`. Target: every rule in CLAUDE.md, and close to 100% of `SessionEngine`.
- **Snapshot-style previews** for every screen on the iPhone and the Duo, checked by eye against the canvas boards.
- **UI smoke tests (XCUITest)** for the full loop, driven by the launch argument `-doorScript closed,15s,open` and a 15 s demo recipe.
- **Device matrix before each TestFlight:** iPhone 16e, iPhone 17, iPhone Duo (simulator), iPad (compatibility mode), the Watch simulator, and one real iPhone.

## 5. App Store approval checklist (first-time approval)

Checked against Apple's App Review Guidelines (developer.apple.com/app-store/review/guidelines). Apple revised them again on Oct 16, 2026, so re-read the live page at Phase 3.7.

| Guideline | Risk for Pocket Oven | What we do |
| --- | --- | --- |
| **4.3(b) Spam: "simple timers" are saturated** | **Highest risk.** A reviewer may see "another focus timer". | Lead with the game in the name, subtitle, screenshots and description: baking, decorating, the recipe book. **Decided: Games › Casual** primary, Productivity secondary. The review notes describe the fold and flip mechanic and the decorating game. |
| 2.1 App completeness | The reviewer can't wait 25 minutes and has no Duo | Settings → **Demo bake (15 s)**. The review notes give exact steps for face-down and say the hinge is optional. No placeholders and no dead buttons. |
| 2.1(b) and 3.1.1 IAP | IAP not submitted, or no restore | Create the IAP in App Store Connect and attach it to the first build. Restore Purchases sits in Settings and on the unlock sheet. StoreKit 2 only. Never link to outside purchases. |
| 2.3 Metadata | Screenshots that don't match the app | Real captures. iPhone screens first, plus Duo screens (required for apps built with the 27.1 SDK from April 2027; we include them from the start). 4+ copy. |
| 2.4.1 iPad | A crash in iPad compatibility mode | Test on an iPad simulator. |
| 2.4.2 Power | Screen awake for 90 minutes | Black screen, a faint line, slow drift, no bright static art. Soak test on a device. |
| 2.5.1 Public APIs | — | Public APIs only, and the hinge API used as documented. |
| **2.5.4 Background modes** | Tempting to keep the app alive with silent audio | **Never.** No background modes in v1. Correctness comes from timestamps and local notifications. |
| 2.5.9 Silent switch | Sounds play in silent mode | `.ambient` audio session. |
| 2.5.16 Widgets and Live Activities | Promo content | Bake state only. |
| 4.1 Copycats, 5.2 IP | Similarity to Toastie; font licences | Original art and sound. Side-by-side check before release. `LICENSES.md` covers the OFL fonts. |
| 4.5.4 Notifications | App broken if notifications are denied | Ask in context with a pre-prompt; the app works fully without them. |
| 4.10 Built-in capabilities | Charging for face-down or hinge play | Door modes are always free. |
| 5.1.1 Privacy | No privacy policy | Policy URL in App Store Connect and in Settings. Privacy label: **Data Not Collected** (nothing leaves the device). |
| 5.1.2 Tracking | — | No ATT prompt, no SDKs. |
| Privacy manifest | Missing required-reason APIs means an upload warning or rejection | `PrivacyInfo.xcprivacy`: UserDefaults CA92.1, system uptime 35F9.1, file timestamps C617.1 if used. Tracking false. |
| Export compliance | — | `ITSAppUsesNonExemptEncryption = NO`. |
| Age rating | Questionnaire | Answer the questionnaire; expect 4+. No user-generated sharing *inside* the app (the share sheet only). |
| Accessibility Nutrition Labels | — | Declare VoiceOver, Larger Text, Reduced Motion and Sufficient Contrast once they are verified. |
| SDK minimums | — | Build with Xcode 27.1 or later. This also meets the April 2027 requirement for the iOS 27 SDK. |
| Name | "Pocket Oven" not checked | Check App Store Connect name availability (30 characters max) before the store assets are made. |

**Review notes template (fill in at 3.7):** what the app is (a baking and decorating game where the bake runs while you focus); how to test without a Duo (Settings → Demo bake, then place the phone face down for 15 s and flip it up); what the hinge does on a Duo; where the IAP is and how to restore it; and that no account, network or data collection is involved.

## 6. Decisions still open (yours)

1. ~~Primary App Store category~~ — decided Oct 31: Games › Casual.
2. Should the demo bake stay in the shipped app? The PRD says yes. App Review needs it, so keep it.
3. Last-30-seconds colour: honey as drawn, or ivory only? The plan builds it as drawn.
4. Which plates, backdrops and toppers are free? Proposal: 3 of each are free.
5. Name and domain availability for "Pocket Oven".
