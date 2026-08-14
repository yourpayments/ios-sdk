import SwiftUI

@MainActor
func openURLWithResult(_ url: URL, using openURL: OpenURLAction) async -> Bool {
    await withCheckedContinuation { continuation in
        openURL(url) { accepted in
            continuation.resume(returning: accepted)
        }
    }
}
