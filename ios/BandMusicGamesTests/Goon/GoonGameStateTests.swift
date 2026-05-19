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

extension GoonGameStateTests {
    func test_gasDrainsOverTimeWhenPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        scene.input.joystick = CGVector(dx: 1, dy: 0)
        let initial = scene.gas
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertLessThan(scene.gas, initial)
    }

    func test_gasDoesNotDrainWhileIdleWhenPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        let initial = scene.gas
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertEqual(scene.gas, initial)
    }

    func test_gasDoesNotDrainWhenNotPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.phaseForTesting = .title
        let initial = scene.gas
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertEqual(scene.gas, initial)
    }

    func test_idleMowerDoesNotCutGrass() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        let initialCutPercentage = scene.grid.cutPercentage
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertEqual(scene.grid.cutPercentage, initialCutPercentage, accuracy: 0.001)
        XCTAssertEqual(scene.score, 0)
    }
}

extension GoonGameStateTests {
    func test_startLevelPlacesConfiguredGasCans() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)

        XCTAssertEqual(scene.gasCans.count, 2)
        XCTAssertTrue(scene.gasCans.allSatisfy { !$0.collected })
        XCTAssertEqual(Set(scene.gasCans.map { "\($0.tileX),\($0.tileY)" }).count, 2)
        XCTAssertTrue(scene.gasCans.allSatisfy { scene.grid.at($0.tileX, $0.tileY) == .tall })
    }

    func test_collectingGasCanRefillsGasAndMarksItCollected() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        let can = scene.gasCans[0]
        scene.gas = 25
        scene.mower.position = can.position

        scene.tickGameLogic(deltaSeconds: 0.016)

        XCTAssertEqual(scene.gas, scene.config.gasMax)
        XCTAssertTrue(scene.gasCans[0].collected)
        XCTAssertEqual(scene.phase, .playing)
    }

    func test_startLevelPlacesConfiguredStumpsWithoutGasCanOverlap() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)

        let gasTiles = Set(scene.gasCans.map { "\($0.tileX),\($0.tileY)" })
        let stumpTiles = Set(scene.stumps.map { "\($0.tileX),\($0.tileY)" })

        XCTAssertEqual(scene.stumps.count, 2)
        XCTAssertEqual(stumpTiles.count, 2)
        XCTAssertTrue(scene.input.canDig)
        XCTAssertTrue(stumpTiles.isDisjoint(with: gasTiles))
        XCTAssertTrue(scene.stumps.allSatisfy { !$0.dug })
        XCTAssertTrue(scene.stumps.allSatisfy { scene.grid.at($0.tileX, $0.tileY) == .stump })
    }

    func test_stumpDoesNotDigWithoutDigInput() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        let stump = scene.stumps[0]
        scene.mower.position = stump.position

        scene.tickGameLogic(deltaSeconds: 3.0)

        XCTAssertFalse(scene.stumps[0].dug)
        XCTAssertEqual(scene.grid.at(stump.tileX, stump.tileY), .stump)
    }

    func test_diggingStumpRemovesBlockerAndCutsTile() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        let stump = scene.stumps[0]
        scene.mower.position = stump.position
        scene.input.digging = true

        scene.tickGameLogic(deltaSeconds: 3.0)

        XCTAssertTrue(scene.stumps[0].dug)
        XCTAssertEqual(scene.grid.at(stump.tileX, stump.tileY), .cut)
        XCTAssertEqual(scene.phase, .playing)
    }
}

extension GoonGameStateTests {
    func test_startLevelPlacesConfiguredCricketsWithoutItemOverlap() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)

        let gasTiles = Set(scene.gasCans.map { "\($0.tileX),\($0.tileY)" })
        let stumpTiles = Set(scene.stumps.map { "\($0.tileX),\($0.tileY)" })
        let cricketTiles = Set(scene.crickets.map { "\($0.tileX),\($0.tileY)" })

        XCTAssertEqual(scene.crickets.count, 2)
        XCTAssertEqual(cricketTiles.count, 2)
        XCTAssertTrue(cricketTiles.isDisjoint(with: gasTiles))
        XCTAssertTrue(cricketTiles.isDisjoint(with: stumpTiles))
        XCTAssertTrue(scene.crickets.allSatisfy { !$0.splatted })
        XCTAssertTrue(scene.crickets.allSatisfy { scene.grid.at($0.tileX, $0.tileY) == .tall })
    }

    func test_cricketCollisionSplatsAndDeductsGasOnce() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        let cricket = scene.crickets[0]
        let initialGas = scene.gas
        scene.mower.position = cricket.position

        scene.tickGameLogic(deltaSeconds: 0.016)

        XCTAssertTrue(scene.crickets[0].splatted)
        XCTAssertEqual(scene.gas, initialGas - 30)
        XCTAssertEqual(scene.phase, .playing)

        let gasAfterSplat = scene.gas
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.gas, gasAfterSplat)
    }

    func test_cricketsHopOnConfiguredInterval() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        scene.mower.position = safeCorner(in: scene)

        let before = scene.crickets.map { "\($0.tileX),\($0.tileY)" }
        scene.tickGameLogic(deltaSeconds: CGFloat(scene.config.cricketMs) / 1000 + 0.01)
        let after = scene.crickets.map { "\($0.tileX),\($0.tileY)" }

        XCTAssertNotEqual(before, after)
        XCTAssertTrue(scene.crickets.allSatisfy { !$0.splatted })
    }

    private func safeCorner(in scene: GoonGameScene) -> CGPoint {
        let corners = [
            CGPoint(x: 28, y: 28),
            CGPoint(x: scene.size.width - 28, y: 28),
            CGPoint(x: 28, y: scene.size.height - 28),
            CGPoint(x: scene.size.width - 28, y: scene.size.height - 28),
        ]

        return corners.max { lhs, rhs in
            minimumDistance(from: lhs, to: scene.crickets) < minimumDistance(from: rhs, to: scene.crickets)
        } ?? CGPoint(x: 28, y: 28)
    }

    private func minimumDistance(from point: CGPoint, to crickets: [GoonCricket]) -> CGFloat {
        crickets.map { cricket in
            let dx = point.x - cricket.position.x
            let dy = point.y - cricket.position.y
            return sqrt(dx * dx + dy * dy)
        }.min() ?? .greatestFiniteMagnitude
    }
}
