import XCTest
@testable import BandMusicGames

final class HalfCourtStatsTests: XCTestCase {
    func testBeatRunAccumulatesAndSurvivesOnFireCycle() {
        var s = HalfCourtStats()
        // 5 consecutive on-beat releases — the run must NOT reset at 3 (ON FIRE
        // consumes onBeatStreak, but the chased record keeps counting).
        for _ in 0..<5 { s.registerBeatRelease(onBeat: true) }
        XCTAssertEqual(s.bestBeatStreak, 5)
        s.registerBeatRelease(onBeat: false)
        XCTAssertEqual(s.bestBeatStreak, 5, "off-beat ends the run but keeps the best")
        s.registerBeatRelease(onBeat: true)
        s.registerBeatRelease(onBeat: true)
        XCTAssertEqual(s.bestBeatStreak, 5, "shorter new run doesn't beat the best")
    }

    func testFieldGoalPercent() {
        var s = HalfCourtStats()
        s.shots = 12; s.made = 7
        XCTAssertEqual(s.fgPercent, 58)
        XCTAssertEqual(HalfCourtStats().fgPercent, 0, "no shots → 0, not divide-by-zero")
    }
}
