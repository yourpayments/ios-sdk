public enum IntentEvent {
    case update(PaymentIntent)
    case statusChange(IntentStatus)
    case success(PayResult)
    case error(Error)
}
