//
//  AddressAutocompleteViewModel.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import Foundation
import MapKit

class AddressAutocompleteViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var addressField = ""
    @Published var showSuggestions = false
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var selectedCompletion: MKLocalSearchCompletion?
    @Published var mapRegion: MKCoordinateRegion?
    @Published var selectedCoordinate: CLLocationCoordinate2D?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func updateQuery(_ text: String) {
        showSuggestions = !text.isEmpty
        completer.queryFragment = text
    }

    func setSearchRegion(using location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        completer.region = region
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            if self.showSuggestions {
                self.suggestions = completer.results
            } else {
                self.suggestions = []
            }
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        let pickedAddress = suggestion.title + " " + suggestion.subtitle
        self.addressField = pickedAddress
        self.completer.queryFragment = pickedAddress
        self.showSuggestions = false
        self.suggestions = []
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        Task {
            let response = try? await search.start()
            if let item = response?.mapItems.first, let coordinate = item.placemark.coordinate as CLLocationCoordinate2D? {
                await MainActor.run {
                    self.selectedCoordinate = coordinate
                    self.mapRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                }
            }
        }
    }
}

