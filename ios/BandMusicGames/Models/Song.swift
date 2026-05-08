import SwiftUI

struct Song: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let gameName: String
    let gameUrl: String
    let trackUri: String
    let hexColor: String
    let unlocked: Bool

    var color: Color { Color(hex: hexColor) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
}

extension Song {
    static let catalog: [Song] = [
        Song(
            id: "goon",
            title: "FOR CUTTING GRASS",
            artist: "GOON",
            gameName: "GRASS CUTTER 2003",
            gameUrl: "https://forcuttinggrass.goon.bandmusicgames.party",
            trackUri: "spotify:track:6EJAb3oTjDFwrt1dpIJPbr",
            hexColor: "#39ff14",
            unlocked: true
        ),
        Song(
            id: "fratty",
            title: "FRATTY PIPELINE",
            artist: "GROUCHO BARKS",
            gameName: "FRATTY PIPELINE",
            gameUrl: "https://frattypipeline.grouchobarks.bandmusicgames.party",
            trackUri: "spotify:track:33lVSu93J91BDmhfRT7iTA",
            hexColor: "#ff8c00",
            unlocked: true
        ),
        Song(
            id: "garden",
            title: "STAINED GRASS WINDOW",
            artist: "GROUCHO BARKS",
            gameName: "GARDEN",
            gameUrl: "https://garden.grouchobarks.bandmusicgames.party",
            trackUri: "spotify:track:5FjmryC7WxCnaeutu1XpRg",
            hexColor: "#a8e063",
            unlocked: true
        ),
        Song(
            id: "francis",
            title: "FRANCIS",
            artist: "DARGER",
            gameName: "FRANCIS",
            gameUrl: "https://francis.darger.bandmusicgames.party",
            trackUri: "spotify:track:64h0585a6LWXOdsCD2pOiW",
            hexColor: "#7b68ee",
            unlocked: true
        ),
        Song(
            id: "thai-lunch",
            title: "THAI LUNCH",
            artist: "VARIOUS",
            gameName: "THAI LUNCH",
            gameUrl: "https://thai-lunch.bandmusicgames.party",
            trackUri: "spotify:track:5F6r2aDjKbkaz1sNFcql5c",
            hexColor: "#ff4e50",
            unlocked: true
        ),
        Song(
            id: "pale",
            title: "PALE",
            artist: "???",
            gameName: "PALE",
            gameUrl: "https://pale.bandmusicgames.party",
            trackUri: "spotify:track:6lrQWiXw2IMtxKJd53PhJV",
            hexColor: "#c9d6df",
            unlocked: true
        ),
        Song(
            id: "rust-cards",
            title: "RUST CARDS",
            artist: "???",
            gameName: "RUST CARDS",
            gameUrl: "https://rust-cards.bandmusicgames.party",
            trackUri: "spotify:track:52y4KhkcAbYcogFg2u7UVP",
            hexColor: "#ce2f39",
            unlocked: true
        ),
        Song(
            id: "narasroom",
            title: "LIZZY MCGUIRE",
            artist: "NARA'S ROOM",
            gameName: "HALF COURT HERO",
            gameUrl: "https://lizzymcguire.narasroom.bandmusicgames.party",
            trackUri: "spotify:track:0000000000000000000001",
            hexColor: "#FF1493",
            unlocked: true
        ),
    ]
}

// MARK: - Color init from hex string

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8) / 255
        let b = Double(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
