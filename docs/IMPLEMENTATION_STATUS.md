# Madeira Steam Library — implementation status

This is a standalone iOS companion. Madeira is used as a reference for Steam authentication and game-content compatibility; this repository does not copy the full Madeira source.

## CI and releases
- GitHub Actions builds an unsigned iOS device IPA and an iOS Simulator ZIP.
- The workflow uploads device and simulator build logs.
- The scheduled workflow updates the nightly prerelease.
- The device IPA is unsigned and must be signed by a supported sideloading tool before installation.

## Feature verification
- [x] SwiftUI app shell and Library tab exist.
- [x] Steam owned-games service source exists.
- [x] Nightly build/release workflow and build artifacts exist.
- [ ] Verify Steam sign-in end-to-end with a real account, including Steam Guard and QR flows.
- [ ] Verify owned-game retrieval for public/private libraries and error states.
- [ ] Implement and test a real download queue with progress, pause/cancel, retries, and disk-space checks.
- [ ] Implement Madeira-compatible manifest/depot acquisition and file assembly.
- [ ] Add installation/import handoff to Madeira and verify it with a downloaded game.
- [ ] Add automated tests for parsing, errors, and download-state transitions.

## Important limitation
A successful Xcode build only proves the configured target compiles. It does not prove that Steam authentication, owned-game retrieval, depot downloads, or import into Madeira works. Do not describe those features as complete until tested end-to-end.

## Downloader acceptance criteria
The downloader must use authenticated Steam session state from the existing sign-in flow, resolve app/depot manifests using the protocol Madeira actually supports, validate entitlements, download and verify chunks, reconstruct files safely in the app sandbox, expose progress and cancellation, handle expired sessions and insufficient disk space, and produce an install/import record accepted by Madeira. A store-page listing or public Steam Web API response alone is not enough to download game files.
