import SwiftUI

struct LibraryView: View {
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
                            downloads.refreshLocalInventory()
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
                downloads.refreshLocalInventory()
            }
        }
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

    private var partial: Bool {
        downloads.hasPartialDownload(appID: game.id)
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

            statusBlock
            actionRow
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBlock: some View {
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
            case .finished:
                Label("Installed (Madeira-compatible layout)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed:
                Text(job.errorMessage ?? "Download failed")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .cancelled:
                Text("Cancelled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .paused:
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if installed {
            Label("Installed (Madeira-compatible layout)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            if partial {
                Text("Leftover incomplete download data is still on disk.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        } else if partial {
            Label("Incomplete download on device", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if let job, job.state == .queued || job.state == .running {
            Button("Cancel", role: .destructive) {
                downloads.cancel(appID: game.id)
            }
            .font(.caption)
        } else if let job, job.state == .failed {
            HStack(spacing: 12) {
                Button("Try again") {
                    downloads.start(
                        appID: game.id,
                        name: game.name,
                        installDirectory: game.installDirectory
                    )
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)

                if partial || installed {
                    Button("Delete local copy", role: .destructive) {
                        downloads.deleteLocalCopy(appID: game.id)
                    }
                    .font(.caption)
                }
            }
        } else if installed && !partial {
            // Fully installed — only allow delete, not another Install
            Button("Delete local copy", role: .destructive) {
                downloads.deleteLocalCopy(appID: game.id)
            }
            .font(.caption)
        } else if partial {
            // Incomplete (with or without a finished-looking manifest leftover)
            HStack(spacing: 12) {
                Button("Continue download") {
                    downloads.start(
                        appID: game.id,
                        name: game.name,
                        installDirectory: game.installDirectory
                    )
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)

                Button("Delete local copy", role: .destructive) {
                    downloads.deleteLocalCopy(appID: game.id)
                }
                .font(.caption)
            }
        } else if !installed {
            Button("Install") {
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
