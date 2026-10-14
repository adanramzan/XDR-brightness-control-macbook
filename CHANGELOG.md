# Changelog

## 1.2.0 — 2026-10-15

- Fix: the screen no longer turns white during three-finger Space swipes, Mission Control or app launch animations. Boost now uses a 1×1 EDR trigger and a scaled gamma table instead of a full-screen multiply overlay.
- F1/F2 in the XDR range now shows a brightness HUD with the boost level and estimated nits (macOS 27 shows no HUD of its own there).
- Fix: the system Display HUD could stay on screen forever when holding F2 across the SDR maximum; macOS now always receives the key release for presses it saw.
- New app icon (regenerate with `bash scripts/make-icon.sh`).
- Fix: `build.sh` failed when rebuilding over an existing app because of a read-only license file.

## 1.1.0 — 2026-10-14

Initial public release of the standalone app.

- Icon-only menu bar item with estimated nits in its popup.
- Continuous XDR boost slider and scrolling inside the popup.
- Native brightness slider and F1/F2 SDR-to-XDR transition handling.
- Accessibility setup and automatic event-tap retry.
- Removal of the overlay on quit, sleep, session inactivity and unsupported display changes.
- Universal build, source archive, DMG packaging, checksums, and automated policy/build checks.

Physical nits are not measured. The live rendering/native-brightness smoke test passed on an M1 Max; physical F1/F2 interception requires Accessibility permission and remains a manual validation step.
