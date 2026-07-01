import XCTest
@testable import BandMusicGames

final class BlockGradeTests: XCTestCase {
    // Normal-difficulty window: 0.52–0.76. Center band = middle 40% (p 0.30–0.70).
    private func grade(_ fill: CGFloat) -> BlockGrade {
        BlockGrade.grade(fill: fill, greenLow: 0.52, greenHigh: 0.76)
    }

    func testOutsideWindow() {
        XCTAssertEqual(grade(0.51), .early)
        XCTAssertEqual(grade(0.77), .late)
    }

    func testCenterBandIsSwat() {
        // Probe strictly inside the p ∈ [0.30, 0.70] band — exact boundary
        // values land on float rounding and aren't behaviorally meaningful.
        XCTAssertEqual(grade(0.64), .swat)                // dead center
        XCTAssertEqual(grade(0.52 + 0.24 * 0.31), .swat)  // just inside low edge
        XCTAssertEqual(grade(0.52 + 0.24 * 0.69), .swat)  // just inside high edge
    }

    func testWindowEdgesAreOrdinaryBlocks() {
        XCTAssertEqual(grade(0.53), .inWindow)
        XCTAssertEqual(grade(0.75), .inWindow)
    }

    func testSuccessChances() {
        XCTAssertEqual(BlockGrade.swat.successChance, 0.95)
        XCTAssertEqual(BlockGrade.inWindow.successChance, 0.70)
        XCTAssertEqual(BlockGrade.early.successChance, 0)
        XCTAssertEqual(BlockGrade.late.successChance, 0)
    }
}
