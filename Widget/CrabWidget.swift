import WidgetKit
import SwiftUI
import ActivityKit

@main
struct CrabBundle: WidgetBundle {
    var body: some Widget {
        CrabLiveActivity()
    }
}

struct CrabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CrabAttributes.self) { context in
            HStack(spacing: 12) {
                ClawdView(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.name).font(.headline)
                    Text("\(context.state.emoji) \(context.state.mood)").font(.subheadline)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.7))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ClawdView(height: 30)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.emoji).font(.title)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.name) · \(context.state.mood)")
                }
            } compactLeading: {
                ClawdView(height: 18)
            } compactTrailing: {
                Text(context.state.emoji)
            } minimal: {
                ClawdView(height: 16)
            }
        }
    }
}
