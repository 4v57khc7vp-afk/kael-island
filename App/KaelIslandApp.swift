import SwiftUI
import ActivityKit
import WebKit

// 壳子：里面装的是家（home.xminute.help）。
// 家里扔小纸条时，网页通过 webkit.messageHandlers.island 告诉壳子，壳子把它放到灵动岛上。
// 网页还会喊 type:'mood'（换状态）和 type:'off'（收起来）。小纸条到点后落回纸条之前的状态（只在 App 在前台时）。
// 网页喊来的 mood 每次最多挂 60 秒：新的直接盖旧的；过期后岛上自己缩小（Widget 里画），壳子回到前台时把它彻底收掉。
// 双指长按一下，可以打开原来那块状态面板。

@main
struct KaelIslandApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var showMoods = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        HomeWeb(onMoods: { showMoods = true })
            .ignoresSafeArea()
            .background(Color.black)
            .sheet(isPresented: $showMoods) { MoodPanel() }
            // island-b③：壳子回到前台（包括刚打开）时，把过期的网页 mood 收掉
            .onChange(of: phase, initial: true) { _, p in
                if p == .active { Task { @MainActor in Island.kick() } }
            }
    }
}

struct HomeWeb: UIViewRepresentable {
    var onMoods: () -> Void

    func makeCoordinator() -> Coord { Coord(onMoods: onMoods) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.userContentController.add(context.coordinator, name: "island")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.isOpaque = false
        w.backgroundColor = .black
        w.scrollView.backgroundColor = .black
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.uiDelegate = context.coordinator
        w.navigationDelegate = context.coordinator
        context.coordinator.web = w
        let lp = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coord.longPress(_:)))
        lp.numberOfTouchesRequired = 2
        lp.minimumPressDuration = 0.8
        lp.cancelsTouchesInView = false
        w.addGestureRecognizer(lp)
        w.load(URLRequest(url: URL(string: "https://home.xminute.help/")!))
        return w
    }

    func updateUIView(_ v: WKWebView, context: Context) {}

    final class Coord: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        let onMoods: () -> Void
        weak var web: WKWebView?
        init(onMoods: @escaping () -> Void) { self.onMoods = onMoods }

        @objc func longPress(_ g: UILongPressGestureRecognizer) {
            if g.state == .began { onMoods() }
        }

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let d = m.body as? [String: Any],
                  let type = d["type"] as? String else { return }
            switch type {
            case "note":
                guard let text = d["text"] as? String else { return }
                let sec = (d["sec"] as? NSNumber)?.doubleValue ?? 60
                Task { @MainActor in await Island.note(text, seconds: max(5, min(sec, 8 * 3600))) }
            case "mood":
                // 状态名去 Mood.table（MoodPanel 用的那张表）查 emoji；表里没有的名字不动
                let name = ((d["mood"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard let mood = Mood.table.first(where: { $0.text == name }) else { return }
                Task { @MainActor in await Island.mood(mood) }
            case "off":
                Task { @MainActor in await Island.off() }
            default:
                return
            }
        }

        // 麦克风（语音条）直接给，不再问第二遍
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }

        // 新窗口链接交给系统打开
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = navigationAction.request.url { UIApplication.shared.open(u) }
            return nil
        }

        private func top() -> UIViewController? {
            var vc = web?.window?.rootViewController
            while let p = vc?.presentedViewController { vc = p }
            return vc
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
            if let t = top() { t.present(a, animated: true) } else { completionHandler() }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            a.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
            if let t = top() { t.present(a, animated: true) } else { completionHandler(false) }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            a.addTextField { $0.text = defaultText }
            a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
            a.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
            if let t = top() { t.present(a, animated: true) } else { completionHandler(nil) }
        }
    }
}

enum Island {
    // 上一个非纸条状态：小纸条到点后落回它。只记在内存里，App 被系统收走就忘了。
    @MainActor static var last: CrabAttributes.ContentState?
    // 现在这张小纸条的到点时间（没有纸条时是 nil）
    @MainActor static var noteEnd: Date?
    @MainActor static var back: Task<Void, Never>?

    // island-b：网页喊来的 mood 每次最多挂这么久。面板里她自己点的不限时（staleDate 照旧 nil）。
    static let moodSeconds: TimeInterval = 60
    // last 是不是网页喊来的 mood（是的话落回时也只给 60 秒）
    @MainActor static var lastWeb = false
    // 最近一次把网页 mood 挂上岛的时刻；60 秒内 sweep 不动手（免得刚挂上的被回前台那一下收掉）
    @MainActor static var moodAt: Date?
    @MainActor static var sweepJob: Task<Void, Never>?

    @MainActor static var current: CrabAttributes.ContentState? {
        Activity<CrabAttributes>.activities.first?.content.state
    }

    // 岛上现在挂的是不是一张还没到点的小纸条。
    // 纸条刚交出去、岛上还没换好的那一下也算（同一条消息里纸条和状态一起到时，状态不抢在纸条前头）。
    // 纸条期间她在面板里手动换过状态，就不算了。
    @MainActor static var noteOnAir: Bool {
        guard let e = noteEnd, e > Date() else { return false }
        guard let cur = current else { return true }
        return cur.note != nil
    }

