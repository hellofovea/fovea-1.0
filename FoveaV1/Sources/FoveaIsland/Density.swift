import CoreGraphics

// How much room the notch's open panels take (docs/island/SPACIOUS.md). Fovea 1.0, Oct 9: the
// Workbench drew its Mac at about two thirds of its size, so on the real screen every panel read
// a size too big (Choose chat's words larger than a coding agent's). Each size moved down a step,
// Compact to 13 pt words and 28 pt controls (the Mac's menus and buttons). Oct 27, Ryan, of the
// larger size: "dont have the big version as well": 1.0 has one size, Compact, nothing switches
// it, and each token is written with its Compact value alone. The resting notch and the voice bar
// take their numbers as they are.

extension WorkbenchTokens {
    // Oct 27, Ryan: "rn the notch is way too big. make it smaller and more ambient like our notch.
    // but i do like the translucent design tho". Compact a step smaller again: every length the
    // panels are drawn with scaled, hairlines and gaps of 2 pt or less as they were; the words a
    // little smaller, never below 9.5 pt (and never larger than they were). Spacious, the voice bar
    // and the notch at rest are unchanged.
    static let compactScale: CGFloat = 0.86
    static let compactTypeScale: CGFloat = 0.92

    /// A length in Compact: scaled, 2 pt or less as it is.
    static func size(_ length: CGFloat) -> CGFloat {
        length <= 2 ? length : (length * compactScale * 2).rounded() / 2
    }

    /// A word's size in Compact.
    static func typeSize(_ size: CGFloat) -> CGFloat {
        max(min(size, 9.5), (size * compactTypeScale * 2).rounded() / 2)
    }
}
