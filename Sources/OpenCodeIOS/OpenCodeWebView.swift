import SwiftUI
import WebKit

struct OpenCodeWebView: UIViewRepresentable {
    let serverURL: URL
    let username: String
    let password: String
    let reloadToken: Int
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            serverURL: serverURL,
            username: username,
            password: password,
            onLoadingChange: { isLoading = $0 },
            onError: { loadError = $0 }
        )
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
        view.load(URLRequest(url: serverURL, timeoutInterval: 20))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let originChanged = context.coordinator.update(
            serverURL: serverURL,
            username: username,
            password: password
        )
        let shouldReload = context.coordinator.consumeReloadToken(reloadToken)
        if originChanged || shouldReload {
            loadError = nil
            isLoading = true
            view.load(URLRequest(url: serverURL, timeoutInterval: 20))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var allowedScheme: String
        private var allowedHost: String
        private var allowedPort: Int
        private var username: String
        private var password: String
        private var lastReloadToken = 0
        private let onLoadingChange: (Bool) -> Void
        private let onError: (String?) -> Void

        init(
            serverURL: URL,
            username: String,
            password: String,
            onLoadingChange: @escaping (Bool) -> Void,
            onError: @escaping (String?) -> Void
        ) {
            allowedScheme = serverURL.scheme?.lowercased() ?? "https"
            allowedHost = serverURL.host?.lowercased() ?? ""
            allowedPort = serverURL.port ?? (allowedScheme == "https" ? 443 : 80)
            self.username = username
            self.password = password
            self.onLoadingChange = onLoadingChange
            self.onError = onError
        }

        @discardableResult
        func update(serverURL: URL, username: String, password: String) -> Bool {
            let scheme = serverURL.scheme?.lowercased() ?? "https"
            let host = serverURL.host?.lowercased() ?? ""
            let port = serverURL.port ?? (scheme == "https" ? 443 : 80)
            let changed = scheme != allowedScheme || host != allowedHost || port != allowedPort
            allowedScheme = scheme
            allowedHost = host
            allowedPort = port
            self.username = username
            self.password = password
            return changed
        }

        func consumeReloadToken(_ token: Int) -> Bool {
            guard token != lastReloadToken else { return false }
            lastReloadToken = token
            return true
        }

        private func isAllowed(_ url: URL?) -> Bool {
            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  let host = url.host?.lowercased(),
                  url.user == nil,
                  url.password == nil,
                  ["http", "https"].contains(scheme) else { return false }
            let port = url.port ?? (scheme == "https" ? 443 : 80)
            return scheme == allowedScheme && host == allowedHost && port == allowedPort
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(isAllowed(action.request.url) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onError(nil)
            onLoadingChange(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChange(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            onLoadingChange(false)
            onError(error.localizedDescription)
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
