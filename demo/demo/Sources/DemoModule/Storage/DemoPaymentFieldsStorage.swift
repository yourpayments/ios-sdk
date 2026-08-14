import Foundation

enum DemoPaymentFieldType: Codable {
    case merchantCode
    case amount
    case currency

    var title: String {
        switch self {
        case .merchantCode: return DemoConstants.Text.merchantCodeTitle
        case .amount: return DemoConstants.Text.amountTitle
        case .currency: return DemoConstants.Text.currencyTitle
        }
    }

    var `default`: String {
        switch self {
        case .merchantCode: return DemoConstants.Text.merchantCodeDefault
        case .amount: return DemoConstants.Text.amountDefault
        case .currency: return DemoConstants.Text.currencyDefault
        }
    }

    var placeholder: String { return DemoConstants.Text.fieldPlaceholder }
}

struct DemoPaymentField: Codable {
    let type: DemoPaymentFieldType
    var text: String?

    init(_ type: DemoPaymentFieldType, text: String? = nil) {
        self.type = type
        self.text = text ?? type.default
    }
}

enum DemoPaymentFieldsStorage {
    private static let key = DemoConstants.Storage.paymentFieldsKey
    private static let minimalTypes: [DemoPaymentFieldType] = [
        .merchantCode,
        .amount,
        .currency
    ]

    static func load() -> [DemoPaymentField] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let array = try? JSONDecoder().decode([DemoPaymentField].self, from: data)
        else {
            return minimalTypes.map { DemoPaymentField($0) }
        }

        let savedByType = Dictionary(uniqueKeysWithValues: array.map { ($0.type, $0) })
        return minimalTypes.map { savedByType[$0] ?? DemoPaymentField($0) }
    }

    static func save(_ model: [DemoPaymentField]) {
        let data = try? JSONEncoder().encode(model)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
