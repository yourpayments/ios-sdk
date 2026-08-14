import Foundation
import Yourpayments

struct DemoStatusDetails {
    let resolvedStatus: WaitForResultStatus
    let intentStatus: String
    let transactionStatus: String

    init(response: IntentStatusResponse) {
        self.resolvedStatus = Self.resolve(intentStatus: response.intent.status)
        self.intentStatus = response.intent.status
        self.transactionStatus = Self.transactionStatus(from: response.transactions)
    }

    init(resolvedStatus: IntentStatus, data: IntentResponse) {
        self.resolvedStatus = Self.resolve(intentStatus: data.status, fallback: resolvedStatus)
        self.intentStatus = data.status
        self.transactionStatus = Self.transactionStatus(from: data.transactions ?? [])
    }

    init(resolvedStatus: WaitForResultStatus, data: IntentResponse) {
        self.resolvedStatus = resolvedStatus
        self.intentStatus = data.status
        self.transactionStatus = Self.transactionStatus(from: data.transactions ?? [])
    }

    var message: String {
        "Status: \(resolvedStatus.rawValue)\nintent status: \(intentStatus)\ntransaction status: \(transactionStatus)"
    }

    var hasDeclinedTransaction: Bool {
        transactionStatus
            .split(separator: ",")
            .contains { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DECLINED" }
    }

    private static func transactionStatus(from transactions: [YPJSONObject]) -> String {
        let statuses = transactions.compactMap { transaction -> String? in
            guard case .string(let status)? = transaction["status"] else { return nil }
            return status
        }
        return statuses.isEmpty ? "unknown" : statuses.joined(separator: ", ")
    }

    private static func resolve(intentStatus: String) -> WaitForResultStatus {
        resolve(intentStatus: intentStatus, fallback: IntentStatus.from(intentStatus))
    }

    private static func resolve(intentStatus: String, fallback: IntentStatus) -> WaitForResultStatus {
        switch fallback {
        case .requiresPaymentData:
            return .requiresPaymentData
        case .requiresPaymentMethod:
            return .requiresPaymentMethod
        case .expired:
            return .expired
        case .success:
            return .success
        }
    }

    private static func waitStatus(from status: IntentStatus) -> WaitForResultStatus {
        switch status {
        case .requiresPaymentData:
            return .requiresPaymentData
        case .requiresPaymentMethod:
            return .requiresPaymentMethod
        case .expired:
            return .expired
        case .success:
            return .success
        }
    }
}
