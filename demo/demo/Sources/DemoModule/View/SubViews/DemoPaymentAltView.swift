import SwiftUI
import Yourpayments

struct DemoPaymentAltView: View {
    @ObservedObject var viewModel: DemoHeadlessPaymentViewModel
    let method: DemoPaymentAltMethod
    let openURL: OpenURLAction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DemoConstants.Layout.sectionSpacing) {
                DemoPaymentHeaderView(title: method.title, amountText: viewModel.amountText)

                switch method {
                case .fasterPayments:
                    sbpBankSelection
                case .sberPay:
                    sberPayAction
                }

                if let altLink = viewModel.altLink {
                    Button("Открыть ссылку") {
                        Task {
                            await viewModel.openAltLink(altLink) { url in
                                await openURLWithResult(url, using: openURL)
                            }
                        }
                    }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("payment.headless.openAltLinkButton")

                    Text(altLink.absoluteString)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                Button("Проверить результат") { Task { await viewModel.checkPaymentResult() } }
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isActionInProgress)
                    .accessibilityIdentifier("payment.headless.waitResultButton")

                Button("Другой способ оплаты") { viewModel.backToOptions() }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("payment.headless.backToOptionsButton")
            }
            .padding(DemoConstants.Layout.screenHorizontalPadding)
        }
        .accessibilityIdentifier(method == .fasterPayments ? "payment.headless.sbp" : "payment.headless.alt")
        .task {
            guard method == .fasterPayments else { return }
            await viewModel.loadSbpBanks()
        }
    }

    private var sbpBankSelection: some View {
        VStack(alignment: .leading, spacing: DemoConstants.Layout.sectionSpacing) {
            Text("Выберите банк для оплаты через СБП.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Поиск банка", text: $viewModel.sbpSearchText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("payment.headless.sbp.searchField")

            if viewModel.isActionInProgress && viewModel.sbpBanks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("payment.headless.sbp.loading")
            } else if viewModel.filteredSbpBanks.isEmpty {
                Text("Банки не найдены")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: DemoConstants.Layout.inputSpacing) {
                    ForEach(viewModel.filteredSbpBanks, id: \.sbpIdentity) { bank in
                        Button {
                            Task {
                                await viewModel.selectSbpBank(bank) { url in
                                    await openURLWithResult(url, using: openURL)
                                }
                            }
                        } label: {
                            HStack(spacing: DemoConstants.Layout.inputSpacing) {
                                Image(systemName: "building.columns")
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bank.bankName)
                                        .font(.headline)
                                    Text(bank.schema)
                                        .font(.caption)
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
                        .disabled(viewModel.isActionInProgress)
                        .accessibilityIdentifier("payment.headless.sbp.bank.\(bank.sbpIdentity)")
                    }
                }
            }
        }
        .accessibilityIdentifier("payment.headless.sbpLinkButton")
    }

    private var sberPayAction: some View {
        VStack(alignment: .leading, spacing: DemoConstants.Layout.sectionSpacing) {
            Text("Получите платежную ссылку и откройте ее в SberPay.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await viewModel.loadAndOpenAltLink(method) { url in
                        await openURLWithResult(url, using: openURL)
                    }
                }
            } label: {
                if viewModel.isActionInProgress {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(method.actionTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isActionInProgress)
            .accessibilityIdentifier("payment.headless.sberPayLinkButton")
        }
    }
}

private extension SbpBank {
    var sbpIdentity: String {
        [bankName, schema, webClientUrl]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}
