import Foundation

public struct IntentStatusData: Codable, Sendable {
    public let status: String
    public init(status: String) { self.status = status }
}

public struct IntentStatusResponse: Codable, Sendable {
    public let intent: IntentStatusData
    public let transactions: [YPJSONObject]
    public init(intent: IntentStatusData, transactions: [YPJSONObject] = []) {
        self.intent = intent
        self.transactions = transactions
    }

    private enum CodingKeys: String, CodingKey { case intent, transactions }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decode(IntentStatusData.self, forKey: .intent)
        transactions = try container.decodeIfPresent([YPJSONObject].self, forKey: .transactions) ?? []
    }
}

extension IntentStatusResponse {
    var resolvedStatus: IntentStatus {
        IntentStatus.from(intent.status)
    }

    func declinedTransaction(matchingPuid puid: String?) -> YPJSONObject? {
        guard let puid = puid?.trimmingCharacters(in: .whitespacesAndNewlines), !puid.isEmpty else { return nil }

        return transactions.reversed().first { transaction in
            guard isDeclined(transaction) else { return false }
            guard case .string(let transactionPuid)? = transaction["puid"] else { return false }
            return transactionPuid.trimmingCharacters(in: .whitespacesAndNewlines) == puid
        }
    }

    func declinedTransaction(changedSince baseline: IntentStatusResponse) -> YPJSONObject? {
        transactions.enumerated().reversed().first { index, transaction in
            guard isDeclined(transaction) else { return false }

            if let identity = transactionIdentity(transaction),
               let baselineTransaction = baseline.transactions.first(where: { transactionIdentity($0) == identity }) {
                return !isDeclined(baselineTransaction)
            }

            if index < baseline.transactions.count {
                return !isDeclined(baseline.transactions[index])
            }

            return true
        }?.element
    }

    private func isDeclined(_ transaction: YPJSONObject) -> Bool {
        guard case .string(let status)? = transaction["status"] else { return false }
        return status.uppercased() == "DECLINED"
    }

    private func transactionIdentity(_ transaction: YPJSONObject) -> String? {
        transaction.transactionDisplayId
    }
}

extension YPJSONObject {
    var transactionDisplayId: String? {
        guard let id = self["id"] else { return nil }
        switch id {
        case .string(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .number(let value):
            guard value.isFinite else { return nil }
            if value.rounded() == value, value >= Double(Int64.min), value <= Double(Int64.max) {
                return String(Int64(value))
            }
            return String(value)
        case .bool, .object, .array, .null:
            return nil
        }
    }
}

public enum IntentStatus: String, Codable, Sendable {
    case requiresPaymentData = "RequiresPaymentData"
    case requiresPaymentMethod = "RequiresPaymentMethod"
    case expired = "Expired"
    case success = "Success"

    public static func from(_ raw: String) -> IntentStatus {
        switch raw {
        case Self.requiresPaymentData.rawValue, "Pending":
            return .requiresPaymentData
        case Self.requiresPaymentMethod.rawValue:
            return .requiresPaymentMethod
        case Self.expired.rawValue:
            return .expired
        case Self.success.rawValue:
            return .success
        default:
            return .requiresPaymentData
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .success, .expired: return true
        case .requiresPaymentData, .requiresPaymentMethod: return false
        }
    }
}

public enum WaitForResultStatus: String, Codable, Sendable {
    case requiresPaymentData = "RequiresPaymentData"
    case requiresPaymentMethod = "RequiresPaymentMethod"
    case expired = "Expired"
    case success = "Success"
    case declined = "Declined"
}
