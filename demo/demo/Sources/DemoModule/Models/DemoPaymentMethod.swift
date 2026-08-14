enum DemoPaymentMethod: String, Identifiable {
    case card
    case fasterPayments
    case sberPay

    var id: String { rawValue }

    init?(rawType: String) {
        switch rawType.lowercased() {
        case "card":
            self = .card
        case "fasterpayments", "sbp":
            self = .fasterPayments
        case "sberpay":
            self = .sberPay
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .card:
            return "Банковская карта"
        case .fasterPayments:
            return "СБП"
        case .sberPay:
            return "SberPay"
        }
    }

    var subtitle: String {
        switch self {
        case .card:
            return "Visa, Mastercard, МИР"
        case .fasterPayments:
            return "Оплата через приложение банка"
        case .sberPay:
            return "Оплата через SberPay"
        }
    }

    var iconName: String {
        switch self {
        case .card:
            return "creditcard"
        case .fasterPayments:
            return "qrcode"
        case .sberPay:
            return "arrow.up.right.square"
        }
    }
}
