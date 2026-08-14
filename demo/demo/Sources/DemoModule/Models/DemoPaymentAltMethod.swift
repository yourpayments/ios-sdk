enum DemoPaymentAltMethod: String {
    case fasterPayments
    case sberPay

    var title: String {
        switch self {
        case .fasterPayments:
            return "СБП"
        case .sberPay:
            return "SberPay"
        }
    }

    var actionTitle: String {
        switch self {
        case .fasterPayments:
            return "Открыть СБП"
        case .sberPay:
            return "Открыть SberPay"
        }
    }

    var openErrorMessage: String {
        switch self {
        case .fasterPayments:
            return "Не удалось открыть приложение банка или веб-клиент СБП"
        case .sberPay:
            return "Не удалось открыть SberPay"
        }
    }
}

