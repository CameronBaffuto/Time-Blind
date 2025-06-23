//
//  GeocodingService.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import Foundation
import CoreLocation

@MainActor
final class GeocodingService {
    static let shared = GeocodingService()
    private let geocoder = CLGeocoder()

    private init() {}

    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let location = placemarks?.first?.location {
                    continuation.resume(returning: location.coordinate)
                } else {
                    continuation.resume(throwing: GeocodingError.noResult)
                }
            }
        }
    }

    enum GeocodingError: Error, LocalizedError {
        case noResult

        var errorDescription: String? {
            switch self {
            case .noResult: return "Could not find a location for that address."
            }
        }
    }
}

