public enum PayInput: Sendable {
    case card(CardData)
    case cryptogram(String)
}
