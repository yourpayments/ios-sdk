import SwiftUI

struct DemoPaymentResultView: View {
    let result: DemoPaymentResult
    let isActionInProgress: Bool
    let onRefreshStatus: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: DemoConstants.Layout.sectionSpacing) {
            Spacer()
            Image(systemName: result.systemImage)
                .font(.system(size: 56))
            Text(result.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(result.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if result.allowsStatusRefresh {
                Button {
                    onRefreshStatus()
                } label: {
                    if isActionInProgress {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Проверить статус")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionInProgress)
                .accessibilityIdentifier("payment.headless.refreshStatusButton")
            }
            Button("Повторить") { onRetry() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("payment.headless.retryButton")
            Button("Закрыть") { onClose() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("payment.headless.closeResultButton")
        }
        .padding(DemoConstants.Layout.screenHorizontalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("payment.headless.result")
        .accessibilityValue(Text(result.accessibilityValue))
    }
}
