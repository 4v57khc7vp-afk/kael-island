import ActivityKit
import Foundation

struct CrabAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mood: String
        var emoji: String
        var since: Date
    }
    var name: String
}
