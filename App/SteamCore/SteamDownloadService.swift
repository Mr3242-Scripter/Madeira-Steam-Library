import Foundation
import SwiftUI

/// High-level download queue that uses Madeira's DepotDownloader against the
/// signed-in Steam session. Writes into the app Documents steamapps layout so
/// the result is Madeira-compatible (common/<installdir> + appmanifest_*.acf).
@MainActor
final class SteamDownloadService: ObservableObject {
    static let shared = SteamDownloadService()

    struct Job: Identifiable, Equatable {
        let id: Int
        let name: String
        var progress: SteamDownloadProgress
        var state: State
        var errorMessage: String?

        enum State: String {
            case queued, running, paused, finished, failed, cancelled
        }
    }

    /// Local install or incomplete download discovered on disk.
    struct LocalGame: Identifiable, Hashable {
        let id: Int
        let name: String
        let folderName: String?
        let isComplete: Bool
        let hasPartial: Bool
        let bytesOnDisk: Int64
    }

    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isBusy = false
    @Published private(set) var localGames: [LocalGame] = []
    @Published private(set) var steamAppsBytes: Int64 = 0
    @Published private(set) var deviceFreeBytes: Int64 = 0
    @Published private(set) var deviceTotalBytes: Int64 = 0

    private var activeTask: Task<Void, Never>?
    private var activeAppID: Int?

