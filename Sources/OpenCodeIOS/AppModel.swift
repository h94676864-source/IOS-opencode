import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var serverURL: URL
    @Published var connectionState: ConnectionState = .idle
    @Published var isChecking = false
    @Published var serverPassword = SecureCredentialStore.read()

    private let defaults = UserDefaults.standard
    private let storageKey = "opencode.serverURL"

    init() {
        let fallback = URL(string: "http://127.0.0.1:4096")!
        serverURL = defaults.string(forKey: storageKey).flatMap(URL.init(string:)) ?? fallback
    }

    var isLoopbackAddress: Bool {
        let host = serverURL.host?.lowercased() ?? ""
        return host == "localhost" || host == "::1" || host == "127.0.0.1" || host.hasPrefix("127.")
    }

    func saveSettings(server: String, password: String) throws {
        let value = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = URLComponents(string: value),
              let scheme = c.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              let url = URL(string: value.hasSuffix("/") ? String(value.dropLast()) : value) else {
            throw ServerURLError.invalid
        }
        try SecureCredentialStore.write(password)
        serverURL = url
        serverPassword = password
        defaults.set(url.absoluteString, forKey: storageKey)
        connectionState = .idle
    }

    func authenticatedURL() -> URL {
        guard !serverPassword.isEmpty else { return serverURL }
        let tokenData = Data("opencode:\(serverPassword)".utf8).base64EncodedString()
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        components?.queryItems = (components?.queryItems ?? []) + [
            URLQueryItem(name: "auth_token", value: tokenData)
        ]
        return components?.url ?? serverURL
    }

    func checkConnection() async {
        guard !isChecking else { return }
        guard !isLoopbackAddress else {
            connectionState = .failed("No local OpenCode engine is bundled in this iOS build. 127.0.0.1 points to this iPhone. Connect to a reachable OpenCode server, or add an iOS-native engine.")
            return
        }
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: serverURL.appendingPathComponent("global/health"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if !serverPassword.isEmpty {
            let credentials = Data("opencode:\(serverPassword)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                connectionState = .failed("Server health check failed. Verify the address, password, and server status.")
                return
            }
            connectionState = .connected
        } catch {
            connectionState = .failed("Could not reach server: \(error.localizedDescription)")
        }
    }
}

enum ConnectionState: Equatable {
    case idle, connected, failed(String)
}

enum ServerURLError: LocalizedError {
    case invalid
    var errorDescription: String? {
        "Enter a valid HTTP(S) server URL without embedded credentials, query, or fragment."
    }
}
