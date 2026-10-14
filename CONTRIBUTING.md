# Contributing

Keep changes focused on built-in XDR brightness and the small menu bar control.

1. Fork the repository and create a branch.
2. Run `bash scripts/test.sh` and `bash XDRBrightness/build.sh` with full Xcode installed.
3. Add tests for changes to brightness transitions or limits.
4. For input/rendering changes, test on a real built-in XDR display: F2 across SDR maximum, F1 back through neutral, held-key repeats, popup scrolling, sleep/wake and quit. Report your Mac model and macOS version. Hosted CI cannot replace these checks.
5. Open a pull request describing the problem, behavior and validation. Clearly distinguish calculated nits from measured luminance.

Do not commit app bundles, build folders, DMGs, signing credentials or personal diagnostic logs. Keep upstream copyright and license notices. A contribution is submitted under this repository's GPL-3.0 license; do not copy proprietary code.

## Releases

Update `VERSION` and `CHANGELOG.md`, build and test from a clean checkout, and manually check physical key behavior with Accessibility permission. A tag matching `v<VERSION>` triggers the release workflow, which builds a universal app and publishes a DMG, complete source archive and SHA-256 checksums. Re-running the release workflow updates the matching draft release before publishing. Apple notarization is not configured; disclose that in release notes.
