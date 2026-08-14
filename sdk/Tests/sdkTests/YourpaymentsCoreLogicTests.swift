import XCTest
@testable import Yourpayments

final class YourpaymentsCoreLogicTests: XCTestCase {
    func testCardDataStringDescriptionMasksSensitiveValues() {
        let card = CardData(pan: "4652 0354 4066 7037", expMonth: "12", expYear: "25", cvv: "987")

        let description = String(describing: card)

        XCTAssertEqual(description, "CardData(pan=****7037, exp=**/**, cvv=***)")
        XCTAssertFalse(description.contains("465203"))
        XCTAssertFalse(description.contains("12"))
        XCTAssertFalse(description.contains("25"))
        XCTAssertFalse(description.contains("987"))
    }

    func testCardDataDebugDescriptionMasksSensitiveValues() {
        let card = CardData(pan: "4652 0354 4066 7037", expMonth: "12", expYear: "25", cvv: "987")

        XCTAssertEqual(String(reflecting: card), "CardData(pan=****7037, exp=**/**, cvv=***)")
    }

    func testCardDataDescriptionUsesFallbackForMissingPanSuffix() {
        let card = CardData(pan: "abc", expMonth: "12", expYear: "25", cvv: "987")

        XCTAssertEqual(String(describing: card), "CardData(pan=****, exp=**/**, cvv=***)")
    }

    func testYPConfigDefaultsToProductionBaseUrl() {
        XCTAssertEqual(YPConfig.productionBaseUrl, "https://ypmn.ru")
        XCTAssertEqual(YPConfig.sandboxBaseUrl, "https://sandbox.ypmn.ru")
        XCTAssertEqual(YPConfig().baseUrl, YPConfig.productionBaseUrl)
    }

    func testIntentStatusMapsCurrentLegacyAndUnknownStatuses() {
        XCTAssertEqual(IntentStatus.from("Success"), .success)
        XCTAssertEqual(IntentStatus.from("Expired"), .expired)
        XCTAssertEqual(IntentStatus.from("RequiresPaymentData"), .requiresPaymentData)
        XCTAssertEqual(IntentStatus.from("RequiresPaymentMethod"), .requiresPaymentMethod)
        XCTAssertEqual(IntentStatus.from("Pending"), .requiresPaymentData)
        XCTAssertEqual(IntentStatus.from("unknown"), .requiresPaymentData)
    }

    func testIntentStatusTerminalValues() {
        XCTAssertTrue(IntentStatus.success.isTerminal)
        XCTAssertTrue(IntentStatus.expired.isTerminal)
        XCTAssertFalse(IntentStatus.requiresPaymentData.isTerminal)
        XCTAssertFalse(IntentStatus.requiresPaymentMethod.isTerminal)
    }

    func testAltPayMethodMapping() {
        XCTAssertEqual(AltPayMethod.fromType("FasterPayments"), .fasterPayments)
        XCTAssertEqual(AltPayMethod.fromType("SberPay"), .sberPay)
        XCTAssertNil(AltPayMethod.fromType("Unknown"))
    }

    func testIntentResponseDecodesDefaults() throws {
        let data = Data(#"{"id":"intent-id","status":"Pending"}"#.utf8)

        let response = try JSONDecoder().decode(IntentResponse.self, from: data)

        XCTAssertEqual(response.id, "intent-id")
        XCTAssertEqual(response.status, "Pending")
        XCTAssertEqual(response.secret, "")
        XCTAssertEqual(response.amount, 0)
        XCTAssertNil(response.paymentMethods)
    }

    func testIntentResponseDecodesTransactionsAsObjectsOnly() throws {
        let data = Data(#"{"id":"intent-id","status":"Pending","transactions":[{"id":"tx-1","amount":10}]}"#.utf8)

        let response = try JSONDecoder().decode(IntentResponse.self, from: data)

        XCTAssertEqual(response.transactions?.count, 1)
        XCTAssertNotNil(response.transactions?.first?["id"])

        let nonObjectData = Data(#"{"id":"intent-id","status":"Pending","transactions":["tx-1"]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(IntentResponse.self, from: nonObjectData))
    }

    func testIntentStatusResponseDefaultsTransactionsToEmptyArray() throws {
        let data = Data(#"{"intent":{"status":"Pending"}}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertTrue(response.transactions.isEmpty)
    }

    func testIntentStatusResponseDoesNotResolveDeclinedTransactionAsWaitFailure() throws {
        let data = Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"DECLINED","puid":null}]}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertEqual(response.resolvedStatus, .requiresPaymentMethod)
    }

    func testIntentStatusResponseKeepsRequiresPaymentMethodWithoutDeclinedTransaction() throws {
        let data = Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[]}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertEqual(response.resolvedStatus, .requiresPaymentMethod)
    }

