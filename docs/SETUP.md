# Build and sign in

This repository has a minimal Xcode iOS app target. On a Mac with Xcode, Git, and curl:

1. Clone this repository.
2. Run `sh scripts/import-madeira-steam-signin.sh`.
3. Open `MadeiraSteamLibrary.xcodeproj`.
4. Build the shared `MadeiraSteamLibrary` scheme for an iOS simulator or your device.

The importer fetches only the existing sign-in module from the official Madeira source tree. It does not copy the complete Madeira repository. Review the imported license headers and the upstream Madeira Converter Exception before redistribution.

## Sign-in implementation

The Settings screen calls Madeira's `SteamSignInModel.shared`, including the original password + Steam Guard and QR workflows. The model stores tokens through Madeira's `SteamTokenStore` in the device-only Keychain. Credentials and tokens must not be printed or stored in app preferences.

## Known incomplete functionality

The Library tab is a placeholder. The actual owned-library fetcher and Madeira-compatible depot/install pipeline have not yet been ported. A future change must inspect and port their direct dependencies, preserve Valve's ownership checks, and verify the final install records with Madeira's scanner before claiming game downloads work.
