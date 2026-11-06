import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var serverText = "https://ios-opencode.onrender.com"
    @State private var usernameText = "opencode"
    @State private var passwordText = ""
    @State private var validationError: String?
    @State private var webIsLoading = true
    @State private var webLoadError: String?
    @State private var reloadToken = 0

    private let background = Color(red: 0.055, green: 0.06, blue: 0.075)

    var body: some View {
        NavigationStack {
            Group {
                if model.connectionState == .connected {
                    connectedView
                } else {
                    connectionForm
                }
            }
            .background(background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle(model.connectionState == .connected ? "OpenCode" : "Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.connectionState == .connected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Change") {
                            model.connectionState = .idle
                            passwordText = model.serverPassword
                        }
                    }
                }
            }
        }
        .tint(.white)
        .onAppear {
            serverText = model.serverURL.absoluteString
            usernameText = model.serverUsername
            passwordText = model.serverPassword
        }
    }

    private var connectionForm: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            Image(systemName: "terminal.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 7) {
                Text("OpenCode")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Connect to your server")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            VStack(spacing: 14) {
                credentialField(title: "SERVER URL", icon: "link") {
                    TextField("https://ios-opencode.onrender.com", text: $serverText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .accessibilityIdentifier("serverURLField")
                }

                credentialField(title: "USERNAME", icon: "person") {
                    TextField("opencode", text: $usernameText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("usernameField")
                }

                credentialField(title: "PASSWORD", icon: "lock") {
                    SecureField("Render server password", text: $passwordText)
                        .textContentType(.password)
                        .accessibilityIdentifier("passwordField")
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if case let .failed(message) = model.connectionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Button(action: connect) {
                HStack(spacing: 10) {
                    if model.isChecking {
                        ProgressView().tint(.black)
                    }
                    Text(model.isChecking ? "Connecting…" : "Connect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.black)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
            }
            .disabled(model.isChecking)
            .accessibilityIdentifier("connectButton")

            Text("Your password is saved securely on this iPhone.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func credentialField<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.52))

            HStack(spacing: 11) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 18)
                content()
                    .font(.body)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(.white.opacity(0.09), lineWidth: 1)
            }
        }
    }

    private var connectedView: some View {
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
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                    Text("OpenCode could not load")
                        .font(.headline)
                    Text(webLoadError)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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
    }

    private func connect() {
        validationError = nil
        do {
            try model.saveSettings(
                server: serverText,
                username: usernameText,
                password: passwordText
            )
            Task { await model.checkConnection() }
        } catch {
            validationError = error.localizedDescription
        }
    }
}
