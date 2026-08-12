import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var searchText = ""
    @State private var selectedMedia: MediaItem?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Dark background
                Color(.black).ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Hero Carousel
                        if !viewModel.featuredItems.isEmpty {
                            HeroCarouselView(items: viewModel.featuredItems) { item in
                                navigationPath.append(item)
                            }
                            .frame(height: 260)
                        }

                        // Content rows
                        VStack(alignment: .leading, spacing: 28) {
                            // Trending Movies row
                            MediaRowView(
                                title: "Trending Movies",
                                items: viewModel.trendingMovies,
                                state: viewModel.moviesState
                            ) { item in
                                navigationPath.append(item)
                            }

                            // Trending TV Shows row
                            MediaRowView(
                                title: "Trending TV Shows",
                                items: viewModel.trendingTVShows,
                                state: viewModel.tvShowsState
                            ) { item in
                                navigationPath.append(item)
                            }

                            // Search results (only when searching)
                            if viewModel.hasSearched {
                                MediaRowView(
                                    title: "Results for \"\(viewModel.searchQuery)\"",
                                    items: viewModel.searchResults,
                                    state: viewModel.searchState
                                ) { item in
                                    navigationPath.append(item)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Opaflix")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: MediaItem.self) { item in
                MovieDetailView(mediaItem: item)
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search movies & TV shows..."
            )
            .onChange(of: searchText) { _, newValue in
                viewModel.searchQuery = newValue
                viewModel.onSearchQueryChanged()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.red)
        .task {
            await viewModel.loadTrendingContent()
        }
        .refreshable {
            await viewModel.refreshAll()
        }
    }
}

// MARK: - Hero Carousel

struct HeroCarouselView: View {
    let items: [MediaItem]
    let onTap: (MediaItem) -> Void

    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HeroCardView(item: item)
                    .tag(index)
                    .onTapGesture { onTap(item) }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % max(items.count, 1)
            }
        }
        .overlay(alignment: .bottom) {
            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<items.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.red : Color.white.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

struct HeroCardView: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            AsyncImage(url: item.backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipped()
                case .failure:
                    fallbackView
                case .empty:
                    shimmerView
                @unknown default:
                    fallbackView
                }
            }

            // Gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.85)]),
                startPoint: .center,
                endPoint: .bottom
            )

            // Title & metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(
                        String(format: "%.1f", item.rating),
                        systemImage: "star.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.yellow)

                    if !item.displayDate.isEmpty {
                        Text("•")
                            .foregroundStyle(.gray)
                        Text(item.displayDate)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }

                    Text(item.isMovie ? "Movie" : "TV Show")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    private var fallbackView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: 260)
    }

    private var shimmerView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(maxWidth: .infinity, maxHeight: 260)
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }
}

// MARK: - Media Row View

struct MediaRowView: View {
    let title: String
    let items: [MediaItem]
    let state: LoadingState
    let onTap: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            switch state {
            case .idle, .loading:
                loadingRow
            case .loaded:
                if items.isEmpty {
                    emptyRow
                } else {
                    contentRow
                }
            case .error(let message):
                errorRow(message: message)
            }
        }
    }

    private var contentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                // Leading spacer
                Color.clear.frame(width: 4)

                ForEach(items) { item in
                    MediaPosterCard(item: item)
                        .onTapGesture { onTap(item) }
                }

                // Trailing spacer
                Color.clear.frame(width: 4)
            }
        }
    }

    private var loadingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                Color.clear.frame(width: 4)
                ForEach(0..<6, id: \.self) { _ in
                    PosterPlaceholder()
                }
                Color.clear.frame(width: 4)
            }
        }
        .disabled(true)
    }

    private var emptyRow: some View {
        Text("Nothing here yet.")
            .font(.subheadline)
            .foregroundStyle(.gray)
            .padding(.horizontal, 16)
    }

    private func errorRow(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Media Poster Card

struct MediaPosterCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 210)
                        .clipped()
                case .failure:
                    posterFallback
                case .empty:
                    posterShimmer
                @unknown default:
                    posterFallback
                }
            }
            .frame(width: 140, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

            // Title
            Text(item.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            // Rating
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text(String(format: "%.1f", item.rating))
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
    }

    private var posterFallback: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 140, height: 210)
            .overlay {
                Image(systemName: item.isMovie ? "film" : "tv")
                    .font(.title)
                    .foregroundStyle(.gray)
            }
    }

    private var posterShimmer: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 140, height: 210)
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }
}

// MARK: - Poster Placeholder (Shimmer)

struct PosterPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.12))
                .frame(width: 140, height: 210)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 100, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.08))
                .frame(width: 60, height: 10)
        }
    }
}
