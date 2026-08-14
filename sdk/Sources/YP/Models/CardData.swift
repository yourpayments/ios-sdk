public struct CardData: CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    public let pan: String
    public let expMonth: String
    public let expYear: String
    public let cvv: String

    public var description: String {
        maskedDescription
    }

    public var debugDescription: String {
        maskedDescription
    }

    public init(pan: String, expMonth: String, expYear: String, cvv: String) {
        self.pan = pan
        self.expMonth = expMonth
        self.expYear = expYear
        self.cvv = cvv
    }

    private var maskedDescription: String {
        "CardData(pan=\(maskedPan), exp=**/**, cvv=***)"
    }

    private var maskedPan: String {
        let digits = pan.filter { $0.isNumber }
        guard digits.count >= 4 else { return "****" }
        return "****\(digits.suffix(4))"
    }
}
