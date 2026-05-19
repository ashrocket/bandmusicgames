import XCTest
@testable import BandMusicGames

final class FrattypipelinePrototypeTests: XCTestCase {
    func testBeatClockReportsHitWindowNearBeatBoundary() {
        var clock = FrattypipelineBeatClock(bpm: 120)

        XCTAssertTrue(clock.isInHitWindow)
        XCTAssertEqual(clock.beatIndex, 0)

        clock.advance(by: 0.25)
        XCTAssertFalse(clock.isInHitWindow)
        XCTAssertEqual(clock.beatIndex, 0)

        clock.advance(by: 0.20)
        XCTAssertTrue(clock.isInHitWindow)
        XCTAssertEqual(clock.beatIndex, 0)

        clock.advance(by: 0.10)
        XCTAssertEqual(clock.beatIndex, 1)
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

    func testCampusMoodTracksBeatBarkProgress() {
        var mood = FrattypipelineCampusMood()

        XCTAssertEqual(mood.title, "Quiet Quad")
        XCTAssertEqual(mood.displayProgress, "HYPE 0/3")

        mood.registerBark(onBeat: true)
        mood.registerBark(onBeat: true)

        XCTAssertEqual(mood.title, "Crowd Hype")
        XCTAssertEqual(mood.displayProgress, "HYPE 2/3")

        mood.registerBark(onBeat: false)
        XCTAssertEqual(mood.title, "Heads Turning")

        mood.complete()
        XCTAssertEqual(mood.title, "Quad Awake")

        mood.reset()
        XCTAssertEqual(mood.displayProgress, "HYPE 0/3")
    }

    func testSongSectionAdvancesByEightBeatPhrases() {
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 0), .intro)
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 7), .intro)
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 8), .verse)
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 16), .hook)
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 24), .bridge)
        XCTAssertEqual(FrattypipelineSongSection.section(forBeat: 32), .intro)
    }

    func testSongStackUnlocksStemsOnlyFromOnBeatBarks() {
        var stack = FrattypipelineSongStack()

        XCTAssertEqual(stack.displayProgress, "STEMS 1/4")
        XCTAssertEqual(stack.activeStemTitle, "Drums")

        stack.registerBark(onBeat: false)
        XCTAssertEqual(stack.displayProgress, "STEMS 1/4")

        stack.registerBark(onBeat: true)
        stack.registerBark(onBeat: true)
        XCTAssertEqual(stack.displayProgress, "STEMS 3/4")
        XCTAssertEqual(stack.activeStemTitle, "Barks")

        stack.complete()
        XCTAssertEqual(stack.displayProgress, "STEMS 4/4")
        XCTAssertEqual(stack.activeStemTitle, "Crowd")

        stack.reset()
        XCTAssertEqual(stack.displayProgress, "STEMS 1/4")
    }

    func testAudioMixMapsSectionAndStemStateToPrototypeSoundProfile() {
        let intro = FrattypipelineAudioMix(stemCount: 1, section: .intro, beatEnergy: 0)
        let hook = FrattypipelineAudioMix(stemCount: 4, section: .hook, beatEnergy: 1)

        XCTAssertEqual(intro.baseFrequency, 82.41, accuracy: 0.001)
        XCTAssertEqual(intro.barkFrequency, 620, accuracy: 0.001)

        XCTAssertEqual(hook.baseFrequency, 123.47, accuracy: 0.001)
        XCTAssertEqual(hook.barkFrequency, 740, accuracy: 0.001)
        XCTAssertGreaterThan(hook.masterGain, intro.masterGain)
    }
}
