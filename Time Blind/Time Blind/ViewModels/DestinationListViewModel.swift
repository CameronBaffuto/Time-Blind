//
//  DestinationListViewModel.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import CoreLocation
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DestinationListViewModel {
    private(set) var etaResults: [PersistentIdentifier: ETAResult] = [:]
    private(set) var loadingDestinationIDs: Set<PersistentIdentifier> = []
    private(set) var isRefreshing = false
    var presentedError: ETARefreshError?

    private var refreshCount = 0
    private let cacheLifetime: TimeInterval = 5 * 60
    private let maximumConcurrentRoutes = 3

    func result(for destination: Destination) -> ETAResult? {
        etaResults[destination.persistentModelID]
    }

    func isLoading(_ destination: Destination) -> Bool {
        loadingDestinationIDs.contains(destination.persistentModelID)
    }

    func refreshETAs(
        for destinations: [Destination],
        context: ModelContext,
        force: Bool = false
    ) async {
        let destinationsToRefresh = destinations.filter { destination in
            let id = destination.persistentModelID
            guard !loadingDestinationIDs.contains(id) else { return false }
            guard !force, let cached = etaResults[id] else { return true }
            return !cached.matches(destination) || cached.updatedAt.timeIntervalSinceNow < -cacheLifetime
        }

        guard !destinationsToRefresh.isEmpty else { return }

        let refreshingIDs = Set(destinationsToRefresh.map(\.persistentModelID))
        loadingDestinationIDs.formUnion(refreshingIDs)
        beginRefresh()
        defer {
            loadingDestinationIDs.subtract(refreshingIDs)
            endRefresh()
        }

        let source: CLLocation
        do {
            source = try await DestinationETAService.shared.getCurrentLocation()
        } catch {
            presentedError = ETARefreshError(message: error.localizedDescription)
            return
        }

        var routeRequests: [RouteRequest] = []
        var updatedCoordinates = false

        for destination in destinationsToRefresh {
            guard !Task.isCancelled else { return }

            let coordinate: CLLocationCoordinate2D
            if let latitude = destination.latitude,
               let longitude = destination.longitude {
                coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            } else {
                do {
                    coordinate = try await GeocodingService.shared.geocode(address: destination.address)
                    destination.latitude = coordinate.latitude
                    destination.longitude = coordinate.longitude
                    destination.lastGeocoded = .now
                    updatedCoordinates = true
                } catch {
                    etaResults[destination.persistentModelID] = ETAResult(
                        destination: destination,
                        status: .geocodingFailed
                    )
                    continue
                }
            }

            routeRequests.append(
                RouteRequest(
                    id: destination.persistentModelID,
                    address: destination.address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }

        if updatedCoordinates {
            do {
                try context.save()
            } catch {
                presentedError = ETARefreshError(message: "Updated locations could not be saved. \(error.localizedDescription)")
            }
        }

        for batchStart in stride(from: 0, to: routeRequests.count, by: maximumConcurrentRoutes) {
            guard !Task.isCancelled else { return }
            let batchEnd = min(batchStart + maximumConcurrentRoutes, routeRequests.count)
            let batch = routeRequests[batchStart..<batchEnd]
            let tasks = batch.map { request in
                Task { @MainActor in
                    await calculateRoute(request, from: source)
                }
            }

            for task in tasks {
                guard !Task.isCancelled else {
                    tasks.forEach { $0.cancel() }
                    return
                }
                let response = await task.value
                etaResults[response.id] = response.result
            }
        }
    }

    func refreshETA(for destination: Destination, context: ModelContext) async {
        await refreshETAs(for: [destination], context: context, force: true)
    }

    func removeResult(for destination: Destination) {
        etaResults[destination.persistentModelID] = nil
        loadingDestinationIDs.remove(destination.persistentModelID)
    }

    private func calculateRoute(_ request: RouteRequest, from source: CLLocation) async -> RouteResponse {
        do {
            let coordinate = CLLocationCoordinate2D(
                latitude: request.latitude,
                longitude: request.longitude
            )
            let route = try await DestinationETAService.shared.calculateETA(
                from: source,
                to: coordinate
            )
            return RouteResponse(
                id: request.id,
                result: ETAResult(
                    address: request.address,
                    latitude: request.latitude,
                    longitude: request.longitude,
                    etaDate: route.etaDate,
                    travelMinutes: route.travelMinutes,
                    status: .available
                )
            )
        } catch {
            return RouteResponse(
                id: request.id,
                result: ETAResult(
                    address: request.address,
                    latitude: request.latitude,
                    longitude: request.longitude,
                    status: .routeFailed
                )
            )
        }
    }

    private func beginRefresh() {
        refreshCount += 1
        isRefreshing = true
    }

    private func endRefresh() {
        refreshCount = max(0, refreshCount - 1)
        isRefreshing = refreshCount > 0
    }
}

struct ETAResult: Sendable {
    let address: String
    let latitude: Double?
    let longitude: Double?
    let etaDate: Date?
    let travelMinutes: Int?
    let status: ETAStatus
    let updatedAt: Date

    init(
        address: String,
        latitude: Double?,
        longitude: Double?,
        etaDate: Date? = nil,
        travelMinutes: Int? = nil,
        status: ETAStatus,
        updatedAt: Date = .now
    ) {
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.etaDate = etaDate
        self.travelMinutes = travelMinutes
        self.status = status
        self.updatedAt = updatedAt
    }

    init(destination: Destination, status: ETAStatus) {
        self.init(
            address: destination.address,
            latitude: destination.latitude,
            longitude: destination.longitude,
            status: status
        )
    }

    func matches(_ destination: Destination) -> Bool {
        address == destination.address
            && latitude == destination.latitude
            && longitude == destination.longitude
    }
}

enum ETAStatus: Sendable {
    case available
    case geocodingFailed
    case routeFailed
}

struct ETARefreshError: Identifiable {
    let id = UUID()
    let message: String
}

private struct RouteRequest {
    let id: PersistentIdentifier
    let address: String
    let latitude: Double
    let longitude: Double
}

private struct RouteResponse {
    let id: PersistentIdentifier
    let result: ETAResult
}
