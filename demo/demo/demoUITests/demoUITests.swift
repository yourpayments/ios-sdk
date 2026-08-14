import XCTest

final class demoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHeadlessFlowOpensAndClosesViaSystemDismiss() {
        let app = makeApp(singlePaymentMode: "options", autoStart: false)
        app.launch()

        app.buttons["demo.runPaymentButton"].tap()

        let optionsScreen = app.scrollViews["payment.headless.options"]
        XCTAssertTrue(optionsScreen.waitForExistence(timeout: 15))

        app.dismissSystemSheet()

        XCTAssertTrue(optionsScreen.waitForNonExistence(timeout: 10))
    }

    func testHeadlessFlowCanReopenAfterClose() {
        let app = makeApp(singlePaymentMode: "options", autoStart: false)
        app.launch()

        let runButton = app.buttons["demo.runPaymentButton"]
        runButton.tap()
        let optionsScreen = app.scrollViews["payment.headless.options"]
        XCTAssertTrue(optionsScreen.waitForExistence(timeout: 15))

        app.dismissSystemSheet()
        XCTAssertTrue(optionsScreen.waitForNonExistence(timeout: 10))

        runButton.tap()
        XCTAssertTrue(optionsScreen.waitForExistence(timeout: 15))
    }

    func testHeadlessPaymentShowsCardFields() {
        let app = makeApp(singlePaymentMode: "card", autoStart: true)
        app.launch()

        XCTAssertTrue(app.textFields["payment.headless.card.numberField"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["payment.headless.card.expiryField"].exists)
        XCTAssertTrue(app.secureTextFields["payment.headless.card.cvvField"].exists || app.textFields["payment.headless.card.cvvField"].exists)
    }

    func testHeadlessPaymentShowsAltAction() {
        let app = makeApp(singlePaymentMode: "sbp", autoStart: true)
        app.launch()

        XCTAssertTrue(app.scrollViews["payment.headless.sbp"].waitForExistence(timeout: 15))
    }

    private func makeApp(singlePaymentMode: String, autoStart: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_AUTOMATION"] = "1"
        app.launchEnvironment["DEMO_AUTOSTART"] = autoStart ? "1" : "0"
        app.launchEnvironment["DEMO_MERCHANT_CODE"] = "widget"
        app.launchEnvironment["DEMO_AMOUNT"] = "2000"
        app.launchEnvironment["DEMO_CURRENCY"] = "RUB"
        app.launchEnvironment["DEMO_USE_DUAL_MESSAGE_PAYMENT"] = "0"
        app.launchEnvironment["DEMO_SINGLE_PAYMENT_MODE"] = singlePaymentMode
        return app
    }
}

private extension XCUIElement {
    func dismissSystemSheet() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
