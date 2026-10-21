import Foundation
import SwiftUI
import CoreLocation
import AVFoundation

@MainActor
final class BackgroundLocationController:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published private(set) var isEnabled =
        UserDefaults.standard.bool(forKey: "backgroundLocationEnabled")

    @Published private(set) var status = ""

    private let manager = CLLocationManager()

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
        let frameworks = Bundle.main.privateFrameworksPath ?? Bundle.main.bundlePath
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
            UserDefaults.standard.set(true, forKey: "backgroundLocationEnabled")
            enableLocationUpdates()
        } else {
            disableLocation(message: "Background location is off.")
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
            disableLocation(message: "Location Services are disabled on this iPhone.")
            return
        }
        switch manager.authorizationStatus {
        case .authorizedAlways:
            applyBackgroundLocationIfPossible()
        case .notDetermined:
            status = "Allow location access when prompted. Choose Always to permit background updates."
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            status = "Location is currently allowed only while the app is in use. Change permission to Always in iPhone Settings for background updates."
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            disableLocation(message: "Location permission is unavailable. Enable it in iPhone Settings to use background location.")
        @unknown default:
            disableLocation(message: "The current location permission is not supported.")
        }
    }

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
        UserDefaults.standard.set(false, forKey: "backgroundLocationEnabled")
        status = message
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.handleAuthorizationChange(manager)
        }
    }

    private func handleAuthorizationChange(_ manager: CLLocationManager) {
        guard isEnabled else { return }
        if manager.authorizationStatus == .authorizedAlways {
            applyBackgroundLocationIfPossible()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            disableLocation(message: "Location permission is unavailable. Enable it in iPhone Settings to use background location.")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = "Location update error: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class SilentBackgroundAudioController: ObservableObject {
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
            let player = try AVAudioPlayer(data: Self.silentWaveData())
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            guard player.play() else {
                throw NSError(
                    domain: "SilentBackgroundAudio",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The audio player could not start."]
                )
            }
            self.player = player
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "silentBackgroundAudioEnabled")
            status = "Silent background audio is playing."
        } catch {
            player?.stop()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isEnabled = false
            UserDefaults.standard.set(false, forKey: "silentBackgroundAudioEnabled")
            status = "Could not start silent audio: \(error.localizedDescription)"
        }
    }

    private func stopSilentAudio() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "silentBackgroundAudioEnabled")
    }

    private static func silentWaveData() -> Data {
        let sampleRate: UInt32 = 8_000
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let payloadSize = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendLE(payloadSize + 36, to: &data)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(channels, to: &data)
        appendLE(sampleRate, to: &data)
        appendLE(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8), to: &data)
        appendLE(channels * (bitsPerSample / 8), to: &data)
        appendLE(bitsPerSample, to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendLE(payloadSize, to: &data)
        data.append(Data(repeating: 0, count: Int(payloadSize)))
        return data
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) {
            data.append(contentsOf: $0)
        }
    }
}
