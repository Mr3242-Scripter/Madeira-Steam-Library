# Project guide

This repository is independent of Madeira. It selectively imports only Madeira's existing Steam sign-in source; it does not copy the full Madeira project.

## Setup on Mac

1. Install Xcode and command-line tools.
2. From the repository root, run `sh scripts/import-madeira-steam-signin.sh`.
3. Open `MadeiraSteamLibrary.xcodeproj` in Xcode.
4. Select an iOS simulator or your own device and build. Live sign-in has not yet been verified from this separate target.

The importer fetches only `SteamSignIn.swift`, the sign-in transport and credential/QR/Keychain files, the sign-in error type, helper files, and the protocol messages from Madeira's public source. It does not clone or copy the whole Madeira repository.

## Current implementation state

- App entry point, Library/Settings tabs, and Steam sign-in form: scaffolded.
- Same Madeira sign-in implementation: imported by script, including password + Steam Guard and QR flows.
- Owned library listing: not connected yet.
- Madeira-compatible game download/install: not connected yet.

The library and installer must be ported as a separate, audited slice from Madeira. Keep Steam ownership checks and the install record format. Never log credentials or tokens. Source references and license notes are in README and docs/IMPLEMENTATION.md.
