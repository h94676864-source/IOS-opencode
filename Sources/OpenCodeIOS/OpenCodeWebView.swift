import SwiftUI
import WebKit

struct OpenCodeWebView: UIViewRepresentable {
    let serverURL: URL
    let username: String
    let password: String

    func makeCoordinator() -> Coordinator {
        Coordinator(serverURL: serverURL, username: username, password: password)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.055, green: 0.06, blue: 0.075, alpha: 1)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: serverURL))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.update(serverURL: serverURL, username: username, password: password)
        if view.url?.absoluteString != serverURL.absoluteString {
            view.load(URLRequest(url: serverURL))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var allowedScheme: String
        private var allowedHost: String
        private var allowedPort: Int
        private var username: String
        private var password: String

        init(serverURL: URL, username: String, password: String) {
            allowedScheme = serverURL.scheme?.lowercased() ?? "https"
            allowedHost = serverURL.host?.lowercased() ?? ""
            allowedPort = serverURL.port ?? (allowedScheme == "https" ? 443 : 80)
            self.username = username
            self.password = password
        }

        func update(serverURL: URL, username: String, password: String) {
            allowedScheme = serverURL.scheme?.lowercased() ?? "https"
            allowedHost = serverURL.host?.lowercased() ?? ""
            allowedPort = serverURL.port ?? (allowedScheme == "https" ? 443 : 80)
            self.username = username
            self.password = password
        }

        private func isAllowed(_ url: URL?) -> Bool {
            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  let host = url.host?.lowercased(),
                  ["http", "https"].contains(scheme) else { return false }
            let port = url.port ?? (scheme == "https" ? 443 : 80)
            return scheme == allowedScheme && host == allowedHost && port == allowedPort
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(isAllowed(action.request.url) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let protection = challenge.protectionSpace
            let isSameOrigin = protection.host.lowercased() == allowedHost &&
                protection.port == allowedPort &&
                protection.protocol?.lowercased() == allowedScheme

            guard isSameOrigin,
                  protection.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
                  !password.isEmpty else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            let credential = URLCredential(user: username, password: password, persistence: .forSession)
            completionHandler(.useCredential, credential)
        }
    }
}
