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

    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isBusy = false

    private var activeTask: Task<Void, Never>?
    private var activeAppID: Int?

    /// Root for Steam library layout inside the app sandbox:
    /// Documents/steamapps/common/<installdir>
    /// Documents/steamapps/appmanifest_<id>.acf
    /// Documents/steamapps/downloading/
    var steamAppsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("steamapps", isDirectory: true)
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

    /// Start or resume a download for an owned app.
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
    }

    private func runInstall(appID: Int, name: String) async {
        defer {
            isBusy = false
            activeAppID = nil
            activeTask = nil
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

            let downloader = DepotDownloader(session: session.cmSession)
            let installURL = try await downloader.install(
                app,
                steamApps: steamAppsURL,
                ownedDepots: { nil },
                progress: { [weak self] prog in
                    Task { @MainActor in
                        guard let self else { return }
                        if var job = self.job(for: appID) {
                            job.progress = prog
                            job.state = .running
                            self.upsert(job)
                        }
                    }
                }
            )

            _ = installURL
            upsert(Job(id: appID, name: name,
                       progress: SteamDownloadProgress(phase: .finishing, totalBytes: 1, doneBytes: 1),
                       state: .finished, errorMessage: nil))
        } catch is CancellationError {
            if var job = job(for: appID) {
                job.state = .cancelled
                upsert(job)
            }
        } catch {
            upsert(Job(id: appID, name: name, progress: .init(),
                       state: .failed, errorMessage: SteamSignIn.message(error)))
        }
    }

    private func upsert(_ job: Job) {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.insert(job, at: 0)
        }
    }
}
