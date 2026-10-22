import ActivityKit

struct CrabAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mood: String
        var emoji: String
    }
    var name: String
}
