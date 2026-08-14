public struct WaitForResultOpts: Sendable {
    public let intervalMs: Int64?
    public let timeoutMs: Int64?
    public let puid: String?
    
    public init(intervalMs: Int64? = nil, timeoutMs: Int64? = nil, puid: String? = nil) {
        self.intervalMs = intervalMs
        self.timeoutMs = timeoutMs
        self.puid = puid
    }
}
