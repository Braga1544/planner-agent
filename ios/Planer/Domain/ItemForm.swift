import Foundation

struct ItemForm: Equatable {
    var type: ItemType = .todo
    var title = ""
    var body = ""
    var area: AreaSlug = .personal
    var projectId: String?
    var priority: Priority = .normal
    var dueDate: String?
    var status: ItemStatus = .open

    static func empty(area: AreaSlug = .personal, projectId: String? = nil, type: ItemType = .todo) -> ItemForm {
        var form = ItemForm()
        form.area = area
        form.projectId = projectId
        form.type = type
        return form
    }

    init() {}

    init(item: Item) {
        type = item.type
        title = item.title
        body = item.body ?? ""
        area = item.area
        projectId = item.projectId
        priority = item.priority
        dueDate = item.dueDate
        status = item.status
    }

    func create() -> ItemCreate {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return ItemCreate(
            type: type, area: area, projectId: projectId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: trimmedBody.isEmpty ? nil : trimmedBody,
            priority: priority,
            dueDate: type == .todo ? dueDate : nil
        )
    }

    func update() -> ItemUpdate {
        let base = create()
        return ItemUpdate(
            type: base.type, area: base.area, projectId: base.projectId, title: base.title,
            body: base.body, status: status, priority: base.priority, dueDate: base.dueDate
        )
    }

    static func groupByType(_ items: [Item]) -> [ItemType: [Item]] {
        var groups: [ItemType: [Item]] = [.todo: [], .idea: [], .note: []]
        for item in items { groups[item.type, default: []].append(item) }
        return groups
    }
}
