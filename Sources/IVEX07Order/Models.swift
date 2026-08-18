import Foundation

enum ProductStatus: String, Codable, CaseIterable {
    case newOrder = "Нова поръчка"
    case accepted = "Приета"
    case processing = "В обработка"
    case ordered = "Поръчана"
    case partlyReady = "Частично готова"
    case ready = "Готова"
    case shipped = "Изпратена"
    case delivered = "Доставена"
    case cancelled = "Отказана"
}

struct ProductLine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var cartons = 1.0
    var piecesPerCarton = 1.0
    var unitPrice = 0.0
    var cbmPerCarton = 0.0
    var note = ""
    var status: ProductStatus = .newOrder
    var statusNote = ""

    var totalQuantity: Double { cartons * piecesPerCarton }
    var totalPrice: Double { totalQuantity * unitPrice }
    var totalCBM: Double { cartons * cbmPerCarton }
    var hasOrderData: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct StoreOrder: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: Int
    var name: String
    var orderNumber: String
    var products: [ProductLine] = []
    var sentToSupplier = false
    var completedAt: Date?

    var usedProducts: [ProductLine] { products.filter(\.hasOrderData) }
    var totalPrice: Double { usedProducts.reduce(0) { $0 + $1.totalPrice } }
    var totalCBM: Double { usedProducts.reduce(0) { $0 + $1.totalCBM } }
}
