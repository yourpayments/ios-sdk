public struct UpdateChanges: Sendable {
    public let receiptEmail: String?
    public let tokenize: Bool?
    public let clearReceiptEmail: Bool

    public init(receiptEmail: String? = nil, tokenize: Bool? = nil, clearReceiptEmail: Bool = false) {
        self.receiptEmail = receiptEmail
        self.tokenize = tokenize
        self.clearReceiptEmail = clearReceiptEmail
    }

    func merged(with newer: UpdateChanges) -> UpdateChanges {
        let receiptEmail: String?
        let clearReceiptEmail: Bool

        if newer.clearReceiptEmail {
            receiptEmail = nil
            clearReceiptEmail = true
        } else if let newerReceiptEmail = newer.receiptEmail {
            receiptEmail = newerReceiptEmail
            clearReceiptEmail = false
        } else {
            receiptEmail = self.receiptEmail
            clearReceiptEmail = self.clearReceiptEmail
        }

        return UpdateChanges(
            receiptEmail: receiptEmail,
            tokenize: newer.tokenize ?? tokenize,
            clearReceiptEmail: clearReceiptEmail
        )
    }
}
