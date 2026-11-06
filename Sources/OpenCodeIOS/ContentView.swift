import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = false
    @State private var webIsLoading = true
    @State private var webLoadError: String?
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            mainContent
                .background(Color(red: 0.055, green: 0.06, blue: 0.075))
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { navigationToolbar }
                .sheet(isPresented: $showingSettings) {
                    ServerSettingsView()
                        .environmentObject(model)
                        .presentationDetents([.medium, .large])
                }
        }
        .tint(.white)
        .task {
            guard model.connectionState == .idle else { return }
            await model.checkConnection()
        }
    }

    private var navigationTitle: String {
        guard let version = model.serverVersion, !version.isEmpty else {
            return "OpenCode"
        }
        return "OpenCode · \(version)"
    }

    @ViewBuilder
    private var mainContent: some View {
        if model.connectionState == .connected {
            connectedContent
        } else {
            connectPanel
        }
    }

    private var connectedContent: some View {
        ZStack {
            OpenCodeWebView(
                serverURL: model.authenticatedURL(),
                username: model.serverUsername,
                password: model.serverPassword,
                reloadToken: reloadToken,
                isLoading: $webIsLoading,
                loadError: $webLoadError
            )

            if webIsLoading {
                loadingOverlay
            }

            if let message = webLoadError {
                loadErrorOverlay(message)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var loadingOverlay: some View {
        ProgressView("Loading OpenCode…")
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func loadErrorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
            Text("OpenCode page could not load")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try again", action: reloadWebView)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        if model.connectionState == .connected {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: reloadWebView) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reload OpenCode")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Connection settings")
        }
    }

    private func reloadWebView() {
        webLoadError = nil
        webIsLoading = true
        reloadToken &+= 1
    }

    private var connectPanel: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 42, weight: .medium))
                    .padding(22)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)

                Text("Connect to OpenCode")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Connect this iPhone to a running OpenCode server.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)

                if model.isLoopbackAddress {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("A server address is required")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                        .foregroundStyle(.orange)

                        Text("This iPhone build is a client; it does not contain the Android Linux engine. The default 127.0.0.1 address points back to this iPhone. Add your reachable cloud or LAN OpenCode server in Connection settings.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: 440, alignment: .leading)
                    .padding(16)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 22)
                }

                serverAddressCard

                if case let .failed(message) = model.connectionState {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 24)
                }

                connectButton

                Button("Connection settings") {
                    showingSettings = true
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 28)
            .foregroundStyle(.white)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var serverAddressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVER")
                .font(.caption2.bold())
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))

            Text(model.serverURL.absoluteString)
                .font(.system(.footnote, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 28)
    }

    private var connectButton: some View {
        Button {
            if model.isLoopbackAddress {
                // The default loopback URL points back to this iPhone, not the cloud server.
                showingSettings = true
            } else {
                Task { await model.checkConnection() }
            }
        } label: {
            HStack {
                if model.isChecking {
                    ProgressView().tint(.black)
                }
                Text(model.isChecking ? "Checking…" : (model.isLoopbackAddress ? "Configure server" : "Connect"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.black)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(model.isChecking)
        .padding(.horizontal, 28)
    }
}
