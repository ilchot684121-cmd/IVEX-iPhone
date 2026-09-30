import Foundation

struct OfficeDelivery {
    let documentID: String
    let sourceOrderID: String
    let order: StoreOrder
}

enum IVEXSyncError: LocalizedError {
    case invalidResponse
    case server(Int, String)
    case authentication(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Няма валиден отговор от облака."
        case let .server(code, message): return "Облакът върна грешка \(code): \(message)"
        case let .authentication(message): return "Неуспешна връзка с облака: \(message)"
        }
    }
}

/// Uses the same Firebase anonymous authentication flow as the Android app.
/// Firestore rules require `request.auth` and a matching `authUid`.
@MainActor
final class FirebaseSyncService {
    private let projectID = "ivex07-cloud"
    private let databaseID = "(default)"
    private let apiKey = "AIzaSyB_Rzg4ChIlHHBFfuEo2TQe2QzD-cicoIM"
    private var cachedToken: AuthToken?

    func register(profile: ClientProfile, clientID: String) async throws {
        let auth = try await validAuthToken()
        let now = Self.timestamp()
        let fields: [String: Any] = [
            "clientId": value(clientID), "clientName": value(profile.name),
            "company": value(profile.company), "phone": value(profile.phone),
            "email": value(profile.email), "authUid": value(auth.localID),
            "platform": value("ios"), "appVersion": value("0.5.7"),
            "active": value(true), "updatedAt": timestampValue(now),
            "createdAt": timestampValue(now)
        ]
        try await write(collection: "registered_clients", documentID: clientID, fields: fields, idToken: auth.idToken)
    }

    func send(order: StoreOrder, profile: ClientProfile, clientID: String) async throws {
        let auth = try await validAuthToken()
        let products = order.usedProducts.map { product -> [String: Any] in
            ["mapValue": ["fields": [
                "id": value(product.id.uuidString), "name": value(product.name),
                "cartons": value(product.cartons), "pcsPerCarton": value(product.piecesPerCarton),
                "totalQuantity": value(product.totalQuantity), "unitPrice": value(product.unitPrice),
                "totalPrice": value(product.totalPrice), "cbmPerCarton": value(product.cbmPerCarton),
                "totalCubicMeters": value(product.totalCBM), "note": value(product.note),
                "productStatus": value(product.status.rawValue), "statusNote": value(product.statusNote),
                "hasLocalPhoto": value(product.photoData != nil)
            ]]]
        }
        let now = Self.timestamp()
        let fields: [String: Any] = [
            "orderNumber": value(order.orderNumber), "clientName": value(profile.name),
            "clientId": value(clientID), "clientCompany": value(profile.company),
            "clientPhone": value(profile.phone), "clientEmail": value(profile.email),
            "authUid": value(auth.localID), "recipientAuthUid": value(auth.localID),
            "recipientClientId": value(clientID), "storeName": value(order.name),
            "storeNumber": value(order.number), "supplierId": value("iphone"),
            "products": ["arrayValue": ["values": products]], "productCount": value(products.count),
            "totalPrice": value(order.totalPrice), "totalCubicMeters": value(order.totalCBM),
            "depositRmb": value(order.depositRmb), "remainingRmb": value(order.remainingRmb),
            "orderStatus": value(order.orderStatus.rawValue),
            "shoppingPeriodId": value(order.shoppingPeriodID.isEmpty ? Self.period() : order.shoppingPeriodID),
            "hasLocalBusinessCard": value(order.businessCardData != nil),
            "sourcePlatform": value("ios"), "cloudSchemaVersion": value(8),
            "appVersion": value("0.5.7"), "createdAt": timestampValue(now),
            "updatedAt": timestampValue(now)
        ]
        let safeOrderNumber = order.orderNumber.replacingOccurrences(
            of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression
        )
        try await write(
            collection: "orders", documentID: "\(clientID)_\(safeOrderNumber)",
            fields: fields, idToken: auth.idToken
        )
    }

