# Implementation plan

## Sign-in
Reuse Madeira's existing implementation. Run `scripts/import-madeira-steam-signin.sh` to import only authentication files; the importer is limited to sign-in and token storage.

## Owned library
Madeira's library reads Steam license lists and app product information through a Steam connection-manager session. Inspect and port only those components and direct dependencies.

## Downloads
Use Madeira-compatible install layout and its depot/content pipeline. Preserve Steam ownership checks, validate manifest paths, and mark a game installed only after files and install records are complete. Do not bypass DRM or entitlement checks.

## Verification
- Build the iOS target with imported sign-in files.
- Exercise password, Steam Guard, QR, cancellation, expired QR, and sign-out on device.
- Confirm credentials and tokens never appear in logs or ordinary files.
- Confirm Keychain storage is device-only and removed on sign-out.
- Test library refresh/download only with an account that owns the relevant app.
