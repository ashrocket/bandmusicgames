import XCTest
@testable import BandMusicGames

@MainActor
final class GoonGameStateTests: XCTestCase {
    func test_initialPhase_isTitle() {
        let scene = GoonGameScene.make()
        XCTAssertEqual(scene.phase, .title)
    }

    func test_startLevel_transitionsToPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        XCTAssertEqual(scene.phase, .playing)
        XCTAssertEqual(scene.levelNum, 1)
        XCTAssertEqual(scene.gas, 600)
    }

    func test_onGasOut_transitionsToGameOver() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.gas = 0
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .gameOver)
    }

    func test_onWinThreshold_transitionsToLevelComplete() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.cutPctOverride = 0.81 // simulate threshold met
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .levelComplete)
    }

    func test_winLevel5_transitionsToWin() {
        let scene = GoonGameScene.make()
        scene.startLevel(5)
        scene.cutPctOverride = 0.91
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .win)
    }

    func test_retryFromGameOver_restartsSameLevel() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        scene.gas = 0
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .gameOver)

        scene.retry()
        XCTAssertEqual(scene.phase, .playing)
        XCTAssertEqual(scene.levelNum, 3)
        XCTAssertEqual(scene.gas, 180)
    }
}

extension GoonGameStateTests {
    func test_savedLevel_defaultsTo1() {
        UserDefaults.standard.removeObject(forKey: "goon_level")
        XCTAssertEqual(GoonGameScene.savedLevel, 1)
    }

    func test_completingLevel_savesNextAsUnlocked() {
        UserDefaults.standard.removeObject(forKey: "goon_level")
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.cutPctOverride = 0.81
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .levelComplete)
        scene.nextLevel()
        XCTAssertEqual(GoonGameScene.savedLevel, 2)
    }

    func test_winningLevel5_setsWonFlag() {
        UserDefaults.standard.removeObject(forKey: "goon_won")
        let scene = GoonGameScene.make()
        scene.startLevel(5)
        scene.cutPctOverride = 0.91
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .win)
        XCTAssertTrue(GoonGameScene.hasWon)
    }

    func test_replayFromWin_resetsAllProgress() {
        UserDefaults.standard.set(5, forKey: "goon_level")
        UserDefaults.standard.set(true, forKey: "goon_won")
        let scene = GoonGameScene.make()
        scene.phaseForTesting = .win
        scene.replayFromWin()
        XCTAssertEqual(scene.phase, .title)
        XCTAssertEqual(GoonGameScene.savedLevel, 1)
        XCTAssertFalse(GoonGameScene.hasWon)
    }
}
