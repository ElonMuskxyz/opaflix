import SwiftUI

// MARK: - Opaflix App Entry Point

/// ═══════════════════════════════════════════════════
/// Opaflix — Movie & TV Show Streaming Client
/// ═══════════════════════════════════════════════════
///
/// Before running, open `TMDbService.swift` and replace
/// `YOUR_TMDB_API_KEY` with your actual TMDb API key from:
/// https://www.themoviedb.org/settings/api
///
/// The app fetches metadata from TMDb and embeds streams
/// via the Rivestream aggregator.

@main
struct OpaflixApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
