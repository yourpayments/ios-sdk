import Combine
import Foundation
import Yourpayments

@MainActor
final class DemoScreenViewModel: ObservableObject {
    @Published var merchantCode: String
    @Published var amount: String
    @Published var currency: String
    @Published var useDualMessagePayment = false

    var onStartRequested: ((DemoScreenStartPayload) -> Void)?

    let merchantCodeTitle = DemoPaymentFieldType.merchantCode.title
    let merchantCodePlaceholder = DemoPaymentFieldType.merchantCode.placeholder
    let amountTitle = DemoPaymentFieldType.amount.title
    let amountPlaceholder = DemoPaymentFieldType.amount.placeholder
    let currencyTitle = DemoPaymentFieldType.currency.title
    let currencyPlaceholder = DemoPaymentFieldType.currency.placeholder
    let automationSettings: DemoAutomationSettings

    private let worker: DemoScreenWorker

    init(
        worker: DemoScreenWorker,
        automationSettings: DemoAutomationSettings = .current
    ) {
        self.worker = worker
        self.automationSettings = automationSettings

        if automationSettings.isE2E {
            worker.resetFields()
        }
        let fields = worker.loadFields()
        merchantCode = automationSettings.isEnabled ? (automationSettings.merchantCode ?? fields.merchantCode) : fields.merchantCode
        amount = automationSettings.isEnabled ? (automationSettings.amount ?? fields.amount) : fields.amount
        currency = automationSettings.isEnabled ? (automationSettings.currency ?? fields.currency) : fields.currency
        useDualMessagePayment = automationSettings.isEnabled ? (automationSettings.useDualMessagePayment ?? false) : false
    }

    func startButtonTapped() {
        onStartRequested?(currentPayload())
    }

    func currentPayload() -> DemoScreenStartPayload {
        worker.makeStartPayload(
            merchantCode: merchantCode,
            amount: amount,
            currency: currency,
            useDualMessagePayment: useDualMessagePayment
        )
    }
}
