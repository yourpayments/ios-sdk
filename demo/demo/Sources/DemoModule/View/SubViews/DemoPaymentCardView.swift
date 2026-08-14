import SwiftUI

struct DemoPaymentCardView: View {
    @ObservedObject var viewModel: DemoHeadlessPaymentViewModel
    let openURL: OpenURLAction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DemoConstants.Layout.sectionSpacing) {
                DemoPaymentHeaderView(title: "Оплата картой", amountText: viewModel.amountText)

                Group {
                    TextField("Номер карты", text: $viewModel.cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .accessibilityIdentifier("payment.headless.card.numberField")
                        .onChange(of: viewModel.cardNumber) { _, newValue in
                            viewModel.cardNumberChanged(newValue)
                        }
                    if let cardCapabilitiesText = viewModel.cardCapabilitiesText {
                        HStack(spacing: 6) {
                            Image(DemoConstants.Asset.earthGlobe)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text(cardCapabilitiesText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if viewModel.isBinInfoLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Загружаем данные карты")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if let binInfoText = viewModel.binInfoText {
                        Text(binInfoText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let binInfoErrorText = viewModel.binInfoErrorText {
                        Text(binInfoErrorText)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    HStack(spacing: DemoConstants.Layout.inputSpacing) {
                        TextField("ММГГ", text: $viewModel.expiry)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("payment.headless.card.expiryField")
                        SecureField("CVV", text: $viewModel.cvv)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("payment.headless.card.cvvField")
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        await viewModel.payByCard { url in
                            await openURLWithResult(url, using: openURL)
                        }
                    }
                } label: {
                    if viewModel.isActionInProgress {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Оплатить \(viewModel.amountText)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isActionInProgress)
                .accessibilityIdentifier("payment.headless.payByCardButton")

                Button("Другой способ оплаты") { viewModel.backToOptions() }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("payment.headless.backToOptionsButton")
            }
            .padding(DemoConstants.Layout.screenHorizontalPadding)
        }
    }
}
