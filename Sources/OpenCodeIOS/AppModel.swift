import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var serverURL: URL
    @Published var connectionState: ConnectionState = .idle
    @Published var isChecking = false
    @Published var serverPassword = SecureCredentialStore.read()
    @Published var serverUsername: String
    @Published var serverVersion: String?

    private let defaults = UserDefaults.standard
    private let storageKey = "opencode.serverURL"
    private let usernameKey = "opencode.serverUsername"

    init() {
        let fallback = URL(string: "https://ios-opencode-production.up.railway.app")!
        serverURL = defaults.string(forKey: storageKey).flatMap(URL.init(string:)) ?? fallback
        serverUsername = defaults.string(forKey: usernameKey) ?? "opencode"
    }

    var isLoopbackAddress: Bool {
        let host = (serverURL.host ?? "").lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return host == "localhost" ||
            host.hasSuffix(".localhost") ||
            host == "::1" ||
            host == "0:0:0:0:0:0:0:1" ||
            host == "::ffff:127.0.0.1" ||
            host == "127.0.0.1" ||
            host.hasPrefix("127.")
    }

    func saveSettings(server: String, username: String, password: String) throws {
        let value = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true else {
            throw ServerURLError.invalid
        }

        components.scheme = scheme
        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw ServerURLError.invalid }

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty else { throw ServerURLError.invalidUsername }

        try SecureCredentialStore.write(password)
        serverURL = url
        serverUsername = cleanUsername
        serverPassword = password
        serverVersion = nil
        defaults.set(url.absoluteString, forKey: storageKey)
        defaults.set(cleanUsername, forKey: usernameKey)
        connectionState = .idle
    }

    // Credentials are sent only to the configured origin and never placed in the URL.
    func authenticatedURL() -> URL { serverURL }

    func checkConnection() async {
        guard !isChecking else { return }
        guard !isLoopbackAddress else {
            serverVersion = nil
            connectionState = .failed("No local OpenCode engine is bundled in this iOS build. 127.0.0.1 points to this iPhone. Configure a reachable OpenCode server, or add an iOS-native engine.")
            return
        }

        isChecking = true
        defer { isChecking = false }

        let healthURL = serverURL.appendingPathComponent("global/health")
        var request = URLRequest(url: healthURL, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !serverPassword.isEmpty {
            let credentials = Data("\(serverUsername):\(serverPassword)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        // Do not follow redirects: a redirect must never receive this server's credentials.
        let session = URLSession(
            configuration: .ephemeral,
            delegate: RejectRedirectsDelegate(),
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                serverVersion = nil
                connectionState = .failed("The server returned an invalid HTTP response.")
                return
            }

            guard (200..<300).contains(http.statusCode) else {
                serverVersion = nil
                let detail: String
                switch http.statusCode {
                case 301, 302, 303, 307, 308:
                    detail = "The server redirected the health request. Enter its final HTTPS/LAN URL directly."
                case 401, 403:
                    detail = "Authentication failed. Check the server username and password."
                case 404:
                    detail = "The OpenCode health endpoint was not found. Check the server URL and base path."
                default:
                    detail = "Server returned HTTP \(http.statusCode). Check the server status and URL."
                }
                connectionState = .failed(detail)
                return
            }

            let health: OpenCodeHealth
            do {
                health = try JSONDecoder().decode(OpenCodeHealth.self, from: data)
            } catch {
                serverVersion = nil
                connectionState = .failed("This endpoint responded, but it did not return a valid OpenCode health response.")
                return
            }

            guard health.healthy else {
                serverVersion = nil
                connectionState = .failed("The OpenCode server reported that it is not healthy.")
                return
            }

            serverVersion = health.version
            connectionState = .connected
        } catch {
            serverVersion = nil
            connectionState = .failed("Could not reach server: \(error.localizedDescription)")
        }
    }
}

private struct OpenCodeHealth: Decodable {
    let healthy: Bool
    let version: String
}

private final class RejectRedirectsDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
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
