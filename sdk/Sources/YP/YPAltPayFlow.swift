import Foundation

public class AltPayFlow {
    public let method: AltPayMethod
    public let link: String?
    private let image: String
    private let getLinkHandler: @Sendable (AltLinkOpts) async throws -> String

    init(method: AltPayMethod, link: String?, image: String, getLinkHandler: @escaping @Sendable (AltLinkOpts) async throws -> String) {
        self.method = method
        self.link = link
        self.image = image
        self.getLinkHandler = getLinkHandler
    }

    public func getImage() -> String { image }

    public func getLink(opts: AltLinkOpts = AltLinkOpts()) async throws -> String {
        try await getLinkHandler(opts)
    }
}

public final class SberPayFlow: AltPayFlow {
    private let sendSmsHandler: @Sendable (String) async throws -> Void

    init(method: AltPayMethod, link: String?, image: String, getLinkHandler: @escaping @Sendable (AltLinkOpts) async throws -> String, sendSmsHandler: @escaping @Sendable (String) async throws -> Void) {
        self.sendSmsHandler = sendSmsHandler
        super.init(method: method, link: link, image: image, getLinkHandler: getLinkHandler)
    }

    public func sendSms(phone: String) async throws {
        try await sendSmsHandler(phone)
    }
}

public final class FasterPaymentsFlow: AltPayFlow {
    public let banks: [SbpBank]

    init(method: AltPayMethod, link: String?, image: String, banks: [SbpBank], getLinkHandler: @escaping @Sendable (AltLinkOpts) async throws -> String) {
        self.banks = banks
        super.init(method: method, link: link, image: image, getLinkHandler: getLinkHandler)
    }
}

public final class GenericAltFlow: AltPayFlow {}

final class YPEventHub {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<IntentEvent>.Continuation] = [:]

    func stream() -> AsyncStream<IntentEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(32)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations[id] = nil
                self?.lock.unlock()
            }
        }
    }

    func emit(_ event: IntentEvent) {
        lock.lock()
        let values = Array(continuations.values)
        lock.unlock()
        values.forEach { $0.yield(event) }
    }
}
