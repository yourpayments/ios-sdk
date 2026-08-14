import Foundation

public struct YPError: Error, LocalizedError {
    public let message: String
    public let cause: Error?

    public init(message: String, cause: Error? = nil) {
        self.message = message
        self.cause = cause
    }

    public var errorDescription: String? { message }
}
