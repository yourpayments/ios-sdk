private enum YPAPIConstants {
    enum CreateIntent {
        static let scenario = "IoSSDK"
    }
}

public struct CreateIntentRequest: Encodable, Sendable {
    public let merchantCode: String
    public let amount: Int64
    public let currency: String
    public let messageScheme: String
    public let culture: String?
    public let description: String?
    public let merchantPaymentReference: String?
    public let receiptEmail: String?
    public let accountId: String?
    public let tokenize: Bool?
    public let scenario: String
    public let restrictedPaymentMethods: [String]?
    public let orderTimeout: Int?
    public let retryPayment: Bool?
    public let successRedirectUrl: String?
    public let failRedirectUrl: String?
    public let items: [ProductItem]?
    public let receipts: YPJSONObject?
    public let userInfo: UserInfo?
    public let metaData: YPJSONObject?
    
    public init(
        merchantCode: String,
        amount: Int64,
        currency: String,
        messageScheme: String,
        culture: String? = nil,
        description: String? = nil,
        merchantPaymentReference: String? = nil,
        receiptEmail: String? = nil,
        accountId: String? = nil,
        tokenize: Bool? = nil,
        restrictedPaymentMethods: [String]? = nil,
        orderTimeout: Int? = nil,
        retryPayment: Bool? = nil,
        successRedirectUrl: String? = nil,
        failRedirectUrl: String? = nil,
        items: [ProductItem]? = nil,
        receipts: YPJSONObject? = nil,
        userInfo: UserInfo? = nil,
        metaData: YPJSONObject? = nil
    ) {
        self.merchantCode = merchantCode
        self.amount = amount
        self.currency = currency
        self.messageScheme = messageScheme
        self.culture = culture
        self.description = description
        self.merchantPaymentReference = merchantPaymentReference
        self.receiptEmail = receiptEmail
        self.accountId = accountId
        self.tokenize = tokenize
        self.scenario = YPAPIConstants.CreateIntent.scenario
        self.restrictedPaymentMethods = restrictedPaymentMethods
        self.orderTimeout = orderTimeout
        self.retryPayment = retryPayment
        self.successRedirectUrl = successRedirectUrl
        self.failRedirectUrl = failRedirectUrl
        self.items = items
        self.receipts = receipts
        self.userInfo = userInfo
        self.metaData = metaData
    }
}

public struct IntentResponse: Codable, Sendable {
    public let id: String
    public var status: String
    public let secret: String
    public let createdAt: Int64
    public let updatedAt: Int64
    public let expiredAt: Int64
    public let merchantCode: String
    public let amount: Int64
    public let currency: String
    public let messageScheme: String
    public let description: String?
    public let receiptEmail: String?
    public let tokenize: Bool?
    public let paymentMethods: [PaymentMethodDto]?
    public let terminalInfo: TerminalInfoDto?
    public internal(set) var transactions: [YPJSONObject]?
    
    public init(
        id: String,
        status: String,
        secret: String = "",
        createdAt: Int64 = 0,
        updatedAt: Int64 = 0,
        expiredAt: Int64 = 0,
        merchantCode: String = "",
        amount: Int64 = 0,
        currency: String = "",
        messageScheme: String = "",
        description: String? = nil,
        receiptEmail: String? = nil,
        tokenize: Bool? = nil,
        paymentMethods: [PaymentMethodDto]? = nil,
        terminalInfo: TerminalInfoDto? = nil,
        transactions: [YPJSONObject]? = nil
    ) {
        self.id = id
        self.status = status
        self.secret = secret
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiredAt = expiredAt
        self.merchantCode = merchantCode
        self.amount = amount
        self.currency = currency
        self.messageScheme = messageScheme
        self.description = description
        self.receiptEmail = receiptEmail
        self.tokenize = tokenize
        self.paymentMethods = paymentMethods
        self.terminalInfo = terminalInfo
        self.transactions = transactions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
        createdAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        expiredAt = try container.decodeIfPresent(Int64.self, forKey: .expiredAt) ?? 0
        merchantCode = try container.decodeIfPresent(String.self, forKey: .merchantCode) ?? ""
        amount = try container.decodeIfPresent(Int64.self, forKey: .amount) ?? 0
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
        messageScheme = try container.decodeIfPresent(String.self, forKey: .messageScheme) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        receiptEmail = try container.decodeIfPresent(String.self, forKey: .receiptEmail)
        tokenize = try container.decodeIfPresent(Bool.self, forKey: .tokenize)
        paymentMethods = try container.decodeIfPresent([PaymentMethodDto].self, forKey: .paymentMethods)
        terminalInfo = try container.decodeIfPresent(TerminalInfoDto.self, forKey: .terminalInfo)
        transactions = try container.decodeIfPresent([YPJSONObject].self, forKey: .transactions)
    }
}

public struct TerminalInfoDto: Codable, Sendable {
    public let logoUrl: String?
    public let displayAdvertiseBannerOnWidget: Bool?
    public let bannerImage: String?
    public let bannerLink: String?

    public init(
        logoUrl: String? = nil,
        displayAdvertiseBannerOnWidget: Bool? = nil,
        bannerImage: String? = nil,
        bannerLink: String? = nil
    ) {
        self.logoUrl = logoUrl
        self.displayAdvertiseBannerOnWidget = displayAdvertiseBannerOnWidget
        self.bannerImage = bannerImage
        self.bannerLink = bannerLink
    }
}
