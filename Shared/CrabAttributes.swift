import ActivityKit
import Foundation

struct CrabAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mood: String
        var emoji: String
        var since: Date
        // 小纸条：有 note 时灵动岛显示这句话和到 end 的倒计时
        var note: String? = nil
        var end: Date? = nil
    }
    var name: String
}
