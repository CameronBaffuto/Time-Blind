//
//  GeocodingService.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import Foundation
import CoreLocation
import MapKit

@MainActor
final class GeocodingService {
    static let shared = GeocodingService()

    private init() {}

    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        guard let request = MKGeocodingRequest(addressString: address) else {
            throw GeocodingError.noResult
        }
        let items = try await request.mapItems
        if let location = items.first?.location {
            return location.coordinate
        }
        throw GeocodingError.noResult
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
