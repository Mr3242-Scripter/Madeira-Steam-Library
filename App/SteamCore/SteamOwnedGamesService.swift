import Foundation
import SwiftUI

struct SteamOwnedGameSummary: Identifiable, Hashable {
    let id: Int
    let name: String
    let installDirectory: String
    let estimatedDownloadBytes: UInt64
    let headerImage: String?
}

@MainActor
final class SteamOwnedGamesService: ObservableObject {
    static let shared = SteamOwnedGamesService()

    @Published private(set) var games: [SteamOwnedGameSummary] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let session = SteamSession()
    private lazy var fetcher = SteamLibraryFetcher(session: session)

    func refresh() async {
        guard SteamSignIn.isSignedIn else {
            games = []
            error = "Sign in to Steam in Settings first."
            return
        }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let apps = try await fetcher.fetchOwnedApps()
            games = apps
                .filter(\.installableOnWindows)
                .map {
                    SteamOwnedGameSummary(
                        id: Int($0.appID),
                        name: $0.name,
                        installDirectory: $0.installDir,
                        estimatedDownloadBytes: $0.downloadSize(for: "windows"),
                        headerImage: $0.headerImage
                    )
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            self.error = SteamSignIn.message(error)
        }
    }
}
