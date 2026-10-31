# Progress log

Read the **Current state** first; it says where the next session starts. Then add an entry under **Log** (newest first) each time a slice is finished. Decisions and their reasoning go in `DECISIONS.md`, not here.

## Current state

- **Phase:** 0 is done except the iPhone 17 and iPhone Duo simulators; next is Phase 1.1 (fonts and design-system components)
- **Last green commit:** `c4b1e2b`
- **Blockers:** iOS 27 simulator runtime still downloading (needed for iPhone 17 and iPhone Duo); Apple Developer Program not enrolled (needed by the end of Phase 2 for TestFlight)
- **Simulators that work today:** iPhone 16 (iOS 18.2)

## Log

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
