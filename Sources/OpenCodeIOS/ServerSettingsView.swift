import SwiftUI

struct ServerSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverText = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenCode server address") {
                    TextField("http://192.168.1.20:4096", text: $serverText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)

                    Text("Enter the LAN IP and port of a computer running OpenCode, or an HTTPS server URL. Do not use 127.0.0.1 unless an engine is running inside this iPhone app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Before connecting") {
                    Label("The server must be running and reachable on the same network.", systemImage: "wifi")
                    Label("Allow local-network access if iOS asks.", systemImage: "network")
                    Label("For internet access, use HTTPS and protect the server with authentication.", systemImage: "lock.shield")
                }

                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }

                Section {
                    Button("Save and connect") {
                        do {
                            try model.saveServerURL(serverText)
                            dismiss()
                            Task { await model.checkConnection() }
                        } catch {
                            validationError = error.localizedDescription
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { serverText = model.serverURL.absoluteString }
        }
    }
}
