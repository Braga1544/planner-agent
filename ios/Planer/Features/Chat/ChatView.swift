import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @State private var model: ChatViewModel

    init(client: APIClient, conversation: Conversation) {
        _model = State(initialValue: ChatViewModel(client: client, conversationId: conversation.id, title: conversation.title))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.messages.isEmpty && model.pending == nil {
                        Text("Frag zum Beispiel: „Was steht heute an?“ oder „Leg für Freitag ein ToDo an: Steuer“.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.messages) { message in
                        MessageBubble(
                            role: message.role,
                            text: message.text,
                            tools: message.tools.enumerated().map { ToolChip(id: "\(message.id)-\($0.offset)", name: $0.element, state: .ok) }
                        )
                    }
                    if let pending = model.pending {
                        MessageBubble(role: .user, text: pending.userText, tools: [])
                        MessageBubble(role: .assistant, text: pending.text, tools: pending.tools, isStreaming: true)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: model.pending?.text) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle(model.title ?? "Neuer Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = model.error { ErrorText(message: error) }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Nachricht…", text: $model.input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .disabled(model.isSending)
                MicButton(text: $model.input)
                    .disabled(model.isSending)
                Button {
                    Task { if await model.send() { app.didChangeData() } }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(model.isSending || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Senden")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct MessageBubble: View {
    let role: MessageRole
    let text: String
    let tools: [ToolChip]
    var isStreaming = false

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tools) { tool in
                    Label(tool.name, systemImage: icon(for: tool.state))
                        .font(.caption)
                        .foregroundStyle(tool.state == .error ? Color.red : Color.secondary)
                        .symbolEffect(.pulse, isActive: tool.state == .running)
                }
                if !text.isEmpty {
                    MarkdownText(text: text)
                } else if isStreaming && !tools.contains(where: { $0.state == .running }) {
                    ProgressView()
                }
            }
            .padding(10)
            .background(
                role == .user ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            if role == .assistant { Spacer(minLength: 48) }
        }
    }

    private func icon(for state: ToolState) -> String {
        switch state {
        case .running: "hourglass"
        case .ok: "wrench.and.screwdriver"
        case .error: "exclamationmark.triangle"
        }
    }
}
