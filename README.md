# Madeira Steam Library

A standalone iOS companion project for browsing a Steam account's owned games and integrating Madeira-compatible downloads. It is **not a copy or fork of the full Madeira repository**.

## Current status

- [x] Separate public repository and iOS Xcode project
- [x] Settings UI scaffold for password + Steam Guard and QR sign-in
- [x] Selective importer for Madeira's existing Steam sign-in implementation
- [x] macOS GitHub Actions build workflow
- [x] Owned Steam library listing
- [x] Madeira-compatible game download/install pipeline (source + UI; needs live device verification)
- [ ] Live device authentication and install verification with Madeira

## Reuse Madeira's sign-in and downloader

Madeira's sign-in uses Valve's public `IAuthenticationService` with password + Steam Guard or QR authentication, then stores client tokens in the device-only iOS Keychain. The app UI is wired to the same `SteamSignInModel` API; it does not substitute Steam OpenID or a custom password handler.

Downloads use Madeira's `DepotDownloader` / `ContentDecryptor` / `AppManifestWriter` stack. Ownership is enforced by Steam (depot keys and manifest request codes). Install layout is `Documents/steamapps/common/<installdir>` plus `appmanifest_<appid>.acf`.

On a Mac with Xcode and curl, run:

```sh
sh scripts/import-madeira-steam-signin.sh
```

This imports authentication, library, content, install-record, and native decompressor files from the upstream source tree. It does not clone the whole Madeira repository.

Reference docs:
- [Madeira Steam sign-in](https://github.com/willfaust/Madeira/blob/main/docs/STEAM_SIGNIN.md)
- [Madeira Steam library and downloads](https://github.com/willfaust/Madeira/blob/main/docs/STEAM_LIBRARY.md)

## Build

1. Run the importer (above).
2. Open `MadeiraSteamLibrary.xcodeproj` in Xcode.
3. Ensure imported files under `App/SteamCore/Content`, `Install`, and `Native` are in the app target.
4. Set **Objective-C Bridging Header** to `App/SteamCore/Native/MadeiraSteamLibrary-Bridging-Header.h`.
5. Link `libz` (Build Phases → Link Binary With Libraries).
6. Build for Simulator or device.

GitHub Actions also runs an iOS Simulator build after importing the same files.

## What remains

Live verification on a real device: sign-in, library refresh, a small owned title download, and confirmation that Madeira Dock sees the install record. See [setup](docs/SETUP.md) and [implementation status](docs/IMPLEMENTATION_STATUS.md).

## Licensing and security

Imported sources keep their original copyright and SPDX headers. Review [the upstream Madeira Converter Exception](https://github.com/willfaust/Madeira/blob/main/LICENSE-EXCEPTION.md) before redistribution. Never commit Steam passwords, Steam Guard codes, tokens, or account exports; do not add credentials to logs or ordinary files.
