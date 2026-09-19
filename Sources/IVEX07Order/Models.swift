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

enum OrderStatus: String, Codable, CaseIterable {
    case sentToOffice = "Изпратена до офиса"
    case accepted = "Приета"
    case processing = "В обработка"
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
    var photoData: Data?

    var totalQuantity: Double { cartons * piecesPerCarton }
    var totalPrice: Double { totalQuantity * unitPrice }
    var totalCBM: Double { cartons * cbmPerCarton }
    var hasOrderData: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct ClientProfile: Codable, Equatable {
    var name = ""
    var company = ""
    var phone = ""
    var email = ""

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct StoreOrder: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: Int
    var name: String
    var orderNumber: String
    var products: [ProductLine] = []
    var businessCardData: Data?
    var depositRmb = 0.0
    var orderStatus: OrderStatus = .sentToOffice
    var shoppingPeriodID = ""
    var sentToSupplier = false
    var completedAt: Date?

    var usedProducts: [ProductLine] { products.filter(\.hasOrderData) }
    var totalPrice: Double { usedProducts.reduce(0) { $0 + $1.totalPrice } }
    var totalCBM: Double { usedProducts.reduce(0) { $0 + $1.totalCBM } }
    var remainingRmb: Double { max(0, totalPrice - depositRmb) }

    private enum CodingKeys: String, CodingKey {
        case id, number, name, orderNumber, products, businessCardData, depositRmb
        case orderStatus, shoppingPeriodID, sentToSupplier, completedAt
    }

    init(
        id: UUID = UUID(),
        number: Int,
        name: String,
        orderNumber: String,
        products: [ProductLine] = [],
        businessCardData: Data? = nil,
        depositRmb: Double = 0,
        orderStatus: OrderStatus = .sentToOffice,
        shoppingPeriodID: String = "",
        sentToSupplier: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.orderNumber = orderNumber
        self.products = products
        self.businessCardData = businessCardData
        self.depositRmb = depositRmb
        self.orderStatus = orderStatus
        self.shoppingPeriodID = shoppingPeriodID
        self.sentToSupplier = sentToSupplier
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try values.decode(Int.self, forKey: .number)
        name = try values.decode(String.self, forKey: .name)
        orderNumber = try values.decode(String.self, forKey: .orderNumber)
        products = try values.decodeIfPresent([ProductLine].self, forKey: .products) ?? []
        businessCardData = try values.decodeIfPresent(Data.self, forKey: .businessCardData)
        depositRmb = try values.decodeIfPresent(Double.self, forKey: .depositRmb) ?? 0
        orderStatus = try values.decodeIfPresent(OrderStatus.self, forKey: .orderStatus) ?? .sentToOffice
        shoppingPeriodID = try values.decodeIfPresent(String.self, forKey: .shoppingPeriodID) ?? ""
        sentToSupplier = try values.decodeIfPresent(Bool.self, forKey: .sentToSupplier) ?? false
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

struct AppSettings: Codable, Equatable {
    var languageCode = "bg"
    var smartPriceCoefficient = 0.18
    var eurExchangeRate = 8.40
    var wechatQRData: Data?
}
