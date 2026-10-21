import SwiftUI
import UIKit
import CoreLocation
import AVFoundation

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }

            SteamSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
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
                } else if let error = library.error,
                          library.games.isEmpty {
                    ContentUnavailableView(
                        "Steam Library",
                        systemImage: "gamecontroller",
                        description: Text(error)
                    )
                } else if library.games.isEmpty {
                    ContentUnavailableView(
                        "No games loaded",
                        systemImage: "gamecontroller",
                        description: Text("Sign in to Steam, then tap Refresh.")
                    )
                } else {
                    List(library.games) { game in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(game.name)
                                .font(.headline)

                            Text("App ID: \(game.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if game.estimatedDownloadBytes > 0 {
                                Text(
                                    "Approx. download: \(ByteCountFormatter.string(fromByteCount: Int64(clamping: game.estimatedDownloadBytes), countStyle: .file))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Text(
                                "Madeira-compatible download integration is still in progress."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Steam Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await library.refresh()
                        }
                    } label: {
                        if library.isLoading {
                            ProgressView()
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
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
    @StateObject private var location = BackgroundLocationController()
    @StateObject private var audio = SilentBackgroundAudioController()

    @State private var account = ""
    @State private var password = ""
    @State private var guardCode = ""
    @State private var useQR = false

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
                                Label(
                                    "Start QR sign-in",
                                    systemImage: "qrcode"
                                )
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
                                    Label(
                                        "Open sign-in link",
                                        systemImage: "arrow.up.right.square"
                                    )
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
                                model.signIn(
                                    account: account,
                                    password: submitted
                                )
                            }
                            .disabled(
                                account.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                                || password.isEmpty
                                || model.signInBusy
                            )
                        }

                        if model.guardPrompt != nil {
                            SecureField(
                                "Steam Guard code",
                                text: $guardCode
                            )
                            .textInputAutocapitalization(.characters)

                            Button("Submit code") {
                                let submitted = guardCode
                                guardCode = ""
                                model.submitGuardCode(submitted)
                            }
                            .disabled(
                                guardCode.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
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
                        "Requires location permission and the Location background mode in the Xcode project. Location updates can use additional battery. iOS may still suspend background work."
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

                Section("Security") {
                    LabeledContent(
                        "Sign-in",
                        value: "Madeira implementation"
                    )

                    LabeledContent(
                        "Token storage",
                        value: "iOS Keychain"
                    )

                    Text(
                        "Downloads are not enabled until the Madeira-compatible installer is integrated."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

@MainActor
private final class BackgroundLocationController:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published private(set) var isEnabled =
        UserDefaults.standard.bool(forKey: "backgroundLocationEnabled")

    @Published private(set) var status = ""

    private let manager = CLLocationManager()

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 100

        if isEnabled {
            enableLocationUpdates()
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }

        if enabled {
            isEnabled = true
            UserDefaults.standard.set(
                true,
                forKey: "backgroundLocationEnabled"
            )
            enableLocationUpdates()
        } else {
            disableLocation(
                message: "Background location is off."
            )
        }
    }

    private func enableLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            disableLocation(
                message: "Location Services are disabled on this iPhone."
            )
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = true
            manager.startUpdatingLocation()
            status = "Background location is enabled."

        case .notDetermined:
            status =
                "Allow location access when prompted. Choose Always to permit background updates."
            manager.requestAlwaysAuthorization()

        case .authorizedWhenInUse:
            status =
                "Location is currently allowed only while the app is in use. Change permission to Always in iPhone Settings for background updates."
            manager.requestAlwaysAuthorization()

        case .denied, .restricted:
            disableLocation(
                message: "Location permission is unavailable. Enable it in iPhone Settings to use background location."
            )

        @unknown default:
            disableLocation(
                message: "The current location permission is not supported."
            )
        }
    }

    private func disableLocation(message: String) {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false

        isEnabled = false
        UserDefaults.standard.set(
            false,
            forKey: "backgroundLocationEnabled"
        )
        status = message
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        guard isEnabled else { return }

        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = true
            manager.startUpdatingLocation()
            status = "Background location is enabled."
        } else if manager.authorizationStatus == .denied
                    || manager.authorizationStatus == .restricted {
            disableLocation(
                message: "Location permission is unavailable. Enable it in iPhone Settings to use background location."
            )
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        status = "Location update error: \(error.localizedDescription)"
    }
}

@MainActor
private final class SilentBackgroundAudioController: ObservableObject {
    @Published private(set) var isEnabled =
        UserDefaults.standard.bool(forKey: "silentBackgroundAudioEnabled")

    @Published private(set) var status = ""

    private var player: AVAudioPlayer?

    init() {
        if isEnabled {
            startSilentAudio()
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }

        if enabled {
            startSilentAudio()
        } else {
            stopSilentAudio()
            status = "Silent background audio is off."
        }
    }

    private func startSilentAudio() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(
                data: Self.silentWaveData()
            )

            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()

            guard player.play() else {
                throw NSError(
                    domain: "SilentBackgroundAudio",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The audio player could not start."
                    ]
                )
            }

            self.player = player
            isEnabled = true

            UserDefaults.standard.set(
                true,
                forKey: "silentBackgroundAudioEnabled"
            )

            status = "Silent audio is playing."
        } catch {
            player?.stop()
            player = nil

            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )

            isEnabled = false

            UserDefaults.standard.set(
                false,
                forKey: "silentBackgroundAudioEnabled"
            )

            status =
                "Could not start silent audio: \(error.localizedDescription)"
        }
    }

    private func stopSilentAudio() {
        player?.stop()
        player = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )

        isEnabled = false

        UserDefaults.standard.set(
            false,
            forKey: "silentBackgroundAudioEnabled"
        )
    }

    private static func silentWaveData() -> Data {
        let sampleRate: UInt32 = 8_000
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let payloadSize =
            sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)

        var data = Data()

        data.append(contentsOf: Array("RIFF".utf8))
        appendLE(payloadSize + 36, to: &data)

        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(channels, to: &data)
        appendLE(sampleRate, to: &data)
        appendLE(
            sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8),
            to: &data
        )
        appendLE(channels * (bitsPerSample / 8), to: &data)
        appendLE(bitsPerSample, to: &data)

        data.append(contentsOf: Array("data".utf8))
        appendLE(payloadSize, to: &data)
        data.append(Data(repeating: 0, count: Int(payloadSize)))

        return data
    }

    private static func appendLE<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian

        withUnsafeBytes(of: &littleEndian) {
            data.append(contentsOf: $0)
        }
    }
}
