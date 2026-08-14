public enum AltPayMethod: String, CaseIterable, Sendable {
    case fasterPayments = "FasterPayments"
    case sberPay = "SberPay"
    case alfaPay = "AlfaPay"
    case tPay = "TPay"
    case bnpl = "BNPL"

    public var type: String { rawValue }
    public static func fromType(_ type: String) -> AltPayMethod? { AltPayMethod(rawValue: type) }
}

public struct AltRequestOpts: Sendable {
    public let webview: Bool
    public let puid: String?
    public init(webview: Bool = false, puid: String? = nil) {
        self.webview = webview
        self.puid = puid
    }
}

public struct AltLinkOpts: Sendable {
    public let webview: Bool
    public let puid: String?
    public let schema: String?
    public init(webview: Bool = false, puid: String? = nil, schema: String? = nil) {
        self.webview = webview
        self.puid = puid
        self.schema = schema
    }
}
