enum DemoPaymentResult {
    case success(title: String, message: String)
    case attention(title: String, message: String)
    case failure(title: String, message: String)

    static func status(_ details: DemoStatusDetails) -> DemoPaymentResult {
        if details.hasDeclinedTransaction {
            return .failure(title: "Транзакция отклонена", message: details.message)
        }

        switch details.resolvedStatus {
        case .success:
            return .success(title: "Платеж выполнен", message: details.message)
        case .expired, .declined:
            return .failure(title: "Не удалось оплатить", message: details.message)
        case .requiresPaymentData, .requiresPaymentMethod:
            return .attention(title: "Платеж обрабатывается", message: details.message)
        }
    }

    static func success(details: DemoStatusDetails) -> DemoPaymentResult {
        .success(title: "Платеж выполнен", message: details.message)
    }

    static func attention(title: String, details: DemoStatusDetails) -> DemoPaymentResult {
        .attention(title: title, message: "Завершите подтверждение платежа и вернитесь в приложение.\n\(details.message)")
    }

    var title: String {
        switch self {
        case .success(let title, _), .attention(let title, _):
            return title
        case .failure(let title, _):
            return title
        }
    }

    var message: String {
        switch self {
        case .success(_, let message), .attention(_, let message), .failure(_, let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .attention:
            return "exclamationmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }

    var allowsStatusRefresh: Bool {
        switch self {
        case .attention:
            return true
        case .success, .failure:
            return false
        }
    }

    var accessibilityValue: String {
        switch self {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .attention:
            return "pending"
        }
    }
}
