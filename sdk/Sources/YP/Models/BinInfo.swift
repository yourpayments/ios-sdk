public struct BinInfo: Codable, Sendable {
    public let cardType: String?
    public let countryCode: String?
    public let bankId: Int?
    public let bankName: String?

    private enum CodingKeys: String, CodingKey {
        case cardType, countryCode, bankId, bankName
    }

    public init(cardType: String? = nil, countryCode: String? = nil, bankId: Int? = nil, bankName: String? = nil) {
        self.cardType = cardType
        self.countryCode = countryCode
        self.bankId = bankId
        self.bankName = bankName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType)
        if let stringCountryCode = try? container.decodeIfPresent(String.self, forKey: .countryCode) {
            countryCode = stringCountryCode
        } else if let intCountryCode = try? container.decodeIfPresent(Int.self, forKey: .countryCode) {
            countryCode = String(intCountryCode)
        } else {
            countryCode = nil
        }
        bankId = try container.decodeIfPresent(Int.self, forKey: .bankId)
        bankName = try container.decodeIfPresent(String.self, forKey: .bankName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(cardType, forKey: .cardType)
        try container.encodeIfPresent(countryCode, forKey: .countryCode)
        try container.encodeIfPresent(bankId, forKey: .bankId)
        try container.encodeIfPresent(bankName, forKey: .bankName)
    }
}
