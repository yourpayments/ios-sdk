import Foundation

final class YPAPIClient: @unchecked Sendable {
    private let config: YPConfig
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(config: YPConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    var baseOrigin: YPOrigin? {
        YPOrigin(url: baseURL())
    }

    func createIntent(_ request: CreateIntentRequest) async throws -> IntentResponse {
        try await jsonRequest("api/intent/", method: "POST", body: request)
    }

    func getIntent(id: String) async throws -> IntentResponse {
        try await jsonRequest("api/intent/\(id)/", method: "GET") as IntentResponse
    }

    func updateIntent(id: String, secret: String, patch: [YPPatchOp]) async throws -> IntentResponse {
        try await jsonRequest("api/intent/\(id)/", method: "PATCH", extraHeaders: ["X-Intent-Secret": secret], body: patch)
    }

    func getStatus(id: String) async throws -> IntentStatusResponse {
        try await jsonRequest("api/intent/\(id)/status/", method: "GET") as IntentStatusResponse
    }

    func getBinInfo(id: String, bin: String) async throws -> BinInfo {
        try await jsonRequest("api/intent/\(id)/bin-info/\(bin)/", method: "GET") as BinInfo
    }

    func getPublicKey() async throws -> String {
        let response: PublicKeyWire = try await jsonRequest("api/intent/pay/key/", method: "GET")
        return response.publicKey
    }

    func pay(id: String, cryptogram: String) async throws -> YPPayWireResult {
        let request = CardPaymentWire(id: id, paymentMethod: "Card", cryptogram: cryptogram)
        let data = try await dataRequest("api/intent/\(id)/pay/", method: "POST", body: request).0
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YPError(message: "invalid response")
        }
        if let threeDsUrl = raw["threeDsUrl"] as? String {
            return .threeDsRequired(threeDsUrl)
        }
        do {
            return .authorized(try decoder.decode(IntentStatusResponse.self, from: data))
        } catch {
            throw YPError(message: "invalid response", cause: error)
        }
    }

    func getAltLink(id: String, method: AltPayMethod, opts: AltLinkOpts) async throws -> String {
        var queryItems: [URLQueryItem] = []
        if opts.webview { queryItems.append(URLQueryItem(name: "webview", value: "true")) }
        if let puid = opts.puid { queryItems.append(URLQueryItem(name: "puid", value: puid)) }
        if let schema = opts.schema { queryItems.append(URLQueryItem(name: "schema", value: schema)) }
        let path = "api/intent/alt/\(id)/link/\(method.type)/"
        #if DEBUG
        printAltLinkRequest(path: path, method: "GET", altPayMethod: method, opts: opts, queryItems: queryItems)
        #endif
        do {
            let (data, response) = try await dataRequest(path, method: "GET", queryItems: queryItems)
            #if DEBUG
            printAltLinkResponse(statusCode: response.statusCode, bodyLength: data.count)
            #endif
            return try parseAltLink(data)
        } catch {
            #if DEBUG
            printAltLinkError(error, puid: opts.puid)
            #endif
            throw error
        }
    }

    func sendSms(id: String, phone: String) async throws {
        _ = try await dataRequest("api/intent/\(id)/send-sms/", method: "POST", body: SendSmsWire(phone: phone))
    }

