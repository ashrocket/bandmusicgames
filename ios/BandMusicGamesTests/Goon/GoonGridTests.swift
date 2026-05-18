import XCTest
@testable import BandMusicGames

final class GoonGridTests: XCTestCase {
    func test_grid_isCorrectSize() {
        let grid = GoonGrid.make(for: GoonLevels.all[0])
        XCTAssertEqual(GoonGrid.width, 25)
        XCTAssertEqual(GoonGrid.height, 15)
        XCTAssertEqual(grid.cells.count, 25 * 15)
    }

    func test_level1_hasHouseAndGarden() {
        let grid = GoonGrid.make(for: GoonLevels.all[0])
        let houseCount = grid.cells.filter { $0 == .house }.count
        let gardenCount = grid.cells.filter { $0 == .garden }.count
        XCTAssertGreaterThan(houseCount, 0, "Level 1 must have a house footprint")
        XCTAssertGreaterThan(gardenCount, 0, "Level 1 must have garden tiles")
    }

    func test_otherLevels_areAllTallGrass() {
        for i in 1...4 {
            let grid = GoonGrid.make(for: GoonLevels.all[i])
            let nonTall = grid.cells.filter { $0 != .tall }.count
            XCTAssertEqual(nonTall, 0, "Level \(i+1) starts as full tall grass")
        }
    }

    func test_cutPercentage_isZeroAtStart() {
        let grid = GoonGrid.make(for: GoonLevels.all[1])
        XCTAssertEqual(grid.cutPercentage, 0.0, accuracy: 0.001)
    }

    func test_cutPercentage_countsCutTilesAgainstMowable() {
        var grid = GoonGrid.make(for: GoonLevels.all[1])
        let mowable = grid.cells.filter { $0 == .tall }.count
        grid.cut(at: 0, 0)
        XCTAssertEqual(grid.cutPercentage, 1.0 / Double(mowable), accuracy: 0.001)
    }

    func test_cutPercentageCountsStumpsAsMowableUntilDug() {
        var grid = GoonGrid.make(for: GoonLevels.all[2])
        let mowable = grid.cells.filter { $0 == .tall }.count

        grid.set(4, 4, .stump)
        XCTAssertEqual(grid.cutPercentage, 0, accuracy: 0.001)

        grid.set(4, 4, .cut)
        XCTAssertEqual(grid.cutPercentage, 1.0 / Double(mowable), accuracy: 0.001)
    }
}

extension GoonGridTests {
    func test_mowerCutsTallTileBeneathIt() {
        var grid = GoonGrid.make(for: GoonLevels.all[1])
        XCTAssertEqual(grid.at(5, 5), .tall)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 5 * 32 + 16, y: 480 - (5 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 1)
        XCTAssertEqual(grid.at(5, 5), .cut)
    }

    func test_mowerDoesNotCutHouse() {
        var grid = GoonGrid.make(for: GoonLevels.all[0])
        // Level 1 row 2, col 20 is a house tile
        let before = grid.at(20, 2)
        XCTAssertEqual(before, .house)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 20 * 32 + 16, y: 480 - (2 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 0)
        XCTAssertEqual(grid.at(20, 2), .house)
    }

    func test_mowerCutsCellsAlreadyCutReturnsZero() {
        var grid = GoonGrid.make(for: GoonLevels.all[1])
        // Pre-cut the cell
        grid.set(5, 5, .cut)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 5 * 32 + 16, y: 480 - (5 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 0)
    }

    func test_mowerDoesNotCutStumpUntilDug() {
        var grid = GoonGrid.make(for: GoonLevels.all[2])
        grid.set(5, 5, .stump)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 5 * 32 + 16, y: 480 - (5 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 0)
        XCTAssertEqual(grid.at(5, 5), .stump)
    }
}
