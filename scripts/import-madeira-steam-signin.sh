#!/bin/sh
set -eu
# Selectively imports only Steam sign-in and owned-library source files.
# This does not clone or copy the full Madeira repository.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/App"
BASE="https://raw.githubusercontent.com/willfaust/Madeira/main/app/Madeira/SwiftSteam"
mkdir -p "$APP/SteamSignIn/Auth" "$APP/SteamSignIn/Core" "$APP/SteamSignIn/Helpers" "$APP/SteamSignIn/Proto"
mkdir -p "$APP/SteamCore/Core" "$APP/SteamCore/Library"
fetch() {
  source_path="$1"; target_path="$2"; target="$APP/$target_path"
  mkdir -p "$(dirname "$target")"
  echo "Fetching $source_path"
  curl --fail --location --silent --show-error "$BASE/$source_path" -o "$target"
  if ! grep -q 'SPDX-License-Identifier: GPL-3.0-or-later' "$target"; then
    echo "Unexpected content at $source_path; refusing to continue." >&2
    rm -f "$target"; exit 1
  fi
}
# Existing Madeira sign-in flow: password, Steam Guard, QR and device-only Keychain.
fetch "SteamSignIn.swift" "SteamSignIn/SteamSignIn.swift"
fetch "Auth/SteamAuthAPI.swift" "SteamSignIn/Auth/SteamAuthAPI.swift"
fetch "Auth/SteamCredentialAuth.swift" "SteamSignIn/Auth/SteamCredentialAuth.swift"
fetch "Auth/SteamQRAuth.swift" "SteamSignIn/Auth/SteamQRAuth.swift"
fetch "Auth/SteamTokenStore.swift" "SteamSignIn/Auth/SteamTokenStore.swift"
fetch "Core/SteamError.swift" "SteamSignIn/Core/SteamError.swift"
fetch "Helpers/SteamDevice.swift" "SteamSignIn/Helpers/SteamDevice.swift"
fetch "Proto/SteamProtoMessages.swift" "SteamSignIn/Proto/SteamProtoMessages.swift"

# Owned library protocol/PICS subset only; no Dock, emulator, game launch or cloud code.
fetch "Core/CMServerList.swift" "SteamCore/Core/CMServerList.swift"
fetch "Core/SteamConnection.swift" "SteamCore/Core/SteamConnection.swift"
fetch "Core/SteamMessageCodec.swift" "SteamCore/Core/SteamMessageCodec.swift"
fetch "Core/SteamProtocol.swift" "SteamCore/Core/SteamProtocol.swift"
fetch "Core/SteamCMSession.swift" "SteamCore/Core/SteamCMSession.swift"
fetch "Core/SteamSession.swift" "SteamCore/Core/SteamSession.swift"
fetch "Library/SteamAppInfo.swift" "SteamCore/Library/SteamAppInfo.swift"
fetch "Library/SteamLibraryFetcher.swift" "SteamCore/Library/SteamLibraryFetcher.swift"

# Madeira's helper logs through its app-specific LogStore. Adapt only that
# integration point to OSLog, with message content masked in system logs.
cat > "$APP/SteamSignIn/Helpers/SteamLog.swift" <<'SWIFT'
import Foundation
import OSLog

enum SteamLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.mr3242scripter.MadeiraSteamLibrary",
        category: "Steam"
    )
    static func event(_ message: String) {
        logger.info("\(message, privacy: .private(mask: .hash))")
    }
    static func trace(_ message: String) {
        logger.debug("\(message, privacy: .private(mask: .hash))")
    }
}
SWIFT
echo "Imported selected Madeira sign-in and owned-library files into App/"
echo "No downloader, Dock, emulator, game-launch, or unrelated Madeira files were copied."
