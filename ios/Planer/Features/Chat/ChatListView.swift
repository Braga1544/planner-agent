import SwiftUI

struct ChatListView: View {
    @Environment(AppModel.self) private var app
    @State private var model: ChatListViewModel
    @State private var path: [Conversation] = []
    @State private var creating = false

    init(client: APIClient) {
        _model = State(initialValue: ChatListViewModel(client: client))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let error = model.error { ErrorText(message: error) }
                if model.conversations.isEmpty && model.error == nil {
                    Text("Noch keine Chats. Starte mit „Neuer Chat“.").foregroundStyle(.secondary)
                }
                ForEach(model.conversations) { conversation in
                    NavigationLink(value: conversation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.title ?? "Neuer Chat").lineLimit(1)
                            Text(BerlinTime.formatDateTime(conversation.updatedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            creating = true
                            if let conversation = await model.create() { path.append(conversation) }
                            creating = false
                        }
                    } label: {
                        Label("Neuer Chat", systemImage: "square.and.pencil")
                    }
                    .disabled(creating)
                }
            }
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(client: model.client, conversation: conversation)
            }
            .refreshable { await model.load() }
            .task(id: app.dataVersion) { await model.load() }
        }
    }
}
