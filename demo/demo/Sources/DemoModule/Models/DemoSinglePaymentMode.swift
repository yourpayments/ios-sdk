import Foundation

enum DemoSinglePaymentMode: String, CaseIterable, Identifiable {
    case options
    case card
    case sbp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .options:
            return DemoConstants.Text.optionsMode
        case .card:
            return DemoConstants.Text.cardMode
        case .sbp:
            return DemoConstants.Text.sbpMode
        }
    }
}
