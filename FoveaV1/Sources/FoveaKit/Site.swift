import Foundation

/// Fovea's website (Oct 13): feedback, the subscription (cancel it, keep it, change it) and what
/// leaves your Mac live there, and the app links to them wherever those come up. One place to
/// change them.
public enum FoveaSite {
    public static let home = URL(string: "https://www.hellofovea.com/")!
    /// Feedback: Settings › Account › Help, and Help › Send Feedback.
    public static let feedback = URL(string: "https://www.hellofovea.com/feedback")!
    /// The subscription, to cancel or keep: Settings › Plan › Billing, Help › Manage Subscription,
    /// and the notch's "Pro subscription expired" (Renew).
    public static let account = URL(string: "https://www.hellofovea.com/account")!
    /// The plans: the notch's "Trial ended" and "Usage limit reached" (Upgrade).
    public static let pricing = URL(string: "https://www.hellofovea.com/pricing")!
    /// The site's own words on privacy: Settings › Voice & Capture and the Account page's links.
    public static let whatLeavesYourMac = URL(string: "https://www.hellofovea.com/what-leaves-your-mac")!
    /// Oct 15, the dev team's review MW-04c: the help center and what's new in each version.
    public static let helpCenter = URL(string: "https://www.hellofovea.com/help")!
    public static let whatsNew = URL(string: "https://www.hellofovea.com/changelog")!
    /// Where the Mac app is downloaded, for "Move to Applications" and updates (NH-06).
    public static let download = URL(string: "https://www.hellofovea.com/download")!
}
