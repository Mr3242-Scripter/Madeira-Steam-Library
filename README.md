# Madeira Steam Library

A standalone iOS companion project for browsing a Steam account's owned games and integrating Madeira-compatible downloads. It is **not a copy or fork of the full Madeira repository**.

## Current status

- [x] Separate public repository and iOS Xcode project
- [x] Settings UI scaffold for password + Steam Guard and QR sign-in
- [x] Selective importer for Madeira's existing Steam sign-in implementation
- [x] macOS GitHub Actions build workflow
- [x] Owned Steam library listing
- [ ] Madeira-compatible game download/install pipeline
- [ ] Live device authentication and install verification

## Reuse Madeira's sign-in

Madeira's sign-in uses Valve's public `IAuthenticationService` with password + Steam Guard or QR authentication, then stores client tokens in the device-only iOS Keychain. The app UI is wired to the same `SteamSignInModel` API; it does not substitute Steam OpenID or a custom password handler.

On a Mac with Xcode and curl, run:

```sh
sh scripts/import-madeira-steam-signin.sh
```

This imports only these authentication files from the upstream source tree:
- `SteamSignIn.swift`
- `Auth/SteamAuthAPI.swift`
- `Auth/SteamCredentialAuth.swift`
- `Auth/SteamQRAuth.swift`
- `Auth/SteamTokenStore.swift`
- `Core/SteamError.swift`
- `Helpers/SteamDevice.swift`
- `Helpers/SteamLog.swift`
- `Proto/SteamProtoMessages.swift`

It does not copy Madeira's library, downloader, emulator, Dock, or unrelated code.

Reference docs:
- [Madeira Steam sign-in](https://github.com/willfaust/Madeira/blob/main/docs/STEAM_SIGNIN.md)
- [Madeira Steam library and downloads](https://github.com/willfaust/Madeira/blob/main/docs/STEAM_LIBRARY.md)

## Build

Open `MadeiraSteamLibrary.xcodeproj` in Xcode after running the importer. GitHub Actions also runs an iOS Simulator build after importing the same files.

## What remains

The Library tab is currently a placeholder; the owned-game fetcher is not implemented yet. The download/install pipeline is also not implemented yet. Those must be ported as a small, reviewed slice from Madeira with their direct dependencies, preserving Steam's ownership checks and Madeira's install-record format. No DRM or entitlement bypass is intended.

See [setup](docs/SETUP.md) and [implementation plan](docs/IMPLEMENTATION.md).

## Licensing and security

Imported sources keep their original copyright and SPDX headers. Review [the upstream Madeira Converter Exception](https://github.com/willfaust/Madeira/blob/main/LICENSE-EXCEPTION.md) before redistribution. Never commit Steam passwords, Steam Guard codes, tokens, or account exports; do not add credentials to logs or ordinary files.
