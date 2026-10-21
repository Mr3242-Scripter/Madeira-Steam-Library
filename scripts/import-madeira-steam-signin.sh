#!/bin/sh
set -eu
# Imports Madeira Steam sign-in, owned-library, and depot download sources.
# Does not copy the full Madeira repository.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/App"
BASE="https://raw.githubusercontent.com/willfaust/Madeira/main/app/Madeira/SwiftSteam"
APPBASE="https://raw.githubusercontent.com/willfaust/Madeira/main/app/Madeira"

mkdir -p "$APP/SteamSignIn/Auth" "$APP/SteamSignIn/Core" "$APP/SteamSignIn/Helpers" "$APP/SteamSignIn/Proto"
mkdir -p "$APP/SteamCore/Core" "$APP/SteamCore/Library" "$APP/SteamCore/Content" "$APP/SteamCore/Install" "$APP/SteamCore/Native"

fetch() {
  source_url="$1"; target_path="$2"; target="$APP/$target_path"
  mkdir -p "$(dirname "$target")"
  echo "Fetching $target_path"
  curl --fail --location --silent --show-error "$source_url" -o "$target"
  if ! grep -qE 'SPDX-License-Identifier: (GPL-3.0-or-later|BSD)' "$target" 2>/dev/null; then
    if ! grep -q 'Meta Platforms' "$target" 2>/dev/null; then
      echo "Unexpected content at $target_path; refusing to continue." >&2
      rm -f "$target"; exit 1
    fi
  fi
}

fetch_steam() {
  fetch "$BASE/$1" "$2"
}

# --- Sign-in ---
fetch_steam "SteamSignIn.swift" "SteamSignIn/SteamSignIn.swift"
fetch_steam "Auth/SteamAuthAPI.swift" "SteamSignIn/Auth/SteamAuthAPI.swift"
fetch_steam "Auth/SteamCredentialAuth.swift" "SteamSignIn/Auth/SteamCredentialAuth.swift"
fetch_steam "Auth/SteamQRAuth.swift" "SteamSignIn/Auth/SteamQRAuth.swift"
fetch_steam "Auth/SteamTokenStore.swift" "SteamSignIn/Auth/SteamTokenStore.swift"
fetch_steam "Core/SteamError.swift" "SteamSignIn/Core/SteamError.swift"
fetch_steam "Helpers/SteamDevice.swift" "SteamSignIn/Helpers/SteamDevice.swift"
fetch_steam "Proto/SteamProtoMessages.swift" "SteamSignIn/Proto/SteamProtoMessages.swift"

# --- Core connection / session ---
fetch_steam "Core/CMServerList.swift" "SteamCore/Core/CMServerList.swift"
fetch_steam "Core/LicenseListBox.swift" "SteamCore/Core/LicenseListBox.swift"
fetch_steam "Core/SteamConnection.swift" "SteamCore/Core/SteamConnection.swift"
fetch_steam "Core/SteamMessageCodec.swift" "SteamCore/Core/SteamMessageCodec.swift"
fetch_steam "Core/SteamProtocol.swift" "SteamCore/Core/SteamProtocol.swift"
fetch_steam "Core/SteamCMSession.swift" "SteamCore/Core/SteamCMSession.swift"
fetch_steam "Core/SteamSession.swift" "SteamCore/Core/SteamSession.swift"

# --- Owned library ---
fetch_steam "Library/SteamAppInfo.swift" "SteamCore/Library/SteamAppInfo.swift"
fetch_steam "Library/SteamLibraryFetcher.swift" "SteamCore/Library/SteamLibraryFetcher.swift"

# --- Depot download / decrypt / install record ---
fetch_steam "Content/DepotDownloader.swift" "SteamCore/Content/DepotDownloader.swift"
fetch_steam "Content/DepotManifest.swift" "SteamCore/Content/DepotManifest.swift"
fetch_steam "Content/ContentDecryptor.swift" "SteamCore/Content/ContentDecryptor.swift"
fetch_steam "Install/AppManifestWriter.swift" "SteamCore/Install/AppManifestWriter.swift"

# KeyValues lives outside SwiftSteam in upstream Madeira
fetch "$APPBASE/SteamKeyValues.swift" "SteamCore/Install/SteamKeyValues.swift"

# --- Native decompressors ---
fetch_steam "chunk_zip.c" "SteamCore/Native/chunk_zip.c"
fetch_steam "chunk_zip.h" "SteamCore/Native/chunk_zip.h"
fetch_steam "lzma_shim.c" "SteamCore/Native/lzma_shim.c"
fetch_steam "lzma_shim.h" "SteamCore/Native/lzma_shim.h"
fetch_steam "zstd_edu.c" "SteamCore/Native/zstd_edu.c"
fetch_steam "zstd_edu.h" "SteamCore/Native/zstd_edu.h"

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

echo "Imported sign-in, library, and depot-download sources into App/"
