import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {

    @Published var isConnected = false
    @Published var accessToken: String? = nil
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var currentTrackUri: String? = nil
    @Published var playbackError: PlaybackError? = nil

    enum PlaybackError: Identifiable {
        case noDevice, notPremium, unknown(String)
        var id: String { "\(self)" }
        var message: String {
            switch self {
            case .noDevice:
                return "Open the Spotify app on this device first, then press Play."
            case .notPremium:
                return "Spotify Premium is required for in-app playback."
            case .unknown(let msg):
                return "Playback error: \(msg)"
            }
        }
    }

    private let clientId    = "aa16f7f72c04485fb93d86d2f7ee33d1"
    private let redirectUri = "bandmusicgames://spotify-callback"
    private let scope       = "streaming user-read-email user-read-private"

    private var pendingVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        let stored = UserDefaults.standard.string(forKey: "sp_token")
        let expiry = UserDefaults.standard.double(forKey: "sp_token_expiry")
        if let token = stored, expiry == 0 || Date().timeIntervalSince1970 < expiry - 60 {
            accessToken = token
            isConnected = true
        } else if UserDefaults.standard.string(forKey: "sp_refresh") != nil {
            // Expired token but refresh available — restore connected state and refresh lazily
            isConnected = true
            Task { await self.refreshToken() }
        } else if UserDefaults.standard.bool(forKey: "sp_skip") {
            isConnected = true
        }
    }

    func login() {
        let verifier  = makeCodeVerifier()
        let challenge = makeCodeChallenge(verifier: verifier)
        pendingVerifier = verifier

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id",             value: clientId),
            .init(name: "response_type",          value: "code"),
            .init(name: "redirect_uri",           value: redirectUri),
            .init(name: "scope",                  value: scope),
            .init(name: "code_challenge_method",  value: "S256"),
            .init(name: "code_challenge",         value: challenge),
        ]
        guard let url = comps.url else { return }

        isLoading = true

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "bandmusicgames"
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                guard
                    error == nil,
                    let callbackURL,
                    let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
                    let verifier = self.pendingVerifier
                else { return }
                await self.exchangeCode(code, verifier: verifier)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }

    func skipSpotify() {
        UserDefaults.standard.set(true, forKey: "sp_skip")
        isConnected = true
    }

    func disconnect() {
        ["sp_token", "sp_skip", "sp_token_expiry", "sp_refresh"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        accessToken = nil
        isConnected  = false
        isPlaying    = false
        currentTrackUri = nil
    }

    func handleCallback(url: URL) {}

    // MARK: - Playback

    func playTrack(_ uri: String) async {
        guard let token = await validToken() else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/play")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["uris": [uri]])

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 204:
                isPlaying = true
                currentTrackUri = uri
            case 401:
                await refreshToken()
                // Retry once after refresh
                if let newToken = accessToken {
                    req.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (_, r2) = try await URLSession.shared.data(for: req)
                    if (r2 as? HTTPURLResponse)?.statusCode == 204 {
                        isPlaying = true
                        currentTrackUri = uri
                    }
                }
            case 403:
                playbackError = .notPremium
            case 404:
                playbackError = .noDevice
            case let code:
                playbackError = .unknown("HTTP \(code ?? 0)")
            }
        } catch {
            print("SpotifyAuth: playTrack failed: \(error)")
        }
    }

    func pausePlayback() async {
        guard let token = await validToken() else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/pause")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if (response as? HTTPURLResponse)?.statusCode == 204 {
                isPlaying = false
            }
        } catch {
            print("SpotifyAuth: pause failed: \(error)")
        }
    }

    // MARK: - Private

    private func validToken() async -> String? {
        let expiry = UserDefaults.standard.double(forKey: "sp_token_expiry")
        if let token = accessToken, expiry == 0 || Date().timeIntervalSince1970 < expiry - 60 {
            return token
        }
        await refreshToken()
        return accessToken
    }

    private func refreshToken() async {
        guard let refresh = UserDefaults.standard.string(forKey: "sp_refresh") else { return }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=refresh_token",
            "refresh_token=\(refresh)",
            "client_id=\(clientId)",
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct TokenResponse: Decodable {
                let access_token: String
                let expires_in: Int
                let refresh_token: String?
            }
            let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
            UserDefaults.standard.set(resp.access_token, forKey: "sp_token")
            let expiry = Date().addingTimeInterval(TimeInterval(resp.expires_in)).timeIntervalSince1970
            UserDefaults.standard.set(expiry, forKey: "sp_token_expiry")
            if let newRefresh = resp.refresh_token {
                UserDefaults.standard.set(newRefresh, forKey: "sp_refresh")
            }
            accessToken = resp.access_token
        } catch {
            print("SpotifyAuth: token refresh failed: \(error)")
        }
    }

    private func exchangeCode(_ code: String, verifier: String) async {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedRedirect = redirectUri
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri

        req.httpBody = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(encodedRedirect)",
            "client_id=\(clientId)",
            "code_verifier=\(verifier)",
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct TokenResponse: Decodable {
                let access_token: String
                let expires_in: Int
                let refresh_token: String?
            }
            let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
            UserDefaults.standard.set(resp.access_token, forKey: "sp_token")
            let expiry = Date().addingTimeInterval(TimeInterval(resp.expires_in)).timeIntervalSince1970
            UserDefaults.standard.set(expiry, forKey: "sp_token_expiry")
            if let refresh = resp.refresh_token {
                UserDefaults.standard.set(refresh, forKey: "sp_refresh")
            }
            accessToken = resp.access_token
            isConnected  = true
        } catch {
            print("SpotifyAuth: token exchange failed: \(error)")
        }
    }

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeChallenge(verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
