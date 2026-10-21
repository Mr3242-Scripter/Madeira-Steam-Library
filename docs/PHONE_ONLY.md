# Phone-only workflow (no Mac)

You do **not** need a Mac or Xcode on your device.

## How builds happen

GitHub Actions runs on `macos-15` runners every push to `main`:

1. Imports Madeira Steam sources
2. Builds an **unsigned** device IPA
3. Publishes it to the **nightly** pre-release

## Install on iPhone

1. Open the latest successful Actions run or the [nightly release](https://github.com/Mr3242-Scripter/Madeira-Steam-Library/releases/tag/nightly)
2. Download `MadeiraSteamLibrary.ipa`
3. Sideload with a tool that works on-device or via another phone workflow, for example:
   - **TrollStore** (if your device supports it) — install unsigned IPA persistently
   - **SideStore / AltStore** — needs a computer occasionally for refresh, or a friend with a Mac/PC
   - Any other signing service you already use for Madeira itself

The IPA is **unsigned** (`CODE_SIGNING_ALLOWED=NO`). Your sideload tool must sign it.

iSH cannot compile or codesign iOS apps. Use it only for git/curl if useful; the real build is CI.

## Develop without a Mac

1. Ask Grok (or edit on github.com) to change code
2. Push to `main`
3. Wait for Actions to finish
4. Download the new IPA from the nightly release or the workflow artifact
5. Sideload and test

Paste build errors from the Actions log back into chat so they can be fixed in the next commit.
