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
    @StateObject private var downloads = SteamDownloadService.shared

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
                        GameRowView(game: game, downloads: downloads)
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

private struct GameRowView: View {
    let game: SteamOwnedGameSummary
    @ObservedObject var downloads: SteamDownloadService

    private var job: SteamDownloadService.Job? {
        downloads.job(for: game.id)
    }

    private var installed: Bool {
        downloads.isInstalled(appID: game.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if installed {
                Label("Installed (Madeira-compatible layout)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let job {
                switch job.state {
                case .queued, .running:
                    ProgressView(value: job.progress.fraction) {
                        Text(statusText(for: job))
                            .font(.caption)
                    }
                    if job.progress.bytesPerSecond > 0 {
                        Text(speedText(job.progress.bytesPerSecond))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button("Cancel", role: .destructive) {
                        downloads.cancel(appID: game.id)
                    }
                    .font(.caption)
                case .finished:
                    Label("Download finished", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .failed:
                    Text(job.errorMessage ?? "Download failed")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Try again") {
                        downloads.start(
                            appID: game.id,
                            name: game.name,
                            installDirectory: game.installDirectory
                        )
                    }
                    .font(.caption)
                case .cancelled, .paused:
                    Text(job.state == .paused ? "Paused" : "Cancelled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(downloads.hasPartialDownload(appID: game.id) ? "Resume" : "Install") {
                        downloads.start(
                            appID: game.id,
                            name: game.name,
                            installDirectory: game.installDirectory
                        )
                    }
                    .font(.caption)
                }
            } else if !installed {
                Button(downloads.hasPartialDownload(appID: game.id) ? "Resume download" : "Install") {
                    downloads.start(
                        appID: game.id,
                        name: game.name,
                        installDirectory: game.installDirectory
                    )
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusText(for job: SteamDownloadService.Job) -> String {
        let pct = Int(job.progress.fraction * 100)
        switch job.progress.phase {
        case .preparing: return "Preparing…"
        case .downloading: return "Downloading \(pct)%"
        case .finishing: return "Finishing…"
        }
    }

    private func speedText(_ bps: Double) -> String {
        let s = ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file)
        return "\(s)/s"
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
                        "Downloads use Steam ownership checks (depot keys). Install records use Madeira-compatible appmanifest format under Documents/steamapps."
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

    /// True only when this process is allowed to use Core Location background updates.
    /// LiveContainer / sideload hosts often declare UIBackgroundModes but are not
    /// CL-backgroundable; setting allowsBackgroundLocationUpdates then aborts with
    /// `!stayUp || CLClientIsBackgroundable(...)`.
    private var isCoreLocationBackgroundable: Bool {
        if Self.runningUnderLiveContainer {
            return false
        }
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
              modes.contains("location") else {
            return false
        }
        return true
    }

    private static var runningUnderLiveContainer: Bool {
        let path = Bundle.main.bundlePath
        if path.localizedCaseInsensitiveContains("LiveContainer") {
            return true
        }
        if ProcessInfo.processInfo.environment["LIVECONTAINER_SHARED"] != nil {
            return true
        }
        let frameworks = Bundle.main.privateFrameworksPath
            ?? Bundle.main.bundlePath
        if frameworks.localizedCaseInsensitiveContains("LiveContainer") {
            return true
        }
        return false
    }

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
            if !isCoreLocationBackgroundable {
                isEnabled = false
                UserDefaults.standard.set(false, forKey: "backgroundLocationEnabled")
                status = Self.unavailableMessage
                return
            }
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

    private static let unavailableMessage =
        "Background location is not available in this install (e.g. LiveContainer). Core Location refuses background updates here, so the toggle is disabled to avoid a crash. Silent background audio may still help keep the process awake."

    private func enableLocationUpdates() {
        guard isCoreLocationBackgroundable else {
            disableLocation(message: Self.unavailableMessage)
            return
        }

        guard CLLocationManager.locationServicesEnabled() else {
            disableLocation(
                message: "Location Services are disabled on this iPhone."
            )
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways:
            applyBackgroundLocationIfPossible()

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

    /// Sets background flags only when safe; never asserts under LiveContainer.
    private func applyBackgroundLocationIfPossible() {
        guard isCoreLocationBackgroundable else {
            disableLocation(message: Self.unavailableMessage)
            return
        }
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        status = "Background location is enabled."
    }

    private func disableLocation(message: String) {
        manager.stopUpdatingLocation()
        if isCoreLocationBackgroundable {
            manager.allowsBackgroundLocationUpdates = false
        }

        isEnabled = false
        UserDefaults.standard.set(
            false,
            forKey: "backgroundLocationEnabled"
        )
        status = message
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            self.handleAuthorizationChange(manager)
        }
    }

    private func handleAuthorizationChange(_ manager: CLLocationManager) {
        guard isEnabled else { return }

        if manager.authorizationStatus == .authorizedAlways {
            applyBackgroundLocationIfPossible()
        } else if manager.authorizationStatus == .denied
                    || manager.authorizationStatus == .restricted {
            disableLocation(
                message: "Location permission is unavailable. Enable it in iPhone Settings to use background location."
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.status = "Location update error: \(error.localizedDescription)"
        }
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

            status = "Silent background audio is playing."
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
