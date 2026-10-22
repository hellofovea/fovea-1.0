import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Oct 15 review, AC-02.1, AC-02.2 and MW-04d: what Settings › Plan says when the plan isn't simply
// on. A trial with its days left and what happens after it; the trial ended; credits used up (the
// usage card, as before); a subscription ending or expired, with Renew; a payment processing, with
// Refresh; a payment that failed, with Update Payment; the billing page that wouldn't open, with
// Try Again. One card at the top of the pane, in Settings' own rows. The plan is simulated (1.0
// has no account server); opening the billing page is real.

extension CapturesModel {
    /// The website's billing page (Oct 13), opened for real; when the Mac can't open it, Plan
    /// says so with Try Again (MW-04d).
    func openBilling() {
        if NSWorkspace.shared.open(FoveaSite.account) {
            if planAlert == .billingUnavailable { animate(.layout) { planAlert = nil } }
        } else {
            animate(.layout) { planAlert = .billingUnavailable }
        }
    }

    /// Refresh, while a payment is processing: asked again, and (simulated) Pro is on.
    func refreshPayment() {
        guard !refreshingPayment else { return }
        refreshingPayment = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.refreshPayment)))
            self.refreshingPayment = false
            guard self.planAlert == .paymentProcessing else { return }
            self.animate(.layout) { self.planAlert = nil; self.plan = .pro; self.nextPlan = nil }
            self.say(L("Your payment went through. You're on Pro."))
        }
    }

    /// A review stage's plan: the alert, on the plan it belongs to, and Plan open.
    func stagePlan(_ alert: PlanAlert?) {
        windowError = nil
        animate(.layout) {
            planAlert = alert
            nextPlan = nil
            switch alert {
            case .trial, .subscriptionEnding, .paymentFailed, .almostOut, .usedUp: plan = .pro
            case .trialEnded, .expired, .paymentProcessing: plan = .free
            case .billingUnavailable, nil: break
            }
        }
        openSettings(.plan)
    }

    /// The trial's last day, five days from now (simulated).
    var trialEnds: Date { Lines.calendar.date(byAdding: .day, value: 5, to: now) ?? now }
}

/// The plan's state, when there's one to tell: at the top of Plan.
struct PlanStatusSection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let alert = model.planAlert, let status = status(alert) {
            SettingsSection("Your plan") {
                SettingsCard {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: status.symbol)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(status.urgent ? palette.danger : palette.secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                            Text(status.detail).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        action(alert)
                    }
                    .cardPadding()
                }
            }
        }
    }

    private struct Status {
        let symbol: String
        let title: String
        let detail: String
        var urgent = false
        let review: String
        let note: String
    }

    // Oct 18, Ryan: the title and the detail in the primary language (the review's notes stay).
    private func status(_ alert: PlanAlert) -> Status? {
        let free = Plan.free
        let credits = free.credits.formatted()
        switch alert {
        case .trial:
            return Status(symbol: "clock", title: L("Pro trial · 5 days left"),
                          detail: L("On \(Lines.day(model.trialEnds)) you move to Free: dictation as much as you like, \(credits) credits a month, 30 days of history. Nothing you've captured is lost."),
                          review: "AC-02.1", note: "The trial: days left, and what happens after it")
        case .trialEnded:
            return Status(symbol: "clock.badge.exclamationmark", title: L("Your Pro trial has ended"),
                          detail: L("You're on Free now: dictation as much as you like and \(credits) credits a month. Upgrade to take things and dispatch as before."),
                          review: "AC-02.1", note: "Trial ended: on Free, with Upgrade")
        case .subscriptionEnding:
            return Status(symbol: "calendar.badge.exclamationmark", title: L("Pro ends \(Lines.day(model.usage.resets))"),
                          detail: L("You cancelled it. Until then nothing changes; after that you're on Free."),
                          review: "MW-04d", note: "Subscription ending, with Renew")
        case .expired:
            return Status(symbol: "exclamationmark.circle", title: L("Your Pro subscription has expired"),
                          detail: L("You're on Free: dictation as before, and \(credits) credits a month for taking things and dispatching."),
                          review: "MW-04d", note: "Subscription expired, with Renew")
        case .paymentFailed:
            let grace = Lines.calendar.date(byAdding: .day, value: 7, to: model.now) ?? model.now
            return Status(symbol: "creditcard.trianglebadge.exclamationmark", title: L("Your payment didn't go through"),
                          detail: L("Pro stays on until \(Lines.day(grace)) while you update your card. After that you move to Free."),
                          urgent: true, review: "MW-04d", note: "Payment failed: Update Payment opens the website")
        case .billingUnavailable:
            return Status(symbol: "wifi.exclamationmark", title: L("Couldn't open the billing page"),
                          detail: L("Check your connection, then try again."),
                          urgent: true, review: "MW-04d", note: "The billing page didn't open: Try Again")
        case .almostOut, .usedUp, .paymentProcessing:
            // The credits card says these, where the credits are (AC-02.2, MW-04d).
            return nil
        }
    }

    @ViewBuilder private func action(_ alert: PlanAlert) -> some View {
        switch alert {
        case .trial:
            Button("Choose a Plan…") { model.scrollTarget = "plans" }
        case .trialEnded:
            Button("Upgrade…") { model.scrollTarget = "plans" }
                .buttonStyle(.borderedProminent)
        case .subscriptionEnding, .expired:
            Button("Renew ↗") { model.openBilling() }
                .buttonStyle(.borderedProminent)
        case .paymentFailed:
            Button("Update Payment ↗") { model.openBilling() }
                .buttonStyle(.borderedProminent)
        case .billingUnavailable:
            Button("Try Again") { model.openBilling() }
        case .almostOut, .usedUp, .paymentProcessing:
            EmptyView()
        }
    }
}
