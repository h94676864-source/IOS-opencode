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
        VStack(spacing: 18) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 42, weight: .medium))
                .padding(22)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

            Text("Connect to OpenCode")
                .font(.title2.bold())

            Text("Connect this iPhone to a running OpenCode server.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 28)

            if model.isLoopbackAddress {
                Label("No iOS-local engine is bundled yet", systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("The Android PRoot/Alpine runtime cannot run as-is on iOS. A native runtime port is still required for standalone operation.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 28)
            }

            serverAddressCard

            if case let .failed(message) = model.connectionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 28)
            }

            connectButton

            Button("Connection settings") {
                showingSettings = true
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
        .foregroundStyle(.white)
    }

    private var serverAddressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVER")
                .font(.caption2.bold())
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))

            Text(model.serverURL.absoluteString)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 28)
    }

    private var connectButton: some View {
        Button {
            Task { await model.checkConnection() }
        } label: {
            HStack {
                if model.isChecking {
                    ProgressView().tint(.black)
                }
                Text(model.isChecking ? "Checking…" : "Connect")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.black)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(model.isChecking || model.isLoopbackAddress)
        .padding(.horizontal, 28)
    }
}
