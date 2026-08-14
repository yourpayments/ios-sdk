public struct YPConfig: Sendable {
    public static let productionBaseUrl = "https://ypmn.ru"
    public static let sandboxBaseUrl = "https://sandbox.ypmn.ru"

    public let baseUrl: String
    public let headers: [String: String]

    public init(baseUrl: String = Self.productionBaseUrl, headers: [String: String] = [:]) {
        self.baseUrl = baseUrl
        self.headers = headers
    }
}
