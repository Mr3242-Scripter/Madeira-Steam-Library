import SwiftUI
import CoreLocation
import AVFoundation

struct SteamSettingsView: View {
    @StateObject private var model = SteamSignInModel.shared
    @StateObject private var location = BackgroundLocationController()
    @StateObject private var audio = SilentBackgroundAudioController()
    @StateObject private var downloads = SteamDownloadService.shared

    @State private var account = ""
    @State private var password = ""
    @State private var guardCode = ""
    @State private var useQR = false
    @State private var confirmFactoryReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Steam account") {
                    if model.signedIn {
                        Label(
                            model.accountName ?? "Signed in",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)

                        Button("Sign out", role: .destructive) {
                            model.signOut()
                        }
                    } else {
                        Picker("Sign-in method", selection: $useQR) {
                            Text("Password").tag(false)
                            Text("QR code").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if useQR {
                            Button {
                                model.beginQR()
                            } label: {
                                Label("Start QR sign-in", systemImage: "qrcode")
                            }

                            if let image = model.qrImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(maxWidth: 240, maxHeight: 240)
                                    .frame(maxWidth: .infinity)
                            }

                            if let link = model.qrLink {
                                ShareLink(item: link) {
                                    Label("Open sign-in link", systemImage: "arrow.up.right.square")
                                }
                            }
                        } else {
                            TextField("Steam account name", text: $account)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            SecureField("Password", text: $password)

                            Button("Sign in") {
                                let submitted = password
                                password = ""
                                model.signIn(account: account, password: submitted)
                            }
                            .disabled(
                                account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || password.isEmpty
                                || model.signInBusy
                            )
                        }

                        if model.guardPrompt != nil {
                            SecureField("Steam Guard code", text: $guardCode)
                                .textInputAutocapitalization(.characters)

                            Button("Submit code") {
                                let submitted = guardCode
                                guardCode = ""
                                model.submitGuardCode(submitted)
                            }
                            .disabled(
                                guardCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.signInBusy
                            )
                        }

                        if model.signInBusy {
                            ProgressView("Connecting to Steam…")
                        }

                        if let error = model.signInError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                }

                Section("Background operation") {
                    Toggle(
                        "Use location in background",
                        isOn: Binding(
                            get: { location.isEnabled },
                            set: { location.setEnabled($0) }
                        )
                    )

                    if !location.status.isEmpty {
                        Text(location.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text(
                        "Requires Always location permission and a normal (non-LiveContainer) install with the Location background mode. Under LiveContainer this crashes iOS Core Location, so the toggle stays off. Prefer silent background audio there."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Toggle(
                        "Silent background audio",
                        isOn: Binding(
                            get: { audio.isEnabled },
                            set: { audio.setEnabled($0) }
                        )
                    )

                    if !audio.status.isEmpty {
                        Text(audio.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text(
                        "Plays silent audio while enabled. This does not guarantee that iOS will keep the app running indefinitely."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Storage") {
                    LabeledContent("Device free") {
                        Text(byteString(downloads.deviceFreeBytes))
                    }
                    if downloads.deviceTotalBytes > 0 {
                        LabeledContent("Device total") {
                            Text(byteString(downloads.deviceTotalBytes))
                        }
                    }
                    LabeledContent("Downloaded games") {
                        Text(byteString(downloads.steamAppsBytes))
                    }

                    if downloads.localGames.isEmpty {
                        Text("No local game copies yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(downloads.localGames) { game in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name)
                                    Text(
                                        game.hasPartial
                                            ? "Incomplete · \(byteString(game.bytesOnDisk))"
                                            : "Installed · \(byteString(game.bytesOnDisk))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    downloads.deleteLocalCopy(appID: game.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button("Delete all local copies", role: .destructive) {
                            downloads.deleteAllLocalCopies()
                        }
                    }
                }
                .onAppear {
                    downloads.refreshLocalInventory()
                }

                Section("Reset") {
                    Button("Erase all app data", role: .destructive) {
                        confirmFactoryReset = true
                    }
                    Text(
                        "Signs out of Steam, deletes every local game copy, and clears Settings preferences for this app. This cannot be undone."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Security") {
                    LabeledContent("Sign-in", value: "Madeira implementation")
                    LabeledContent("Token storage", value: "iOS Keychain")
                    Text(
                        "Downloads use Steam ownership checks (depot keys). Install records use Madeira-compatible appmanifest format under Documents/steamapps."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Erase all app data?",
                isPresented: $confirmFactoryReset,
                titleVisibility: .visible
            ) {
                Button("Erase everything", role: .destructive) {
                    audio.setEnabled(false)
                    location.setEnabled(false)
                    downloads.factoryReset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Steam login, local games, download journals, and app preferences will be removed from this device.")
            }
        }
    }

    private func byteString(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, n), countStyle: .file)
    }
}
