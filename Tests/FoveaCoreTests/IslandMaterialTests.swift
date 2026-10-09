import XCTest
@testable import FoveaCore

final class IslandMaterialTests: XCTestCase {
    private let ramp = IslandMaterialRamp(floor: 0.8, solidDepth: 32 + 24, fade: 120)

    func testRampIsSolidThroughTheNotchBand() {
        XCTAssertEqual(ramp.opacity(atDepth: 0), 1)
        XCTAssertEqual(ramp.opacity(atDepth: 32), 1)
        XCTAssertEqual(ramp.opacity(atDepth: 56), 1)
    }

    func testRampNeverDropsBelowTheFloor() {
        var previous = 1.0
        for depth in stride(from: CGFloat(0), through: 600, by: 4) {
            let opacity = ramp.opacity(atDepth: depth)
            XCTAssertGreaterThanOrEqual(opacity, 0.8, "depth \(depth)")
            XCTAssertLessThanOrEqual(opacity, previous + 1e-9, "the ramp only ever lightens with depth")
            previous = opacity
        }
        XCTAssertEqual(ramp.opacity(atDepth: 56 + 120), 0.8, accuracy: 1e-9)
        XCTAssertEqual(ramp.opacity(atDepth: 420), 0.8, accuracy: 1e-9)
    }

    func testRampStopsSpanTheRampAndEndClear() {
        let stops = ramp.rampStops()
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.first?.opacity, 1)
        XCTAssertEqual(stops.last?.location ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(stops.last?.opacity ?? 1, 0, accuracy: 1e-9)
        XCTAssertEqual(zip(stops, stops.dropFirst()).filter { $0.location > $1.location }.count, 0)
        XCTAssertEqual(ramp.height, 176)
    }

    func testParseAcceptsNamesAndLetters() {
        XCTAssertEqual(IslandMaterial.parse("graded"), .graded)
        XCTAssertEqual(IslandMaterial.parse("D"), .graded)
        XCTAssertEqual(IslandMaterial.parse("a"), .black)
        XCTAssertEqual(IslandMaterial.parse("proportionalFade"), .proportionalFade)
        XCTAssertNil(IslandMaterial.parse("frosted"))
        XCTAssertEqual(IslandMaterial.default, .black, "the PRD's surface stays the default")
    }

    func testPrefsSavedBeforeTheMaterialStillDecode() throws {
        let old = Data(#"{"detachedFrame":[[10,20],[300,200]]}"#.utf8)
        let prefs = try JSONDecoder().decode(IslandPrefs.self, from: old)
        XCTAssertNil(prefs.material)
        let saved = try JSONEncoder().encode(IslandPrefs(material: .graded))
        XCTAssertEqual(try JSONDecoder().decode(IslandPrefs.self, from: saved).material, .graded)
    }
}
