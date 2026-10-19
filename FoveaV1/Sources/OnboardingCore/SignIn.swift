import Foundation

// Oct 15 review, FR-03, FR-04, AC-01.1, AC-01.2: signing up, as it goes. Apple, Google or an email;
// waiting on Apple or Google, with Cancel; canceled, back to the choices with a quiet line; failed,
// with Try Again; for an email, a link sent, Resend after a countdown, and a different email. 1.0
// has no account server: Apple, Google and the link are simulated, and what's kept stays on this
// Mac (Settings › Account).

/// Where signing up is.
public enum SignInPhase: Equatable, Sendable {
    /// Apple, Google, or an email.
    case choosing
    /// Apple or Google has the person (its own window, in the shipping app); Cancel stops it.
    case waiting(AccountProvider)
    /// Canceled: the choices again, with a quiet line.
    case canceled(AccountProvider)
    /// It didn't work: say so, and Try Again.
    case failed(AccountProvider)
    /// A link sent to this email; the page waits for it to be opened.
    case checkEmail(String)
    /// Signed up: the page goes on by itself, or with Continue when it's come back to.
    case signedIn(AccountProvider)

    public var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    /// The choices are on the page (Apple, Google, the email box).
    public var showsChoices: Bool {
        switch self {
        case .choosing, .canceled: true
        default: false
        }
    }
}

extension AccountProvider {
    /// The name the page says: "Apple", "Google", or "email".
    public var title: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        case .email: L("email")
        }
    }
}

/// The email's Resend, held back a while after each send (AC-01.2).
public enum ResendCountdown {
    /// Seconds before Resend works again.
    public static let seconds = 30

    /// "Resend in 0:24", or "Resend Email" once it's time.
    public static func label(secondsLeft: Int) -> String {
        guard secondsLeft > 0 else { return Copy.signInResend }
        // Oct 18, Ryan: in the primary language.
        let time = "\(secondsLeft / 60):\(String(format: "%02d", secondsLeft % 60))"
        return L("Resend in \(time)")
    }
}
