public struct PaymentMethodDto: Codable, Sendable {
    public let type: String
    public let group: String?
    public let link: String?
    public let deepLinks: [String]?
    public let image: String?
    public let banks: [SbpBank]?
    public let capabilities: [PaymentMethodCapability]?
    public let primary: Bool?
    
    public init(
        type: String,
        group: String? = nil,
        link: String? = nil,
        deepLinks: [String]? = nil,
        image: String? = nil,
        banks: [SbpBank]? = nil,
        capabilities: [PaymentMethodCapability]? = nil,
        primary: Bool? = nil
    ) {
        self.type = type
        self.group = group
        self.link = link
        self.deepLinks = deepLinks
        self.image = image
        self.banks = banks
        self.capabilities = capabilities
        self.primary = primary
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, group, link, deepLinks, image, banks, capabilities, primary
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        group = try container.decodeIfPresent(String.self, forKey: .group)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        deepLinks = try container.decodeIfPresent([String].self, forKey: .deepLinks)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        banks = try container.decodeIfPresent([SbpBank].self, forKey: .banks)
        capabilities = try container.decodeIfPresent(
            [String].self,
            forKey: .capabilities
        )?.compactMap(PaymentMethodCapability.init(rawValue:))
        primary = try container.decodeIfPresent(Bool.self, forKey: .primary)
    }
}
