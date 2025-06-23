//
//  DestinationListViewModel.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import Foundation
import SwiftData
import CoreLocation
import Combine


import Foundation
import SwiftData
import CoreLocation
import Combine

@MainActor
final class DestinationListViewModel: ObservableObject {
    @Published var etaResults: [String: ETAResult] = [:]
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    struct ETAResult {
        let etaDate: Date
        let travelMinutes: Int
        let status: ETAStatus
    }
    enum ETAStatus { case ok, geocodingFailed, etaFailed }

    func refreshETAs(for destinations: [Destination], context: ModelContext) async {
        isRefreshing = true
        defer { isRefreshing = false }

        etaResults = [:]
        errorMessage = nil

        let locationService = DestinationETAService.shared

        for destination in destinations {
            // Only process destinations with coordinates
            guard let lat = destination.latitude, let lng = destination.longitude else {
                // Try to geocode if not already present
                do {
                    let coord = try await GeocodingService.shared.geocode(address: destination.address)
                    destination.latitude = coord.latitude
                    destination.longitude = coord.longitude
                    try? context.save() // Save to persistent store
                    // Now we have coords, proceed with ETA calculation
                    try await Task.sleep(nanoseconds: 200_000_000) // Prevent rate-limiting
                    let result = try await locationService.calculateETA(to: coord)
                    etaResults[destination.address] = ETAResult(etaDate: result.etaDate, travelMinutes: result.travelMinutes, status: .ok)
                } catch {
                    etaResults[destination.address] = ETAResult(etaDate: Date(), travelMinutes: 0, status: .geocodingFailed)
                }
                continue
            }

            let destCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            do {
                let result = try await locationService.calculateETA(to: destCoord)
                etaResults[destination.address] = ETAResult(etaDate: result.etaDate, travelMinutes: result.travelMinutes, status: .ok)
                try await Task.sleep(nanoseconds: 200_000_000) // Prevent overloading MapKit
            } catch {
                etaResults[destination.address] = ETAResult(etaDate: Date(), travelMinutes: 0, status: .etaFailed)
            }
        }
    }

}

