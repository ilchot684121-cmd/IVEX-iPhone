import Foundation

enum IVEXSyncError: LocalizedError {
    case invalidResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Няма валиден отговор от облака."
        case let .server(code, message):
            return "Облакът върна грешка \(code): \(message)"
        }
    }
}

struct FirebaseSyncService: Sendable {
    private let projectID = "ivex07-cloud"
    private let databaseID = "(default)"

    func register(profile: ClientProfile, clientID: String) async throws {
        let now = Self.timestamp()
        let fields: [String: Any] = [
            "clientId": value(clientID),
            "clientName": value(profile.name),
            "company": value(profile.company),
            "phone": value(profile.phone),
            "email": value(profile.email),
            "platform": value("ios"),
            "active": value(true),
            "updatedAt": timestampValue(now),
            "createdAt": timestampValue(now)
        ]
        try await write(collection: "registered_clients", documentID: clientID, fields: fields)
    }

    func send(order: StoreOrder, profile: ClientProfile, clientID: String) async throws {
        let products = order.usedProducts.map { product -> [String: Any] in
            [
                "mapValue": ["fields": [
                    "id": value(product.id.uuidString),
                    "name": value(product.name),
                    "cartons": value(product.cartons),
                    "pcsPerCarton": value(product.piecesPerCarton),
                    "totalQuantity": value(product.totalQuantity),
                    "unitPrice": value(product.unitPrice),
                    "totalPrice": value(product.totalPrice),
                    "cbmPerCarton": value(product.cbmPerCarton),
                    "totalCubicMeters": value(product.totalCBM),
                    "note": value(product.note),
                    "productStatus": value(product.status.rawValue),
                    "statusNote": value(product.statusNote),
                    "hasLocalPhoto": value(product.photoData != nil)
                ]]
            ]
        }
        let now = Self.timestamp()
        let fields: [String: Any] = [
            "orderNumber": value(order.orderNumber),
            "clientName": value(profile.name),
            "clientId": value(clientID),
            "clientCompany": value(profile.company),
            "clientPhone": value(profile.phone),
            "clientEmail": value(profile.email),
            "storeName": value(order.name),
            "storeNumber": value(order.number),
            "supplierId": value("iphone"),
            "shoppingPeriodId": value(Self.period()),
            "products": ["arrayValue": ["values": products]],
            "totalPrice": value(order.totalPrice),
            "totalCbm": value(order.totalCBM),
            "depositRmb": value(0.0),
            "remainingRmb": value(order.totalPrice),
            "sourcePlatform": value("ios"),
            "createdAt": timestampValue(now),
            "updatedAt": timestampValue(now)
        ]
        try await write(collection: "orders", documentID: order.id.uuidString, fields: fields)
    }

    private func write(collection: String, documentID: String, fields: [String: Any]) async throws {
        let encodedID = documentID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? documentID
        let path = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/\(databaseID)/documents/\(collection)/\(encodedID)"
        guard let url = URL(string: path) else { throw IVEXSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IVEXSyncError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Неизвестна грешка"
            throw IVEXSyncError.server(http.statusCode, message)
        }
    }

    private func value(_ text: String) -> [String: Any] { ["stringValue": text] }
    private func value(_ number: Double) -> [String: Any] { ["doubleValue": number] }
    private func value(_ number: Int) -> [String: Any] { ["integerValue": String(number)] }
    private func value(_ flag: Bool) -> [String: Any] { ["booleanValue": flag] }
    private func timestampValue(_ text: String) -> [String: Any] { ["timestampValue": text] }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func period() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}
