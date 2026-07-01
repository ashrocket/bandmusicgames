import XCTest
@testable import BandMusicGames

/// Regression guard for the a06060a difficulty inversion fix: every tunable
/// must stay monotonic easy → normal → hard.
final class HalfCourtDifficultyTests: XCTestCase {
    private let ordered: [HalfCourtDifficulty] = [.easy, .normal, .hard]

    private func assertStrictlyDecreasing(_ values: [CGFloat], _ name: String) {
        for i in 1..<values.count {
            XCTAssertLessThan(values[i], values[i - 1], "\(name) must decrease easy→hard")
        }
    }

    private func assertStrictlyIncreasing(_ values: [CGFloat], _ name: String) {
        for i in 1..<values.count {
            XCTAssertGreaterThan(values[i], values[i - 1], "\(name) must increase easy→hard")
        }
    }

    func testGreenWindowNarrowsWithDifficulty() {
        assertStrictlyDecreasing(ordered.map { $0.greenWindow.high - $0.greenWindow.low }, "green window width")
    }

    func testAccuraciesDropWithDifficulty() {
        assertStrictlyDecreasing(ordered.map(\.perfectAccuracy), "perfectAccuracy")
        assertStrictlyDecreasing(ordered.map(\.greenAccuracy), "greenAccuracy")
        assertStrictlyDecreasing(ordered.map(\.lateAccuracy), "lateAccuracy")
    }

    func testCPUGetsMeanerWithDifficulty() {
        // Smaller multiplier = tighter CPU shots (a06060a: hard must be the sniper).
        assertStrictlyDecreasing(ordered.map(\.cpuShotMultiplier), "cpuShotMultiplier")
        assertStrictlyIncreasing(ordered.map(\.cpuDriveSpeed), "cpuDriveSpeed")
        assertStrictlyIncreasing(ordered.map(\.cpuStealRate), "cpuStealRate")
    }

    func testPressureRisesWithDifficulty() {
        assertStrictlyDecreasing(ordered.map { CGFloat($0.shotClockSeconds) }, "shotClockSeconds")
        assertStrictlyIncreasing(ordered.map(\.chargeRate), "chargeRate")
    }
}
