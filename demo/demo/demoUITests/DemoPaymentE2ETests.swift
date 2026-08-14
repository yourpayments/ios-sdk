import XCTest

final class DemoPaymentE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCardWithoutThreeDSSucceeds() {
        let app = launchDemoE2E()
        selectCard(in: app)
        enter(.withoutThreeDS, in: app)
        submitCard(in: app)
        waitForResult(.success, in: app)
    }

    func testThreeDSSuccessAndFailure() {
        XCTContext.runActivity(named: "3DS success") { _ in
            runThreeDS(outcome: .success)
        }
        XCTContext.runActivity(named: "3DS failure") { _ in
            runThreeDS(outcome: .failure)
        }
    }

    func testFasterPaymentsSuccessAndFailure() {
        XCTContext.runActivity(named: "Faster Payments success") { _ in
            runFasterPayments(outcome: .success)
        }
        XCTContext.runActivity(named: "Faster Payments failure") { _ in
            runFasterPayments(outcome: .failure)
        }
    }

    private func runThreeDS(outcome: DemoPaymentE2EOutcome) {
        let app = launchDemoE2E()
        selectCard(in: app)
        enter(.withThreeDS, in: app)
        submitCard(in: app)
        completeSandboxPage(with: outcome)
        waitForResult(outcome, in: app)
        app.terminate()
    }

    private func runFasterPayments(outcome: DemoPaymentE2EOutcome) {
        let app = launchDemoE2E()
        selectFasterPaymentsBank(in: app)
        completeSandboxPage(with: outcome)
        waitForResult(outcome, in: app)
        app.terminate()
    }
}
