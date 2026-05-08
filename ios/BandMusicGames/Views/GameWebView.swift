import SwiftUI
import WebKit

/// A full-screen game session embedded in a WKWebView.
/// Injects the Spotify token (or skip flag) as a cookie before loading
/// so the web game sees it on `.bandmusicgames.party`.
struct GameSheetView: View {
    let song: Song
    let spotifyToken: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameWebView(
                url: URL(string: song.gameUrl)!,
                spotifyToken: spotifyToken
            )
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.55))
                    .padding(12)
            }
        }
    }
}

// MARK: - UIViewRepresentable wrapper

struct GameWebView: UIViewRepresentable {
    let url: URL
    let spotifyToken: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)

        injectCookieAndLoad(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Cookie injection

    private func injectCookieAndLoad(into webView: WKWebView) {
        let store = webView.configuration.websiteDataStore.httpCookieStore

        func load() { webView.load(URLRequest(url: url)) }

        if let token = spotifyToken {
            let props: [HTTPCookiePropertyKey: Any] = [
                .name:    "sp_token",
                .value:   token,
                .domain:  ".bandmusicgames.party",
                .path:    "/",
                .secure:  "TRUE",
            ]
            if let cookie = HTTPCookie(properties: props) {
                store.setCookie(cookie) { load() }
                return
            }
        }

        let skipProps: [HTTPCookiePropertyKey: Any] = [
            .name:   "sp_skip",
            .value:  "1",
            .domain: ".bandmusicgames.party",
            .path:   "/",
            .secure: "TRUE",
        ]
        if let cookie = HTTPCookie(properties: skipProps) {
            store.setCookie(cookie) { load() }
        } else {
            load()
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow everything within the game subdomain family
            decisionHandler(.allow)
        }
    }
}
