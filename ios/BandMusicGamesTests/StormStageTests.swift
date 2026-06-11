import XCTest
@testable import BandMusicGames

final class StormStageTests: XCTestCase {
    // Mirrors the scene's tuning block: greenLow 0.50, greenHigh 0.80,
    // perfectLow 0.60, perfectHigh 0.70.
    private func stage(_ charge: CGFloat?) -> StormStage {
        StormStage.stage(charge: charge, greenLow: 0.50, greenHigh: 0.80,
                         perfectLow: 0.60, perfectHigh: 0.70)
    }

    func testNilChargeIsClear() {
        XCTAssertEqual(stage(nil), .clear)
    }

    func testZeroChargeIsBuildingWithZeroProgress() {
        XCTAssertEqual(stage(0), .building(progress: 0))
    }

    func testHalfwayToWindowIsBuildingHalf() {
        XCTAssertEqual(stage(0.25), .building(progress: 0.5))
    }

    func testWindowEntryIsGreenNotPerfect() {
        XCTAssertEqual(stage(0.50), .green(perfect: false))
    }

    func testPerfectZoneBoundsMatchShotError() {
        XCTAssertEqual(stage(0.60), .green(perfect: true))
        XCTAssertEqual(stage(0.65), .green(perfect: true))
        XCTAssertEqual(stage(0.70), .green(perfect: true))
        XCTAssertEqual(stage(0.71), .green(perfect: false))
    }

    func testWindowTopIsStillGreen() {
        XCTAssertEqual(stage(0.80), .green(perfect: false))
    }

    func testPastWindowIsParted() {
        XCTAssertEqual(stage(0.81), .parted)
        XCTAssertEqual(stage(1.18), .parted)
    }

    func testKindsDistinguishStagesIgnoringValues() {
        XCTAssertEqual(stage(0.1).kind, stage(0.4).kind)
        XCTAssertNotEqual(stage(0.4).kind, stage(0.55).kind)
        XCTAssertNotEqual(stage(0.55).kind, stage(0.9).kind)
        XCTAssertNotEqual(stage(nil).kind, stage(0.1).kind)
    }
}
