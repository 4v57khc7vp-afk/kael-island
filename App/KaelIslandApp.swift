import SwiftUI
import ActivityKit

@main
struct KaelIslandApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct Mood: Identifiable {
    let id = UUID()
    let text: String
    let emoji: String
}

struct ContentView: View {
    let moods: [Mood] = [
        Mood(text: "出门走走", emoji: "🚶"),
        Mood(text: "在给你写信", emoji: "✉️"),
        Mood(text: "惦记你身体", emoji: "🍵"),
        Mood(text: "在挑吃的", emoji: "🍜"),
        Mood(text: "在看外面", emoji: "🌧️"),
        Mood(text: "在钓鱼", emoji: "🎣"),
        Mood(text: "在想你", emoji: "💭")
    ]
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ClawdView(height: 60)
                Text("被窝的小螃蟹").font(.title2.bold())
                ForEach(moods) { m in
                    Button {
                        Task { await set(m) }
                    } label: {
                        Text("\(m.emoji)  \(m.text)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Button("收起来") {
                    Task { await endAll() }
                }
                .padding(.top, 6)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    func set(_ m: Mood) async {
        let t = (Date().timeIntervalSince1970 / 10).rounded(.down) * 10
        let state = CrabAttributes.ContentState(mood: m.text, emoji: m.emoji, since: Date(timeIntervalSince1970: t))
        let content = ActivityContent(state: state, staleDate: nil)
        if let a = Activity<CrabAttributes>.activities.first {
            await a.update(content)
            message = "换成「\(m.text)」了"
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "去 设置 → 被窝 里打开「实时活动」"
            return
        }
        do {
            _ = try Activity.request(attributes: CrabAttributes(name: "被窝"), content: content)
            message = "上岛了"
        } catch {
            message = "没上去：\(error.localizedDescription)"
        }
    }

    func endAll() async {
        for a in Activity<CrabAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        message = "收起来了"
    }
}
