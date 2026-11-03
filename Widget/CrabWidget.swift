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

struct CrabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CrabAttributes.self) { context in
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
            .activityBackgroundTint(Color.black.opacity(0.7))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CrabFace(state: context.state, box: CGSize(width: 72, height: 48))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.emoji).font(.title)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let n = context.state.note {
                        VStack(spacing: 2) {
                            Text(n).lineLimit(2)
                            NoteTimer(state: context.state, stale: context.isStale)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("\(context.attributes.name) · \(context.state.mood)")
                    }
                }
            } compactLeading: {
                CrabFace(state: context.state, box: CGSize(width: 44, height: 30))
            } compactTrailing: {
                if let e = context.state.end, !context.isStale, e > context.state.since {
                    Text(timerInterval: context.state.since...e, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 40)
                } else {
                    Text(context.state.emoji)
                }
            } minimal: {
                ClawdView(height: 16)
            }
        }
    }
}
