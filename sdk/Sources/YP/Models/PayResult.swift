public enum PayResult: Sendable {
    case authorized(IntentStatusResponse)
    case threeDsRequired(threeDsUrl: String)
}
