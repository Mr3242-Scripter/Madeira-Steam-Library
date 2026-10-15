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
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Steam Library",
                systemImage: "gamecontroller",
                description: Text("The owned-game browser is not connected yet. Sign in under Settings while library integration is being built.")
            )
            .navigationTitle("Library")
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

                Section("Security") {
                    LabeledContent("Sign-in", value: "Madeira implementation")
                    LabeledContent("Token storage", value: "iOS Keychain")
                    Text("The owned-game browser and Madeira-compatible downloads are not connected yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
