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
- [x] Importer pulls sign-in + library + **depot downloader** (Content/, Install/, Native decompressors).
- [x] `SteamDownloadService` + Install/Resume/Cancel UI on Library rows.
- [ ] Verify Steam sign-in end-to-end with a real account, including Steam Guard and QR flows.
- [ ] Verify owned-game retrieval for public/private libraries and error states.
- [ ] Live test download queue with progress, cancel, retries, and disk-space checks on device.
- [ ] Confirm install records are accepted by Madeira Dock discovery.
- [ ] Add automated tests for parsing, errors, and download-state transitions.

## Important limitation
A successful Xcode build only proves the configured target compiles. It does not prove that Steam authentication, owned-game retrieval, depot downloads, or import into Madeira works. Do not describe those features as complete until tested end-to-end.

## Downloader acceptance criteria
The downloader must use authenticated Steam session state from the existing sign-in flow, resolve app/depot manifests using the protocol Madeira actually supports, validate entitlements, download and verify chunks, reconstruct files safely in the app sandbox, expose progress and cancellation, handle expired sessions and insufficient disk space, and produce an install/import record accepted by Madeira. A store-page listing or public Steam Web API response alone is not enough to download game files.

## After pull / clone
```sh
sh scripts/import-madeira-steam-signin.sh
open MadeiraSteamLibrary.xcodeproj
```
Add any newly imported files under `App/SteamCore/Content`, `Install`, and `Native` to the target if Xcode does not pick them up automatically. Set the bridging header to:
`App/SteamCore/Native/MadeiraSteamLibrary-Bridging-Header.h`
Link `libz` (and system `lzma` if required by the shim).
