import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum YPCryptogram {
    private struct BrowserInfo: Encodable {
        let AcceptHeader: String
        let ColorDepth: Int
        let IpAddress: String
        let Language: String
        let ScreenHeight: Int
        let ScreenWidth: Int
        let TimeZone: Int
        let UserAgent: String
        let JavaEnabled: Bool
        let JavaScriptEnabled: Bool
    }

    private struct ValuePayload: Encodable {
        let PAN: String
        let cvv: String
    }

    private struct CardInfoPayload: Encodable {
        let FirstSixDigits: String
        let LastFourDigits: String
        let ExpDateYear: String
        let ExpDateMonth: String
    }

    private struct Envelope: Encodable {
        let `Type`: String
        let BrowserInfoBase64: String
        let CardInfo: CardInfoPayload
        let KeyVersion: Int
        let Value: String
    }

    static func build(publicKeyPem: String, card: CardData) throws -> String {
        let pan = card.pan.filter(\.isNumber)
        let cvv = card.cvv.filter(\.isNumber)
        let month = card.expMonth.filter(\.isNumber)
        let year = card.expYear.filter(\.isNumber)
        guard pan.count >= 13 else { throw YPError(message: "cryptogram: invalid PAN") }

        do {
            let encoder = JSONEncoder()
            let valueData = try encoder.encode(ValuePayload(PAN: pan, cvv: cvv))
            guard let valueString = String(data: valueData, encoding: .utf8),
                  let encrypted = try RSAUtils.encryptWithRSAPublicKeyNewMethod(str: valueString, pubkeyBase64: publicKeyPem) else {
                throw YPError(message: "cryptogram: encryption failed")
            }

            let browserInfoData = try encoder.encode(collectBrowserInfo())
            let browserInfoBase64 = browserInfoData.base64EncodedString()
            let envelope = Envelope(
                Type: "Card",
                BrowserInfoBase64: browserInfoBase64,
                CardInfo: CardInfoPayload(
                    FirstSixDigits: String(pan.prefix(6)),
                    LastFourDigits: String(pan.suffix(4)),
                    ExpDateYear: year,
                    ExpDateMonth: month
                ),
                KeyVersion: 1,
                Value: encrypted.base64EncodedString()
            )
            return try encoder.encode(envelope).base64EncodedString()
        } catch let error as YPError {
            throw error
        } catch {
            throw YPError(message: "cryptogram: encryption failed", cause: error)
        }
    }

    private static func collectBrowserInfo() -> BrowserInfo {
        #if canImport(UIKit)
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let screenHeight = Int(bounds.height * scale)
        let screenWidth = Int(bounds.width * scale)
        let systemVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        #else
        let screenHeight = 0
        let screenWidth = 0
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: ".", with: "_")
        #endif

        return BrowserInfo(
            AcceptHeader: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            ColorDepth: 24,
            IpAddress: "0.0.0.0",
            Language: Locale.preferredLanguages.first ?? Locale.current.identifier,
            ScreenHeight: screenHeight,
            ScreenWidth: screenWidth,
            TimeZone: TimeZone.current.secondsFromGMT() / 60,
            UserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            JavaEnabled: false,
            JavaScriptEnabled: true
        )
    }
}
