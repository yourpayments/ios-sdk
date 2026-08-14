import Foundation

public struct Billing: Encodable, Sendable {
    public let firstName: String?
    public let lastName: String?
    public let email: String?
    public let countryCode: String?
    public let phone: String?
    public let city: String?
    public let state: String?
    public let companyName: String?
    public let taxId: String?
    public let addressLine1: String?
    public let addressLine2: String?
    public let zipCode: String?
    
    public init(
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        countryCode: String? = nil,
        phone: String? = nil,
        city: String? = nil,
        state: String? = nil,
        companyName: String? = nil,
        taxId: String? = nil,
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        zipCode: String? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.countryCode = countryCode
        self.phone = phone
        self.city = city
        self.state = state
        self.companyName = companyName
        self.taxId = taxId
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.zipCode = zipCode
    }
}