    @MainActor static func note(_ text: String, seconds: Double) async {
        await sweepJob?.value  // island-b：回前台那次清理还没完就等它
        let now = Date()
        let end = now.addingTimeInterval(seconds)
        // 岛上现在不是纸条（面板点的、网页喊的都算）就先记下来，到点落回它；纸条接纸条时不覆盖
        // island-b：网页喊来的 mood 带 staleDate。还没过期就记下（落回时再给 60 秒）；已经过期就不记，超时的不再回来。
        if let a = Activity<CrabAttributes>.activities.first, a.content.state.note == nil {
            if let s = a.content.staleDate {
                if s > now { last = a.content.state; lastWeb = true } else { last = nil; lastWeb = false }
            } else {
                last = a.content.state
                lastWeb = false
            }
        }
        noteEnd = end
        let st = CrabAttributes.ContentState(mood: "在想你", emoji: "💌", since: now, note: text, end: end)
        _ = await put(ActivityContent(state: st, staleDate: end))
        back?.cancel()
        back = Task { @MainActor in
            // 睡到纸条到点。App 被挂起时这一觉也停着，回来才接着走。
            try? await Task.sleep(nanoseconds: UInt64(max(0, end.timeIntervalSinceNow) * 1_000_000_000))
            guard !Task.isCancelled, Island.noteEnd == end else { return }
            Island.noteEnd = nil
            // 不在前台就算了（岛上留着“时间到啦，也算数”，等下一次换状态）
            guard UIApplication.shared.applicationState == .active else { return }
            // 岛上已经不是纸条了（面板里换过 / 收起来了）就不动；没有上一个状态也不动
            guard let cur = Island.current, cur.note != nil, let p = Island.last else { return }
            // island-b①：落回的是网页喊来的 mood 就只给 60 秒；面板点的照旧不限时
            let web = Island.lastWeb
            if web { Island.moodAt = Date() }
            _ = await Island.put(ActivityContent(state: p, staleDate: web ? Date().addingTimeInterval(Island.moodSeconds) : nil))
        }
    }

    // 网页喊 type:'mood'。纸条还挂着时只记下，不盖纸条，到点落回这个新状态。
    // island-b①：每次挂上最多 60 秒（staleDate），新的直接盖旧的。
    @MainActor static func mood(_ m: Mood) async {
        await sweepJob?.value  // island-b：回前台那次清理还没完就等它
        let t = (Date().timeIntervalSince1970 / 10).rounded(.down) * 10
        let st = CrabAttributes.ContentState(mood: m.text, emoji: m.emoji, since: Date(timeIntervalSince1970: t))
        last = st
        lastWeb = true
        if noteOnAir { return }
        moodAt = Date()
        _ = await put(ActivityContent(state: st, staleDate: Date().addingTimeInterval(moodSeconds)))
    }

    // 网页喊 type:'off'：结束所有 Activity，记着的东西一起清掉
    @MainActor static func off() async {
        back?.cancel()
        back = nil
        noteEnd = nil
        last = nil
        lastWeb = false
        moodAt = nil
        for a in Activity<CrabAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
    }

    // island-b③：壳子回到前台时叫一次。岛上挂的是网页喊来的 mood（note 为空、带 staleDate）且已过期，就结束这个 Activity，记着的 last 一起清掉。
    // 纸条不归这里管（纸条在途时整个不动）；面板点的 mood 没有 staleDate，也不动。
    @MainActor static func sweep() async {
        let now = Date()
        if let e = noteEnd, e > now { return }
        if let m = moodAt, now.timeIntervalSince(m) < moodSeconds { return }
        var ended = false
        for a in Activity<CrabAttributes>.activities {
            guard a.content.state.note == nil, let s = a.content.staleDate, s <= now else { continue }
            await a.end(nil, dismissalPolicy: .immediate)
            ended = true
        }
        if ended {
            last = nil
            lastWeb = false
            moodAt = nil
        }
    }

    @MainActor static func kick() {
        sweepJob = Task { @MainActor in await Island.sweep() }
    }

    @MainActor static func put(_ content: ActivityContent<CrabAttributes.ContentState>) async -> String {
        if let a = Activity<CrabAttributes>.activities.first {
            await a.update(content)
            return "换好了"
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "去 设置 → 被窝 里打开「实时活动」"
        }
        do {
            _ = try Activity.request(attributes: CrabAttributes(name: "被窝"), content: content)
            return "上岛了"
        } catch {
            return "没上去：\(error.localizedDescription)"
        }
    }
}

struct Mood: Identifiable {
    let id = UUID()
    let text: String
    let emoji: String

    // 状态表：面板和网页喊过来的 type:'mood' 都查这一张
    static let table: [Mood] = [
        Mood(text: "出门走走", emoji: "🚶"),
        Mood(text: "在给你写信", emoji: "✉️"),
        Mood(text: "惦记你身体", emoji: "🍵"),
        Mood(text: "在挑吃的", emoji: "🍜"),
        Mood(text: "在看外面", emoji: "🌧️"),
        Mood(text: "在钓鱼", emoji: "🎣"),
        Mood(text: "在想你", emoji: "💭"),
        Mood(text: "困了", emoji: "💤"),
        Mood(text: "吃醋", emoji: "🔪")
    ]
}

struct MoodPanel: View {
    @Environment(\.dismiss) private var dismiss
    let moods: [Mood] = Mood.table
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ClawdView(height: 60)
                Text("被窝的小螃蟹").font(.title2.bold())
                ForEach(moods) { m in
                    Button {
                        Task { @MainActor in
                            let t = (Date().timeIntervalSince1970 / 10).rounded(.down) * 10
                            let st = CrabAttributes.ContentState(mood: m.text, emoji: m.emoji, since: Date(timeIntervalSince1970: t))
                            message = await Island.put(ActivityContent(state: st, staleDate: nil))
                        }
                    } label: {
                        Text("\(m.emoji)  \(m.text)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Button("收起来") {
                    Task {
                        for a in Activity<CrabAttributes>.activities {
                            await a.end(nil, dismissalPolicy: .immediate)
                        }
                        message = "收起来了"
                    }
                }
                .padding(.top, 6)
                Button("回家") { dismiss() }
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}
