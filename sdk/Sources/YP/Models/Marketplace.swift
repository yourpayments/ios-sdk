import Foundation

public struct Marketplace: Encodable, Sendable {
    public let merchantCode: String
    
    public init(merchantCode: String) {
        self.merchantCode = merchantCode
    }
}