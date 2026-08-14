import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoScreenRootView()
                .preferredColorScheme(.light)
        }
    }
}
