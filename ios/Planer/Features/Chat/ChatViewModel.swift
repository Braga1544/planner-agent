import Foundation
import Observation

@MainActor
@Observable
final class ChatListViewModel {
    @ObservationIgnored let client: APIClient
    private(set) var conversations: [Conversation] = []
    var error: String?

    init(client: APIClient) { self.client = client }

    func load() async {
        do {
            conversations = try await client.get("/conversations")
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func create() async -> Conversation? {
        do {
            let conversation: Conversation = try await client.post("/conversations")
            return conversation
        } catch {
            self.error = errorMessage(error)
            return nil
        }
    }
}

@MainActor
@Observable
final class ChatViewModel {
    @ObservationIgnored let client: APIClient
    let conversationId: String
    private(set) var title: String?
    private(set) var messages: [DisplayMessage] = []
    private(set) var pending: PendingTurn?
    var input = ""
    var error: String?

    init(client: APIClient, conversationId: String, title: String? = nil) {
        self.client = client
        self.conversationId = conversationId
        self.title = title
    }

    var isSending: Bool { pending != nil }

    func load() async {
        do {
            let raw: [Message] = try await client.get("/conversations/\(conversationId)/messages")
            messages = ChatDisplay.displayMessages(raw)
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func send() async -> Bool {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, pending == nil else { return false }
        input = ""
        error = nil
        pending = PendingTurn(userText: text)
        do {
            try await ChatStream.send(client: client, conversationId: conversationId, text: text) { [weak self] event in
                self?.pending?.apply(event)
            }
        } catch {
            pending = nil
            input = text
            self.error = errorMessage(error)
            return false
        }
        let streamError = pending?.error
        await load() // load history first, then drop the live bubble
        pending = nil
        error = streamError
        await refreshTitle()
        return true
    }

    // title comes with the first msg, no single endpoint, so go through the list
    private func refreshTitle() async {
        guard title == nil,
              let conversations: [Conversation] = try? await client.get("/conversations") else { return }
        title = conversations.first { $0.id == conversationId }?.title
    }
}
