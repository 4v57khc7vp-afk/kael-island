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
                Text("🦀").font(.largeTitle)
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
                    Text("🦀").font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.emoji).font(.title)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.name) · \(context.state.mood)")
                }
            } compactLeading: {
                Text("🦀")
            } compactTrailing: {
                Text(context.state.emoji)
            } minimal: {
                Text("🦀")
            }
        }
    }
}
