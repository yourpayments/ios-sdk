import CoreGraphics
import Foundation

enum DemoConstants {
    enum Layout {
        static let one: CGFloat = 1
        static let smallCornerRadius: CGFloat = 8

        static let fieldSpacing: CGFloat = 10
        static let inputSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24

        static let screenHorizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 24
        static let buttonVerticalPadding: CGFloat = 16
        static let logoTopPadding: CGFloat = 20

        static let logoHeight: CGFloat = 80
        static let inputHeight: CGFloat = 50
    }

    enum Text {
        static let merchantCodeTitle = "MerchantCode:"
        static let amountTitle = "Amount (minor units):"
        static let currencyTitle = "Currency (Optional):"
        static let fieldPlaceholder = "Введите текст"

        static let merchantCodeDefault = "widget"
        static let amountDefault = "2000"
        static let currencyDefault = "RUB"

        static let useDualMessagePayment = "Use dual message payment"
        static let tokenize = "Tokenize"
        static let tokenizeDefault = "Default"
        static let tokenizeEnabled = "Enabled"
        static let tokenizeDisabled = "Disabled"
        static let runPayment = "Run payment"

        static let optionsMode = "Options"
        static let cardMode = "Card"
        static let sbpMode = "SBP"
    }

    enum Accessibility {
        static let merchantCodeField = "demo.merchantCodeField"
        static let amountField = "demo.amountField"
        static let currencyField = "demo.currencyField"
        static let useDualMessagePaymentToggle = "demo.useDualMessagePaymentToggle"
        static let tokenizePicker = "demo.tokenizePicker"
        static let runPaymentButton = "demo.runPaymentButton"
    }

    enum Asset {
        static let logo = "logo"
        static let earthGlobe = "earth-globe"
    }

    enum ColorName {
        static let primary = "color_blue"
    }

    enum Preview {
        static let demoRoot = "Demo Root"
        static let demoScreen = "Demo Screen"
        static let demoInputField = "Demo Input Field"
        static let inputText = "Preview"
        static let inputTitle = "Field title"
        static let inputPlaceholder = "Placeholder"
        static let inputAccessibilityIdentifier = "preview.input"
    }

    enum Storage {
        static let paymentFieldsKey = "DemoPaymentFieldsStorage_Key"
    }

    enum Environment {
        static let automation = "DEMO_AUTOMATION"
        static let e2e = "DEMO_E2E"
        static let autoStart = "DEMO_AUTOSTART"
        static let merchantCode = "DEMO_MERCHANT_CODE"
        static let amount = "DEMO_AMOUNT"
        static let currency = "DEMO_CURRENCY"
        static let useDualMessagePayment = "DEMO_USE_DUAL_MESSAGE_PAYMENT"
        static let singlePaymentMode = "DEMO_SINGLE_PAYMENT_MODE"

        static let enabledValue = "1"
        static let disabledValue = "0"
        static let trueValue = "true"
        static let yesValue = "yes"
        static let falseValue = "false"
        static let noValue = "no"
    }
}
