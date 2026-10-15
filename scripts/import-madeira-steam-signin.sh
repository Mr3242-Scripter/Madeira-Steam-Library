#!/bin/sh
set -eu
# Imports only sign-in source files. Does not clone/copy the full Madeira repo.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEST="$ROOT/App/SteamSignIn"
BASE="https://raw.githubusercontent.com/willfaust/Madeira/main/app/Madeira/SwiftSteam"
mkdir -p "$DEST/Auth" "$DEST/Core" "$DEST/Helpers" "$DEST/Proto"
fetch() {
  source_path="$1"; target_path="$2"; target="$DEST/$target_path"
  mkdir -p "$(dirname "$target")"
  echo "Fetching $source_path"
  curl --fail --location --silent --show-error "$BASE/$source_path" -o "$target"
  if ! grep -q 'SPDX-License-Identifier: GPL-3.0-or-later' "$target"; then
    echo "Unexpected content at $source_path; refusing to continue." >&2
    rm -f "$target"; exit 1
  fi
}
fetch "SteamSignIn.swift" "SteamSignIn.swift"
fetch "Auth/SteamAuthAPI.swift" "Auth/SteamAuthAPI.swift"
fetch "Auth/SteamCredentialAuth.swift" "Auth/SteamCredentialAuth.swift"
fetch "Auth/SteamQRAuth.swift" "Auth/SteamQRAuth.swift"
fetch "Auth/SteamTokenStore.swift" "Auth/SteamTokenStore.swift"
fetch "Core/SteamError.swift" "Core/SteamError.swift"
fetch "Helpers/SteamDevice.swift" "Helpers/SteamDevice.swift"
fetch "Helpers/SteamLog.swift" "Helpers/SteamLog.swift"
fetch "Proto/SteamProtoMessages.swift" "Proto/SteamProtoMessages.swift"
echo "Imported selected Madeira sign-in files into $DEST"
echo "Add these files to your iOS target in Xcode and review upstream licensing."
