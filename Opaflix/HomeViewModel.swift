import Foundation
import Observation

// MARK: - Loading / Error States

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Home ViewModel

@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State

    var trendingMovies: [MediaItem] = []
    var trendingTVShows: [MediaItem] = []
    var searchResults: [MediaItem] = []
    var featuredItems: [MediaItem] = []

    var moviesState: LoadingState = .idle
    var tvShowsState: LoadingState = .idle
    var searchState: LoadingState = .idle

    var searchQuery: String = ""
    var hasSearched: Bool = false

    // MARK: - Private

    private let service = TMDbService.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - Initial Fetch

    func loadTrendingContent() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTrendingMovies() }
            group.addTask { await self.fetchTrendingTVShows() }
        }
    }

    func fetchTrendingMovies() async {
        guard moviesState != .loading else { return }
        moviesState = .loading
        do {
            trendingMovies = try await service.fetchTrendingMovies()
            updateFeatured()
            moviesState = .loaded
        } catch {
            moviesState = .error(error.localizedDescription)
        }
    }

    func fetchTrendingTVShows() async {
        guard tvShowsState != .loading else { return }
        tvShowsState = .loading
        do {
            trendingTVShows = try await service.fetchTrendingTVShows()
            updateFeatured()
            tvShowsState = .loaded
        } catch {
            tvShowsState = .error(error.localizedDescription)
        }
    }

    private func updateFeatured() {
        // Build the hero carousel from the top-rated trending items
        let combined = (trendingMovies + trendingTVShows)
            .filter { $0.backdropPath != nil }
            .sorted { ($0.rating) > ($1.rating) }
        featuredItems = Array(combined.prefix(10))
    }

    // MARK: - Search (Debounced)

    func onSearchQueryChanged() {
        searchTask?.cancel()
        hasSearched = false

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchState = .idle
            return
        }

        searchTask = Task {
            // Debounce by 400ms
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    func performSearch(query: String) async {
        searchState = .loading
        hasSearched = true
        do {
            searchResults = try await service.searchAll(query: query)
            searchState = searchResults.isEmpty ? .error("No results found for \"\(query)\"") : .loaded
        } catch {
            if !(error is CancellationError) {
                searchState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    func refreshAll() async {
        await loadTrendingContent()
    }
}
