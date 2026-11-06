import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var serverURL: URL
    @Published var connectionState: ConnectionState = .idle
    @Published var isChecking = false

    private let defaults = UserDefaults.standard
    private let storageKey = "opencode.serverURL"

    init() {
        let fallback = URL(string: "http://127.0.0.1:4096")!
        let saved = defaults.string(forKey: storageKey)
        serverURL = saved.flatMap(URL.init(string:)) ?? fallback
    }

    var isLoopbackAddress: Bool {
        let host = serverURL.host?.lowercased() ?? ""
        return host == "localhost" || host == "::1" || host == "127.0.0.1" ||
            host.hasPrefix("127.")
    }

    func saveServerURL(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = URLComponents(string: value),
              let scheme = c.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              let url = URL(string: value.hasSuffix("/") ? String(value.dropLast()) : value) else {
            throw ServerURLError.invalid
        }
        serverURL = url
        defaults.set(url.absoluteString, forKey: storageKey)
        connectionState = .idle
    }

    func checkConnection() async {
        guard !isChecking else { return }
        guard !isLoopbackAddress else {
            connectionState = .failed(
                "No OpenCode engine is bundled in this iOS build. 127.0.0.1 points to this iPhone, where no server is running. Set the address of a running OpenCode server in Connection settings."
            )
            return
        }

        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: serverURL.appendingPathComponent("global/health"))
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                connectionState = .failed("The server responded, but its health endpoint did not return HTTP 2xx. Check the OpenCode server URL and version.")
                return
            }
            connectionState = .connected
        } catch {
            connectionState = .failed("Could not reach the server: \(error.localizedDescription)")
        }
    }
}

enum ConnectionState: Equatable {
    case idle, connected, failed(String)
}

enum ServerURLError: LocalizedError {
    case invalid
    var errorDescription: String? {
        "Enter a valid HTTP(S) server URL without credentials, query, or fragment."
    }
}
