import Foundation

public struct ThreeDsResult: Sendable, Equatable {
    public enum Status: String, Sendable {
        case success = "SUCCESS"
        case failure = "FAILURE"
    }

    public let status: Status
    public let code: String?
    public let intentStatus: IntentStatus?

    public init(status: Status, code: String? = nil, intentStatus: IntentStatus? = nil) {
        self.status = status
        self.code = code
        self.intentStatus = intentStatus
    }
}

func parseThreeDsMessage(_ raw: String?) -> ThreeDsResult? {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    guard let data = raw.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    guard let code = object["code"] as? String else { return nil }
    guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

    if code == "0" {
        return ThreeDsResult(status: .success, code: code, intentStatus: .success)
    }
    return ThreeDsResult(status: .failure, code: code)
}

struct YPThreeDsMessageOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int
}

func isThreeDsAllowedOrigin(_ origin: YPThreeDsMessageOrigin?, allowedOrigin: YPOrigin?) -> Bool {
    guard let origin, let allowedOrigin else { return false }
    return allowedOrigin.matches(scheme: origin.scheme, host: origin.host, port: origin.port)
}

func parseThreeDsOrigin(_ raw: String?) -> YPThreeDsMessageOrigin? {
    guard let raw, let url = URL(string: raw), let origin = YPOrigin(url: url) else { return nil }
    return YPThreeDsMessageOrigin(scheme: origin.scheme, host: origin.host, port: origin.port ?? 0)
}

#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

public typealias ThreeDsContainerView = UIView

public final class ThreeDsView: @unchecked Sendable {
    @MainActor
    public private(set) var webView: WKWebView?

    @MainActor
    public var results: AsyncStream<ThreeDsResult> {
        AsyncStream { continuation in
            if let lastResult {
                continuation.yield(lastResult)
            }

            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    private let threeDsUrl: String
    private let intent: PaymentIntent
    private let allowedOrigin: YPOrigin?
    @MainActor private var lastResult: ThreeDsResult?
    @MainActor private var continuations: [UUID: AsyncStream<ThreeDsResult>.Continuation] = [:]
    @MainActor private var settled = false
    @MainActor private var pollingTask: Task<Void, Never>?
    @MainActor private var userContentController: WKUserContentController?

    init(threeDsUrl: String, intent: PaymentIntent, allowedOrigin: YPOrigin?) {
        self.threeDsUrl = threeDsUrl
        self.intent = intent
        self.allowedOrigin = allowedOrigin
    }

    @discardableResult
    @MainActor
    public func mount(into container: ThreeDsContainerView) -> ThreeDsView {
        releaseWebView()

        let contentController = WKUserContentController()
        contentController.add(YPThreeDsScriptMessageHandler { [weak self] payload in
            guard isThreeDsAllowedOrigin(payload.frameOrigin, allowedOrigin: self?.allowedOrigin),
                  isThreeDsAllowedOrigin(payload.eventOrigin, allowedOrigin: self?.allowedOrigin)
            else { return }
            let raw = payload.data
            guard let result = parseThreeDsMessage(raw) else { return }
            self?.settle(result)
        }, name: "YpBridge")

        let script = """
        window.addEventListener('message', function(e) {
          try {
            var raw = typeof e.data === 'string' ? e.data : JSON.stringify(e.data);
            if (typeof raw !== 'string') { return; }
            window.webkit.messageHandlers.YpBridge.postMessage({ data: raw, origin: e.origin || '' });
          } catch (_) {}
        });
        """
        contentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            configuration.preferences.javaScriptEnabled = true
        }

        let webView = WKWebView(frame: container.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let url = URL(string: threeDsUrl) {
            webView.load(URLRequest(url: url))
        }
        container.addSubview(webView)

        self.userContentController = contentController
        self.webView = webView
        beginPolling()
        return self
    }

    @MainActor public func unmount() {
        pollingTask?.cancel()
        pollingTask = nil
        webView?.removeFromSuperview()
    }

    @MainActor public func destroy() {
        settled = true
        releaseWebView()
        continuations.values.forEach { $0.finish() }
        continuations = [:]
    }

    @MainActor
    private func beginPolling() {
        pollingTask?.cancel()
        guard !settled else { return }

        let intent = intent
        pollingTask = Task { [weak self, intent] in
            let baseline = try? await intent.threeDsGetStatusDetails()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }

                do {
                    let response = try await intent.threeDsGetStatusDetails()
                    let status = response.resolvedStatus

                    switch status {
                    case .success:
                        await MainActor.run { self?.settle(ThreeDsResult(status: .success, intentStatus: status)) }
                    case .expired:
                        await MainActor.run { self?.settle(ThreeDsResult(status: .failure, intentStatus: status)) }
                    case .requiresPaymentData, .requiresPaymentMethod:
                        if let baseline, response.declinedTransaction(changedSince: baseline) != nil {
                            await MainActor.run { self?.settle(ThreeDsResult(status: .failure)) }
                        }
                    }
                } catch {
                    // Fallback polling errors are intentionally ignored.
                }
            }
        }
    }

    @MainActor
    private func settle(_ result: ThreeDsResult) {
        guard !settled else { return }
        settled = true
        pollingTask?.cancel()
        pollingTask = nil
        lastResult = result
        continuations.values.forEach { $0.yield(result) }

        Task { await intent.threeDsComplete(with: result) }
    }

    @MainActor
    private func releaseWebView() {
        unmount()
        userContentController?.removeScriptMessageHandler(forName: "YpBridge")
        userContentController?.removeAllUserScripts()
        userContentController = nil
        webView?.stopLoading()
        webView = nil
    }
}

private final class YPThreeDsScriptMessageHandler: NSObject, WKScriptMessageHandler {
    struct Payload: Sendable {
        let data: String
        let eventOrigin: YPThreeDsMessageOrigin?
        let frameOrigin: YPThreeDsMessageOrigin?
    }

    private let handler: @MainActor @Sendable (Payload) -> Void

    init(handler: @escaping @MainActor @Sendable (Payload) -> Void) {
        self.handler = handler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let data = body["data"] as? String
        else { return }
        let securityOrigin = message.frameInfo.securityOrigin
        let frameOrigin = YPThreeDsMessageOrigin(
            scheme: securityOrigin.`protocol`,
            host: securityOrigin.host,
            port: securityOrigin.port
        )
        let payload = Payload(
            data: data,
            eventOrigin: parseThreeDsOrigin(body["origin"] as? String),
            frameOrigin: frameOrigin
        )
        Task { @MainActor in handler(payload) }
    }
}
#else
public typealias ThreeDsContainerView = Never

@available(*, unavailable, message: "ThreeDsView requires UIKit and WebKit")
public final class ThreeDsView {
    public private(set) var webView: Never?
    public var results: AsyncStream<ThreeDsResult> { AsyncStream { $0.finish() } }
    init(threeDsUrl: String, intent: PaymentIntent, allowedOrigin: YPOrigin?) {}
    @discardableResult public func mount(into container: ThreeDsContainerView) -> ThreeDsView { self }
    public func unmount() {}
    public func destroy() {}
}
#endif
