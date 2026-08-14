public enum YP {
    public static func createIntent(
        request: CreateIntentRequest,
        config: YPConfig = YPConfig()
    ) async throws -> PaymentIntent {
        let api = YPAPIClient(config: config)
        let data = try await api.createIntent(request)
        return PaymentIntent(data: data, api: api, secret: data.secret)
    }

    public static func getIntent(
        id: String,
        config: YPConfig = YPConfig(),
        secret: String? = nil
    ) async throws -> PaymentIntent {
        let api = YPAPIClient(config: config)
        let data = try await api.getIntent(id: id)
        return PaymentIntent(data: data, api: api, secret: secret ?? data.secret)
    }

    public static func wrapIntent(
        data: IntentResponse,
        config: YPConfig = YPConfig()
    ) -> PaymentIntent {
        PaymentIntent(data: data, api: YPAPIClient(config: config), secret: data.secret)
    }
}
