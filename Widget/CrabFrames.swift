//  灵动岛里会动的小螃蟹。做法来自 TangfanOVO/clawd-icons（MIT）：
//  一层一套「计时器字体」，Text(timerInterval:) 秒的个位走到几就显示第几帧。
//  CrabLayer2 / CrabState2 / CRAB_STATES_2 由打包时 tools/fonts.py 生成到 Widget/Generated/。

import SwiftUI

struct CrabFrames2: View {
    let st: CrabState2
    let since: Date
    let box: CGSize
    let lock: Bool
    var body: some View {
        let p = min(box.width / CGFloat(st.w), box.height / CGFloat(st.h))
        let w = CGFloat(st.w) * p, h = CGFloat(st.h) * p
        let layers = lock ? st.layers.filter { $0.phase == 0 && $0.kind != 2 } : st.layers
        ZStack(alignment: .bottomTrailing) {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, l in
                let start = since.addingTimeInterval(l.phase)
                Text(timerInterval: start...start.addingTimeInterval(8 * 3600), countsDown: false)
                    .font(.custom(l.font, fixedSize: p * 100))
                    .foregroundStyle(crabColor(l.color))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .frame(width: w * 6, height: h, alignment: .bottomTrailing)
            }
        }
        .frame(width: w, height: h, alignment: .bottomTrailing)
        .clipped()
    }
}

private func crabColor(_ rgb: UInt32) -> Color {
    Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
}

// 「在想你」没有自己的动画，先借「在看外面」那只：趴窗台听雨、等月亮
private let CRAB_ALIAS: [String: String] = ["在想你": "在看外面"]

struct CrabFace: View {
    let state: CrabAttributes.ContentState
    let box: CGSize
    var lock: Bool = false
    var body: some View {
        let key = CRAB_ALIAS[state.mood] ?? state.mood
        if let st = CRAB_STATES_2[key] {
            CrabFrames2(st: st, since: state.since, box: box, lock: lock)
        } else {
            ClawdView(height: box.height * 0.7)
        }
    }
}
