import WidgetKit
import SwiftUI
import ActivityKit

@main
struct CrabBundle: WidgetBundle {
    var body: some Widget {
        CrabLiveActivity()
    }
}

struct NoteTimer: View {
    let state: CrabAttributes.ContentState
    let stale: Bool
    var body: some View {
        if let e = state.end, !stale, e > state.since {
            HStack(spacing: 4) {
                Text("被窝在等你")
                Text(timerInterval: state.since...e, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)
            }
        } else {
            Text("时间到啦，也算数")
        }
    }
}

// island-b②：网页喊来的 mood 过了 60 秒（isStale 且不是纸条）。这时岛上和锁屏都缩成最小：
// 只画 ClawdView 那只静态小螃蟹（十几个 Rectangle，画一次就完），不再画 CrabFace（每层一个 Text(timerInterval:)，系统要每秒换帧）。
// 纸条的 isStale 不走这里，照旧是“时间到啦，也算数”。
private func moodGone(_ c: ActivityViewContext<CrabAttributes>) -> Bool {
    c.isStale && c.state.note == nil
}

struct CrabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CrabAttributes.self) { context in
            Group {
                if moodGone(context) {
                    HStack(spacing: 8) {
                        ClawdView(height: 16)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                } else {
                    HStack(spacing: 12) {
                        CrabFace(state: context.state, box: CGSize(width: 60, height: 40), lock: true)
                        VStack(alignment: .leading, spacing: 2) {
                            if let n = context.state.note {
                                Text(n).font(.headline).lineLimit(2)
                                NoteTimer(state: context.state, stale: context.isStale).font(.subheadline)
                            } else {
                                Text(context.attributes.name).font(.headline)
                                Text("\(context.state.emoji) \(context.state.mood)").font(.subheadline)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
            .activityBackgroundTint(Color.black.opacity(0.7))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if moodGone(context) {
                        ClawdView(height: 20)
                    } else {
                        CrabFace(state: context.state, box: CGSize(width: 72, height: 48))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !moodGone(context) {
                        Text(context.state.emoji).font(.title)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let n = context.state.note {
                        VStack(spacing: 2) {
                            Text(n).lineLimit(2)
                            NoteTimer(state: context.state, stale: context.isStale)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if !moodGone(context) {
                        Text("\(context.attributes.name) · \(context.state.mood)")
                    }
                }
            } compactLeading: {
                if moodGone(context) {
                    ClawdView(height: 16)
                } else {
                    CrabFace(state: context.state, box: CGSize(width: 44, height: 30))
                }
            } compactTrailing: {
                if let e = context.state.end, !context.isStale, e > context.state.since {
                    Text(timerInterval: context.state.since...e, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 40)
                } else if !moodGone(context) {
                    Text(context.state.emoji)
                }
            } minimal: {
                ClawdView(height: 16)
            }
        }
    }
}
