import Foundation

enum ToolState: Equatable { case running, ok, error }

struct ToolChip: Identifiable, Equatable {
    var id: String
    var name: String
    var state: ToolState
}

struct PendingTurn: Equatable {
    var userText: String
    var text = ""
    var tools: [ToolChip] = []
    var error: String?
    var finished = false

    init(userText: String) { self.userText = userText }

    mutating func apply(_ event: ChatStreamEvent) {
        switch event {
        case .text(let delta):
            text += delta
        case .toolStart(let name, let id):
            tools.append(ToolChip(id: id, name: name, state: .running))
        case .toolEnd(_, let id, let isError):
            if let index = tools.firstIndex(where: { $0.id == id }) {
                tools[index].state = isError ? .error : .ok
            }
        case .done:
            finished = true
        case .error(let detail):
            finished = true
            error = detail
        }
    }
}

struct DisplayMessage: Identifiable, Equatable {
    var id: String
    var role: MessageRole
    var text: String
    var tools: [String]
}

enum ChatDisplay {
    // same as web: drop time prefix, tools as chips
    static func displayMessages(_ messages: [Message]) -> [DisplayMessage] {
        messages.compactMap { message in
            var texts: [String] = []
            var tools: [String] = []
            for (index, block) in message.content.enumerated() {
                switch block["type"]?.stringValue {
                case "text":
                    guard let text = block["text"]?.stringValue else { continue }
                    // hide "[Jetzt: …]" prefix
                    if message.role == .user, index == 0, text.hasPrefix("[Jetzt:") { continue }
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { texts.append(text) }
                case "tool_use":
                    if let name = block["name"]?.stringValue { tools.append(name) }
                default:
                    continue
                }
            }
            guard !texts.isEmpty || !tools.isEmpty else { return nil }
            return DisplayMessage(id: message.id, role: message.role, text: texts.joined(separator: "\n\n"), tools: tools)
        }
    }
}
