import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if model.connectionState == .connected {
                    OpenCodeWebView(serverURL: model.serverURL).ignoresSafeArea(edges: .bottom)
                } else {
                    connectPanel
                }
            }
            .background(Color(red: 0.055, green: 0.06, blue: 0.075))
            .navigationTitle("OpenCode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.connectionState == .connected {
                        Button { Task { await model.checkConnection() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView().environmentObject(model).presentationDetents([.medium, .large])
            }
        }
        .tint(.white)
    }

    private var connectPanel: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 42, weight: .medium))
                .padding(22)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            Text("Connect to OpenCode").font(.title2.bold())
            Text("Connect this iPhone to an OpenCode server running on your computer or reachable network.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 28)
            VStack(alignment: .leading, spacing: 8) {
                Text("SERVER").font(.caption2.bold()).tracking(1.2).foregroundStyle(.white.opacity(0.5))
                Text(model.serverURL.absoluteString).font(.system(.footnote, design: .monospaced))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 28)
            if case let .failed(message) = model.connectionState {
                Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            Button {
                Task { await model.checkConnection() }
            } label: {
                HStack {
                    if model.isChecking { ProgressView().tint(.black) }
                    Text(model.isChecking ? "Checking…" : "Connect").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .foregroundStyle(.black).background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(model.isChecking).padding(.horizontal, 28)
            Text("Configure the server address in the top-right settings.")
                .font(.caption).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 30)
        .foregroundStyle(.white)
    }
}
