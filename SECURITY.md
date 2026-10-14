# Security

This app uses Accessibility permission to intercept brightness keys. It does not record keystrokes, send telemetry, contact a server, or store keyboard events. Unrelated keys pass through. It also uses the private macOS DisplayServices brightness API, a 1×1-pixel Metal EDR window, and the public display gamma-table API (restored on quit, and by macOS if the app exits).

Only the latest release is maintained; there is no guaranteed response time. For a security issue, use [GitHub's private vulnerability reporting](https://github.com/adanramzan/XDR-brightness-control-macbook/security/advisories/new) when available. Do not post secrets or personal diagnostic data in public issues. For a non-sensitive bug, use the issue tracker.

Release binaries are locally/ad-hoc signed, not Apple-notarized. Verify the published SHA-256 checksum if needed, or build from source. Checksums verify the download against the published release; they are not a Developer ID identity guarantee. Never disable system-wide security protections to run the app.
