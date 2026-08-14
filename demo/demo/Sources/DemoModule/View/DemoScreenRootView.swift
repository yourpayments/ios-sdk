import SwiftUI
import Yourpayments

@MainActor
struct DemoScreenRootView: View {
    @StateObject private var screenViewModel: DemoScreenViewModel
    @State private var isPaymentPresented = false
    @State private var activePayload: DemoScreenStartPayload
    @State private var hasAutoStarted = false

    init() {
        let screenViewModel = DemoScreenViewModel(worker: DemoScreenWorker())
        _screenViewModel = StateObject(wrappedValue: screenViewModel)
        _activePayload = State(initialValue: screenViewModel.currentPayload())
    }

    var body: some View {
        DemoScreenView(viewModel: screenViewModel)
            .sheet(isPresented: $isPaymentPresented) {
                DemoHeadlessPaymentView(
                    payload: activePayload,
                    automationSettings: screenViewModel.automationSettings
                )
            }
            .onAppear {
                screenViewModel.onStartRequested = { payload in
                    activePayload = payload
                    isPaymentPresented = true
                }

                guard screenViewModel.automationSettings.isEnabled,
                      screenViewModel.automationSettings.autoStart,
                      !hasAutoStarted else { return }
                hasAutoStarted = true
                screenViewModel.startButtonTapped()
            }
    }
}

#Preview(DemoConstants.Preview.demoRoot) {
    DemoScreenRootView()
}
