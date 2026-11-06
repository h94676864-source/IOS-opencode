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
        let saved = defaults.string(forKey: storageKey) ?? "http://127.0.0.1:4096"
        serverURL = URL(string: saved) ?? URL(string: "http://127.0.0.1:4096")!
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
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: serverURL.appendingPathComponent("global/health"))
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                connectionState = .failed("Server returned an unexpected HTTP status.")
                return
            }
            connectionState = .connected
        } catch {
            connectionState = .failed(error.localizedDescription)
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
