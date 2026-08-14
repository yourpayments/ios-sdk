import Foundation

struct DemoAutomationSettings {
    let isEnabled: Bool
    let isE2E: Bool
    let autoStart: Bool
    let merchantCode: String?
    let amount: String?
    let currency: String?
    let useDualMessagePayment: Bool?
    let singlePaymentMode: DemoSinglePaymentMode

    static let current = DemoAutomationSettings(processInfo: .processInfo)

    init(processInfo: ProcessInfo) {
        let environment = processInfo.environment
        isE2E = Self.boolValue(for: DemoConstants.Environment.e2e, in: environment) ?? false
        isEnabled = !isE2E && (Self.boolValue(for: DemoConstants.Environment.automation, in: environment) ?? false)
        autoStart = Self.boolValue(for: DemoConstants.Environment.autoStart, in: environment) ?? false
        merchantCode = Self.stringValue(for: DemoConstants.Environment.merchantCode, in: environment)
        amount = Self.stringValue(for: DemoConstants.Environment.amount, in: environment)
        currency = Self.stringValue(for: DemoConstants.Environment.currency, in: environment)
        useDualMessagePayment = Self.boolValue(for: DemoConstants.Environment.useDualMessagePayment, in: environment)
        singlePaymentMode = Self.singlePaymentModeValue(in: environment) ?? .options
    }

    private static func stringValue(for key: String, in environment: [String: String]) -> String? {
        guard let value = environment[key], !value.isEmpty else { return nil }
        return value
    }

    private static func boolValue(for key: String, in environment: [String: String]) -> Bool? {
        guard let value = environment[key]?.lowercased() else { return nil }

        switch value {
        case DemoConstants.Environment.enabledValue,
             DemoConstants.Environment.trueValue,
             DemoConstants.Environment.yesValue:
            return true
        case DemoConstants.Environment.disabledValue,
             DemoConstants.Environment.falseValue,
             DemoConstants.Environment.noValue:
            return false
        default:
            return nil
        }
    }

    private static func singlePaymentModeValue(in environment: [String: String]) -> DemoSinglePaymentMode? {
        guard let value = environment[DemoConstants.Environment.singlePaymentMode]?.lowercased() else { return nil }
        return DemoSinglePaymentMode(rawValue: value)
    }
}
