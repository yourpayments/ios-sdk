import SwiftUI

struct DemoHeadlessPaymentView: View {
    @StateObject private var viewModel: DemoHeadlessPaymentViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(payload: DemoScreenStartPayload, automationSettings: DemoAutomationSettings) {
        _viewModel = StateObject(wrappedValue: DemoHeadlessPaymentViewModel(payload: payload, automationSettings: automationSettings))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Оплата")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { dismiss() }
                    }
                }
                .task { await viewModel.start() }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await viewModel.applicationDidBecomeActive() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .loading:
            DemoPaymentLoadingView()
        case .options:
            DemoPaymentOptionsView(viewModel: viewModel)
        case .card:
            DemoPaymentCardView(viewModel: viewModel, openURL: openURL)
        case .alt(let method):
            DemoPaymentAltView(viewModel: viewModel, method: method, openURL: openURL)
        case .result(let result):
            DemoPaymentResultView(
                result: result,
                isActionInProgress: viewModel.isActionInProgress,
                onRefreshStatus: { Task { await viewModel.checkPaymentResult() } },
                onRetry: { Task { await viewModel.retry() } },
                onClose: { dismiss() }
            )
        }
    }
}