    private func jsonRequest<T: Decodable, Body: Encodable>(_ path: String,
                                                            method: String,
                                                            extraHeaders: [String: String] = [:],
                                                            body: Body? = Optional<EmptyBody>.none) async throws -> T {
        let data = try await dataRequest(path, method: method, extraHeaders: extraHeaders, body: body).0
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YPError(message: "invalid response", cause: error)
        }
    }

    private func jsonRequest<T: Decodable>(_ path: String,
                                           method: String,
                                           extraHeaders: [String: String] = [:]) async throws -> T {
        let data = try await dataRequest(path, method: method, extraHeaders: extraHeaders).0
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YPError(message: "invalid response", cause: error)
        }
    }

    private func dataRequest<Body: Encodable>(_ path: String,
                                              method: String,
                                              queryItems: [URLQueryItem] = [],
                                              extraHeaders: [String: String] = [:],
                                              body: Body? = Optional<EmptyBody>.none) async throws -> (Data, HTTPURLResponse) {
        guard let requestURL = URL(string: path, relativeTo: baseURL())?.absoluteURL else { throw YPError(message: "invalid url") }
        var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else { throw YPError(message: "invalid url") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        config.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        extraHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw YPError(message: "network error", cause: error)
        }
        guard let http = response as? HTTPURLResponse else { throw YPError(message: "network error") }
        guard (200...299).contains(http.statusCode) else {
            let serverMessage = (try? decoder.decode(APIErrorWire.self, from: data).message)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = serverMessage?.isEmpty == false ? serverMessage! : "HTTP \(http.statusCode)"
            throw YPError(message: message, cause: YPHTTPErrorCause(statusCode: http.statusCode, body: data))
        }
        return (data, http)
    }

    private func dataRequest(_ path: String,
                             method: String,
                             queryItems: [URLQueryItem] = [],
                             extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        try await dataRequest(path, method: method, queryItems: queryItems, extraHeaders: extraHeaders, body: Optional<EmptyBody>.none)
    }

    private func parseAltLink(_ data: Data) throws -> String {
        if let jsonString = try? decoder.decode(String.self, from: data) {
            return jsonString
        }
        if (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil {
            throw YPError(message: "invalid response")
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw YPError(message: "invalid response")
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { throw YPError(message: "invalid response") }
        return trimmedValue
    }

    private func baseURL() -> URL {
        let raw = config.baseUrl.hasSuffix("/") ? config.baseUrl : config.baseUrl + "/"
        return URL(string: raw) ?? URL(string: YPConfig.productionBaseUrl + "/")!
    }

    #if DEBUG
    private func printAltLinkRequest(path: String,
                                     method: String,
                                     altPayMethod: AltPayMethod,
                                     opts: AltLinkOpts,
                                     queryItems: [URLQueryItem]) {
        let requestURL = URL(string: path, relativeTo: baseURL())?.absoluteURL
        var components = requestURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems.map { item in
                item.name == "puid" ? URLQueryItem(name: item.name, value: "<redacted>") : item
            }
        }
        let fullURL = components?.url?.absoluteString ?? requestURL?.absoluteString ?? "<invalid url>"
        let puidValue = opts.puid == nil ? "nil" : "<redacted>"

        print("[YP][AltLink] request url=\(fullURL), method=\(method), AltPayMethod=\(altPayMethod.type), opts.webview=\(opts.webview), opts.puid.present=\(opts.puid != nil), opts.puid.value=\(puidValue), opts.schema=\(opts.schema ?? "nil")")
    }

    private func printAltLinkResponse(statusCode: Int, bodyLength: Int) {
        print("[YP][AltLink] response status=\(statusCode), body.length=\(bodyLength)")
    }

    private func printAltLinkError(_ error: Error, puid: String?) {
        if let ypError = error as? YPError,
           let httpCause = ypError.cause as? YPHTTPErrorCause {
            print("[YP][AltLink] error status=\(httpCause.statusCode), body=\(altLinkLogBody(httpCause.body, puid: puid))")
        }
    }

    private func altLinkLogBody(_ body: Data, puid: String?) -> String {
        let raw = String(data: body, encoding: .utf8) ?? "<non-utf8 body length=\(body.count)>"
        return redactPuid(raw, puid: puid)
    }

    private func redactPuid(_ value: String, puid: String?) -> String {
        var redacted = value
        if let puid, !puid.isEmpty {
            redacted = redacted.replacingOccurrences(of: puid, with: "<redacted>")
        }
        let replacements = [
            (#"(?i)(puid=)[^&\s\"]+"#, "$1<redacted>"),
            (#"(?i)(\"puid\"\s*:\s*)\"[^\"]*\""#, "$1\"<redacted>\"")
        ]
        for (pattern, template) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
            redacted = regex.stringByReplacingMatches(in: redacted, range: range, withTemplate: template)
        }
        return redacted
    }
    #endif
}

struct YPPatchOp: Encodable {
    let op = "replace"
    let path: String
    let value: YPJSONValue
}

enum YPPayWireResult {
    case authorized(IntentStatusResponse)
    case threeDsRequired(String)
}

private struct EmptyBody: Encodable {}
private struct PublicKeyWire: Decodable { let publicKey: String }
private struct APIErrorWire: Decodable { let message: String? }
private struct SendSmsWire: Encodable { let phone: String }
private struct CardPaymentWire: Encodable {
    let id: String
    let paymentMethod: String
    let cryptogram: String
}

struct YPOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int?

    init?(url: URL) {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = url.port ?? Self.defaultPort(for: scheme)
    }

    func matches(scheme: String, host: String, port: Int) -> Bool {
        guard self.scheme == scheme.lowercased(), self.host == host.lowercased() else { return false }
        guard let expectedPort = self.port else { return true }
        return port == expectedPort || (port == 0 && expectedPort == Self.defaultPort(for: self.scheme))
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}
