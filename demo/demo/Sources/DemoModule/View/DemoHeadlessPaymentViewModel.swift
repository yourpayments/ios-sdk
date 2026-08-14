import SwiftUI
import Yourpayments

@MainActor
final class DemoHeadlessPaymentViewModel: ObservableObject {
    enum Step {
        case loading
        case options
        case card
        case alt(DemoPaymentAltMethod)
        case result(DemoPaymentResult)
    }

    @Published var cardNumber = ""
    @Published private(set) var binInfoText: String?
    @Published private(set) var binInfoErrorText: String?
    @Published private(set) var isBinInfoLoading = false
    @Published private(set) var cardCapabilitiesText: String?
    @Published var expiry = ""
    @Published var cvv = ""
    @Published private(set) var step: Step = .loading
    @Published private(set) var amountText = ""
    @Published private(set) var errorText: String?
    @Published private(set) var availableMethods: [DemoPaymentMethod] = []
    @Published private(set) var altLink: URL?
    @Published private(set) var threeDsLink: URL?
    @Published private(set) var sbpBanks: [SbpBank] = []
    @Published var sbpSearchText = ""
    @Published private(set) var isActionInProgress = false

    private let payload: DemoScreenStartPayload
    private let automationSettings: DemoAutomationSettings
    private let requestFactory = DemoCreateIntentRequestFactory()
    private let apiConfig = YPConfig(baseUrl: YPConfig.sandboxBaseUrl)
    private var intent: PaymentIntent?
    private var fasterPaymentsFlow: FasterPaymentsFlow?
    private var eventsTask: Task<Void, Never>?
    private var binInfoTask: Task<Void, Never>?
    private var currentBin: String?
    private var didStart = false
    private var shouldRefreshStatusOnActive = false
    private var currentAltPuid: String?

    init(payload: DemoScreenStartPayload, automationSettings: DemoAutomationSettings) {
        self.payload = payload
        self.automationSettings = automationSettings
        amountText = Self.makeAmountText(amount: payload.amount, currency: payload.currency)
    }

    deinit {
        eventsTask?.cancel()
        binInfoTask?.cancel()
    }

    func cardNumberChanged(_ value: String) {
        let bin = String(value.filter { $0 >= "0" && $0 <= "9" }.prefix(6))
        guard bin.count == 6 else {
            clearBinInfo()
            return
        }
        guard bin != currentBin else { return }
        currentBin = bin
        binInfoTask?.cancel()
        binInfoText = nil
        binInfoErrorText = nil
        guard !automationSettings.isEnabled, let intent else {
            isBinInfoLoading = false
            return
        }
        isBinInfoLoading = true
        binInfoTask = Task { [weak self, intent] in
            do {
                let info = try await intent.getBinInfo(bin: bin)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentBin == bin else { return }
                    self?.isBinInfoLoading = false
                    self?.binInfoText = Self.makeBinInfoText(info)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentBin == bin else { return }
                    self?.isBinInfoLoading = false
                    self?.binInfoErrorText = "Не удалось загрузить данные BIN"
                }
            }
        }
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        if automationSettings.isEnabled {
            configureAutomationFlow()
            return
        }

        step = .loading
        errorText = nil
        do {
            let request = try requestFactory.makeCreateIntentRequest(payload: payload)
            let intent = try await YP.createIntent(request: request, config: apiConfig)
            self.intent = intent
            let data = await intent.data
            availableMethods = Self.makeMethods(from: data.paymentMethods)
            cardCapabilitiesText = Self.makeCardCapabilitiesText(from: data.paymentMethods)
            step = .options
            observe(intent)
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func select(_ method: DemoPaymentMethod) {
        errorText = nil
        currentAltPuid = nil
        switch method {
        case .card:
            step = .card
        case .fasterPayments:
            step = .alt(.fasterPayments)
        case .sberPay:
            step = .alt(.sberPay)
        }
    }

    var filteredSbpBanks: [SbpBank] {
        let trimmed = sbpSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sbpBanks }
        return sbpBanks.filter { $0.bankName.localizedCaseInsensitiveContains(trimmed) }
    }

    func backToOptions() {
        errorText = nil
        altLink = nil
        sbpSearchText = ""
        currentAltPuid = nil
        step = .options
    }

