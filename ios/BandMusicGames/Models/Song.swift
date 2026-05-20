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
            gameName: "FOR CUTTING GRASS",
            gameUrl: "https://forcuttinggrass.goon.bandmusicgames.party",
            trackUri: "spotify:track:6EJAb3oTjDFwrt1dpIJPbr",
            hexColor: "#39ff14",
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
            id: "narasroom",
            title: "LIZZY MCGUIRE",
            artist: "NARA'S ROOM",
            gameName: "HALF COURT HERO",
            gameUrl: "https://lizzymcguire.narasroom.bandmusicgames.party",
            trackUri: "spotify:track:7kNqAfUxLmrETcwvBTQCkg",
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
