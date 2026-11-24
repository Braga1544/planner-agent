import Foundation
import Testing
@testable import Planer

struct ChatDisplayTests {
    private func message(_ id: String, _ role: MessageRole, _ json: String) throws -> Message {
        let content = try JSONDecoder().decode([JSONValue].self, from: Data(json.utf8))
        return Message(id: id, seq: 0, role: role, content: content)
    }

    @Test func hidesTimePrefixAndToolResults() throws {
        let messages = [
            try message("u1", .user, #"[{"type":"text","text":"[Jetzt: Sa 10.10.2026 14:00]"},{"type":"text","text":"Was steht an?"}]"#),
            try message("a1", .assistant, #"[{"type":"thinking","thinking":""},{"type":"tool_use","id":"t1","name":"get_agenda","input":{}}]"#),
            try message("u2", .user, #"[{"type":"tool_result","tool_use_id":"t1","content":"[]"}]"#),
            try message("a2", .assistant, #"[{"type":"text","text":"Heute ist frei."}]"#),
        ]
        #expect(ChatDisplay.displayMessages(messages) == [
            DisplayMessage(id: "u1", role: .user, text: "Was steht an?", tools: []),
            DisplayMessage(id: "a1", role: .assistant, text: "", tools: ["get_agenda"]),
            DisplayMessage(id: "a2", role: .assistant, text: "Heute ist frei.", tools: []),
        ])
    }

    @Test func prefixOnlyHiddenAsFirstUserBlock() throws {
        let display = ChatDisplay.displayMessages([
            try message("a1", .assistant, #"[{"type":"text","text":"[Jetzt: bleibt sichtbar]"}]"#),
        ])
        #expect(display.first?.text == "[Jetzt: bleibt sichtbar]")
    }

    @Test func pendingTurnAppliesEvents() {
        var turn = PendingTurn(userText: "Hallo")
        turn.apply(.toolStart(name: "search", id: "t1"))
        turn.apply(.text("Hal"))
        turn.apply(.text("lo"))
        turn.apply(.toolEnd(name: "search", id: "t1", isError: false))
        #expect(turn.text == "Hallo")
        #expect(turn.tools == [ToolChip(id: "t1", name: "search", state: .ok)])
        #expect(!turn.finished)
        turn.apply(.error("kaputt"))
        #expect(turn.finished)
        #expect(turn.error == "kaputt")
    }
}
