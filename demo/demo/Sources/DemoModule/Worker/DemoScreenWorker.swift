import Foundation
import Yourpayments

final class DemoScreenWorker {
    func resetFields() {
        DemoPaymentFieldsStorage.reset()
    }

    func loadFields() -> DemoScreenFields {
        let fields = DemoPaymentFieldsStorage.load()

        return DemoScreenFields(
            merchantCode: text(for: .merchantCode, in: fields),
            amount: text(for: .amount, in: fields),
            currency: text(for: .currency, in: fields)
        )
    }

    func makeStartPayload(
        merchantCode: String,
        amount: String,
        currency: String,
        useDualMessagePayment: Bool,
        tokenize: Bool?
    ) -> DemoScreenStartPayload {
        let fields = [
            DemoPaymentField(.merchantCode, text: merchantCode),
            DemoPaymentField(.amount, text: amount),
            DemoPaymentField(.currency, text: currency)
        ]

        DemoPaymentFieldsStorage.save(fields)

        return DemoScreenStartPayload(
            merchantCode: merchantCode,
            amount: amount,
            currency: currency,
            useDualMessagePayment: useDualMessagePayment,
            tokenize: tokenize
        )
    }

    private func text(for type: DemoPaymentFieldType, in fields: [DemoPaymentField]) -> String {
        fields.first(where: { $0.type == type })?.text ?? type.default
    }
}

struct DemoScreenFields {
    let merchantCode: String
    let amount: String
    let currency: String
}
