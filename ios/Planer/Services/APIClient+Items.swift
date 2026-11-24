import Foundation

extension APIClient {
    func toggleDone(_ item: Item) async throws {
        let _: Item = try await patch("/items/\(item.id)", body: StatusUpdate(status: item.status == .done ? .open : .done))
    }
}
