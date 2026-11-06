import SwiftUI

struct ServerSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverText = ""
    @State private var usernameText = "opencode"
    @State private var passwordText = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenCode server") {
                    TextField("http://192.168.1.20:4096", text: $serverText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                    TextField("Username", text: $usernameText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Server password (optional)", text: $passwordText)
                        .textContentType(.password)
                    Text("Password is stored in iOS Keychain. Use a reachable server address; 127.0.0.1 refers to this iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Connection requirements") {
                    Label("The server must accept connections from this device.", systemImage: "wifi")
                    Label("Allow local-network access if iOS asks.", systemImage: "network")
                    Label("Use HTTPS when connecting over the internet.", systemImage: "lock.shield")
                }
                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }
                Section {
                    Button("Save and connect") {
                        do {
                            try model.saveSettings(server: serverText, username: usernameText, password: passwordText)
                            dismiss()
                            Task { await model.checkConnection() }
                        } catch { validationError = error.localizedDescription }
                    }.fontWeight(.semibold)
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                serverText = model.serverURL.absoluteString
                usernameText = model.serverUsername
                passwordText = model.serverPassword
            }
        }
    }
}
