import Foundation

struct DemoScreenStartPayload {
    let merchantCode: String
    let amount: String
    let currency: String
    let useDualMessagePayment: Bool
    let tokenize: Bool?
}
