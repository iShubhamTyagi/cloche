# Progress log

Read the **Current state** first; it says where the next session starts. Then add an entry under **Log** (newest first) each time a slice is finished. Decisions and their reasoning go in `DECISIONS.md`, not here.

## Current state

- **Phase:** 0 is done; next is Phase 1.1 (fonts and design-system components)
- **Last green commit:** see the log entry below
- **Blockers:** Apple Developer Program not enrolled (needed by the end of Phase 2 for TestFlight); watchOS 27 runtime not installed (needed in Phase 3)
- **Simulators:** iPhone 17, iPhone 17e and iPhone Duo on iOS 27.2; iPhone 16 on iOS 18.2 (minimum-version check)
- **Known for Phase 1:** the Duo simulator boots folded, showing the cover display (1398 × 2034 px). The system reserves a strip down the cover's right edge, so centred content sits left of centre; cover screens need the reserved-region APIs. `simctl io screenshot` needs `--display=1` on the Duo.

## Log

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
