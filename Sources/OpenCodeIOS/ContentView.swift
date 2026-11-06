import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = false
    @State private var webIsLoading = true
    @State private var webLoadError: String?
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            Group {
                if model.connectionState == .connected {
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
                            ProgressView("Loading OpenCode…")
                                .padding(18)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        if let webLoadError {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                                Text("OpenCode page could not load").font(.headline)
                                Text(webLoadError)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                Button("Try again") {
                                    self.webLoadError = nil
                                    webIsLoading = true
                                    reloadToken &+= 1
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(24)
                            .frame(maxWidth: 340)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    connectPanel
                }
            }
            .background(Color(red: 0.055, green: 0.06, blue: 0.075))
            .navigationTitle("OpenCode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.connectionState == .connected {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            webLoadError = nil
                            webIsLoading = true
                            reloadToken &+= 1
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Reload OpenCode")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Connection settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView()
                    .environmentObject(model)
                    .presentationDetents([.medium, .large])
            }
        }
        .tint(.white)
        .task {
            if model.connectionState == .idle {
                await model.checkConnection()
            }
        }
    }

    private var connectPanel: some View {
        VStack(spacing: 18) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 42, weight: .medium))
                .padding(22)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            Text("Connect to OpenCode").font(.title2.bold())
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

            if case let .failed(message) = model.connectionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 28)
            }

            Button {
                Task { await model.checkConnection() }
            } label: {
                HStack {
                    if model.isChecking { ProgressView().tint(.black) }
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

            Button("Connection settings") { showingSettings = true }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
        .foregroundStyle(.white)
    }
}
