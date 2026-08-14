import XCTest

enum DemoPaymentE2EOutcome: String {
    case success
    case failure

    var sandboxButtonTitle: String {
        switch self {
        case .success: return "Успех"
        case .failure: return "Неудача"
        }
    }
}

struct DemoPaymentE2ECard {
    let number: String
    let month: String
    let cvv: String

    static let withoutThreeDS = DemoPaymentE2ECard(
        number: "4652035440667037",
        month: "08",
        cvv: "971"
    )
    static let withThreeDS = DemoPaymentE2ECard(
        number: "4051060000000178",
        month: "12",
        cvv: "895"
    )
}

extension XCTestCase {
    func launchDemoE2E() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_E2E"] = "1"
        app.launch()

        let runButton = app.buttons["demo.runPaymentButton"]
        XCTAssertTrue(runButton.waitForExistence(timeout: 10))
        runButton.tap()

        XCTAssertTrue(app.scrollViews["payment.headless.options"].waitForExistence(timeout: 30))
        return app
    }

    func selectCard(in app: XCUIApplication) {
        let cardButton = app.buttons["payment.headless.method.card"]
        XCTAssertTrue(cardButton.waitForExistence(timeout: 10))
        cardButton.tap()
        XCTAssertTrue(app.textFields["payment.headless.card.numberField"].waitForExistence(timeout: 10))
    }

    func enter(_ card: DemoPaymentE2ECard, in app: XCUIApplication) {
        let numberField = app.textFields["payment.headless.card.numberField"]
        let expiryField = app.textFields["payment.headless.card.expiryField"]
        let cvvField = cardSecurityCodeField(in: app)

        numberField.tap()
        numberField.typeText(card.number)
        expiryField.tap()
        expiryField.typeText(expiry(month: card.month))
        cvvField.tap()
        cvvField.typeText(card.cvv)
    }

    func submitCard(in app: XCUIApplication) {
        let payButton = app.buttons["payment.headless.payByCardButton"]
        XCTAssertTrue(payButton.waitForExistence(timeout: 10))
        payButton.tap()
    }

    func selectFasterPaymentsBank(in app: XCUIApplication) {
        let methodButton = app.buttons["payment.headless.method.fasterPayments"]
        XCTAssertTrue(methodButton.waitForExistence(timeout: 10))
        methodButton.tap()

        let bank = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "payment.headless.sbp.bank."))
            .firstMatch
        XCTAssertTrue(bank.waitForExistence(timeout: 30))
        bank.tap()
    }

    func completeSandboxPage(with outcome: DemoPaymentE2EOutcome) {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20))

        let title = outcome.sandboxButtonTitle
        let button = safari.buttons[title]

        if button.waitForExistence(timeout: 60) {
            completeSandboxAction(button)
            return
        }

        let link = safari.links[title]
        if link.waitForExistence(timeout: 10) {
            completeSandboxAction(link)
            return
        }

        let text = safari.staticTexts[title]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Sandbox action \(title) was not found in Safari")
        completeSandboxAction(text)
    }

    func waitForResult(_ outcome: DemoPaymentE2EOutcome, in app: XCUIApplication) {
        app.activate()
        let result = app.descendants(matching: .any)
            .matching(identifier: "payment.headless.result")
            .firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 60))

        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            let value = result.value as? String
            if value == outcome.rawValue {
                return
            }
            if value == DemoPaymentE2EOutcome.success.rawValue || value == DemoPaymentE2EOutcome.failure.rawValue {
                XCTFail("Expected payment result \(outcome.rawValue), got \(value ?? "nil")")
                return
            }

            let refreshButton = app.buttons["payment.headless.refreshStatusButton"]
            guard refreshButton.waitForExistence(timeout: 10) else {
                continue
            }

            let hittable = NSPredicate(format: "hittable == true")
            let refreshExpectation = XCTNSPredicateExpectation(predicate: hittable, object: refreshButton)
            guard XCTWaiter.wait(for: [refreshExpectation], timeout: 10) == .completed else {
                continue
            }
            refreshButton.tap()

            let expectedValue = NSPredicate(format: "value == %@", outcome.rawValue)
            let resultExpectation = XCTNSPredicateExpectation(predicate: expectedValue, object: result)
            if XCTWaiter.wait(for: [resultExpectation], timeout: 10) == .completed {
                return
            }
        }

        XCTFail("Payment result did not become \(outcome.rawValue); current value is \(String(describing: result.value))")
    }

    private func cardSecurityCodeField(in app: XCUIApplication) -> XCUIElement {
        let secureField = app.secureTextFields["payment.headless.card.cvvField"]
        if secureField.waitForExistence(timeout: 3) {
            return secureField
        }

        let textField = app.textFields["payment.headless.card.cvvField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3))
        return textField
    }

    private func completeSandboxAction(_ action: XCUIElement) {
        action.tap()

        let handled = NSPredicate(format: "exists == false OR hittable == false")
        let expectation = XCTNSPredicateExpectation(predicate: handled, object: action)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 20),
            .completed,
            "Sandbox did not finish handling the selected outcome"
        )
    }

    private func expiry(month: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.component(.year, from: Date()) + 1
        return String(format: "%@%02d", month, year % 100)
    }
}
