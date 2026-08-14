public struct SbpBank: Codable, Sendable {
    public let bankName: String
    public let logoUrl: String?
    public let schema: String
    public let webClientUrl: String?
    public let isWebClientActive: Bool?
    public let packageName: String?

    enum CodingKeys: String, CodingKey {
        case bankName
        case logoUrl = "logoURL"
        case schema
        case webClientUrl
        case isWebClientActive
        case packageName
    }

    public init(
        bankName: String,
        logoUrl: String? = nil,
        schema: String,
        webClientUrl: String? = nil,
        isWebClientActive: Bool? = nil,
        packageName: String? = nil
    ) {
        self.bankName = bankName
        self.logoUrl = logoUrl
        self.schema = schema
        self.webClientUrl = webClientUrl
        self.isWebClientActive = isWebClientActive
        self.packageName = packageName
    }
}
