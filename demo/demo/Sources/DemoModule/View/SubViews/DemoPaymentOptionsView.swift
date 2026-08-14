import SwiftUI

struct DemoPaymentOptionsView: View {
    @ObservedObject var viewModel: DemoHeadlessPaymentViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DemoConstants.Layout.sectionSpacing) {
                DemoPaymentHeaderView(title: "Выберите способ оплаты", amountText: viewModel.amountText)

                if viewModel.availableMethods.isEmpty {
                    Text("Нет доступных способов оплаты")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                ForEach(viewModel.availableMethods) { method in
                    Button { viewModel.select(method) } label: {
                        HStack(spacing: DemoConstants.Layout.inputSpacing) {
                            Image(systemName: method.iconName)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.title)
                                    .font(.headline)
                                Text(method.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DemoConstants.Layout.smallCornerRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("payment.headless.method.\(method.rawValue)")
                }
            }
            .padding(DemoConstants.Layout.screenHorizontalPadding)
        }
        .accessibilityIdentifier("payment.headless.options")
    }
}
