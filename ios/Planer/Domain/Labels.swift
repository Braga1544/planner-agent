extension ItemType {
    var label: String {
        switch self {
        case .todo: "ToDo"
        case .idea: "Idee"
        case .note: "Notiz"
        }
    }

    var groupLabel: String {
        switch self {
        case .todo: "ToDos"
        case .idea: "Ideen"
        case .note: "Notizen"
        }
    }

    var symbol: String {
        switch self {
        case .todo: "circle"
        case .idea: "lightbulb"
        case .note: "note.text"
        }
    }
}

extension Priority {
    var label: String {
        switch self {
        case .high: "hoch"
        case .normal: "normal"
        case .low: "niedrig"
        }
    }
}

extension ItemStatus {
    var label: String {
        switch self {
        case .open: "offen"
        case .done: "erledigt"
        case .archived: "archiviert"
        }
    }
}

extension ProjectStatus {
    var label: String {
        switch self {
        case .active: "Aktiv"
        case .paused: "Pausiert"
        case .done: "Erledigt"
        case .archived: "Archiviert"
        }
    }
}