    func loadSbpBanks() async {
        errorText = nil
        guard sbpBanks.isEmpty else { return }
        guard !automationSettings.isEnabled else {
            sbpBanks = [
                SbpBank(bankName: "Demo Bank", logoUrl: nil, schema: "demo-bank"),
                SbpBank(bankName: "Sandbox Bank", logoUrl: nil, schema: "sandbox-bank")
            ]
            return
        }
        guard let intent else {
            showFailure("Intent is not ready")
            return
        }
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let flow = try await intent.getFasterPaymentsFlow()
            fasterPaymentsFlow = flow
            sbpBanks = flow.banks
            if flow.banks.isEmpty {
                showFailure("Банки СБП не загружены")
            }
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func payByCard(openThreeDs: @escaping @MainActor (URL) async -> Bool) async {
        errorText = nil
        threeDsLink = nil
        guard !automationSettings.isEnabled else {
            step = .result(.success(title: "Платеж выполнен", message: "Demo payment authorized"))
            return
        }
        guard let intent else {
            showFailure("Intent is not ready")
            return
        }
        binInfoTask?.cancel()
        isBinInfoLoading = false
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let result = try await intent.pay(input: .card(cardData()))
            switch result {
            case .authorized(let response):
                step = .result(.success(details: DemoStatusDetails(response: response)))
            case .threeDsRequired(let url):
                try await openThreeDsLink(url, openThreeDs: openThreeDs)
            }
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func loadAndOpenAltLink(_ method: DemoPaymentAltMethod, openLink: @escaping @MainActor (URL) async -> Bool) async {
        errorText = nil
        altLink = nil
        guard !automationSettings.isEnabled else {
            guard let url = URL(string: "https://sandbox.ypmn.ru/demo/\(method.rawValue)") else { return }
            altLink = url
            if await openLink(url) {
                shouldRefreshStatusOnActive = true
            } else {
                showFailure("Не удалось открыть ссылку оплаты")
            }
            return
        }
        guard let intent else {
            showFailure("Intent is not ready")
            return
        }
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let puid = beginAltAttempt()
            let link: String
            switch method {
            case .fasterPayments:
                let flow = try await intent.getFasterPaymentsFlow(opts: AltRequestOpts(puid: puid))
                link = try await flow.getLink(opts: AltLinkOpts(puid: puid))
            case .sberPay:
                let flow = try await intent.getSberPayFlow(opts: AltRequestOpts(puid: puid))
                link = try await flow.getLink(opts: AltLinkOpts(puid: puid))
            }
            guard let url = URL(string: link) else { throw YPError(message: "invalid payment link") }
            altLink = url
            if await openLink(url) {
                shouldRefreshStatusOnActive = true
            } else {
                showFailure(method.openErrorMessage)
            }
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func selectSbpBank(_ bank: SbpBank, openLink: @escaping @MainActor (URL) async -> Bool) async {
        errorText = nil
        altLink = nil
        guard !automationSettings.isEnabled else {
            guard let url = URL(string: "https://sandbox.ypmn.ru/demo/sbp/\(bank.schema)") else { return }
            altLink = url
            if await openLink(url) {
                shouldRefreshStatusOnActive = true
            } else {
                showFailure(DemoPaymentAltMethod.fasterPayments.openErrorMessage)
            }
            return
        }
        guard let flow = fasterPaymentsFlow else {
            showFailure("SBP flow is not ready")
            return
        }
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let puid = beginAltAttempt()
            let link = try await flow.getLink(
                opts: AltLinkOpts(
                    webview: false,
                    puid: puid,
                    schema: try makeSbpLinkSchema(for: bank)
                )
            )
            guard let url = URL(string: link) else { throw YPError(message: "invalid payment link") }
            altLink = url
            if await openLink(url) {
                shouldRefreshStatusOnActive = true
            } else {
                showFailure(DemoPaymentAltMethod.fasterPayments.openErrorMessage)
            }
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func openAltLink(_ url: URL, openLink: @escaping @MainActor (URL) async -> Bool) async {
        errorText = nil
        if await openLink(url) {
            shouldRefreshStatusOnActive = true
        } else {
            showFailure("Не удалось открыть ссылку оплаты")
        }
    }

    func applicationDidBecomeActive() async {
        guard shouldRefreshStatusOnActive else { return }
        shouldRefreshStatusOnActive = false
        await checkPaymentResult()
    }

    func checkPaymentResult() async {
        if currentAltPuid != nil {
            await waitForResult()
        } else {
            await refreshStatus()
        }
    }

    func refreshStatus() async {
        errorText = nil
        guard !automationSettings.isEnabled else {
            step = .result(.success(title: "Платеж выполнен", message: "Demo payment completed"))
            return
        }
        guard let intent else {
            showFailure("Intent is not ready")
            return
        }
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let status = try await intent.getStatus()
            step = .result(.status(await makeStatusDetails(status: status, intent: intent)))
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func waitForResult() async {
        errorText = nil
        guard !automationSettings.isEnabled else {
            step = .result(.success(title: "Платеж выполнен", message: "Demo payment completed"))
            return
        }
        guard let intent else {
            showFailure("Intent is not ready")
            return
        }
        isActionInProgress = true
        defer { isActionInProgress = false }
        do {
            let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: currentAltPuid))
            step = .result(.status(await makeStatusDetails(status: status, intent: intent)))
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    func retry() async {
        didStart = false
        intent = nil
        fasterPaymentsFlow = nil
        cardCapabilitiesText = nil
        clearBinInfo()
        threeDsLink = nil
        altLink = nil
        sbpBanks = []
        sbpSearchText = ""
        shouldRefreshStatusOnActive = false
        currentAltPuid = nil
        await start()
    }

    private func observe(_ intent: PaymentIntent) {
        eventsTask?.cancel()
        eventsTask = Task { [weak self] in
            for await event in intent.events {
                guard !Task.isCancelled else { return }
                await self?.handle(event, intent: intent)
            }
        }
    }

    private func handle(_ event: IntentEvent, intent: PaymentIntent) async {
        switch event {
        case .update:
            break
        case .statusChange(let status):
            if status.isTerminal {
                step = .result(.status(await makeStatusDetails(status: status, intent: intent)))
            }
        case .success:
            step = .result(.success(details: await makeStatusDetails(status: await intent.status, intent: intent)))
        case .error(let error):
            let details = await makeStatusDetails(status: await intent.status, intent: intent)
            errorText = error.localizedDescription
            step = .result(.failure(title: "Не удалось оплатить", message: "\(error.localizedDescription)\n\(details.message)"))
        }
    }

    private func configureAutomationFlow() {
        availableMethods = [.card, .fasterPayments]
        switch automationSettings.singlePaymentMode {
        case .options:
            step = .options
        case .card:
            step = .card
        case .sbp:
            step = .alt(.fasterPayments)
        }
    }

    private func cardData() -> CardData {
        let digits = expiry.filter(\.isNumber)
        let month = String(digits.prefix(2))
        let year = String(digits.dropFirst(2).prefix(2))
        return CardData(pan: cardNumber, expMonth: month, expYear: year, cvv: cvv)
    }

    private func showFailure(_ message: String) {
        errorText = message
        step = .result(.failure(title: "Не удалось оплатить", message: message))
    }

    private func beginAltAttempt() -> String {
        let puid = UUID().uuidString.lowercased()
        currentAltPuid = puid
        return puid
    }

    private func makeStatusDetails(status: IntentStatus, intent: PaymentIntent) async -> DemoStatusDetails {
        DemoStatusDetails(resolvedStatus: status, data: await intent.data)
    }

    private func makeStatusDetails(status: WaitForResultStatus, intent: PaymentIntent) async -> DemoStatusDetails {
        DemoStatusDetails(resolvedStatus: status, data: await intent.data)
    }

    private func clearBinInfo() {
        binInfoTask?.cancel()
        currentBin = nil
        binInfoText = nil
        binInfoErrorText = nil
        isBinInfoLoading = false
    }

    private static func makeBinInfoText(_ info: BinInfo) -> String? {
        let parts = [info.cardType, info.bankName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func openThreeDsLink(_ rawURL: String, openThreeDs: @escaping @MainActor (URL) async -> Bool) async throws {
        guard let url = URL(string: rawURL) else { throw YPError(message: "invalid 3DS url") }
        threeDsLink = url
        if await openThreeDs(url) {
            shouldRefreshStatusOnActive = true
            if let intent {
                step = .result(.attention(title: "Требуется 3DS", details: await makeStatusDetails(status: await intent.status, intent: intent)))
            } else {
                step = .result(.attention(title: "Требуется 3DS", message: "Завершите подтверждение платежа и вернитесь в приложение."))
            }
        } else {
            showFailure("Не удалось открыть страницу 3DS")
        }
    }

    private func makeSbpLinkSchema(for bank: SbpBank) throws -> String {
        guard !bank.schema.isEmpty else { throw YPError(message: "bank schema is missing") }
        return bank.schema
    }

    private static func makeMethods(from paymentMethods: [PaymentMethodDto]?) -> [DemoPaymentMethod] {
        (paymentMethods?.compactMap { DemoPaymentMethod(rawType: $0.type) } ?? []).filter { $0 != .sberPay }
    }

    private static func makeCardCapabilitiesText(from paymentMethods: [PaymentMethodDto]?) -> String? {
        guard let capabilities = paymentMethods?.first(where: { DemoPaymentMethod(rawType: $0.type) == .card })?.capabilities else {
            return nil
        }
        let hasDomestic = capabilities.contains(.domestic)
        let hasInternational = capabilities.contains(.international)
        return hasDomestic && hasInternational ? "Принимаем карты любой страны" : nil
    }

    private static func makeAmountText(amount: String, currency: String) -> String {
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "RUB" : currency
        guard let minorUnits = Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return "\(amount) \(trimmedCurrency)"
        }
        return String(format: "%.2f %@", minorUnits / 100, trimmedCurrency)
    }
}
