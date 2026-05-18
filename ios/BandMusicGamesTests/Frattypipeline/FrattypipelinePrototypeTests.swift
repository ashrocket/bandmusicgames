import XCTest
@testable import BandMusicGames

final class FrattypipelinePrototypeTests: XCTestCase {
    func testBeatClockReportsHitWindowNearBeatBoundary() {
        var clock = FrattypipelineBeatClock(bpm: 120)

        XCTAssertTrue(clock.isInHitWindow)

        clock.advance(by: 0.25)
        XCTAssertFalse(clock.isInHitWindow)

        clock.advance(by: 0.20)
        XCTAssertTrue(clock.isInHitWindow)
    }

    @MainActor
    func testInputConsumesBarkOnce() {
        let input = FrattypipelineInputController()

        XCTAssertFalse(input.consumeBark())

        input.triggerBark()
        XCTAssertTrue(input.consumeBark())
        XCTAssertFalse(input.consumeBark())
    }

    func testQuestCopyNamesPrototypeLoop() {
        XCTAssertEqual(FrattypipelineQuestState.findStage.title, "Find The Stage")
        XCTAssertEqual(FrattypipelineQuestState.barkOnBeat.detail, "Tap BARK inside the gold beat window.")
        XCTAssertEqual(FrattypipelineQuestState.complete.title, "Quad Awake")
    }
}