    func receiveOfficeOrders(profile: ClientProfile, clientID: String) async throws -> [OfficeDelivery] {
        let auth = try await validAuthToken()
        let path = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/\(databaseID)/documents/orders?pageSize=500"
        guard let url = URL(string: path) else { throw IVEXSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(auth.idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, authentication: false)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IVEXSyncError.invalidResponse
        }
        let cleanName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (root["documents"] as? [[String: Any]] ?? []).compactMap { document in
            guard let fields = document["fields"] as? [String: Any],
                  fieldBool(fields, "officeCreated"),
                  fieldBool(fields, "deliverToAppHistory") else { return nil }
            let targetID = fieldString(fields, "recipientClientId").isEmpty
                ? fieldString(fields, "clientId") : fieldString(fields, "recipientClientId")
            let targetName = fieldString(fields, "clientName")
            guard targetID == clientID || (!cleanName.isEmpty && targetName.caseInsensitiveCompare(cleanName) == .orderedSame) else {
                return nil
            }
            let products = fieldArray(fields, "products").compactMap { raw -> ProductLine? in
                guard let map = raw["mapValue"] as? [String: Any],
                      let values = map["fields"] as? [String: Any] else { return nil }
                let name = fieldString(values, "name").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return ProductLine(
                    id: UUID(uuidString: fieldString(values, "id")) ?? UUID(),
                    name: name,
                    cartons: max(1, fieldDouble(values, "cartons")),
                    piecesPerCarton: max(1, fieldDouble(values, "pcsPerCarton")),
                    unitPrice: fieldDouble(values, "unitPrice"),
                    cbmPerCarton: fieldDouble(values, "cbmPerCarton"),
                    note: fieldString(values, "note"),
                    status: ProductStatus(rawValue: fieldString(values, "productStatus")) ?? .newOrder,
                    statusNote: fieldString(values, "statusNote")
                )
            }
            guard !products.isEmpty else { return nil }
            let documentName = document["name"] as? String ?? ""
            let documentID = documentName.split(separator: "/").last.map(String.init) ?? ""
            guard !documentID.isEmpty else { return nil }
            let storeNumber = max(1, Int(fieldDouble(fields, "storeNumber")))
            let order = StoreOrder(
                number: storeNumber,
                name: fieldString(fields, "storeName").isEmpty ? "Магазин \(storeNumber)" : fieldString(fields, "storeName"),
                orderNumber: fieldString(fields, "orderNumber"),
                products: products,
                depositRmb: fieldDouble(fields, "depositRmb"),
                shoppingPeriodID: fieldString(fields, "shoppingPeriodId"),
                completedAt: Date()
            )
            return OfficeDelivery(
                documentID: documentID,
                sourceOrderID: fieldString(fields, "sourceOrderId"),
                order: order
            )
        }
    }

