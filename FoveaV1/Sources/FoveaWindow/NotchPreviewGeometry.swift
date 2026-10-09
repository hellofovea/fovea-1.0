import CoreGraphics
import FoveaCore
import FoveaKit

/// Settings › Notch's preview at a MacBook's own size, from Core's geometry (the shipping
/// numbers, `IslandLayoutSpec` on the 13-inch sample): the 200×32 notch, and the voice bar the
/// notch's width between 6 pt ears, 44 pt below it, its bottom corners 14 pt.
enum NotchPreviewGeometry {
    private static let voice = NotchGeometry.frames(density: .voice, metrics: .sampleNotched, spec: IslandLayoutSpec())
    static let notch: CGSize = voice.notch.size
    static let bar = CGSize(width: voice.width, height: voice.minHeight)
    static let topRadius: CGFloat = voice.topRadius
    static let bottomRadius: CGFloat = voice.bottomRadius
}
