import SwiftUI

struct DemoInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .never
    var accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DemoConstants.Layout.fieldSpacing) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .accessibilityIdentifier(accessibilityIdentifier)
                .padding(.horizontal, DemoConstants.Layout.inputSpacing)
                .frame(height: DemoConstants.Layout.inputHeight)
                .background(
                    RoundedRectangle(cornerRadius: DemoConstants.Layout.smallCornerRadius)
                        .stroke(Color(DemoConstants.ColorName.primary), lineWidth: DemoConstants.Layout.one)
                )
        }
    }
}
