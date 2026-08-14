import Foundation

public final class PaymentIntent: @unchecked Sendable {
    private let session: PaymentIntentSession
    private let eventHub: YPEventHub

    var api: YPAPIClient { session.api }

    init(data: IntentResponse, api: YPAPIClient, secret: String) {
        let eventHub = YPEventHub()
        self.eventHub = eventHub
        self.session = PaymentIntentSession(data: data, api: api, secret: secret, eventHub: eventHub)
    }

    public var id: String { get async { await session.id } }
    public var status: IntentStatus { get async { await session.status } }
    public var data: IntentResponse { get async { await session.data } }
    public var events: AsyncStream<IntentEvent> { eventHub.stream() }

    public func update(changes: UpdateChanges) async throws {
        try await session.update(changes: changes, intent: self)
    }

    public func getStatus() async throws -> IntentStatus {
        try await session.getStatus()
    }

    public func getStatusDetails() async throws -> IntentStatusResponse {
        try await session.getStatusDetails()
    }

    public func getBinInfo(bin: String) async throws -> BinInfo {
        let normalizedBin = bin.filter { $0 >= "0" && $0 <= "9" }
        guard normalizedBin.count == 6 else {
            throw YPError(message: "getBinInfo: bin must contain exactly 6 digits")
        }
        return try await session.getBinInfo(bin: normalizedBin)
    }

    public func pay(input: PayInput) async throws -> PayResult {
        try await session.pay(input: input)
    }

    public func getPaymentMethod(method: AltPayMethod, opts: AltRequestOpts = AltRequestOpts()) async throws -> AltPayFlow {
        try await session.getPaymentMethod(method: method, opts: opts)
    }

    public func getFasterPaymentsFlow(opts: AltRequestOpts = AltRequestOpts()) async throws -> FasterPaymentsFlow {
        guard let flow = try await getPaymentMethod(method: .fasterPayments, opts: opts) as? FasterPaymentsFlow else {
            throw YPError(message: "getPaymentMethod: mathod \(AltPayMethod.fasterPayments.type) not present in intent")
        }
        return flow
    }

    public func getSberPayFlow(opts: AltRequestOpts = AltRequestOpts()) async throws -> SberPayFlow {
        guard let flow = try await getPaymentMethod(method: .sberPay, opts: opts) as? SberPayFlow else {
            throw YPError(message: "getPaymentMethod: mathod \(AltPayMethod.sberPay.type) not present in intent")
        }
        return flow
    }

    public func waitForResult(opts: WaitForResultOpts = WaitForResultOpts()) async throws -> WaitForResultStatus {
        try await session.waitForResult(opts: opts)
    }

    #if canImport(UIKit) && canImport(WebKit)
        public func create3dsView(result: PayResult) throws -> ThreeDsView {
            guard case .threeDsRequired(let threeDsUrl) = result else {
                throw YPError(message: "create3dsView: 3DS result required")
            }
            return ThreeDsView(threeDsUrl: threeDsUrl, intent: self, allowedOrigin: api.baseOrigin)
        }

        public func create3dsView(threeDsUrl: String) -> ThreeDsView {
            ThreeDsView(threeDsUrl: threeDsUrl, intent: self, allowedOrigin: api.baseOrigin)
        }
    #else
        @available(*, unavailable, message: "create3dsView requires UIKit and WebKit")
        public func create3dsView(result: PayResult) throws -> ThreeDsView {
            fatalError("create3dsView requires UIKit and WebKit")
        }
    #endif

    func threeDsGetStatus() async throws -> IntentStatus {
        try await session.getStatus()
    }

    func threeDsGetStatusDetails() async throws -> IntentStatusResponse {
        try await session.getStatusDetails()
    }

    func threeDsComplete(with result: ThreeDsResult) async {
        await session.completeThreeDs(with: result)
    }
}

