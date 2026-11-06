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
        let fallback = URL(string: "https://ios-opencode.onrender.com")!
        let savedURL = defaults.string(forKey: storageKey).flatMap(URL.init(string:))
        let wasOldRailwayDefault = savedURL?.host?.lowercased().hasSuffix(".railway.app") == true
        if wasOldRailwayDefault || savedURL == nil {
            serverURL = fallback
            defaults.set(fallback.absoluteString, forKey: storageKey)
        } else {
            serverURL = savedURL!
        }
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
        guard !password.isEmpty else { throw ServerURLError.missingPassword }

        try SecureCredentialStore.write(password)
        serverURL = url
        serverUsername = cleanUsername
        serverPassword = password
        serverVersion = nil
        defaults.set(url.absoluteString, forKey: storageKey)
        defaults.set(cleanUsername, forKey: usernameKey)
        connectionState = .idle
    }

    func authenticatedURL() -> URL { serverURL }

    func checkConnection() async {
        guard !isChecking else { return }
        guard !isLoopbackAddress else {
            serverVersion = nil
            connectionState = .failed("Enter your reachable Render or LAN server address.")
            return
        }

        isChecking = true
        defer { isChecking = false }

        let healthURL = serverURL.appendingPathComponent("global/health")
        var request = URLRequest(url: healthURL, timeoutInterval: 75)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let credentials = Data("\(serverUsername):\(serverPassword)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

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
                    detail = "The server redirected the health request. Check the Render service URL."
                case 401, 403:
                    detail = "Login failed. Check the username and password in Render environment variables."
                case 404:
                    detail = "OpenCode health endpoint was not found. Check the server URL."
                case 502, 503, 504:
                    detail = "Render is starting the free service. Wait a moment and tap Connect again."
                default:
                    detail = "Server returned HTTP \(http.statusCode). Check Render deployment logs."
                }
                connectionState = .failed(detail)
                return
            }

            let health: OpenCodeHealth
            do {
                health = try JSONDecoder().decode(OpenCodeHealth.self, from: data)
            } catch {
                serverVersion = nil
                connectionState = .failed("The server replied, but its OpenCode health response was invalid.")
                return
            }

            guard health.healthy else {
                serverVersion = nil
                connectionState = .failed("OpenCode server reported that it is not healthy.")
                return
            }

            serverVersion = health.version
            connectionState = .connected
        } catch {
            serverVersion = nil
            connectionState = .failed("Could not reach Render. The free service may be waking up; try Connect again.")
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
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .invalid:
            return "Enter a valid HTTP(S) server URL without embedded credentials, query, or fragment."
        case .invalidUsername:
            return "Server username cannot be empty."
        case .missingPassword:
            return "Enter the server password from Render."
        }
    }
}
