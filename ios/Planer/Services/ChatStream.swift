import Foundation

enum ChatStreamEvent: Equatable {
    case text(String)
    case toolStart(name: String, id: String)
    case toolEnd(name: String, id: String, isError: Bool)
    case done(messageId: String?)
    case error(String)
}

enum ChatStream {
    static let interrupted = "Verbindung unterbrochen. Die Antwort wird im Hintergrund trotzdem gespeichert – lade den Chat gleich neu."

    static func event(from sse: SSEEvent) -> ChatStreamEvent? {
        let payload = (try? JSONSerialization.jsonObject(with: Data(sse.data.utf8))) as? [String: Any] ?? [:]
        let name = payload["name"] as? String ?? ""
        let id = payload["id"] as? String ?? ""
        switch sse.event {
        case "text": return .text(payload["delta"] as? String ?? "")
        case "tool_start": return .toolStart(name: name, id: id)
        case "tool_end": return .toolEnd(name: name, id: id, isError: payload["is_error"] as? Bool ?? false)
        case "done": return .done(messageId: payload["message_id"] as? String)
        case "error": return .error(payload["detail"] as? String ?? "Unbekannter Fehler")
        default: return nil
        }
    }

    // no done/error or aborted -> interrupted
    static func consume<S: AsyncSequence>(_ bytes: S, onEvent: @MainActor (ChatStreamEvent) -> Void) async where S.Element == UInt8 {
        var finished = false
        do {
            for try await sse in SSEEventSequence(base: bytes) {
                guard let event = Self.event(from: sse) else { continue }
                switch event {
                case .done, .error: finished = true
                default: break
                }
                await onEvent(event)
                if finished { break }
            }
        } catch {
            // aborted midway, reported below
        }
        // task cancel is not an interruption
        if !finished && !Task.isCancelled { await onEvent(.error(interrupted)) }
    }

    // errors before the stream (409 etc) are thrown
    static func send(client: APIClient, conversationId: String, text: String, onEvent: @MainActor (ChatStreamEvent) -> Void) async throws {
        let bytes = try await client.stream("/conversations/\(conversationId)/messages", body: ChatRequest(text: text))
        await consume(bytes, onEvent: onEvent)
    }
}
