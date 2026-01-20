//
//  TimeBlindWidgets.swift
//  TimeBlindWidgets
//
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TimeBlindWidgets: WidgetBundle {
    var body: some Widget {
        TimeBlindLiveActivity()
    }
}

struct TimeBlindLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeBlindTripAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bird.fill")
                        .frame(width: 22, height: 22)
                    Text(context.attributes.destinationName)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                Text("Leave by \(context.state.leaveBy.formatted(date: .omitted, time: .shortened))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("Leave in")
                        .foregroundColor(.secondary)
                    Text(context.state.leaveBy, style: .timer)
                        .monospacedDigit()
                }
                .font(.caption)
                Text("\(context.state.travelMinutes) min drive")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.1))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bird.fill")
                        .renderingMode(.template)
                        .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.destinationName)
                        .font(.caption)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.leaveBy, style: .timer)
                        .monospacedDigit()
                }

            } compactLeading: {
                HStack(spacing: 6) {
                    Image(systemName: "bird.fill")
                        .renderingMode(.template)
                        .foregroundStyle(.green)

                    Text(context.attributes.destinationName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

            } compactTrailing: {
                Text(context.state.leaveBy, style: .timer)
                    .monospacedDigit()
                    .lineLimit(1)

            } minimal: {
                Image(systemName: "bird.fill")
                    .renderingMode(.template)
                    .foregroundStyle(.green)
            }
        }
    }
}
