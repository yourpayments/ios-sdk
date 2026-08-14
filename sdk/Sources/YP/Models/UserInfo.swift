import Foundation

public struct UserInfo: Encodable, Sendable {
    public let billing: Billing?
    
    public init(billing: Billing? = nil) {
        self.billing = billing
    }
}