    var steamAppsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("steamapps", isDirectory: true)
    }

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func job(for appID: Int) -> Job? {
        jobs.first { $0.id == appID }
    }

    func hasPartialDownload(appID: Int) -> Bool {
        DepotDownloader.hasPartialDownload(appID: UInt32(appID), steamApps: steamAppsURL)
    }

    func isInstalled(appID: Int) -> Bool {
        let manifest = steamAppsURL.appendingPathComponent("appmanifest_\(appID).acf")
        return FileManager.default.fileExists(atPath: manifest.path)
    }

    /// Incomplete downloads that are not currently running (e.g. after a crash).
    func unfinishedDownloads() -> [LocalGame] {
        refreshLocalInventory()
        return localGames.filter { $0.hasPartial && !isRunning(appID: $0.id) }
    }

    func isRunning(appID: Int) -> Bool {
        activeAppID == appID && isBusy
    }

    func start(appID: Int, name: String, installDirectory: String) {
        guard SteamSignIn.isSignedIn else {
            upsert(Job(id: appID, name: name, progress: .init(), state: .failed,
                       errorMessage: "Sign in to Steam in Settings first."))
            return
        }
        if let existing = job(for: appID), existing.state == .running {
            return
        }

        upsert(Job(id: appID, name: name, progress: .init(phase: .preparing),
                   state: .queued, errorMessage: nil))

        activeTask?.cancel()
        activeAppID = appID
        isBusy = true

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runInstall(appID: appID, name: name)
        }
    }

    func cancel(appID: Int) {
        guard activeAppID == appID else { return }
        activeTask?.cancel()
        activeTask = nil
        activeAppID = nil
        isBusy = false
        if var job = job(for: appID) {
            job.state = .cancelled
            upsert(job)
        }
        refreshLocalInventory()
    }

    /// Removes install folder, appmanifest, and download journal for one app.
    @discardableResult
    func deleteLocalCopy(appID: Int) -> Bool {
        if activeAppID == appID {
            cancel(appID: appID)
        }
        let fm = FileManager.default
        let manifest = steamAppsURL.appendingPathComponent("appmanifest_\(appID).acf")
        let journal = steamAppsURL.appendingPathComponent("downloading/\(appID)", isDirectory: true)

        var folderName: String?
        if let data = try? Data(contentsOf: manifest),
           var parser = try? SteamKeyValues(data),
           let root = try? parser.read(),
           let state = root["AppState"],
           let dir = state["installdir"]?.string {
            folderName = dir
        }

        if let folderName, !folderName.isEmpty {
            let commonRoot = steamAppsURL.appendingPathComponent("common", isDirectory: true)
            let common = commonRoot.appendingPathComponent(folderName, isDirectory: true)
            if common.path.hasPrefix(commonRoot.path) {
                try? fm.removeItem(at: common)
            }
        }

        try? fm.removeItem(at: manifest)
        try? fm.removeItem(at: journal)

        jobs.removeAll { $0.id == appID }
        refreshLocalInventory()
        return true
    }

    /// Drop only the download journal (keep a finished install).
    func clearPartialJournal(appID: Int) {
        let journal = steamAppsURL.appendingPathComponent("downloading/\(appID)", isDirectory: true)
        try? FileManager.default.removeItem(at: journal)
        refreshLocalInventory()
    }

    func deleteLocalCopies(appIDs: [Int]) {
        for id in appIDs {
            deleteLocalCopy(appID: id)
        }
    }

    func deleteAllLocalCopies() {
        refreshLocalInventory()
        for game in localGames {
            deleteLocalCopy(appID: game.id)
        }
        let fm = FileManager.default
        for sub in ["downloading", "common", "depotcache"] {
            let url = steamAppsURL.appendingPathComponent(sub, isDirectory: true)
            try? fm.removeItem(at: url)
        }
        if let manifests = try? fm.contentsOfDirectory(at: steamAppsURL, includingPropertiesForKeys: nil) {
            for url in manifests where url.lastPathComponent.hasPrefix("appmanifest_") {
                try? fm.removeItem(at: url)
            }
        }
        jobs.removeAll()
        refreshLocalInventory()
    }

    /// Signs out of Steam, deletes all local installs, and clears app preferences.
    func factoryReset() {
        activeTask?.cancel()
        activeTask = nil
        activeAppID = nil
        isBusy = false

        deleteAllLocalCopies()

        SteamSignInModel.shared.signOut()
        SteamOwnedGamesService.shared.clear()

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "backgroundLocationEnabled")
        defaults.removeObject(forKey: "silentBackgroundAudioEnabled")

        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if !bundleID.isEmpty, let domain = defaults.persistentDomain(forName: bundleID) {
            for key in domain.keys {
                defaults.removeObject(forKey: key)
            }
        }

        jobs = []
        refreshLocalInventory()
    }

    func refreshLocalInventory() {
        let fm = FileManager.default
        try? fm.createDirectory(at: steamAppsURL, withIntermediateDirectories: true)

        var found: [Int: LocalGame] = [:]

        if let items = try? fm.contentsOfDirectory(at: steamAppsURL, includingPropertiesForKeys: nil) {
            for url in items {
                let name = url.lastPathComponent
                guard name.hasPrefix("appmanifest_"), name.hasSuffix(".acf") else { continue }
                let idStr = name
                    .replacingOccurrences(of: "appmanifest_", with: "")
                    .replacingOccurrences(of: ".acf", with: "")
                guard let appID = Int(idStr) else { continue }

                var displayName = "App \(appID)"
                var folder: String?
                var size: Int64 = 0

                if let data = try? Data(contentsOf: url),
                   var parser = try? SteamKeyValues(data),
                   let root = try? parser.read(),
                   let state = root["AppState"] {
                    if let n = state["name"]?.string, !n.isEmpty { displayName = n }
                    folder = state["installdir"]?.string
                    if let s = state["SizeOnDisk"]?.string, let v = Int64(s) {
                        size = v
                    }
                }

                if size == 0, let folder, !folder.isEmpty {
                    let common = steamAppsURL
                        .appendingPathComponent("common", isDirectory: true)
                        .appendingPathComponent(folder, isDirectory: true)
                    size = Self.directorySize(at: common)
                }

                let partial = hasPartialDownload(appID: appID)
                found[appID] = LocalGame(
                    id: appID,
                    name: displayName,
                    folderName: folder,
                    isComplete: true,
                    hasPartial: partial,
                    bytesOnDisk: size + Self.directorySize(
                        at: steamAppsURL.appendingPathComponent("downloading/\(appID)", isDirectory: true)
                    )
                )
            }
        }

        let downloadingRoot = steamAppsURL.appendingPathComponent("downloading", isDirectory: true)
        if let dirs = try? fm.contentsOfDirectory(at: downloadingRoot, includingPropertiesForKeys: nil) {
            for dir in dirs {
                guard let appID = Int(dir.lastPathComponent), found[appID] == nil else { continue }
                guard hasPartialDownload(appID: appID) else { continue }
                let size = Self.directorySize(at: dir)
                found[appID] = LocalGame(
                    id: appID,
                    name: "App \(appID) (incomplete)",
                    folderName: nil,
                    isComplete: false,
                    hasPartial: true,
                    bytesOnDisk: size
                )
            }
        }

        localGames = found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        steamAppsBytes = Self.directorySize(at: steamAppsURL)

        if let values = try? documentsURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]) {
            deviceFreeBytes = values.volumeAvailableCapacityForImportantUsage.map { Int64($0) } ?? 0
            deviceTotalBytes = values.volumeTotalCapacity.map { Int64($0) } ?? 0
        } else {
            deviceFreeBytes = 0
            deviceTotalBytes = 0
        }
    }

    private func runInstall(appID: Int, name: String) async {
        defer {
            isBusy = false
            activeAppID = nil
            activeTask = nil
            refreshLocalInventory()
        }

        do {
            try FileManager.default.createDirectory(at: steamAppsURL, withIntermediateDirectories: true)

            let session = SteamSession()
            let fetcher = SteamLibraryFetcher(session: session)
            let apps = try await fetcher.fetchOwnedApps()
            guard let app = apps.first(where: { Int($0.appID) == appID }) else {
                throw SteamFileError.invalid("App \(appID) is not in the owned library.")
            }

            upsert(Job(id: appID, name: name, progress: .init(phase: .preparing),
                       state: .running, errorMessage: nil))

            let downloader = DepotDownloader(session: session)
            let installURL = try await downloader.install(
                app,
                steamApps: steamAppsURL,
                ownedDepots: { nil }
            ) { [weak self] prog in
                Task { @MainActor in
                    guard let self else { return }
                    if var job = self.job(for: appID) {
                        job.progress = prog
                        job.state = .running
                        self.upsert(job)
                    }
                }
            }

            _ = installURL

            // Successful install: drop journal so the row is not stuck as "incomplete"
            clearPartialJournal(appID: appID)

            upsert(Job(
                id: appID,
                name: name,
                progress: SteamDownloadProgress(phase: .finishing, totalBytes: 1, doneBytes: 1),
                state: .finished,
                errorMessage: nil
            ))
        } catch is CancellationError {
            if var job = job(for: appID) {
                job.state = .cancelled
                upsert(job)
            }
        } catch {
            upsert(Job(
                id: appID,
                name: name,
                progress: .init(),
                state: .failed,
                errorMessage: SteamSignIn.message(error)
            ))
        }
    }

    private func upsert(_ job: Job) {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.insert(job, at: 0)
        }
    }

    nonisolated private static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }
}
