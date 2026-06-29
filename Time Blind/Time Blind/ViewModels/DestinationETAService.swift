//
//  DestinationETAService.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import CoreLocation
import Foundation
import MapKit

@MainActor
final class DestinationETAService: NSObject {
    static let shared = DestinationETAService()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTask: Task<CLLocation, Error>?
    private var cachedLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
    }

    func getCurrentLocation() async throws -> CLLocation {
        if let cachedLocation,
           cachedLocation.timestamp.timeIntervalSinceNow > -60 {
            return cachedLocation
        }

        if let locationTask {
            return try await locationTask.value
        }

        let task = Task { @MainActor in
            try await requestCurrentLocation()
        }
        locationTask = task

        do {
            let location = try await task.value
            locationTask = nil
            return location
        } catch {
            locationTask = nil
            throw error
        }
    }

    func calculateETA(
        from source: CLLocation,
        to destination: CLLocationCoordinate2D
    ) async throws -> (etaDate: Date, travelMinutes: Int) {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: source, address: nil)
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        request.destination = MKMapItem(location: destinationLocation, address: nil)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        request.departureDate = .now

        let response = try await MKDirections(request: request).calculateETA()
        return (
            response.expectedArrivalDate,
            max(1, Int((response.expectedTravelTime / 60).rounded()))
        )
    }

    func calculateETA(
        to destination: CLLocationCoordinate2D
    ) async throws -> (etaDate: Date, travelMinutes: Int) {
        let source = try await getCurrentLocation()
        return try await calculateETA(from: source, to: destination)
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            continueLocationRequestIfAuthorized()
        }
    }

    private func continueLocationRequestIfAuthorized() {
        guard locationContinuation != nil else { return }

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finishLocationRequest(
                with: .failure(
                    NSError(
                        domain: kCLErrorDomain,
                        code: CLError.denied.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "Location access is required to calculate travel times."]
                    )
                )
            )
        @unknown default:
            finishLocationRequest(with: .failure(ETAError.locationUnavailable))
        }
    }

    private func finishLocationRequest(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }

    enum ETAError: Error, LocalizedError {
        case locationUnavailable

        var errorDescription: String? {
            "Your current location is unavailable. Try again in a moment."
        }
    }
}

extension DestinationETAService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continueLocationRequestIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finishLocationRequest(with: .failure(ETAError.locationUnavailable))
            return
        }
        cachedLocation = location
        finishLocationRequest(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishLocationRequest(with: .failure(error))
    }
}
