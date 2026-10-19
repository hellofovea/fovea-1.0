import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Oct 15 review, AC-01.4 and AC-01.5: signing in again, from Account when signed out or from a
// session that couldn't be restored (MW-02a). A Mac sheet with the three ways the first run
// offers (Apple, Google, an email), each with its wait, its failure and, for the email, the link
// that went. Simulated: 1.0 has no account server, so Apple's and Google's answers are played and
// the account is kept on this Mac (FoveaPrefs' accountEmail and accountProvider).

extension CapturesModel {
    /// The sign-in sheet, from its first page.
    func startSignIn() { signIn = SignInFlow() }

    func cancelSignIn() { signIn = nil }

    /// Continue with Apple or Google: their own window opens, and Fovea waits on it.
    func continueSignIn(with provider: AccountProvider) {
        signIn?.stage = .waiting(provider)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.signIn)))
            guard self.signIn?.stage == .waiting(provider) else { return }
            self.finishSignIn(provider, email: "")
        }
    }

    /// Continue with Email: a link goes to it (simulated: nothing is sent).
    func sendSignInLink() {
        guard let email = signIn?.email.trimmingCharacters(in: .whitespaces), Self.looksLikeEmail(email) else { return }
        signIn?.stage = .emailSent(email, Date())
    }

    func resendSignInLink() {
        guard case .emailSent(let email, _) = signIn?.stage else { return }
        signIn?.stage = .emailSent(email, Date())
    }

    /// Signed in: the account kept on this Mac, the session ready.
    func finishSignIn(_ provider: AccountProvider, email: String) {
        animate(.swap) {
            signedOut = false
            if session == .failed { session = .ready }
            profileEmail = email.isEmpty ? Self.signedInWith(provider) : email
        }
        signIn = nil
        onAccountEdited?(email, provider)
        say(L("Signed in"))
    }

    static func name(_ provider: AccountProvider) -> String {
        switch provider {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return L("email")
        }
    }

    /// Oct 18, Ryan: in the primary language, a sentence for each way in.
    static func signedInWith(_ provider: AccountProvider) -> String {
        switch provider {
        case .apple: return L("Signed in with Apple")
        case .google: return L("Signed in with Google")
        case .email: return L("Signed in with email")
        }
    }

    static func looksLikeEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !s.contains(" ")
    }
}

struct SignInSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @FocusState private var emailFocused: Bool

    var body: some View {
        let stage = model.signIn?.stage ?? .choose
        VStack(alignment: .leading, spacing: 16) {
            switch stage {
            case .choose: choose
            case .waiting(let provider): waiting(provider)
            case .failed(let provider, let reason): failed(provider, reason)
            case .emailSent(let email, let at): sent(email, at)
            }
        }
        .padding(22)
        .frame(width: 400)
        .animation(model.motion.animation(.swap), value: stage)
    }

    // MARK: Pages

    private var choose: some View {
        @Bindable var model = model
        let email = model.signIn?.email ?? ""
        return VStack(alignment: .leading, spacing: 16) {
            header("Sign in to Fovea", "Your captures stay on this Mac either way.")
            VStack(spacing: 8) {
                Button { model.continueSignIn(with: .apple) } label: {
                    Label("Continue with Apple", systemImage: "apple.logo").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.isDark ? Color.white : Color.black)
                .foregroundStyle(palette.isDark ? Color.black : Color.white)
                Button { model.continueSignIn(with: .google) } label: {
                    Text("Continue with Google").frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            HStack(spacing: 8) {
                Rectangle().fill(palette.hairline).frame(height: 0.5)
                Text("or").font(.system(size: 11.5)).foregroundStyle(palette.tertiary)
                Rectangle().fill(palette.hairline).frame(height: 0.5)
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField("Email", text: Binding(get: { model.signIn?.email ?? "" }, set: { model.signIn?.email = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($emailFocused)
                    .onSubmit { model.sendSignInLink() }
                Button { model.sendSignInLink() } label: { Text("Continue with Email").frame(maxWidth: .infinity) }
                    .controlSize(.large)
                    .disabled(!CapturesModel.looksLikeEmail(email.trimmingCharacters(in: .whitespaces)))
            }
            HStack {
                Spacer()
                Button("Cancel") { model.cancelSignIn() }.keyboardShortcut(.cancelAction)
            }
        }
    }

    private func waiting(_ provider: AccountProvider) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                header(L("Waiting for \(CapturesModel.name(provider))…"),
                       L("Finish signing in in the window \(CapturesModel.name(provider)) opened, then come back here."))
            }
            HStack {
                Spacer()
                Button("Cancel") { model.signIn?.stage = .choose }.keyboardShortcut(.cancelAction)
            }
        }
    }

    private func failed(_ provider: AccountProvider, _ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 22)).foregroundStyle(palette.warning)
                header(L("Couldn't sign in with \(CapturesModel.name(provider))"), reason)
            }
            HStack {
                Button("Use Another Way") { model.signIn?.stage = .choose }
                Spacer()
                Button("Cancel") { model.cancelSignIn() }.keyboardShortcut(.cancelAction)
                Button("Try Again") { model.continueSignIn(with: provider) }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func sent(_ email: String, _ at: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.badge").font(.system(size: 22)).foregroundStyle(palette.accent)
                header("Check your email", L("We sent a link to \(email). Open it on this Mac to sign in. It works for 15 minutes."))
            }
            HStack {
                Button("Use a Different Email") { model.signIn?.stage = .choose }
                Spacer()
                // Resend waits half a minute, counting down, so a second link doesn't cross the first.
                TimelineView(.periodic(from: at, by: 1)) { context in
                    let left = max(0, T.Simulated.resendWait - Int(context.date.timeIntervalSince(at)))
                    Button(left > 0 ? "Resend in 0:\(String(format: "%02d", left))" : "Resend") { model.resendSignInLink() }
                        .disabled(left > 0)
                        .monospacedDigit()
                }
                Button("Cancel") { model.cancelSignIn() }.keyboardShortcut(.cancelAction)
            }
        }
    }

    /// Oct 18, Ryan: in the primary language; a sentence with a value in it comes made with L().
    private func header(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(key: title)).font(.system(size: 15, weight: .semibold))
            Text(L(key: detail)).font(.system(size: 12.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
