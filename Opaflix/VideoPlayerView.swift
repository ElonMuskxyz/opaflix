import SwiftUI
import WebKit

// MARK: - Embedded Web Video Player

/// A UIViewRepresentable wrapper around WKWebView configured for inline streaming.
struct VideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Allow inline playback (no forced fullscreen on iPhone)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Enable PiP and AirPlay
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true

        // Configure preferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        // Inject custom CSS for a clean look
        let cssSource = """
            var style = document.createElement('style');
            style.textContent = 'body { background-color: #000; margin: 0; padding: 0; }';
            document.head.appendChild(style);
        """
        let script = WKUserScript(
            source: cssSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Dark, seamless background
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false

        // Allow full-screen video
        webView.configuration.preferences.isElementFullscreenEnabled = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if the URL actually changed to avoid reload loops
        guard webView.url != url else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[VideoPlayer] Navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("[VideoPlayer] Provisional navigation failed: \(error.localizedDescription)")
        }

        // Allow opening new windows (e.g., fullscreen player spawns)
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Handle popup windows for full-screen video players
            if navigationAction.targetFrame == nil {
                let popup = WKWebView(frame: .zero, configuration: configuration)
                popup.navigationDelegate = self
                popup.uiDelegate = self
                popup.isOpaque = false
                popup.backgroundColor = .black

                // Present the popup in a new window by adding to key window
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    popup.frame = keyWindow.bounds
                    popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    keyWindow.addSubview(popup)

                    // Add a close button to dismiss the popup
                    let closeButton = UIButton(type: .system)
                    closeButton.setTitle("✕", for: .normal)
                    closeButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
                    closeButton.tintColor = .white
                    closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
                    closeButton.layer.cornerRadius = 20
                    closeButton.frame = CGRect(x: 16, y: 50, width: 40, height: 40)
                    closeButton.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
                    closeButton.addAction(UIAction { [weak popup, weak closeButton] _ in
                        popup?.stopLoading()
                        popup?.removeFromSuperview()
                        closeButton?.removeFromSuperview()
                    }, for: .touchUpInside)
                    popup.addSubview(closeButton)
                }
                return popup
            }
            return nil
        }
    }
}
