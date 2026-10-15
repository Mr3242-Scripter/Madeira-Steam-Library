import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
            SteamSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.blue)
    }
}

private struct LibraryView: View {
    @StateObject private var library = SteamOwnedGamesService.shared

    var body: some View {
        NavigationStack {
            Group {
                if library.isLoading && library.games.isEmpty {
                    ProgressView("Loading owned Steam games…")
                } else if let error = library.error, library.games.isEmpty {
                    ContentUnavailableView("Steam Library", systemImage: "gamecontroller",
                        description: Text(error))
                } else if library.games.isEmpty {
                    ContentUnavailableView("No games loaded", systemImage: "gamecontroller",
                        description: Text("Sign in to Steam, then tap Refresh."))
                } else {
                    List(library.games) { game in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(game.name).font(.headline)
                            Text("App ID: \(game.id)")
                                .font(.caption).foregroundStyle(.secondary)
                            if game.estimatedDownloadBytes > 0 {
                                Text("Approx. download: \(ByteCountFormatter.string(fromByteCount: Int64(clamping: game.estimatedDownloadBytes), countStyle: .file))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("Madeira-compatible download integration is still in progress.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Steam Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await library.refresh() }
                    } label: {
                        if library.isLoading { ProgressView() }
                        else { Label("Refresh", systemImage: "arrow.clockwise") }
                    }
                    .disabled(library.isLoading)
                }
            }
            .task {
                if library.games.isEmpty && !library.isLoading {
                    await library.refresh()
                }
            }
        }
    }
}

private struct SteamSettingsView: View {
    @StateObject private var model = SteamSignInModel.shared
    @State private var account = ""
    @State private var password = ""
    @State private var guardCode = ""
    @State private var useQR = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Steam account") {
                    if model.signedIn {
                        Label(model.accountName ?? "Signed in", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Sign out", role: .destructive) { model.signOut() }
                    } else {
                        Picker("Sign-in method", selection: $useQR) {
                            Text("Password").tag(false)
                            Text("QR code").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if useQR {
                            Button { model.beginQR() } label: {
                                Label("Start QR sign-in", systemImage: "qrcode")
                            }
                            if let image = model.qrImage {
                                Image(uiImage: image).resizable().interpolation(.none)
                                    .scaledToFit().frame(maxWidth: 240, maxHeight: 240)
                                    .frame(maxWidth: .infinity)
                            }
                            if let link = model.qrLink {
                                ShareLink(item: link) {
                                    Label("Open sign-in link", systemImage: "arrow.up.right.square")
                                }
                            }
                        } else {
                            TextField("Steam account name", text: $account)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            SecureField("Password", text: $password)
                            Button("Sign in") {
                                let submitted = password
                                password = ""
                                model.signIn(account: account, password: submitted)
                            }
                            .disabled(account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || model.signInBusy)
                        }

                        if model.guardPrompt != nil {
                            SecureField("Steam Guard code", text: $guardCode)
                                .textInputAutocapitalization(.characters)
                            Button("Submit code") {
                                let submitted = guardCode
                                guardCode = ""
                                model.submitGuardCode(submitted)
                            }
                            .disabled(guardCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.signInBusy)
                        }
                        if model.signInBusy { ProgressView("Connecting to Steam…") }
                        if let error = model.signInError {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
                Section("Security") {
                    LabeledContent("Sign-in", value: "Madeira implementation")
                    LabeledContent("Token storage", value: "iOS Keychain")
                    Text("Downloads are not enabled until the Madeira-compatible installer is integrated.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
