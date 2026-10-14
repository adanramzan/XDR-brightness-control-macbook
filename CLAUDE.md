# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS menu bar app (AppKit, no Xcode project, no SwiftPM, no third-party deps) that lets F2 keep raising brightness past the SDR maximum on a MacBook Pro's built-in XDR display, via a 1×1 EDR trigger window plus a scaled gamma table. Scope is deliberately narrow: built-in XDR brightness plus the small popup control.

## Commands

All scripts `cd` to the repo root themselves; requires full Xcode (`swiftc`, `xcrun`, `lipo`, `codesign`).

```sh
bash scripts/test.sh                 # compile + run policy tests (build/xdr-policy-tests)
bash XDRBrightness/build.sh          # universal (arm64+x86_64) ad-hoc-signed app → dist/XDR Brightness.app
open "dist/XDR Brightness.app"
"dist/XDR Brightness.app/Contents/MacOS/XDRBrightness" --self-test   # needs XDR hardware; prints JSON report, exit 0/1
bash scripts/package.sh              # DMG + source tarball + SHA256SUMS; needs a clean git tree and a build matching VERSION
```

There is no test framework and no way to run a single test: `XDRBrightness/tests/main.swift` is a flat list of `check(...)` calls (fatalError on failure) compiled together with only `BoostPolicy.swift`. Add new cases there.

Adding a new source file requires adding it to the explicit `swiftc` file list in `XDRBrightness/build.sh` (and to `scripts/test.sh` if tests need it).

## Architecture

- **`BoostPolicy.swift`** — pure, Foundation-only logic: which screen is supported, level→gain mapping (1×–3.2×), scroll clamping, the F1/F2 SDR↔XDR transition (`keyStep` returns `nil` to let macOS handle the key, a value to consume it), and the nits estimate (approximate M1 XDR curve, not measurement). Keep it free of AppKit so tests compile without the app. Changes to transitions or limits need tests.
- **`BrightnessKeys.swift`** — a `cgSessionEventTap` (requires Accessibility trust) intercepting brightness keys both as `NX_SYSDEFINED` media events (type 14, subtype 8, keys 2/3) and as keycodes 144/145. `KeyGate` (in `BoostPolicy.swift`, tested) swallows a key-up only if macOS saw none of that key's presses; otherwise the system HUD waits forever for the release. Cmd/Ctrl/Option combos pass through (Option–Shift = fine steps). Re-enables itself on tap timeout.
- **`main.swift`** — everything else:
  - `NativeBrightness`: `dlopen`s private `DisplayServices.framework` for hardware brightness get/set.
  - `BoostView`/`BoostWindow`: a 1×1 `MTKView` clearing to `rgba16Float` `(gain, gain, gain)` in a click-through window at the screen's top-left pixel, above shielding level on all Spaces. It only exists to keep the display in EDR mode; `applyGamma()` does the actual boost by scaling a captured gamma table by `BoostPolicy.gammaFactor` (capped at current headroom), re-checked every 0.5 s via the readout timer, and `removeOverlay()` restores it with `CGDisplayRestoreColorSyncSettings()`. Do not go back to a full-screen `multiplyBlendMode` overlay: WindowServer drops the filter during Space swipes/app animations and the screen turns white.
  - `BrightnessHUD`: our own glass HUD panel (centered under the menu bar, fades after 1.5 s) for consumed F1/F2 presses. Don't use private `OSD.framework` `OSDManager`: on macOS 27 the call succeeds but nothing is shown (the system HUD now comes from Control Center and only for real hardware brightness changes).
  - `AppDelegate`: status-item menu with XDR + native sliders and nits readout; picks the built-in EDR-capable screen in `configureDisplay()`; `applyBoost()` always tears down and recreates the trigger. Trigger and gamma boost are removed on sleep/session-inactive/quit and when level is neutral. The key-tap callback must return immediately and defer overlay work via `DispatchQueue.main.async`. A 2 s timer retries starting the event tap until Accessibility is granted.

## Constraints

- Target is macOS 12+, `-swift-version 5`; avoid newer-only APIs without availability checks.
- `VERSION` (strict `X.Y.Z`) drives the bundle version and release; releases are triggered by pushing tag `v<VERSION>` (`.github/workflows/release.yml`). Update `CHANGELOG.md` alongside.
- CI (`macos-14`) only runs policy tests and the universal build; input/rendering changes must be checked on real XDR hardware (F2 across SDR max, F1 back through neutral, held repeats, popup scroll, sleep/wake, quit).
- Describe nits as estimates, never measured luminance.
- GPL-3.0; keep upstream notices (`XDRBrightness/LICENSE.txt`, `NOTICE.txt`, `MediaKeyTap-LICENSE.txt` are copied into the bundle). Never commit `build/`, `dist/`, DMGs, or signing material.
