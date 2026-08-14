import SwiftUI

struct DemoScreenView: View {
    @ObservedObject var viewModel: DemoScreenViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DemoConstants.Layout.largeSpacing) {
                Image(DemoConstants.Asset.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: DemoConstants.Layout.logoHeight)
                    .padding(.top, DemoConstants.Layout.logoTopPadding)

                VStack(spacing: DemoConstants.Layout.sectionSpacing) {
                    DemoInputField(
                        title: viewModel.merchantCodeTitle,
                        placeholder: viewModel.merchantCodePlaceholder,
                        text: $viewModel.merchantCode,
                        accessibilityIdentifier: DemoConstants.Accessibility.merchantCodeField
                    )

                    DemoInputField(
                        title: viewModel.amountTitle,
                        placeholder: viewModel.amountPlaceholder,
                        text: $viewModel.amount,
                        keyboardType: .numberPad,
                        accessibilityIdentifier: DemoConstants.Accessibility.amountField
                    )

                    DemoInputField(
                        title: viewModel.currencyTitle,
                        placeholder: viewModel.currencyPlaceholder,
                        text: $viewModel.currency,
                        textInputAutocapitalization: .characters,
                        accessibilityIdentifier: DemoConstants.Accessibility.currencyField
                    )
                }

                Toggle(DemoConstants.Text.useDualMessagePayment, isOn: $viewModel.useDualMessagePayment)
                    .tint(Color(DemoConstants.ColorName.primary))
                    .accessibilityIdentifier(DemoConstants.Accessibility.useDualMessagePaymentToggle)

                Button(action: viewModel.startButtonTapped) {
                    Text(DemoConstants.Text.runPayment)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DemoConstants.Layout.buttonVerticalPadding)
                        .background(Color(DemoConstants.ColorName.primary))
                        .clipShape(RoundedRectangle(cornerRadius: DemoConstants.Layout.smallCornerRadius))
                }
                .accessibilityIdentifier(DemoConstants.Accessibility.runPaymentButton)
            }
            .padding(.horizontal, DemoConstants.Layout.screenHorizontalPadding)
            .padding(.bottom, DemoConstants.Layout.bottomPadding)
        }
        .background(Color.white)
    }
}

#Preview(DemoConstants.Preview.demoScreen) {
    DemoScreenView(viewModel: DemoScreenViewModel(worker: DemoScreenWorker()))
}

#Preview(DemoConstants.Preview.demoInputField) {
    DemoInputFieldPreview()
}

private struct DemoInputFieldPreview: View {
    @State private var text = DemoConstants.Preview.inputText

    var body: some View {
        DemoInputField(
            title: DemoConstants.Preview.inputTitle,
            placeholder: DemoConstants.Preview.inputPlaceholder,
            text: $text,
            accessibilityIdentifier: DemoConstants.Preview.inputAccessibilityIdentifier
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
