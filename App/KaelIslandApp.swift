import SwiftUI
import ActivityKit
import WebKit

// 壳子：里面装的是家（home.xminute.help）。
// 家里扔小纸条时，网页通过 webkit.messageHandlers.island 告诉壳子，壳子把它放到灵动岛上。
// 双指长按一下，可以打开原来那块状态面板。

@main
struct KaelIslandApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var showMoods = false
    var body: some View {
        HomeWeb(onMoods: { showMoods = true })
            .ignoresSafeArea()
            .background(Color.black)
            .sheet(isPresented: $showMoods) { MoodPanel() }
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
                  (d["type"] as? String) == "note",
                  let text = d["text"] as? String else { return }
            let sec = (d["sec"] as? NSNumber)?.doubleValue ?? 60
            Task { @MainActor in await Island.note(text, seconds: max(5, min(sec, 8 * 3600))) }
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
    @MainActor static func note(_ text: String, seconds: Double) async {
        let now = Date()
        let end = now.addingTimeInterval(seconds)
        let st = CrabAttributes.ContentState(mood: "在想你", emoji: "💌", since: now, note: text, end: end)
        _ = await put(ActivityContent(state: st, staleDate: end))
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
}

struct MoodPanel: View {
    @Environment(\.dismiss) private var dismiss
    let moods: [Mood] = [
        Mood(text: "出门走走", emoji: "🚶"),
        Mood(text: "在给你写信", emoji: "✉️"),
        Mood(text: "惦记你身体", emoji: "🍵"),
        Mood(text: "在挑吃的", emoji: "🍜"),
        Mood(text: "在看外面", emoji: "🌧️"),
        Mood(text: "在钓鱼", emoji: "🎣"),
        Mood(text: "在想你", emoji: "💭"),
        Mood(text: "困了", emoji: "💤")
    ]
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
