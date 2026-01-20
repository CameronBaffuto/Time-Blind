//
//  LiveActivityManager.swift
//  Time Blind
//
//  Created by Codex on 10/28/25.
//

import ActivityKit
import CoreLocation
import Foundation
import SwiftData

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var updateTask: Task<Void, Never>?
    private var activeActivity: Activity<TimeBlindTripAttributes>?
    private var activeDestinationID: PersistentIdentifier?
    private var activeTargetTime: Date?
    private var modelContainer: ModelContainer?

    private let windowHours: Double = 6
    private let idleInterval: TimeInterval = 900

    func startMonitoring(modelContainer: ModelContainer) {
        guard updateTask == nil else { return }
        self.modelContainer = modelContainer
        updateTask = Task { await monitoringLoop() }
    }

    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }

    func syncNow(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        Task { await sync() }
    }

    private func monitoringLoop() async {
        while !Task.isCancelled {
            await sync()
            let interval = updateInterval()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func updateInterval() -> TimeInterval {
        guard let targetTime = activeTargetTime else { return idleInterval }
        let remaining = targetTime.timeIntervalSince(Date())
        if remaining <= 300 { return 30 }
        if remaining <= 1800 { return 120 }
        return 600
    }

    private func sync() async {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let modelContainer else { return }
        let modelContext = ModelContext(modelContainer)

        let now = Date()
        let descriptor = FetchDescriptor<Destination>(predicate: #Predicate { destination in
            destination.targetArrivalTime != nil
        })

        let all = (try? modelContext.fetch(descriptor)) ?? []
        var didMutate = false
        var upcoming: [(Destination, Date)] = []

        for destination in all {
            guard let target = destination.targetArrivalTime else { continue }
            if !Calendar.current.isDateInToday(target) || target < now {
                destination.targetArrivalTime = nil
                didMutate = true
                continue
            }
            if target.timeIntervalSince(now) <= windowHours * 3600 {
                upcoming.append((destination, target))
            }
        }

        if didMutate {
            try? modelContext.save()
        }

        guard let next = upcoming.sorted(by: { $0.1 < $1.1 }).first else {
            activeTargetTime = nil
            await endActivity()
            return
        }

        let destination = next.0
        let targetTime = next.1
        guard let travelMinutes = await fetchTravelMinutes(for: destination, context: modelContext) else {
            return
        }

        let leaveBy = targetTime.addingTimeInterval(TimeInterval(-travelMinutes * 60))
        let contentState = TimeBlindTripAttributes.ContentState(
            leaveBy: leaveBy,
            targetTime: targetTime,
            travelMinutes: travelMinutes
        )

        if activeDestinationID != destination.id {
            await endActivity()
            let attributes = TimeBlindTripAttributes(
                destinationName: destination.name,
                destinationAddress: destination.address,
                groupName: destination.group?.name
            )
            do {
                let content = ActivityContent(state: contentState, staleDate: nil)
                activeActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                activeDestinationID = destination.id
                activeTargetTime = targetTime
            } catch {
                activeActivity = nil
                activeDestinationID = nil
                activeTargetTime = nil
            }
        } else {
            let content = ActivityContent(state: contentState, staleDate: nil)
            await activeActivity?.update(content)
            activeTargetTime = targetTime
        }
    }

    private func fetchTravelMinutes(for destination: Destination, context: ModelContext) async -> Int? {
        if let lat = destination.latitude, let lng = destination.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            do {
                let result = try await DestinationETAService.shared.calculateETA(to: coord)
                return result.travelMinutes
            } catch {
                return nil
            }
        }

        do {
            let coord = try await GeocodingService.shared.geocode(address: destination.address)
            destination.latitude = coord.latitude
            destination.longitude = coord.longitude
            try? context.save()
            let result = try await DestinationETAService.shared.calculateETA(to: coord)
            return result.travelMinutes
        } catch {
            return nil
        }
    }

    @available(iOS 16.1, *)
    private func endActivity() async {
        guard let activity = activeActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activeActivity = nil
        activeDestinationID = nil
    }
}
