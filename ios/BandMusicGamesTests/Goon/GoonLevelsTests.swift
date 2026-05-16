import XCTest
@testable import BandMusicGames

final class GoonLevelsTests: XCTestCase {
    func test_allLevels_matchWebGame() {
        let levels = GoonLevels.all
        XCTAssertEqual(levels.count, 5)

        // Level 1: THE HOUSE NEXT DOOR
        let l1 = levels[0]
        XCTAssertEqual(l1.n, 1)
        XCTAssertEqual(l1.title, "LEVEL 1")
        XCTAssertEqual(l1.sub, "THE HOUSE NEXT DOOR")
        XCTAssertEqual(l1.gasMax, 600)
        XCTAssertEqual(l1.gasDrain, 0.10, accuracy: 0.001)
        XCTAssertEqual(l1.cans, 0)
        XCTAssertEqual(l1.stumps, 0)
        XCTAssertEqual(l1.crickets, 0)
        XCTAssertEqual(l1.skunks, 0)
        XCTAssertEqual(l1.cricketMs, 0)
        XCTAssertEqual(l1.win, 0.80, accuracy: 0.001)

        // Level 2: RUNNING ON FUMES
        let l2 = levels[1]
        XCTAssertEqual(l2.sub, "RUNNING ON FUMES")
        XCTAssertEqual(l2.gasMax, 200)
        XCTAssertEqual(l2.gasDrain, 0.18, accuracy: 0.001)
        XCTAssertEqual(l2.cans, 2)

        // Level 3: STUMP TROUBLE
        let l3 = levels[2]
        XCTAssertEqual(l3.sub, "STUMP TROUBLE")
        XCTAssertEqual(l3.stumps, 2)

        // Level 4: CRICKET SEASON
        let l4 = levels[3]
        XCTAssertEqual(l4.sub, "CRICKET SEASON")
        XCTAssertEqual(l4.crickets, 2)
        XCTAssertEqual(l4.skunks, 1)
        XCTAssertEqual(l4.cricketMs, 1200)
        XCTAssertEqual(l4.win, 0.85, accuracy: 0.001)

        // Level 5: THE FINAL YARD
        let l5 = levels[4]
        XCTAssertEqual(l5.sub, "THE FINAL YARD")
        XCTAssertEqual(l5.gasMax, 140)
        XCTAssertEqual(l5.cans, 4)
        XCTAssertEqual(l5.stumps, 3)
        XCTAssertEqual(l5.crickets, 3)
        XCTAssertEqual(l5.skunks, 2)
        XCTAssertEqual(l5.cricketMs, 750)
        XCTAssertEqual(l5.win, 0.90, accuracy: 0.001)
    }
}
