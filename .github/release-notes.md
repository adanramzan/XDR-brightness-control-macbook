A small standalone menu bar app for the built-in Liquid Retina XDR display.

Download the **universal DMG**, drag **XDR Brightness** to Applications, and launch it. Source and SHA-256 checksums are attached.

- Click the sun icon for the popup's estimated-nits readout and sliders.
- Scroll inside the popup to adjust XDR boost.
- Enable **F1/F2 control…** in the popup, then grant **XDR Brightness** Accessibility access in System Settings. F2 uses normal macOS brightness until SDR maximum, then raises XDR boost. F1 lowers boost first and then returns to native dimming.
- Boost starts at neutral. Quit restores the normal display gamma.
- In the XDR range, F1/F2 show a brightness HUD with the boost level and estimated nits.

**New in 1.2.0:** no more white screen during three-finger Space swipes, Mission Control or app launches (boost now uses a 1×1 EDR trigger plus the display gamma table instead of a full-screen overlay); the system Display HUD no longer gets stuck when holding F2 across the SDR maximum; new app icon.

**Important:** the app is ad-hoc signed, not Apple-notarized. macOS may require **Privacy & Security → Open Anyway** after the first launch attempt. Do not disable Gatekeeper.

**≈nits is an estimate**, not measured panel output. Software boost targets the 1600-nit peak range; actual output varies and sustained full-screen 1600 nits is not guaranteed. It may affect HDR rendering and other apps that change the display gamma table. The M1-based estimate is not calibrated for every Mac model.

Requires macOS 12+ and a built-in XDR-capable MacBook Pro display. Universal arm64/x86_64 build; external displays are not supported. Policy and build checks pass, and a live rendering/native-brightness smoke test passed on an M1 Max running macOS 27.0.1. Physical F1/F2 interception requires Accessibility permission and remains a manual validation step.

Licensed under GPL-3.0 with upstream notices. See the README for build instructions and limitations.
