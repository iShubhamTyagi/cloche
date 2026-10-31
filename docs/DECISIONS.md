# Decisions log

Choices made during the build that the PRD or design handoff don't settle. Newest first.

| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-31 | CLI derived data lives in `~/Library/Developer/Xcode/DerivedData/PocketOven-cli`, outside the repo | Xcode 27.2 can't load hostless package test bundles from a path containing a space ("My Dev"); verified by running the same tests from a path without spaces |
| 2026-10-31 | `test.sh` runs the package's unit tests through the `PocketOvenKit` scheme, then the app's UI tests | Package testables added to the app scheme were silently skipped |
| 2026-10-31 | Scripts open `DeviceHub.app` | Xcode 27 replaced Simulator.app with DeviceHub |
| 2026-10-31 | Primary App Store category is **Games › Casual**; Productivity is secondary | Lowers the risk of a Guideline 4.3(b) "simple timer" rejection; the decorating game and collection are the product |
| 2026-10-31 | Bundle ID `com.shubhamtyagi.pocketoven` | Placeholder until the App Store Connect record exists; change before the first archive if needed |
| 2026-10-31 | The time protocol is `TimeProviding`, not `Clock` | `Clock` clashes with the Swift standard library |
| 2026-10-31 | Portrait only on iPhone | The design covers portrait only; Duo landscape is reference-only |
| 2026-10-31 | Xcode project uses folder-synchronized groups; all logic lives in the local `PocketOvenKit` package | New files need no project edits; module boundaries enforce the dependency rules in CLAUDE.md |
