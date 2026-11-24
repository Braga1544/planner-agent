import Testing
@testable import Planer

struct ItemFormTests {
    @Test func createTrimsAndDropsDueDateForNonTodos() {
        var form = ItemForm.empty(area: .hobby, projectId: "p1")
        form.title = "  Material bestellen "
        form.body = "  "
        form.dueDate = "2026-10-16"
        let create = form.create()
        #expect(create.title == "Material bestellen")
        #expect(create.body == nil)
        #expect(create.projectId == "p1")
        #expect(create.dueDate == "2026-10-16")
        form.type = .idea
        #expect(form.create().dueDate == nil)
    }

    @Test func roundTripFromItem() {
        let item = Fixtures.item(area: .work, projectId: "p2", type: .todo, title: "Bericht", status: .done, priority: .high, dueDate: "2026-10-20")
        let update = ItemForm(item: item).update()
        #expect(update.status == .done)
        #expect(update.priority == .high)
        #expect(update.projectId == "p2")
        #expect(update.dueDate == "2026-10-20")
    }

    @Test func groupByType() {
        let groups = ItemForm.groupByType([Fixtures.item(type: .todo), Fixtures.item(type: .note), Fixtures.item(type: .todo)])
        #expect(groups[.todo]?.count == 2)
        #expect(groups[.note]?.count == 1)
        #expect(groups[.idea] == [])
    }
}
