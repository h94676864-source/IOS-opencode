import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var serverURL: URL
    @Published var connectionState: ConnectionState = .idle
    @Published var isChecking = false
    @Published var serverPassword = SecureCredentialStore.read()
    @Published var serverUsername: String

    private let defaults = UserDefaults.standard
    private let storageKey = "opencode.serverURL"
    private let usernameKey = "opencode.serverUsername"

    init() {
        let fallback = URL(string: "http://127.0.0.1:4096")!
        serverURL = defaults.string(forKey: storageKey).flatMap(URL.init(string:)) ?? fallback
        serverUsername = defaults.string(forKey: usernameKey) ?? "opencode"
    }

    var isLoopbackAddress: Bool {
        let host = serverURL.host?.lowercased() ?? ""
        return host == "localhost" || host == "::1" || host == "127.0.0.1" || host.hasPrefix("127.")
    }

    func saveSettings(server: String, username: String, password: String) throws {
        let value = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = URLComponents(string: value),
              let scheme = c.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              let url = URL(string: value.hasSuffix("/") ? String(value.dropLast()) : value) else {
            throw ServerURLError.invalid
        }

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty else { throw ServerURLError.invalidUsername }

        try SecureCredentialStore.write(password)
        serverURL = url
        serverUsername = cleanUsername
        serverPassword = password
        defaults.set(url.absoluteString, forKey: storageKey)
        defaults.set(cleanUsername, forKey: usernameKey)
        connectionState = .idle
    }

    // Credentials are supplied only in the HTTP authentication challenge.
    // Never place passwords or base64 credentials in the URL/query string.
    func authenticatedURL() -> URL { serverURL }

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
            let credentials = Data("\(serverUsername):\(serverPassword)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                connectionState = .failed("The server returned an invalid response.")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                let detail: String
                switch http.statusCode {
                case 401, 403: detail = "Authentication failed. Check the server username and password."
                case 404: detail = "The OpenCode health endpoint was not found. Check the server URL and base path."
                default: detail = "Server returned HTTP \(http.statusCode). Check the server status and URL."
                }
                connectionState = .failed(detail)
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
    case invalidUsername

    var errorDescription: String? {
        switch self {
        case .invalid:
            return "Enter a valid HTTP(S) server URL without embedded credentials, query, or fragment."
        case .invalidUsername:
            return "Server username cannot be empty."
        }
    }
}
