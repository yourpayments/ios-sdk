import Foundation

public struct ProductItem: Encodable, Sendable {
    public let name: String
    public let sku: String
    public let unitPrice: String
    public let quantity: String
    public let additionalDetails: String?
    public let vat: String?
    public let marketplace: Marketplace?
    
    public init(
        name: String,
        sku: String,
        unitPrice: String,
        quantity: String,
        additionalDetails: String? = nil,
        vat: String? = nil,
        marketplace: Marketplace? = nil
    ) {
        self.name = name
        self.sku = sku
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.additionalDetails = additionalDetails
        self.vat = vat
        self.marketplace = marketplace
    }
}