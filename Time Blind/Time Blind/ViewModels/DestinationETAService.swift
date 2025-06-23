//
//  DestinationETAService.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import Foundation
import MapKit
import CoreLocation

final class DestinationETAService: NSObject, ObservableObject {
    static let shared = DestinationETAService()
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        locationManager.delegate = self
    }

    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        }
    }

    func calculateETA(to destination: CLLocationCoordinate2D) async throws -> (etaDate: Date, travelMinutes: Int) {
        let userLocation = try await getCurrentLocation()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        request.departureDate = Date()

        let directions = MKDirections(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            directions.calculateETA { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let response = response {
                    let etaDate = response.expectedArrivalDate
                    let travelMinutes = Int(response.expectedTravelTime / 60)
                    continuation.resume(returning: (etaDate, travelMinutes))
                } else {
                    continuation.resume(throwing: ETAError.noResult)
                }
            }
        }
    }

    enum ETAError: Error, LocalizedError {
        case noResult
        var errorDescription: String? {
            "Could not calculate ETA for this destination."
        }
    }
}

extension DestinationETAService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let continuation = locationContinuation, let location = locations.first {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }
}

