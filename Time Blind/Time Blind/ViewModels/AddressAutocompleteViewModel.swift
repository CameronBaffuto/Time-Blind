//
//  AddressAutocompleteViewModel.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import Combine
import CoreLocation
import Foundation
@preconcurrency import MapKit

@MainActor
final class AddressAutocompleteViewModel: NSObject, ObservableObject {
    @Published var addressField = ""
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    @Published var mapRegion: MKCoordinateRegion?
    @Published var selectedCoordinate: CLLocationCoordinate2D?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func updateQuery(_ text: String) {
        errorMessage = nil
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            completer.queryFragment = ""
            suggestions = []
            isSearching = false
            return
        }

        isSearching = true
        completer.queryFragment = query
    }

    func setSearchRegion(using location: CLLocation) {
        completer.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async -> Bool {
        let pickedAddress = [suggestion.title, suggestion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        addressField = pickedAddress
        suggestions = []
        isSearching = false
        selectedCoordinate = nil
        mapRegion = nil
        errorMessage = nil

        do {
            let request = MKLocalSearch.Request(completion: suggestion)
            let response = try await MKLocalSearch(request: request).start()
            guard let coordinate = response.mapItems.first?.location.coordinate else {
                throw GeocodingService.GeocodingError.noResult
            }
            selectedCoordinate = coordinate
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1_000,
                longitudinalMeters: 1_000
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

extension AddressAutocompleteViewModel: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        isSearching = false
        errorMessage = error.localizedDescription
    }
}
