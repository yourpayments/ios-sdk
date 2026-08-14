import SwiftUI

struct DemoPaymentLoadingView: View {
    var body: some View {
        VStack(spacing: DemoConstants.Layout.sectionSpacing) {
            ProgressView()
                .controlSize(.large)
            Text("Готовим оплату")
                .font(.headline)
            Text("Создаем intent и загружаем доступные способы оплаты")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DemoConstants.Layout.screenHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("payment.headless.loading")
    }
}