actor PaymentIntentSession {
    private(set) var data: IntentResponse
    let api: YPAPIClient
    private let operationQueue = YPAsyncOperationQueue()
    private let secret: String
    private let eventHub: YPEventHub
    private var publicKey: String?
    private var latestStatusResponse: IntentStatusResponse?
    private var pendingUpdate: UpdateChanges?
    private var updateWaiters: [CheckedContinuation<Void, Error>] = []
    private var isApplyingUpdate = false

    init(data: IntentResponse, api: YPAPIClient, secret: String, eventHub: YPEventHub) {
        self.data = data
        self.api = api
        self.secret = secret
        self.eventHub = eventHub
    }

    var id: String { data.id }
    var status: IntentStatus { latestStatusResponse?.resolvedStatus ?? IntentStatus.from(data.status) }

    func update(changes: UpdateChanges, intent: PaymentIntent) async throws {
        guard changes.receiptEmail != nil || changes.tokenize != nil || changes.clearReceiptEmail else {
            throw YPError(message: "update: no editable fields provided")
        }

        try await withCheckedThrowingContinuation { continuation in
            pendingUpdate = pendingUpdate?.merged(with: changes) ?? changes
            updateWaiters.append(continuation)

            guard !isApplyingUpdate else { return }
            isApplyingUpdate = true
            Task { await self.applyPendingUpdate(intent: intent) }
        }
    }

    private func applyPendingUpdate(intent: PaymentIntent) async {
        await Task.yield()

        do {
            try await operationQueue.run {
                guard let changes = pendingUpdate else { return }

                pendingUpdate = nil
                let waiters = updateWaiters
                updateWaiters = []

                let patch = patchOperations(from: changes)

                do {
                    data = try await api.updateIntent(id: data.id, secret: secret, patch: patch)
                    latestStatusResponse = nil
                    eventHub.emit(.update(intent))
                    waiters.forEach { $0.resume() }
                } catch {
                    waiters.forEach { $0.resume(throwing: error) }
                    throw error
                }
            }
        } catch {
            // Waiters are resumed inside the queued operation exactly once.
        }

        if pendingUpdate != nil {
            Task { await self.applyPendingUpdate(intent: intent) }
        } else {
            isApplyingUpdate = false
        }
    }

    private func patchOperations(from changes: UpdateChanges) -> [YPPatchOp] {
        var patch: [YPPatchOp] = []
        if changes.clearReceiptEmail {
            patch.append(YPPatchOp(path: "/receiptEmail", value: .null))
        } else if let receiptEmail = changes.receiptEmail {
            patch.append(YPPatchOp(path: "/receiptEmail", value: .string(receiptEmail)))
        }
        if let tokenize = changes.tokenize {
            patch.append(YPPatchOp(path: "/tokenize", value: .bool(tokenize)))
        }
        return patch
    }

    func getStatus() async throws -> IntentStatus {
        let response = try await getStatusDetails()
        return response.resolvedStatus
    }

    func getStatusDetails() async throws -> IntentStatusResponse {
        let intentId = data.id
        let response = try await api.getStatus(id: intentId)
        return try await operationQueue.run {
            let oldStatus = status
            latestStatusResponse = response
            data.status = response.intent.status
            data.transactions = response.transactions
            let newStatus = response.resolvedStatus
            if newStatus != oldStatus {
                eventHub.emit(.statusChange(newStatus))
            }
            return response
        }
    }

    func getBinInfo(bin: String) async throws -> BinInfo {
        try await api.getBinInfo(id: data.id, bin: bin)
    }

    func pay(input: PayInput) async throws -> PayResult {
        try await operationQueue.run {
            try await performPay(input: input)
        }
    }

    private func performPay(input: PayInput) async throws -> PayResult {
        do {
            let cryptogram: String
            switch input {
            case .cryptogram(let value):
                cryptogram = value
            case .card(let card):
                let key: String
                if let publicKey {
                    key = publicKey
                } else {
                    key = try await api.getPublicKey()
                    publicKey = key
                }
                cryptogram = try YPCryptogram.build(publicKeyPem: key, card: card)
            }

            switch try await api.pay(id: data.id, cryptogram: cryptogram) {
            case .threeDsRequired(let url):
                latestStatusResponse = nil
                return .threeDsRequired(threeDsUrl: url)
            case .authorized(let response):
                syncStatus(response)
                let result = PayResult.authorized(response)
                eventHub.emit(.success(result))
                return result
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            eventHub.emit(.error(error))
            throw error
        }
    }

    func getPaymentMethod(method: AltPayMethod, opts: AltRequestOpts) async throws -> AltPayFlow {
        try await operationQueue.run {
            try buildPaymentMethod(method: method, opts: opts)
        }
    }

    private func buildPaymentMethod(method: AltPayMethod, opts: AltRequestOpts) throws -> AltPayFlow {
        guard let paymentMethod = data.paymentMethods?.first(where: { $0.type == method.type }) else {
            throw YPError(message: "getPaymentMethod: method \(method.type) not present in intent")
        }

        let link = paymentMethod.link ?? paymentMethod.deepLinks?.first
        let image = paymentMethod.image ?? ""
        let session = self
        let linkHandler: @Sendable (AltLinkOpts) async throws -> String = { linkOpts in
            try await session.getAltLink(
                method: method,
                opts: AltLinkOpts(
                    webview: linkOpts.webview || opts.webview,
                    puid: linkOpts.puid ?? opts.puid,
                    schema: linkOpts.schema
                )
            )
        }

        switch method {
        case .sberPay:
            return SberPayFlow(method: method, link: link, image: image, getLinkHandler: linkHandler) { phone in
                try await session.sendSms(phone: phone)
            }
        case .fasterPayments:
            return FasterPaymentsFlow(method: method, link: link, image: image, banks: paymentMethod.banks ?? [], getLinkHandler: linkHandler)
        default:
            return GenericAltFlow(method: method, link: link, image: image, getLinkHandler: linkHandler)
        }
    }

    func getAltLink(method: AltPayMethod, opts: AltLinkOpts) async throws -> String {
        try await operationQueue.run {
            try await api.getAltLink(id: data.id, method: method, opts: opts)
        }
    }

    func sendSms(phone: String) async throws {
        try await operationQueue.run {
            try await api.sendSms(id: data.id, phone: phone)
        }
    }

    func waitForResult(opts: WaitForResultOpts) async throws -> WaitForResultStatus {
        let interval = opts.intervalMs ?? 3000
        let timeout = opts.timeoutMs ?? 600_000
        var elapsed: Int64 = 0
        var response = try await getStatusDetails()
        var current = waitForResultStatus(from: response, puid: opts.puid)
        var declinedTransaction = response.declinedTransaction(matchingPuid: opts.puid)

        while current == .requiresPaymentData || current == .requiresPaymentMethod {
            if elapsed >= timeout { throw YPError(message: "pollUntil: timeout") }
            let delayMs = max(interval, 0)
            try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            elapsed += interval <= 0 ? 1 : interval
            response = try await getStatusDetails()
            current = waitForResultStatus(from: response, puid: opts.puid)
            declinedTransaction = response.declinedTransaction(matchingPuid: opts.puid)
        }

        switch current {
        case .success:
            let response = latestStatusResponse ?? IntentStatusResponse(intent: IntentStatusData(status: current.rawValue), transactions: data.transactions ?? [])
            eventHub.emit(.success(.authorized(response)))
        case .declined:
            let message: String
            if let transactionId = declinedTransaction?.transactionDisplayId {
                message = "payment declined (transaction \(transactionId))"
            } else {
                message = "payment declined"
            }
            eventHub.emit(.error(YPError(message: message)))
        case .expired:
            eventHub.emit(.error(YPError(message: "payment expired")))
        case .requiresPaymentData, .requiresPaymentMethod:
            break
        }
        return current
    }

    private func waitForResultStatus(from response: IntentStatusResponse, puid: String?) -> WaitForResultStatus {
        if response.declinedTransaction(matchingPuid: puid) != nil {
            return .declined
        }

        switch response.intent.status {
        case WaitForResultStatus.success.rawValue:
            return .success
        case WaitForResultStatus.expired.rawValue:
            return .expired
        case WaitForResultStatus.requiresPaymentMethod.rawValue:
            return .requiresPaymentMethod
        case WaitForResultStatus.requiresPaymentData.rawValue, "Pending":
            return .requiresPaymentData
        default:
            return .requiresPaymentData
        }
    }

    private func syncStatus(_ raw: String) {
        let oldStatus = status
        latestStatusResponse = nil
        data.status = raw
        let newStatus = status
        if newStatus != oldStatus {
            eventHub.emit(.statusChange(newStatus))
        }
    }

    private func syncStatus(_ response: IntentStatusResponse) {
        let oldStatus = status
        latestStatusResponse = response
        data.status = response.intent.status
        data.transactions = response.transactions
        let newStatus = response.resolvedStatus
        if newStatus != oldStatus {
            eventHub.emit(.statusChange(newStatus))
        }
    }

    func completeThreeDs(with result: ThreeDsResult) async {
        do {
            try await operationQueue.run {
                switch result.status {
                case .success:
                    syncStatus(IntentStatus.success.rawValue)
                    let response = IntentStatusResponse(
                        intent: IntentStatusData(status: IntentStatus.success.rawValue),
                        transactions: data.transactions ?? []
                    )
                    latestStatusResponse = response
                    eventHub.emit(.success(.authorized(response)))
                case .failure:
                    if let intentStatus = result.intentStatus {
                        syncStatus(intentStatus.rawValue)
                    }
                    eventHub.emit(.error(YPError(message: "3DS failed")))
                }
            }
        } catch is CancellationError {
            return
        } catch {
            eventHub.emit(.error(error))
        }
    }
}

final class YPAsyncOperationQueue: @unchecked Sendable {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var isLocked = false
    private var waiters: [Waiter] = []

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async throws {
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if !isLocked {
                    isLocked = true
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            guard let index = waiters.firstIndex(where: { $0.id == id }) else {
                lock.unlock()
                return
            }

            let waiter = waiters.remove(at: index)
            lock.unlock()
            waiter.continuation.resume(throwing: CancellationError())
        }
    }

    private func release() {
        lock.lock()
        if waiters.isEmpty {
            isLocked = false
            lock.unlock()
        } else {
            let waiter = waiters.removeFirst()
            lock.unlock()
            waiter.continuation.resume()
        }
    }
}
