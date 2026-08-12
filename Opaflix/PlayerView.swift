import SwiftUI

// MARK: - Player View

struct PlayerView: View {
    let streamURL: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Video player
            VideoPlayerView(url: streamURL)
                .ignoresSafeArea()
                .overlay {
                    if isLoading {
                        loadingOverlay
                    }
                }

            // Error overlay
            if let error = loadError {
                errorOverlay(message: error)
            }

            // Top overlay: title + dismiss
            VStack {
                topBar
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            // Simulate a brief loading phase then clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)

            Spacer()

            // Title
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // AirPlay indicator placeholder
            Color.clear
                .frame(width: 40, height: 40)
                .padding(.trailing, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.red)
                .scaleEffect(1.8)

            Text("Loading stream...")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Error Overlay

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Playback Error")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Label("Go Back", systemImage: "arrow.left")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
    }
}
