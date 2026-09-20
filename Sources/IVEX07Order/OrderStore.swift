import Foundation
import Combine

@MainActor
final class OrderStore: ObservableObject {
    @Published var profile = ClientProfile()
    @Published var stores: [StoreOrder] = []
    @Published var selectedStoreID: UUID?
    @Published var history: [StoreOrder] = []
    @Published var settings = AppSettings()
    @Published var isSyncing = false
    @Published var syncMessage = ""

    private let fileURL: URL
    private var clientID = UUID().uuidString
    private let syncService = FirebaseSyncService()

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

    func renameStore(_ id: UUID, to name: String) {
        guard let index = stores.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        stores[index].name = clean.isEmpty ? "Магазин \(stores[index].number)" : clean
        save()
    }

    func updateDeposit(_ value: Double, for id: UUID) {
        guard let index = stores.firstIndex(where: { $0.id == id }) else { return }
        stores[index].depositRmb = max(0, value)
        save()
    }

    func updateSettings(_ updated: AppSettings) {
        settings = updated
        save()
    }

    func saveProfile(_ updated: ClientProfile) {
        profile = updated
        save()
        Task { await registerProfile() }
    }

    func registerProfile() async {
        guard profile.isComplete else { return }
        isSyncing = true
        syncMessage = "Регистрацията се изпраща..."
        do {
            try await syncService.register(profile: profile, clientID: clientID)
            syncMessage = "Регистрацията е получена в офиса"
        } catch {
            syncMessage = "Няма връзка. Данните са запазени в телефона."
        }
        isSyncing = false
    }

    func deleteProduct(_ productID: UUID, from storeID: UUID) {
        guard let index = stores.firstIndex(where: { $0.id == storeID }) else { return }
        stores[index].products.removeAll { $0.id == productID }
        save()
    }

    func addProduct(to storeID: UUID) {
        guard let index = stores.firstIndex(where: { $0.id == storeID }) else { return }
        stores[index].products.append(ProductLine())
        save()
    }

    func updateProduct(_ product: ProductLine, in storeID: UUID) {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let productIndex = stores[storeIndex].products.firstIndex(where: { $0.id == product.id }) else { return }
        stores[storeIndex].products[productIndex] = product
        save()
    }

    func saveNow() {
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

    func clearHistory() {
        history = []
        save()
    }

    func factoryReset() {
        profile = ClientProfile()
        stores = []
        selectedStoreID = nil
        history = []
        settings = AppSettings()
        clientID = UUID().uuidString
        addStore()
        save()
    }

    func sendAndCompleteShopping() async throws {
        let orders = stores.filter { !$0.usedProducts.isEmpty }
        guard !orders.isEmpty else { return }
        isSyncing = true
        syncMessage = "Изпращане към IVEX Office..."
        defer { isSyncing = false }
        try await syncService.register(profile: profile, clientID: clientID)
        for order in orders {
            try await syncService.send(order: order, profile: profile, clientID: clientID)
        }
        syncMessage = "Поръчката е получена в офиса"
        completeShopping()
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
        var profile: ClientProfile?
        var clientName: String?
        var clientID: String?
        var stores: [StoreOrder]
        var selectedStoreID: UUID?
        var history: [StoreOrder]
        var settings: AppSettings?
    }

    private func save() {
        let snapshot = Snapshot(profile: profile, clientName: nil, clientID: clientID, stores: stores, selectedStoreID: selectedStoreID, history: history, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        profile = snapshot.profile ?? ClientProfile(name: snapshot.clientName ?? "")
        clientID = snapshot.clientID ?? UUID().uuidString
        stores = snapshot.stores
        selectedStoreID = snapshot.selectedStoreID
        history = snapshot.history
        settings = snapshot.settings ?? AppSettings()
    }


    func csvURL(for selectedStore: StoreOrder? = nil) -> URL? {
        var rows = ["Клиент,Фирма,Магазин,Поръчка,Продукт,Кашони,Бройки в кашон,Количество,Единична цена RMB,Общо RMB,Кубици,Статус,Бележка"]
        let exportStores = selectedStore.map { [$0] } ?? stores
        for store in exportStores {
            for product in store.usedProducts {
                let values = [profile.name, profile.company, store.name, store.orderNumber, product.name,
                              String(product.cartons), String(product.piecesPerCarton), String(product.totalQuantity),
                              String(product.unitPrice), String(product.totalPrice), String(product.totalCBM),
                              product.status.rawValue, product.note]
                rows.append(values.map(Self.csvEscape).joined(separator: ","))
            }
        }
        let suffix = selectedStore.map { "Store_\($0.number)" } ?? "All_Stores"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("IVEX07_\(suffix)_\(Self.makeOrderNumber()).csv")
        do {
            try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }

    private static func csvEscape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func makeOrderNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}
