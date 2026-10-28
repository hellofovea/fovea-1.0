import SwiftUI
import CoreText
import FoveaKit

/// The website's EB Garamond (`lib/landing/fonts.ts`), as the notch's words are set in it: bundled
/// with the notch (`FoveaIsland/Resources/Fonts`, its OFL beside it) and registered for this process
/// the first time the window sets it. Oct 27: the looks that speak in it (`T.Look`).
enum Garamond {
    private static let registered: Bool = {
        for name in ["EBGaramond-Latin.woff2", "EBGaramond-Italic-Latin.woff2"] {
            guard let url = FoveaFiles.island("Fonts/\(name)") else { continue }
            // The notch may have registered them already; that's an error to ignore.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    /// Medium italic, the notch's and the website's word face.
    static func italic(_ size: CGFloat) -> Font {
        _ = registered
        return .custom("EBGaramond-MediumItalic", fixedSize: size)
    }

    /// Medium roman, the website's reading face (`--read`, 500).
    static func roman(_ size: CGFloat) -> Font {
        _ = registered
        return .custom("EBGaramond-Medium", fixedSize: size)
    }

    /// Regular roman, for running words in a small card: Medium at this size reads heavy.
    static func text(_ size: CGFloat) -> Font {
        _ = registered
        return .custom("EBGaramond-Regular", fixedSize: size)
    }
}

/// A display title in the look's face (`T.Look.Face`): New York as Aligned sets it, the website's
/// Garamond italic, or the system face (bold in Notion White). Chinese has no Garamond: the system
/// face, as Aligned's New York does.
struct DisplayFace: ViewModifier {
    let size: CGFloat
    let face: T.Look.Face

    func body(content: Content) -> some View {
        let chinese = FoveaLocale.shared.language == .chinese
        switch face {
        case .garamond where !chinese:
            content.font(Garamond.italic(size * T.Look.garamondScale))
        case .system, .garamond:
            content.font(.system(size: size, weight: WindowLook.shown == .notion ? .bold : .semibold))
                .fontDesign(.default)
                .tracking(T.Aligned.displayTracking(size))
        case .newYork:
            content.font(T.Aligned.display(size))
                .fontDesign(T.Aligned.displayDesign)
                .tracking(T.Aligned.displayTracking(size))
        }
    }
}