    func acknowledgeOfficeOrder(documentID: String, sourceOrderID: String, clientID: String) async throws {
        let auth = try await validAuthToken()
        for targetID in [documentID, sourceOrderID].filter({ !$0.isEmpty }) {
            let encodedID = targetID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? targetID
            let path = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/\(databaseID)/documents/orders/\(encodedID)?updateMask.fieldPaths=recipientReceivedAt&updateMask.fieldPaths=recipientReceivedBy&updateMask.fieldPaths=recipientReceivedPlatform"
            guard let url = URL(string: path) else { throw IVEXSyncError.invalidResponse }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(auth.idToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 25
            request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": [
                "recipientReceivedAt": timestampValue(Self.timestamp()),
                "recipientReceivedBy": value(clientID),
                "recipientReceivedPlatform": value("ios")
            ]])
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data, authentication: false)
        }
    }

    private func validAuthToken() async throws -> AuthToken {
        if let token = cachedToken, token.expiresAt.timeIntervalSinceNow > 120 { return token }
        if let saved = AuthToken.load(), saved.expiresAt.timeIntervalSinceNow > 120 {
            cachedToken = saved
            return saved
        }
        if let saved = AuthToken.load(), !saved.refreshToken.isEmpty {
            do {
                let refreshed = try await refresh(saved)
                cachedToken = refreshed
                refreshed.save()
                return refreshed
            } catch {
                AuthToken.clear()
            }
        }
        let created = try await signInAnonymously()
        cachedToken = created
        created.save()
        return created
    }

    private func signInAnonymously() async throws -> AuthToken {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)") else {
            throw IVEXSyncError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: ["returnSecureToken": true])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, authentication: true)
        let payload = try JSONDecoder().decode(SignInResponse.self, from: data)
        return AuthToken(
            idToken: payload.idToken, refreshToken: payload.refreshToken, localID: payload.localId,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn) ?? 3600)
        )
    }

    private func refresh(_ old: AuthToken) async throws -> AuthToken {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)") else {
            throw IVEXSyncError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        let encoded = old.refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? old.refreshToken
        request.httpBody = "grant_type=refresh_token&refresh_token=\(encoded)".data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, authentication: true)
        let payload = try JSONDecoder().decode(RefreshResponse.self, from: data)
        return AuthToken(
            idToken: payload.idToken, refreshToken: payload.refreshToken, localID: payload.userId,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn) ?? 3600)
        )
    }

    private func write(collection: String, documentID: String, fields: [String: Any], idToken: String) async throws {
        let encodedID = documentID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? documentID
        let path = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/\(databaseID)/documents/\(collection)/\(encodedID)"
        guard let url = URL(string: path) else { throw IVEXSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, authentication: false)
    }

    private func validate(response: URLResponse, data: Data, authentication: Bool) throws {
        guard let http = response as? HTTPURLResponse else { throw IVEXSyncError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = Self.serverMessage(from: data)
            if authentication { throw IVEXSyncError.authentication(message) }
            throw IVEXSyncError.server(http.statusCode, message)
        }
    }

    private static func serverMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String { return message }
        return String(data: data, encoding: .utf8) ?? "Неизвестна грешка"
    }

    private func value(_ text: String) -> [String: Any] { ["stringValue": text] }
    private func value(_ number: Double) -> [String: Any] { ["doubleValue": number] }
    private func value(_ number: Int) -> [String: Any] { ["integerValue": String(number)] }
    private func value(_ flag: Bool) -> [String: Any] { ["booleanValue": flag] }
    private func timestampValue(_ text: String) -> [String: Any] { ["timestampValue": text] }

    private func fieldString(_ fields: [String: Any], _ key: String) -> String {
        guard let value = fields[key] as? [String: Any] else { return "" }
        if let text = value["stringValue"] as? String { return text }
        if let number = value["integerValue"] as? String { return number }
        if let number = value["doubleValue"] as? NSNumber { return number.stringValue }
        return ""
    }

    private func fieldDouble(_ fields: [String: Any], _ key: String) -> Double {
        guard let value = fields[key] as? [String: Any] else { return 0 }
        if let number = value["doubleValue"] as? NSNumber { return number.doubleValue }
        if let number = value["integerValue"] as? String { return Double(number) ?? 0 }
        if let number = value["stringValue"] as? String { return Double(number.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return 0
    }

    private func fieldBool(_ fields: [String: Any], _ key: String) -> Bool {
        guard let value = fields[key] as? [String: Any] else { return false }
        return value["booleanValue"] as? Bool ?? false
    }

    private func fieldArray(_ fields: [String: Any], _ key: String) -> [[String: Any]] {
        guard let value = fields[key] as? [String: Any],
              let array = value["arrayValue"] as? [String: Any] else { return [] }
        return array["values"] as? [[String: Any]] ?? []
    }

    private static func timestamp() -> String { ISO8601DateFormatter().string(from: Date()) }
    private static func period() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}

private struct SignInResponse: Decodable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String
    let localId: String
}

private struct RefreshResponse: Decodable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String
    let userId: String
    private enum CodingKeys: String, CodingKey {
        case idToken = "id_token", refreshToken = "refresh_token"
        case expiresIn = "expires_in", userId = "user_id"
    }
}

private struct AuthToken: Codable {
    let idToken: String
    let refreshToken: String
    let localID: String
    let expiresAt: Date
    private static let storageKey = "ivex07.firebase.auth.token"

    static func load() -> AuthToken? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AuthToken.self, from: data)
    }
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: storageKey) }
}
