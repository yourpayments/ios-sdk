import Foundation
import Yourpayments

final class DemoCreateIntentRequestFactory {
    func makeCreateIntentRequest(payload: DemoScreenStartPayload) throws -> CreateIntentRequest {
        let merchantCode = payload.merchantCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchantCode.isEmpty else {
            throw DemoCreateIntentRequestFactoryError.invalidMerchantCode
        }

        let trimmedAmount = payload.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int64(trimmedAmount), amount >= 100 else {
            throw DemoCreateIntentRequestFactoryError.invalidAmount
        }

        let trimmedCurrency = payload.currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let currency = trimmedCurrency.isEmpty ? "RUB" : trimmedCurrency.uppercased()
        guard currency.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else {
            throw DemoCreateIntentRequestFactoryError.invalidCurrency
        }

        return CreateIntentRequest(
            merchantCode: merchantCode,
            amount: amount,
            currency: currency,
            messageScheme: payload.useDualMessagePayment ? "DMS" : "SMS",
            tokenize: payload.tokenize
        )
    }
}

enum DemoCreateIntentRequestFactoryError: LocalizedError {
    case invalidMerchantCode
    case invalidAmount
    case invalidCurrency

    var errorDescription: String? {
        switch self {
        case .invalidMerchantCode:
            return "Merchant code must not be empty"
        case .invalidAmount:
            return "Amount must be at least 100 minor units"
        case .invalidCurrency:
            return "Currency must be a 3-letter ISO code"
        }
    }
}
