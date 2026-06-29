//
//  DestinationRowView.swift
//  Time Blind
//

import SwiftUI

struct DestinationRowView: View {
    let destination: Destination
    let eta: ETAResult?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing travel time")
                } else if let differenceInMinutes {
                    scheduleIcon(for: differenceInMinutes)
                        .font(.title2)
                }
            }

            statusContent

            if !destination.address.isEmpty {
                Label(destination.address, systemImage: "mappin")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var statusContent: some View {
        if let eta, eta.status == .available,
           let etaDate = eta.etaDate,
           let travelMinutes = eta.travelMinutes {
            VStack(alignment: .leading, spacing: 3) {
                if let differenceInMinutes {
                    Text(scheduleStatus(for: differenceInMinutes))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(differenceInMinutes > 0 ? .red : .green)
                } else {
                    Text("Arrive around \(etaDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .bold()
                }

                Label("\(travelMinutes) min drive", systemImage: "car.fill")
                if let leaveBy {
                    Label(
                        "Leave by \(leaveBy.formatted(date: .omitted, time: .shortened))",
                        systemImage: "clock"
                    )
                }
            }
            .font(.subheadline)
        } else if let eta, eta.status != .available {
            Label(failureMessage(for: eta.status), systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Label("Calculating travel time", systemImage: "location")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var differenceInMinutes: Int? {
        guard let etaDate = eta?.etaDate,
              let targetArrivalTime = destination.targetArrivalTime else {
            return nil
        }
        return Int(etaDate.timeIntervalSince(targetArrivalTime) / 60)
    }

    private var leaveBy: Date? {
        guard let targetArrivalTime = destination.targetArrivalTime,
              let travelMinutes = eta?.travelMinutes else {
            return nil
        }
        return targetArrivalTime.addingTimeInterval(TimeInterval(-travelMinutes * 60))
    }

    private func scheduleStatus(for minutes: Int) -> String {
        guard minutes != 0 else { return "On time" }

        let duration = Duration.seconds(abs(minutes) * 60)
        let formattedDuration = duration.formatted(
            .units(
                allowed: [.hours, .minutes],
                width: .abbreviated,
                maximumUnitCount: 2
            )
        )
        return minutes < 0 ? "\(formattedDuration) early" : "\(formattedDuration) late"
    }

    private func failureMessage(for status: ETAStatus) -> String {
        switch status {
        case .available:
            "Travel time available"
        case .geocodingFailed:
            "Address not found — swipe right to retry"
        case .routeFailed:
            "Route unavailable — swipe right to retry"
        }
    }

    @ViewBuilder
    private func scheduleIcon(for minutes: Int) -> some View {
        if minutes <= 0 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("On time or early")
        } else if minutes < 5 {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .accessibilityLabel("Almost late")
        } else {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Late")
        }
    }
}
