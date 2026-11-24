import Foundation
import Testing
@testable import Planer

@MainActor
struct ChatViewModelTests {
    let server = StubServer()
    let history = """
    [{"id":"m1","seq":1,"role":"user","content":[{"type":"text","text":"[Jetzt: Sa 10.10.2026 14:00]"},{"type":"text","text":"Was steht an?"}],"usage":null,"created_at":"x"},
     {"id":"m2","seq":2,"role":"assistant","content":[{"type":"text","text":"Heute ist frei."}],"usage":null,"created_at":"x"}]
    """

    @Test func sendStreamsAndReloadsHistory() async {
        server.onSSE("POST", "/conversations/c1/messages",
                     "event: text\ndata: {\"delta\":\"Heute ist frei.\"}\n\nevent: done\ndata: {\"message_id\":\"m2\"}\n\n")
        server.on("GET", "/conversations/c1/messages", json: history)
        let model = ChatViewModel(client: server.client(), conversationId: "c1")
        model.input = "Was steht an?"
        let ran = await model.send()
        #expect(ran)
        #expect(server.requests("POST", "/conversations/c1/messages").first?.json["text"] as? String == "Was steht an?")
        #expect(model.messages.map(\.text) == ["Was steht an?", "Heute ist frei."])
        #expect(model.pending == nil)
        #expect(model.error == nil)
        #expect(model.input == "")
    }

    @Test func sendPicksUpServerTitle() async {
        server.onSSE("POST", "/conversations/c1/messages", "event: done\ndata: {\"message_id\":\"m2\"}\n\n")
        server.on("GET", "/conversations/c1/messages", json: history)
        server.on("GET", "/conversations", json: #"[{"id":"c1","title":"Was steht an?","updated_at":"2026-10-10T12:00:00Z"}]"#)
        let model = ChatViewModel(client: server.client(), conversationId: "c1")
        #expect(model.title == nil)
        model.input = "Was steht an?"
        _ = await model.send()
        #expect(model.title == "Was steht an?")
        #expect(model.error == nil)
    }

    @Test func conflictRestoresInput() async {
        server.on("POST", "/conversations/c1/messages", status: 409, json: #"{"detail":"In diesem Chat läuft bereits eine Anfrage"}"#)
        let model = ChatViewModel(client: server.client(), conversationId: "c1")
        model.input = "Hallo"
        #expect(await model.send() == false)
        #expect(model.error == "In diesem Chat läuft bereits eine Anfrage")
        #expect(model.input == "Hallo")
        #expect(model.pending == nil)
    }

    @Test func interruptedStreamShowsHint() async {
        server.onSSE("POST", "/conversations/c1/messages", "event: text\ndata: {\"delta\":\"Hal\"}\n\n")
        server.on("GET", "/conversations/c1/messages", json: "[]")
        let model = ChatViewModel(client: server.client(), conversationId: "c1")
        model.input = "Hallo"
        _ = await model.send()
        #expect(model.error == ChatStream.interrupted)
    }

    @Test func blankInputDoesNothing() async {
        let model = ChatViewModel(client: server.client(), conversationId: "c1")
        model.input = "   "
        #expect(await model.send() == false)
        #expect(server.requests("POST", "/conversations/c1/messages").isEmpty)
    }

    @Test func listCreatesConversation() async {
        server.on("POST", "/conversations", status: 201, json: #"{"id":"c9","title":null,"created_at":"x","updated_at":"2026-10-10T12:00:00Z"}"#)
        let list = ChatListViewModel(client: server.client())
        let created = await list.create()
        #expect(created?.id == "c9")
    }
}
