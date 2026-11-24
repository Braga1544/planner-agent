import SwiftUI

struct MicButton: View {
    @Binding var text: String
    @State private var speech = SpeechRecognizer()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if speech.isRecording {
                speech.stop()
            } else {
                Task { await speech.start(base: text) { text = $0 } }
            }
        } label: {
            Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundStyle(speech.isRecording ? Color.red : Color.accentColor)
                .symbolEffect(.pulse, isActive: speech.isRecording)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(speech.isRecording ? "Diktat beenden" : "Diktieren")
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { speech.stop() }
        }
        .onChange(of: text) { old, new in
            // field was cleared, drop late recognition text
            if new.isEmpty, !old.isEmpty { speech.cancel() }
        }
        .onDisappear { speech.stop() }
        .alert(
            "Spracheingabe",
            isPresented: Binding(get: { speech.message != nil }, set: { if !$0 { speech.message = nil } })
        ) {
            if speech.needsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Einstellungen öffnen") { openURL(url) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(speech.message ?? "")
        }
    }
}
