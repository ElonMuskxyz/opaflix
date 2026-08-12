import SwiftUI

// MARK: - Detail ViewModel

@MainActor
@Observable
final class MovieDetailViewModel {
    var detail: MediaDetail?
    var seasons: [TVSeason] = []
    var episodes: [TVEpisode] = []
    var loadingState: LoadingState = .idle

    // TV picker state
    var selectedSeason: Int = 1
    var selectedEpisode: Int = 1
    var maxSeason: Int { detail?.seasonCount ?? 0 }
    var maxEpisode: Int { episodes.count }

    private let service = TMDbService.shared

    var isTVShow: Bool {
        detail?.isMovie == false
    }

    var displayTitle: String {
        detail?.displayTitle ?? ""
    }

    var displayDate: String {
        detail?.displayDate ?? ""
    }

    var overview: String {
        detail?.overview ?? "No overview available."
    }

    var rating: Double {
        detail?.rating ?? 0
    }

    var tagline: String {
        detail?.tagline ?? ""
    }

    var genreList: String {
        detail?.genres?.map(\.name).joined(separator: " • ") ?? ""
    }

    var runtime: String {
        detail?.displayRuntime ?? ""
    }

    var backdropURL: URL? {
        detail?.backdropURL
    }

    var posterURL: URL? {
        detail?.posterURL
    }

    func loadDetail(for item: MediaItem) async {
        loadingState = .loading
        do {
            if item.isMovie {
                detail = try await service.fetchMovieDetail(id: item.id)
            } else {
                detail = try await service.fetchTVDetail(id: item.id)
                if let maxS = detail?.seasonCount, maxS >= 1 {
                    selectedSeason = 1
                    try await loadEpisodes(season: 1)
                }
            }
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func loadEpisodes(season: Int) async {
        guard let tvId = detail?.id else { return }
        do {
            let seasonDetail = try await service.fetchSeasonDetail(tvId: tvId, seasonNumber: season)
            episodes = seasonDetail.episodes
            selectedEpisode = 1
        } catch {
            episodes = []
        }
    }

    func onSeasonChanged() async {
        await loadEpisodes(season: selectedSeason)
    }

    /// Builds the embed URL for the current selection.
    func embedURL() -> URL? {
        guard let id = detail?.id else { return nil }
        if isTVShow {
            return URL(string: "https://www.rivestream.app/embed?type=tv&id=\(id)&season=\(selectedSeason)&episode=\(selectedEpisode)")
        } else {
            return URL(string: "https://www.rivestream.app/embed?type=movie&id=\(id)")
        }
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    let mediaItem: MediaItem

    @State private var viewModel = MovieDetailViewModel()
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            Color(.black).ignoresSafeArea()

            switch viewModel.loadingState {
            case .idle, .loading:
                loadingView
            case .loaded:
                contentView
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle(viewModel.isTVShow ? "TV Show" : "Movie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showPlayer) {
            if let url = viewModel.embedURL() {
                PlayerView(streamURL: url, title: viewModel.displayTitle)
            }
        }
        .task {
            await viewModel.loadDetail(for: mediaItem)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.red)
                .scaleEffect(1.5)
            Text("Loading details...")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await viewModel.loadDetail(for: mediaItem) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // Backdrop
                backdropSection

                // Metadata
                VStack(alignment: .leading, spacing: 16) {
                    // Title + tagline
                    titleSection

                    // Rating, year, runtime, genres
                    metadataRow

                    // Genre chips
                    if !viewModel.genreList.isEmpty {
                        Text(viewModel.genreList)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Overview
                    overviewSection

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // TV Season/Episode pickers
                    if viewModel.isTVShow && viewModel.maxSeason > 0 {
                        seasonEpisodePickers
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }

                    // Watch Now button
                    watchNowButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Backdrop

    private var backdropSection: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: viewModel.backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 260)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                        }
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 260)
                        .overlay {
                            ProgressView().tint(.white)
                        }
                @unknown default:
                    EmptyView()
                }
            }

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.displayTitle)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            if !viewModel.tagline.isEmpty {
                Text(viewModel.tagline)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 16) {
            Label(
                String(format: "%.1f", viewModel.rating),
                systemImage: "star.fill"
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.yellow)

            if !viewModel.displayDate.isEmpty {
                Label(viewModel.displayDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            if !viewModel.runtime.isEmpty {
                Label(viewModel.runtime, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.white)

            Text(viewModel.overview)
                .font(.body)
                .foregroundStyle(.gray)
                .lineSpacing(4)
        }
    }

    // MARK: - Season / Episode Pickers

    private var seasonEpisodePickers: some View {
        VStack(spacing: 12) {
            // Season picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Season")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)

                Picker("Season", selection: $viewModel.selectedSeason) {
                    ForEach(1...viewModel.maxSeason, id: \.self) { season in
                        Text("Season \(season)").tag(season)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .onChange(of: viewModel.selectedSeason) { _, _ in
                    Task { await viewModel.onSeasonChanged() }
                }
            }

            // Episode picker
            if viewModel.maxEpisode > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Episode")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.gray)
                        .textCase(.uppercase)

                    Picker("Episode", selection: $viewModel.selectedEpisode) {
                        ForEach(1...viewModel.maxEpisode, id: \.self) { ep in
                            if let episode = viewModel.episodes.first(where: { $0.episodeNumber == ep }) {
                                Text("\(ep). \(episode.name)").tag(ep)
                            } else {
                                Text("Episode \(ep)").tag(ep)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Watch Now Button

    private var watchNowButton: some View {
        Button {
            showPlayer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Watch Now")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
    }
}
