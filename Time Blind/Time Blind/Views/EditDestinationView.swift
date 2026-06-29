//
//  EditDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import MapKit
import SwiftData
import SwiftUI

struct EditDestinationView: View {
    @Query(sort: \DestinationGroup.orderIndex) private var groups: [DestinationGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let destination: Destination
    private let originalGroupID: PersistentIdentifier?

    @State private var selectedGroup: DestinationGroup?
    @State private var name: String
    @State private var targetArrivalTime: Date
    @State private var hasTargetArrivalTime: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @StateObject private var addressViewModel: AddressAutocompleteViewModel
    @State private var showAddressSearch = false

    init(destination: Destination) {
        self.destination = destination
        originalGroupID = destination.group?.persistentModelID
        _selectedGroup = State(initialValue: destination.group)
        _name = State(initialValue: destination.name)
        _targetArrivalTime = State(initialValue: destination.targetArrivalTime ?? .now)
        _hasTargetArrivalTime = State(initialValue: destination.targetArrivalTime != nil)

        let addressViewModel = AddressAutocompleteViewModel()
        addressViewModel.addressField = destination.address
        if let latitude = destination.latitude,
           let longitude = destination.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            addressViewModel.selectedCoordinate = coordinate
            addressViewModel.mapRegion = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1_000,
                longitudinalMeters: 1_000
            )
        }
        _addressViewModel = StateObject(wrappedValue: addressViewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Place name", text: $name)
                        .textInputAutocapitalization(.words)

                    Button(action: showAddressPicker) {
                        LabeledContent {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        } label: {
                            Label {
                                Text(addressViewModel.addressField.isEmpty ? "Search for an address" : addressViewModel.addressField)
                                    .foregroundStyle(addressViewModel.addressField.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                            } icon: {
                                Image(systemName: "mappin.and.ellipse")
                            }
                        }
                    }

                    if let region = addressViewModel.mapRegion {
                        Map(position: .constant(.region(region))) {
                            if let coordinate = addressViewModel.selectedCoordinate ?? addressViewModel.mapRegion?.center {
                                Marker("Destination", coordinate: coordinate)
                            }
                        }
                        .frame(minHeight: 180)
                        .clipShape(.rect(cornerRadius: 12))
                        .accessibilityLabel("Map showing the selected destination")
                    }

                    Picker("List", selection: $selectedGroup) {
                        ForEach(groups) { group in
                            Text(group.name).tag(group as DestinationGroup?)
                        }
                    }
                }

                Section("Arrival") {
                    Toggle("Set an arrival time", isOn: $hasTargetArrivalTime)
                    if hasTargetArrivalTime {
                        DatePicker(
                            "Arrive by",
                            selection: $targetArrivalTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .accessibilityLabel("Saving place")
                    } else {
                        Button("Save", action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showAddressSearch) {
                AddressSearchView(viewModel: addressViewModel)
            }
            .task {
                if selectedGroup == nil {
                    selectedGroup = groups.first(where: { $0.name == "Uncategorized" }) ?? groups.first
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !addressViewModel.addressField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedGroup != nil
    }

    private var addressChanged: Bool {
        addressViewModel.addressField != destination.address
    }

    private func showAddressPicker() {
        showAddressSearch = true
    }

    private func save() {
        Task {
            await saveDestination()
        }
    }

    private func saveDestination() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            var updatedCoordinate: CLLocationCoordinate2D?
            if addressChanged {
                if let selectedCoordinate = addressViewModel.selectedCoordinate {
                    updatedCoordinate = selectedCoordinate
                } else {
                    updatedCoordinate = try await GeocodingService.shared.geocode(address: addressViewModel.addressField)
                }
            }

            let updatedOrderIndex: Int
            if selectedGroup?.persistentModelID != originalGroupID {
                updatedOrderIndex = try DestinationOrdering.nextDestinationIndex(
                    in: selectedGroup,
                    context: modelContext
                )
            } else {
                updatedOrderIndex = destination.orderIndex
            }

            let original = OriginalDestinationValues(destination: destination)
            destination.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            destination.address = addressViewModel.addressField
            destination.targetArrivalTime = hasTargetArrivalTime ? targetArrivalTime : nil
            destination.group = selectedGroup
            destination.orderIndex = updatedOrderIndex
            if let updatedCoordinate {
                destination.latitude = updatedCoordinate.latitude
                destination.longitude = updatedCoordinate.longitude
                destination.lastGeocoded = .now
            }

            do {
                try modelContext.save()
            } catch {
                original.restore(destination)
                throw error
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OriginalDestinationValues {
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let targetArrivalTime: Date?
    let lastGeocoded: Date?
    let orderIndex: Int
    let group: DestinationGroup?

    init(destination: Destination) {
        name = destination.name
        address = destination.address
        latitude = destination.latitude
        longitude = destination.longitude
        targetArrivalTime = destination.targetArrivalTime
        lastGeocoded = destination.lastGeocoded
        orderIndex = destination.orderIndex
        group = destination.group
    }

    func restore(_ destination: Destination) {
        destination.name = name
        destination.address = address
        destination.latitude = latitude
        destination.longitude = longitude
        destination.targetArrivalTime = targetArrivalTime
        destination.lastGeocoded = lastGeocoded
        destination.orderIndex = orderIndex
        destination.group = group
    }
}
