import Foundation

// MARK: - API Configuration

enum TMDbConfig {
    /// Replace with your own TMDb API key from https://www.themoviedb.org/settings/api
    static let apiKey = "YOUR_TMDB_API_KEY"
    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p"

    enum PosterSize: String {
        case w92, w154, w185, w342, w500, w780, original
    }

    enum BackdropSize: String {
        case w300, w780, w1280, original
    }

    static func posterURL(path: String?, size: PosterSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }

    static func backdropURL(path: String?, size: BackdropSize = .w1280) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }
}

// MARK: - API Error

enum TMDbError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL."
        case .invalidResponse: "Invalid response from server."
        case .httpError(let code): "Server error (HTTP \(code))."
        case .decodingFailed: "Failed to parse response data."
        case .networkError(let error): error.localizedDescription
        }
    }
}

// MARK: - Codable Models

struct TMDbPaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let page: Int
    let results: [T]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Unified media item used across movies and TV shows in lists.
struct MediaItem: Identifiable, Codable, Sendable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let firstAirDate: String?
    let genreIds: [Int]?
    let mediaType: String?

    var displayTitle: String {
        title ?? name ?? "Untitled"
    }

    var displayDate: String {
        let date = releaseDate ?? firstAirDate ?? ""
        guard date.count >= 4 else { return date }
        return String(date.prefix(4))
    }

    var rating: Double {
        voteAverage ?? 0
    }

    var posterURL: URL? {
        TMDbConfig.posterURL(path: posterPath)
    }

    var backdropURL: URL? {
        TMDbConfig.backdropURL(path: backdropPath)
    }

    var isMovie: Bool {
        mediaType == "movie" || title != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case mediaType = "media_type"
    }
}

struct MediaDetail: Identifiable, Codable, Sendable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let firstAirDate: String?
    let genres: [Genre]?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let runtime: Int?
    let episodeRuntime: [Int]?
    let tagline: String?
    let status: String?

    var displayTitle: String {
        title ?? name ?? "Untitled"
    }

    var displayDate: String {
        let date = releaseDate ?? firstAirDate ?? ""
        guard date.count >= 4 else { return date }
        return String(date.prefix(4))
    }

    var rating: Double {
        voteAverage ?? 0
    }

    var posterURL: URL? {
        TMDbConfig.posterURL(path: posterPath)
    }

    var backdropURL: URL? {
        TMDbConfig.backdropURL(path: backdropPath)
    }

    var isMovie: Bool {
        title != nil
    }

    var seasonCount: Int {
        numberOfSeasons ?? 0
    }

    var displayRuntime: String {
        if let r = runtime, r > 0 {
            return "\(r)m"
        }
        if let er = episodeRuntime?.first, er > 0 {
            return "~\(er)m per ep"
        }
        return ""
    }

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, genres, runtime, tagline, status
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case episodeRuntime = "episode_runtime"
    }
}

struct Genre: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
}

struct TVSeason: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
    }
}

struct TVSeasonDetail: Codable, Sendable {
    let id: Int
    let episodes: [TVEpisode]
    let name: String
    let seasonNumber: Int

    enum CodingKeys: String, CodingKey {
        case id, name, episodes
        case seasonNumber = "season_number"
    }
}

struct TVEpisode: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
    }
}

// MARK: - TMDb API Service

actor TMDbService {
    static let shared = TMDbService()

    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Request Builder

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: "\(TMDbConfig.baseURL)\(path)") else {
            throw TMDbError.invalidURL
        }
        var items = queryItems
        items.append(URLQueryItem(name: "api_key", value: TMDbConfig.apiKey))
        items.append(URLQueryItem(name: "language", value: "en-US"))
        components.queryItems = items
        guard let url = components.url else {
            throw TMDbError.invalidURL
        }
        return url
    }

    private func fetch<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDbError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDbError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw TMDbError.decodingFailed(error)
        }
    }

    // MARK: - Public API Methods

    /// Fetch trending movies for the day.
    func fetchTrendingMovies(page: Int = 1) async throws -> [MediaItem] {
        let url = try buildURL(path: "/trending/movie/day", queryItems: [
            URLQueryItem(name: "page", value: String(page))
        ])
        let response: TMDbPaginatedResponse<MediaItem> = try await fetch(url)
        return response.results
    }

    /// Fetch trending TV shows for the day.
    func fetchTrendingTVShows(page: Int = 1) async throws -> [MediaItem] {
        let url = try buildURL(path: "/trending/tv/day", queryItems: [
            URLQueryItem(name: "page", value: String(page))
        ])
        let response: TMDbPaginatedResponse<MediaItem> = try await fetch(url)
        return response.results
    }

    /// Search for movies by query string.
    func searchMovies(query: String, page: Int = 1) async throws -> [MediaItem] {
        let url = try buildURL(path: "/search/movie", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
        ])
        let response: TMDbPaginatedResponse<MediaItem> = try await fetch(url)
        return response.results
    }

    /// Search for TV shows by query string.
    func searchTVShows(query: String, page: Int = 1) async throws -> [MediaItem] {
        let url = try buildURL(path: "/search/tv", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
        ])
        let response: TMDbPaginatedResponse<MediaItem> = try await fetch(url)
        return response.results
    }

    /// Fetch detailed info for a movie.
    func fetchMovieDetail(id: Int) async throws -> MediaDetail {
        let url = try buildURL(path: "/movie/\(id)")
        return try await fetch(url)
    }

    /// Fetch detailed info for a TV show.
    func fetchTVDetail(id: Int) async throws -> MediaDetail {
        let url = try buildURL(path: "/tv/\(id)")
        return try await fetch(url)
    }

    /// Fetch season detail with episodes for a TV show.
    func fetchSeasonDetail(tvId: Int, seasonNumber: Int) async throws -> TVSeasonDetail {
        let url = try buildURL(path: "/tv/\(tvId)/season/\(seasonNumber)")
        return try await fetch(url)
    }

    /// Search both movies and TV shows concurrently.
    func searchAll(query: String) async throws -> [MediaItem] {
        async let movies = searchMovies(query: query)
        async let tvShows = searchTVShows(query: query)
        let results = try await (movies + tvShows)
        return results.sorted { ($0.rating) > ($1.rating) }
    }
}