    func testIntentStatusResponseDoesNotOverrideTerminalIntentStatusWithDeclinedTransaction() throws {
        let data = Data(#"{"intent":{"status":"Success"},"transactions":[{"id":1934937,"status":"DECLINED","puid":null}]}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertEqual(response.resolvedStatus, .success)
    }

    func testIntentStatusResponseDoesNotUseTransactionsForResolvedStatus() throws {
        let data = Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1,"status":"DECLINED"},{"id":2,"status":"PENDING"}]}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertEqual(response.resolvedStatus, .requiresPaymentMethod)
    }

    func testIntentStatusResponseFindsDeclinedTransactionWithMatchingPuid() throws {
        let data = Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1,"status":"DECLINED","puid":"other"},{"id":1934937,"status":"DECLINED","puid":"attempt-puid"}]}"#.utf8)

        let response = try JSONDecoder().decode(IntentStatusResponse.self, from: data)

        XCTAssertEqual(response.declinedTransaction(matchingPuid: "attempt-puid")?.transactionDisplayId, "1934937")
        XCTAssertNil(response.declinedTransaction(matchingPuid: nil))
        XCTAssertNil(response.declinedTransaction(matchingPuid: ""))
        XCTAssertNil(response.declinedTransaction(matchingPuid: "other-puid"))
    }

    func testIntentStatusResponseFindsTransactionChangedToDeclinedSinceBaseline() throws {
        let baseline = try JSONDecoder().decode(
            IntentStatusResponse.self,
            from: Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"PENDING"}]}"#.utf8)
        )
        let response = try JSONDecoder().decode(
            IntentStatusResponse.self,
            from: Data(#"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"DECLINED"}]}"#.utf8)
        )

        XCTAssertEqual(response.declinedTransaction(changedSince: baseline)?.transactionDisplayId, "1934937")
    }

    func testThreeDsMessageParserMapsSuccessAndFailure() {
        XCTAssertEqual(parseThreeDsMessage(#"{"code":"0"}"#), ThreeDsResult(status: .success, code: "0", intentStatus: .success))
        XCTAssertEqual(parseThreeDsMessage(#"{"code":"1"}"#), ThreeDsResult(status: .failure, code: "1"))
    }

    func testThreeDsMessageParserIgnoresInvalidMessages() {
        XCTAssertNil(parseThreeDsMessage(nil))
        XCTAssertNil(parseThreeDsMessage(""))
        XCTAssertNil(parseThreeDsMessage("not-json"))
        XCTAssertNil(parseThreeDsMessage(#"{"status":"ok"}"#))
        XCTAssertNil(parseThreeDsMessage(#"{"code":" "}"#))
    }

    func testThreeDsOriginValidationUsesAllowedBaseOrigin() throws {
        let allowed = try XCTUnwrap(YPOrigin(url: URL(string: "https://example.com/api")!))

        XCTAssertTrue(isThreeDsAllowedOrigin(YPThreeDsMessageOrigin(scheme: "https", host: "example.com", port: 443), allowedOrigin: allowed))
        XCTAssertFalse(isThreeDsAllowedOrigin(YPThreeDsMessageOrigin(scheme: "https", host: "evil.example", port: 443), allowedOrigin: allowed))
        XCTAssertFalse(isThreeDsAllowedOrigin(YPThreeDsMessageOrigin(scheme: "http", host: "example.com", port: 80), allowedOrigin: allowed))
        XCTAssertFalse(isThreeDsAllowedOrigin(nil, allowedOrigin: allowed))
    }

    func testThreeDsEventOriginParsingUsesDefaultPort() {
        XCTAssertEqual(parseThreeDsOrigin("https://example.com"), YPThreeDsMessageOrigin(scheme: "https", host: "example.com", port: 443))
        XCTAssertEqual(parseThreeDsOrigin("http://example.com:8080/path"), YPThreeDsMessageOrigin(scheme: "http", host: "example.com", port: 8080))
        XCTAssertNil(parseThreeDsOrigin(""))
    }

    func testSbpBankDecodesDocumentedKeys() throws {
        let data = Data(#"{"bankName":"Bank","logoURL":"https://logo","schema":"bank","isWebClientActive":true,"packageName":"pkg"}"#.utf8)

        let bank = try JSONDecoder().decode(SbpBank.self, from: data)

        XCTAssertEqual(bank.bankName, "Bank")
        XCTAssertEqual(bank.logoUrl, "https://logo")
        XCTAssertEqual(bank.schema, "bank")
        XCTAssertEqual(bank.isWebClientActive, true)
        XCTAssertEqual(bank.packageName, "pkg")
    }

    func testSbpBankEncodesDocumentedKeys() throws {
        let bank = SbpBank(bankName: "Bank", logoUrl: "https://logo", schema: "bank", isWebClientActive: false, packageName: "pkg")

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(bank)) as? [String: Any]

        XCTAssertEqual(object?["logoURL"] as? String, "https://logo")
        XCTAssertEqual(object?["isWebClientActive"] as? Bool, false)
        XCTAssertEqual(object?["packageName"] as? String, "pkg")
        XCTAssertNil(object?["package_name"])
    }

    func testIntentResponseDecodesRealBackendPaymentMethodFields() throws {
        let data = Data(#"""
        {
          "id": "intent-id",
          "status": "RequiresPaymentMethod",
          "paymentMethods": [
            {
              "capabilities": ["international", "domestic"],
              "primary": true,
              "type": "Card",
              "group": "Card"
            },
            {
              "link": "https://sandbox.ypmn.ru/api/intent/alt/intent-id/link/FasterPayments",
              "banks": [
                {
                  "bankName": "Сбербанк",
                  "isWebClientActive": false,
                  "logoURL": "https://qr.nspk.ru/proxyapp/logo/bank100000000111.png",
                  "packageName": "ru.sberbankmobile",
                  "schema": "bank100000000111",
                  "webClientUrl": null
                }
              ],
              "image": "https://sandbox.ypmn.ru/api/intent/alt/intent-id/image/FasterPayments",
              "type": "FasterPayments",
              "group": "FastPayment"
            },
            {
              "link": "https://sandbox.ypmn.ru/api/intent/alt/intent-id/link/SberPay",
              "deepLinks": [
                "btripsexpenses://sbolpay/invoicing/v2",
                "sberpay://invoicing/v2"
              ],
              "type": "SberPay",
              "group": "FastPayment"
            }
          ],
          "terminalInfo": {
            "logoUrl": "https://sandbox.ypmn.ru/images/merchant/logo.png",
            "displayAdvertiseBannerOnWidget": true,
            "bannerImage": "https://sandbox.ypmn.ru/assets/img/intent/banner.gif",
            "bannerLink": "https://sandbox.ypmn.ru/doc/"
          }
        }
        """#.utf8)

        let response = try JSONDecoder().decode(IntentResponse.self, from: data)

        let card = try XCTUnwrap(response.paymentMethods?.first { $0.type == "Card" })
        XCTAssertEqual(card.primary, true)
        XCTAssertEqual(card.capabilities, [.international, .domestic])

        let fasterPayments = try XCTUnwrap(response.paymentMethods?.first { $0.type == "FasterPayments" })
        let bank = try XCTUnwrap(fasterPayments.banks?.first)
        XCTAssertEqual(bank.isWebClientActive, false)
        XCTAssertEqual(bank.packageName, "ru.sberbankmobile")

        let sberPay = try XCTUnwrap(response.paymentMethods?.first { $0.type == "SberPay" })
        XCTAssertEqual(sberPay.deepLinks, ["btripsexpenses://sbolpay/invoicing/v2", "sberpay://invoicing/v2"])

        XCTAssertEqual(response.terminalInfo?.logoUrl, "https://sandbox.ypmn.ru/images/merchant/logo.png")
        XCTAssertEqual(response.terminalInfo?.displayAdvertiseBannerOnWidget, true)
        XCTAssertEqual(response.terminalInfo?.bannerImage, "https://sandbox.ypmn.ru/assets/img/intent/banner.gif")
        XCTAssertEqual(response.terminalInfo?.bannerLink, "https://sandbox.ypmn.ru/doc/")
    }

    func testCreateIntentRequestOmitsNilValues() throws {
        let request = CreateIntentRequest(merchantCode: "terminal", amount: 100, currency: "RUB", messageScheme: "Single", merchantPaymentReference: "order-1")

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]

        XCTAssertNil(object?["culture"])
        XCTAssertNil(object?["description"])
        XCTAssertEqual(object?["merchantCode"] as? String, "terminal")
        XCTAssertEqual(object?["messageScheme"] as? String, "Single")
        XCTAssertEqual(object?["merchantPaymentReference"] as? String, "order-1")
        XCTAssertNil(object?["orderTimeout"])
        XCTAssertNil(object?["retryPayment"])
        XCTAssertNil(object?["successRedirectUrl"])
        XCTAssertNil(object?["failRedirectUrl"])
        XCTAssertNil(object?["items"])
        XCTAssertNil(object?["receipts"])
        XCTAssertNil(object?["userInfo"])
        XCTAssertNil(object?["metaData"])
        XCTAssertNil(object?["metadata"])
    }

    func testCreateIntentRequestEncodesNativeFieldsWithOpenAPIKeys() throws {
        let request = CreateIntentRequest(
            merchantCode: "terminal",
            amount: 100,
            currency: "RUB",
            messageScheme: "Single",
            restrictedPaymentMethods: ["BNPL"],
            orderTimeout: 3600,
            retryPayment: true,
            successRedirectUrl: "https://example.com/success",
            failRedirectUrl: "https://example.com/fail",
            items: [
                ProductItem(
                    name: "Phone",
                    sku: "PHONE-123",
                    unitPrice: "10000",
                    quantity: "2",
                    additionalDetails: "Black, 128GB",
                    vat: "22",
                    marketplace: Marketplace(merchantCode: "MERCHANT-001")
                )
            ],
            receipts: ["receiptId": .string("receipt-1")],
            userInfo: UserInfo(billing: Billing(
                firstName: "John",
                lastName: "Doe",
                email: "customer@example.com",
                countryCode: "RU",
                phone: "79990000000",
                city: "Moscow",
                state: "Moscow",
                companyName: "Company",
                taxId: "tax-1",
                addressLine1: "Line 1",
                addressLine2: "Line 2",
                zipCode: "101000"
            )),
            metaData: ["orderId": .string("order-1")]
        )

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]

        XCTAssertEqual(object?["merchantCode"] as? String, "terminal")
        XCTAssertEqual(object?["messageScheme"] as? String, "Single")
        XCTAssertEqual(object?["scenario"] as? String, "IoSSDK")
        XCTAssertEqual(object?["orderTimeout"] as? Int, 3600)
        XCTAssertEqual(object?["retryPayment"] as? Bool, true)
        XCTAssertEqual(object?["successRedirectUrl"] as? String, "https://example.com/success")
        XCTAssertEqual(object?["failRedirectUrl"] as? String, "https://example.com/fail")
        XCTAssertEqual(object?["restrictedPaymentMethods"] as? [String], ["BNPL"])
        XCTAssertNil(object?["merchantPaymentReference"])
        XCTAssertNil(object?["metadata"])

        let items = try XCTUnwrap(object?["items"] as? [[String: Any]])
        XCTAssertEqual(items.first?["name"] as? String, "Phone")
        XCTAssertEqual(items.first?["sku"] as? String, "PHONE-123")
        XCTAssertEqual(items.first?["unitPrice"] as? String, "10000")
        XCTAssertEqual(items.first?["quantity"] as? String, "2")
        XCTAssertEqual(items.first?["additionalDetails"] as? String, "Black, 128GB")
        XCTAssertEqual(items.first?["vat"] as? String, "22")
        XCTAssertEqual((items.first?["marketplace"] as? [String: Any])?["merchantCode"] as? String, "MERCHANT-001")

        XCTAssertEqual((object?["receipts"] as? [String: Any])?["receiptId"] as? String, "receipt-1")
        XCTAssertEqual((object?["metaData"] as? [String: Any])?["orderId"] as? String, "order-1")

        let billing = (object?["userInfo"] as? [String: Any])?["billing"] as? [String: Any]
        XCTAssertEqual(billing?["firstName"] as? String, "John")
        XCTAssertEqual(billing?["lastName"] as? String, "Doe")
        XCTAssertEqual(billing?["email"] as? String, "customer@example.com")
        XCTAssertEqual(billing?["countryCode"] as? String, "RU")
        XCTAssertEqual(billing?["phone"] as? String, "79990000000")
        XCTAssertEqual(billing?["city"] as? String, "Moscow")
        XCTAssertEqual(billing?["state"] as? String, "Moscow")
        XCTAssertEqual(billing?["companyName"] as? String, "Company")
        XCTAssertEqual(billing?["taxId"] as? String, "tax-1")
        XCTAssertEqual(billing?["addressLine1"] as? String, "Line 1")
        XCTAssertEqual(billing?["addressLine2"] as? String, "Line 2")
        XCTAssertEqual(billing?["zipCode"] as? String, "101000")
    }

    func testIntentResponseDecodesIntentKeys() throws {
        let data = Data(#"{"id":"intent-id","status":"Pending","merchantCode":"terminal","messageScheme":"Single"}"#.utf8)

        let response = try JSONDecoder().decode(IntentResponse.self, from: data)

        XCTAssertEqual(response.merchantCode, "terminal")
        XCTAssertEqual(response.messageScheme, "Single")
    }

    func testIntentResponseEncodesIntentKeys() throws {
        let response = IntentResponse(id: "intent-id", status: "Pending", merchantCode: "terminal", messageScheme: "Single")

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(response)) as? [String: Any]

        XCTAssertEqual(object?["merchantCode"] as? String, "terminal")
        XCTAssertEqual(object?["messageScheme"] as? String, "Single")
    }

    func testContentTypeIsSentOnlyForJSONBodyRequests() async throws {
        let client = makeClient(statusCode: 200, body: #"{"id":"intent-id","status":"Pending"}"#)

        _ = try await client.getIntent(id: "intent-id")
        XCTAssertNil(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"))

        _ = try await client.createIntent(CreateIntentRequest(merchantCode: "terminal", amount: 100, currency: "RUB", messageScheme: "Single"))
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPaymentIntentUpdateRejectsEmptyChangesWithoutClearReceiptEmail() async throws {
        let client = makeClient(statusCode: 200, body: #"{"id":"intent-id","status":"Pending"}"#)
        let intent = PaymentIntent(data: IntentResponse(id: "intent-id", status: "Pending"), api: client, secret: "intent-secret")

        do {
            try await intent.update(changes: UpdateChanges())
            XCTFail("Expected empty update error")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "update: no editable fields provided")
            XCTAssertNil(MockURLProtocol.lastRequest)
        }
    }

    func testPaymentIntentUpdateClearsReceiptEmailWithNullPatch() async throws {
        let client = makeClient(statusCode: 200, body: #"{"id":"intent-id","status":"Pending","receiptEmail":null}"#)
        let intent = PaymentIntent(data: IntentResponse(id: "intent-id", status: "Pending"), api: client, secret: "intent-secret")

        try await intent.update(changes: UpdateChanges(clearReceiptEmail: true))

        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/intent/intent-id/")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Intent-Secret"), "intent-secret")

        let body = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        let patch = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        XCTAssertEqual(patch.count, 1)
        XCTAssertEqual(patch.first?["op"] as? String, "replace")
        XCTAssertEqual(patch.first?["path"] as? String, "/receiptEmail")
        XCTAssertTrue(patch.first?["value"] is NSNull)
    }

    func testUpdateChangesMergeUsesLatestReceiptEmailIntent() {
        let clearAfterEmail = UpdateChanges(receiptEmail: "customer@example.com")
            .merged(with: UpdateChanges(clearReceiptEmail: true))
        XCTAssertNil(clearAfterEmail.receiptEmail)
        XCTAssertTrue(clearAfterEmail.clearReceiptEmail)

        let emailAfterClear = UpdateChanges(clearReceiptEmail: true)
            .merged(with: UpdateChanges(receiptEmail: "customer@example.com"))
        XCTAssertEqual(emailAfterClear.receiptEmail, "customer@example.com")
        XCTAssertFalse(emailAfterClear.clearReceiptEmail)
    }

    func testFasterPaymentsGetLinkUsesSchemaOnlyAltLinkQuery() async throws {
        let client = makeClient(statusCode: 200, body: "plain-bank-link")
        let flow = FasterPaymentsFlow(method: .fasterPayments, link: nil, image: "", banks: []) { opts in
            try await client.getAltLink(id: "intent-id", method: .fasterPayments, opts: opts)
        }

        let link = try await flow.getLink(opts: AltLinkOpts(webview: false, puid: nil, schema: "bank100000"))

        XCTAssertEqual(link, "plain-bank-link")
        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.absoluteString, "https://example.com/api/intent/alt/intent-id/link/FasterPayments/?schema=bank100000")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, [
            URLQueryItem(name: "schema", value: "bank100000")
        ])
    }

    func testCardPayUsesTrailingSlashPath() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"Success"}}"#)

        _ = try await client.pay(id: "intent-id", cryptogram: "cryptogram")

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://example.com/api/intent/intent-id/pay/")
    }

    func testGetBinInfoUsesIntentScopedTrailingSlashPathWithoutSecret() async throws {
        let client = makeClient(statusCode: 200, body: #"{"cardType":"Visa","countryCode":"RU","bankId":4,"bankName":"BRD"}"#)

        _ = try await client.getBinInfo(id: "intent-id", bin: "424242")

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://example.com/api/intent/intent-id/bin-info/424242/")
        XCTAssertNil(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Intent-Secret"))
    }

    func testBinInfoDecodesNullableCountryCode() throws {
        let data = Data(#"{"cardType":"Visa","countryCode":null,"bankId":4,"bankName":"BRD"}"#.utf8)

        let binInfo = try JSONDecoder().decode(BinInfo.self, from: data)

        XCTAssertEqual(binInfo.cardType, "Visa")
        XCTAssertNil(binInfo.countryCode)
        XCTAssertEqual(binInfo.bankId, 4)
        XCTAssertEqual(binInfo.bankName, "BRD")
    }

    func testBinInfoDecodesStringCountryCode() throws {
        let data = Data(#"{"cardType":"Visa","countryCode":"RU","bankId":4,"bankName":"BRD"}"#.utf8)

        let binInfo = try JSONDecoder().decode(BinInfo.self, from: data)

        XCTAssertEqual(binInfo.countryCode, "RU")
    }

    func testBinInfoDecodesMissingCountryCode() throws {
        let data = Data(#"{"cardType":"Visa","bankId":4,"bankName":"BRD"}"#.utf8)

        let binInfo = try JSONDecoder().decode(BinInfo.self, from: data)

        XCTAssertNil(binInfo.countryCode)
    }

    func testBinInfoDecodesNumericCountryCodeFromSandbox() throws {
        let data = Data(#"{"cardType":"Visa","countryCode":643,"bankId":2527,"bankName":""}"#.utf8)

        let binInfo = try JSONDecoder().decode(BinInfo.self, from: data)

        XCTAssertEqual(binInfo.cardType, "Visa")
        XCTAssertEqual(binInfo.countryCode, "643")
        XCTAssertEqual(binInfo.bankId, 2527)
        XCTAssertEqual(binInfo.bankName, "")
    }

    func testPaymentIntentGetBinInfoNormalizesFormattedAsciiBin() async throws {
        let client = makeClient(statusCode: 200, body: #"{"cardType":"Visa"}"#)
        let intent = PaymentIntent(data: IntentResponse(id: "intent-id", status: "Pending"), api: client, secret: "")

        _ = try await intent.getBinInfo(bin: "4242 42")

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://example.com/api/intent/intent-id/bin-info/424242/")
    }

    func testPaymentIntentGetBinInfoRejectsInvalidBin() async throws {
        let client = makeClient(statusCode: 200, body: #"{"cardType":"Visa"}"#)
        let intent = PaymentIntent(data: IntentResponse(id: "intent-id", status: "Pending"), api: client, secret: "")

        do {
            _ = try await intent.getBinInfo(bin: "42424")
            XCTFail("Expected invalid bin error")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "getBinInfo: bin must contain exactly 6 digits")
            XCTAssertNil(MockURLProtocol.lastRequest)
        }
    }

    func testPaymentIntentGetBinInfoRejectsNonAsciiDigits() async throws {
        let client = makeClient(statusCode: 200, body: #"{"cardType":"Visa"}"#)
        let intent = PaymentIntent(data: IntentResponse(id: "intent-id", status: "Pending"), api: client, secret: "")

        do {
            _ = try await intent.getBinInfo(bin: "٤٢٤٢٤٢")
            XCTFail("Expected invalid bin error")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "getBinInfo: bin must contain exactly 6 digits")
            XCTAssertNil(MockURLProtocol.lastRequest)
        }
    }

    func testGetAltLinkAcceptsJsonStringResponse() async throws {
        let client = makeClient(
            statusCode: 200,
            body: #""https://simulators.sandbox.ypmn.ru/faster_payments/pay?mdOrder=8237f5cd""#
        )

        let link = try await client.getAltLink(id: "intent-id", method: .fasterPayments, opts: AltLinkOpts())

        XCTAssertEqual(link, "https://simulators.sandbox.ypmn.ru/faster_payments/pay?mdOrder=8237f5cd")
    }

    func testGetAltLinkRejectsNonStringJsonResponse() async throws {
        let client = makeClient(statusCode: 200, body: #"{"url":"https://example.com/pay"}"#)

        do {
            _ = try await client.getAltLink(id: "intent-id", method: .fasterPayments, opts: AltLinkOpts())
            XCTFail("Expected invalid response")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "invalid response")
        }
    }

    func testHTTPErrorUsesFallbackMessageAndCause() async throws {
        let client = makeClient(statusCode: 500, body: #"{"message":"   "}"#)

        do {
            _ = try await client.getIntent(id: "intent-id")
            XCTFail("Expected error")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "HTTP 500")
            XCTAssertNotNil(error.cause as? YPHTTPErrorCause)
        }
    }

    func testGetStatusSynchronizesLocalStatusFromResponse() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"Pending"}}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Success"),
            api: client,
            secret: ""
        )

        let responseStatus = try await intent.getStatus()
        let localStatus = await intent.status
        let localDataStatus = await intent.data.status

        XCTAssertEqual(responseStatus, .requiresPaymentData)
        XCTAssertEqual(localStatus, .requiresPaymentData)
        XCTAssertEqual(localDataStatus, "Pending")
    }

    func testGetStatusUsesBackendIntentStatusWithoutDeclinedOverride() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"DECLINED","puid":null}]}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Pending"),
            api: client,
            secret: ""
        )

        let responseStatus = try await intent.getStatus()
        let localStatus = await intent.status
        let localDataStatus = await intent.data.status
        let localTransactions = await intent.data.transactions

        XCTAssertEqual(responseStatus, .requiresPaymentMethod)
        XCTAssertEqual(localStatus, .requiresPaymentMethod)
        XCTAssertEqual(localDataStatus, "RequiresPaymentMethod")
        XCTAssertEqual(localTransactions?.count, 1)
    }

    func testGetStatusDetailsReturnsResponseAndSynchronizesLocalState() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"Success"},"transactions":[{"id":1934937,"status":"AUTHORIZED","puid":"attempt-puid"}]}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Pending"),
            api: client,
            secret: ""
        )
        let events = intent.events

        let response = try await intent.getStatusDetails()
        let localStatus = await intent.status
        let localData = await intent.data
        let event = try await nextEvent(from: events)

        XCTAssertEqual(response.intent.status, "Success")
        XCTAssertEqual(response.transactions.count, 1)
        guard case .string("AUTHORIZED")? = response.transactions.first?["status"] else {
            return XCTFail("Expected authorized transaction status")
        }
        guard case .string("attempt-puid")? = response.transactions.first?["puid"] else {
            return XCTFail("Expected transaction puid")
        }
        XCTAssertEqual(localStatus, .success)
        XCTAssertEqual(localData.status, "Success")
        XCTAssertEqual(localData.transactions?.count, 1)
        guard case .string("AUTHORIZED")? = localData.transactions?.first?["status"] else {
            return XCTFail("Expected cached authorized transaction status")
        }
        guard case .statusChange(.success)? = event else {
            return XCTFail("Expected status change event")
        }
    }

    func testGetStatusDetailsUsesStatusEndpointWithoutIntentSecret() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"Pending"}}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Pending"),
            api: client,
            secret: "intent-secret"
        )

        _ = try await intent.getStatusDetails()

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://example.com/api/intent/intent-id/status/")
        XCTAssertNil(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Intent-Secret"))
    }

    func testWaitForResultReturnsDeclinedForDeclinedTransactionWithMatchingPuid() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"DECLINED","puid":"attempt-puid"}]}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Pending"),
            api: client,
            secret: ""
        )
        let eventTask = Task { () -> IntentEvent? in
            var iterator = intent.events.makeAsyncIterator()
            while let event = await iterator.next() {
                if case .error = event { return event }
            }
            return nil
        }

        let status = try await intent.waitForResult(opts: WaitForResultOpts(intervalMs: 0, timeoutMs: 0, puid: "attempt-puid"))

        XCTAssertEqual(status, .declined)
        guard case .error(let error)? = await eventTask.value, let ypError = error as? YPError else {
            return XCTFail("Expected payment declined error event")
        }
        XCTAssertEqual(ypError.message, "payment declined (transaction 1934937)")
    }

    func testWaitForResultDoesNotReturnDeclinedForDeclinedTransactionWithoutPuid() async throws {
        let client = makeClient(statusCode: 200, body: #"{"intent":{"status":"RequiresPaymentMethod"},"transactions":[{"id":1934937,"status":"DECLINED","puid":"attempt-puid"}]}"#)
        let intent = PaymentIntent(
            data: IntentResponse(id: "intent-id", status: "Pending"),
            api: client,
            secret: ""
        )

        do {
            _ = try await intent.waitForResult(opts: WaitForResultOpts(intervalMs: 0, timeoutMs: 0))
            XCTFail("Expected timeout")
        } catch let error as YPError {
            XCTAssertEqual(error.message, "pollUntil: timeout")
        }
    }

    func testAsyncOperationQueueCancelsQueuedOperationBeforeStart() async throws {
        let queue = YPAsyncOperationQueue()
        let firstEntered = AsyncGate()
        let releaseFirst = AsyncGate()
        let secondStarted = AsyncFlag()

        let firstTask = Task {
            try await queue.run {
                await firstEntered.open()
                await releaseFirst.wait()
            }
        }

        await firstEntered.wait()

        let secondTask = Task {
            try await queue.run {
                await secondStarted.setTrue()
            }
        }

        await Task.yield()
        secondTask.cancel()
        await releaseFirst.open()

        do {
            try await secondTask.value
            XCTFail("Expected queued operation cancellation")
        } catch is CancellationError {
            // Expected.
        }

        try await firstTask.value
        let didStartSecond = await secondStarted.value
        XCTAssertFalse(didStartSecond)
    }

    func testYPJSONValueRoundTrip() throws {
        let value: YPJSONValue = .object([
            "string": .string("value"),
            "number": .number(1),
            "bool": .bool(true),
            "array": .array([.null])
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(YPJSONValue.self, from: data)

        guard case .object(let object) = decoded else {
            return XCTFail("Expected object")
        }
        XCTAssertNotNil(object["string"])
        XCTAssertNotNil(object["number"])
        XCTAssertNotNil(object["bool"])
        XCTAssertNotNil(object["array"])
    }

    private func makeClient(statusCode: Int, body: String) -> YPAPIClient {
        MockURLProtocol.statusCode = statusCode
        MockURLProtocol.body = Data(body.utf8)
        MockURLProtocol.lastRequest = nil
        MockURLProtocol.lastRequestBody = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return YPAPIClient(config: YPConfig(baseUrl: "https://example.com"), session: URLSession(configuration: configuration))
    }

    private func nextEvent(from events: AsyncStream<IntentEvent>) async throws -> IntentEvent? {
        try await withThrowingTaskGroup(of: IntentEvent?.self) { group in
            group.addTask {
                var iterator = events.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return nil
            }
            let event = try await group.next() ?? nil
            group.cancelAll()
            return event
        }
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                continuations.append(continuation)
            }
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let continuations = continuations
        self.continuations = []
        continuations.forEach { $0.resume() }
    }
}

private actor AsyncFlag {
    private(set) var value = false

    func setTrue() {
        value = true
    }
}

private final class MockURLProtocol: URLProtocol {
    static var statusCode = 200
    static var body = Data()
    static var lastRequest: URLRequest?
    static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? request.httpBodyStream.flatMap(Self.readBody)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return data
    }
}
