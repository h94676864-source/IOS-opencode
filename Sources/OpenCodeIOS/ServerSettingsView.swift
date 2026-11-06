import SwiftUI

struct ServerSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverText = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenCode server") {
                    TextField("https://server.example", text: $serverText)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).textContentType(.URL)
                    Text("Use the HTTPS address of your OpenCode server. For a home-network server, use its LAN IP and port.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }
                Section {
                    Button("Save server") {
                        do {
                            try model.saveServerURL(serverText)
                            dismiss()
                            Task { await model.checkConnection() }
                        } catch { validationError = error.localizedDescription }
                    }.fontWeight(.semibold)
                }
            }
            .navigationTitle("Connection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { serverText = model.serverURL.absoluteString }
        }
    }
}
