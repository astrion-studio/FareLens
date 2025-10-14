import Foundation
import Observation

@Observable
@MainActor
final class WatchlistsViewModel {
    var watchlists: [Watchlist] = []
    var isLoading = false
    var errorMessage: String?
    var showingCreateSheet = false
    var showingUpgradeAlert = false

    private let user: User

    init(user: User) {
        self.user = user
    }

    var canAddWatchlist: Bool {
        watchlists.count < user.maxWatchlists
    }

    var watchlistsRemaining: Int {
        max(0, user.maxWatchlists - watchlists.count)
    }

    func loadWatchlists() async {
        isLoading = true
        errorMessage = nil

        do {
            watchlists = try await WatchlistRepository.shared.fetchWatchlists()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func createWatchlist(_ watchlist: Watchlist) async {
        // Check tier limit
        guard canAddWatchlist else {
            showingUpgradeAlert = true
            return
        }

        do {
            let created = try await WatchlistRepository.shared.createWatchlist(watchlist)
            watchlists.append(created)
            showingCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateWatchlist(_ watchlist: Watchlist) async {
        do {
            let updated = try await WatchlistRepository.shared.updateWatchlist(watchlist)
            if let index = watchlists.firstIndex(where: { $0.id == updated.id }) {
                watchlists[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteWatchlist(_ watchlist: Watchlist) async {
        do {
            try await WatchlistRepository.shared.deleteWatchlist(id: watchlist.id)
            watchlists.removeAll { $0.id == watchlist.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleActive(_ watchlist: Watchlist) async {
        var updated = watchlist
        updated.isActive.toggle()
        await updateWatchlist(updated)
    }
}
