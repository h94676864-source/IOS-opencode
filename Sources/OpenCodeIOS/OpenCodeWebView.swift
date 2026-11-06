import SwiftUI
import WebKit

struct OpenCodeWebView: UIViewRepresentable {
    let serverURL: URL
    func makeCoordinator() -> Coordinator { Coordinator(allowedHost: serverURL.host) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.055, green: 0.06, blue: 0.075, alpha: 1)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.load(URLRequest(url: serverURL))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url?.absoluteString != serverURL.absoluteString {
            view.load(URLRequest(url: serverURL))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let allowedHost: String?
        init(allowedHost: String?) { self.allowedHost = allowedHost }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, let host = url.host,
                  host.caseInsensitiveCompare(allowedHost ?? "") == .orderedSame,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
