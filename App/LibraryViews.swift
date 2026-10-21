import SwiftUI

struct LibraryView: View {
    @StateObject private var library = SteamOwnedGamesService.shared
    @StateObject private var downloads = SteamDownloadService.shared

    @State private var recoveryQueue: [SteamDownloadService.LocalGame] = []
    @State private var recoveryCurrent: SteamDownloadService.LocalGame?
    @State private var showRecovery = false

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
                            presentRecoveryIfNeeded()
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
                presentRecoveryIfNeeded()
            }
            .alert(
                "Incomplete download",
                isPresented: $showRecovery,
                presenting: recoveryCurrent
            ) { game in
                Button("Continue download") {
                    let name = library.games.first(where: { $0.id == game.id })?.name ?? game.name
                    let dir = library.games.first(where: { $0.id == game.id })?.installDirectory ?? game.folderName ?? ""
                    downloads.start(appID: game.id, name: name, installDirectory: dir)
                    advanceRecovery()
                }
                Button("Delete local copy", role: .destructive) {
                    downloads.deleteLocalCopy(appID: game.id)
                    advanceRecovery()
                }
                Button("Skip", role: .cancel) {
                    advanceRecovery()
                }
            } message: { game in
                let size = ByteCountFormatter.string(fromByteCount: game.bytesOnDisk, countStyle: .file)
                Text("“\(game.name)” (App \(game.id)) was interrupted. About \(size) is still on this device. Resume the download, or delete the local files?")
            }
        }
    }

    private func presentRecoveryIfNeeded() {
        let unfinished = downloads.unfinishedDownloads()
        guard !unfinished.isEmpty else { return }
        recoveryQueue = unfinished
        recoveryCurrent = recoveryQueue.first
        showRecovery = recoveryCurrent != nil
    }

    private func advanceRecovery() {
        if !recoveryQueue.isEmpty {
            recoveryQueue.removeFirst()
        }
        recoveryCurrent = recoveryQueue.first
        showRecovery = recoveryCurrent != nil
    }
}

struct GameRowView: View {
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
