import Foundation
import FoveaKit

// Oct 15 review (the dev team's workbook, docs/v1/REVIEW_2026-10-15.md): the window's new states,
// as plain values the model keeps. Their views are in HomeStates.swift, EarlierData.swift,
// SignInSheet.swift, PlanStates.swift and Saving.swift; the review stages that show each are in
// ReviewStages.swift.

/// Oct 15 review, MW-02a: the session the window opens with. While it's restored nothing of the
/// captures shows (not another account's, not "No Captures Yet"); if it can't be, the window says
/// so and offers Try Again and Sign In.
enum SessionState: Equatable { case ready, restoring, failed }

/// Oct 15 review, RC-01 and RC-02: captures kept by an earlier version of Fovea, or by another
/// account on this Mac, waiting to be brought in. 1.0 has no earlier versions and no account
/// server, so these are simulated (a review stage puts them there); nothing is read or deleted.
struct EarlierData: Identifiable, Equatable {
    enum Origin: Equatable {
        /// Fovea before 1.0, on this Mac ("Fovea 0.9").
        case earlierVersion(String)
        /// Another account signed in on this Mac (its email).
        case otherAccount(String)
    }

    enum State: Equatable {
        /// Found, not brought in yet.
        case pending
        /// Being brought in, 0…1.
        case bringingIn(Double)
        /// In Home now; the originals are still where they were, to delete or keep.
        case broughtIn
        case deleting
        /// Couldn't be brought in, and why.
        case failed(String)
    }

    let id: String
    var origin: Origin
    var captures: Int
    var bytes: Int64
    /// When it was last used.
    var date: Date
    /// The account it belongs to.
    var account: String
    var state: State = .pending

    /// Oct 18, Ryan: in the primary language. "From %@" alone is a starting date elsewhere (%@起),
    /// so this has a key of its own.
    var title: String { L("From %@ (earlier data)", english: "From \(source)") }

    /// The version or the account it came from.
    var source: String {
        switch origin {
        case .earlierVersion(let version): return version
        case .otherAccount(let email): return email
        }
    }
}

/// Oct 15 review, AC-01.4 and AC-01.5: signing in, from Account (signed out) or a session that
/// couldn't be restored. Simulated: 1.0 has no account server, so the provider's answer and the
/// email's link are played, and what's kept is kept on this Mac only.
struct SignInFlow: Equatable {
    enum Stage: Equatable {
        /// Continue with Apple, Google, or an email.
        case choose
        /// Waiting on Apple or Google, in their own window.
        case waiting(AccountProvider)
        /// That didn't work, and why.
        case failed(AccountProvider, String)
        /// A link went to this email at this moment (Resend counts down from it).
        case emailSent(String, Date)
    }
    var stage: Stage = .choose
    var email = ""
}

/// Oct 15 review, IS04: a save that didn't work, for its alert.
struct SaveFailure: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

extension T {
    /// Oct 15 review: how long Fovea's simulated services take (1.0 has no servers), in seconds.
    /// The model's waits, never a view's animation.
    enum Simulated {
        static let updateCheck = 1.4
        static let updateDownload = 2.6
        static let signIn = 1.8
        /// Before Resend works again, after an email goes.
        static let resendWait = 30
        static let restore = 2.0
        static let loadCaptures = 1.4
        static let bringIn = 3.0
        static let delete = 1.0
        /// A recording waits this long before Fovea tries it again, then takes `retranscribing`.
        static let retryWait = 2.5
        static let retranscribing = 2.2
        static let report = 1.6
        static let refreshPayment = 1.2
        static let migrationRetry = 1.6
    }
}
