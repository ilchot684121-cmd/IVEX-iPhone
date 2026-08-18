import Foundation
import Combine

@MainActor
final class OrderStore: ObservableObject {
    @Published var clientName = ""
    @Published var stores: [StoreOrder] = []
    @Published var selectedStoreID: UUID?
    @Published var history: [StoreOrder] = []

    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("ivex07-order.json")
        load()
        if stores.isEmpty { addStore() }
    }

    var selectedStore: StoreOrder? {
        stores.first { $0.id == selectedStoreID } ?? stores.first
    }

    func addStore() {
        let next = (stores.map(\.number).max() ?? 0) + 1
        let order = StoreOrder(
            number: next,
            name: "Магазин \(next)",
            orderNumber: Self.makeOrderNumber()
        )
        stores.append(order)
        selectedStoreID = order.id
        save()
    }

    func select(_ id: UUID) { selectedStoreID = id }

    func updateStore(_ updated: StoreOrder) {
        guard let index = stores.firstIndex(where: { $0.id == updated.id }) else { return }
        stores[index] = updated
        selectedStoreID = updated.id
        save()
    }

    func deleteStore(_ id: UUID) {
        stores.removeAll { $0.id == id }
        selectedStoreID = stores.first?.id
        if stores.isEmpty { addStore() }
        save()
    }

    func completeShopping() {
        let completed = stores.filter { !$0.usedProducts.isEmpty }.map { value -> StoreOrder in
            var copy = value
            copy.completedAt = Date()
            return copy
        }
        history.insert(contentsOf: completed, at: 0)
        stores = []
        selectedStoreID = nil
        addStore()
        save()
    }

    func reorder(_ archived: StoreOrder) {
        var copy = archived
        copy.id = UUID()
        copy.number = (stores.map(\.number).max() ?? 0) + 1
        copy.orderNumber = Self.makeOrderNumber()
        copy.sentToSupplier = false
        copy.completedAt = nil
        copy.products = copy.products.map { item in
            var product = item
            product.id = UUID()
            product.status = .newOrder
            product.statusNote = ""
            return product
        }
        stores.append(copy)
        selectedStoreID = copy.id
        save()
    }

    private struct Snapshot: Codable {
        var clientName: String
        var stores: [StoreOrder]
        var selectedStoreID: UUID?
        var history: [StoreOrder]
    }

    private func save() {
        let snapshot = Snapshot(clientName: clientName, stores: stores, selectedStoreID: selectedStoreID, history: history)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        clientName = snapshot.clientName
        stores = snapshot.stores
        selectedStoreID = snapshot.selectedStoreID
        history = snapshot.history
    }

    private static func makeOrderNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}
