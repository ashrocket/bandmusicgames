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
}
