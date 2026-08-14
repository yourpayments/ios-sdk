import Foundation

struct YPHTTPErrorCause: Error, Sendable {
    let statusCode: Int
    let body: Data
}
