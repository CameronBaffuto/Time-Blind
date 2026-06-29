//
//  AddDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import MapKit
import SwiftData
import SwiftUI

struct AddDestinationView: View {
    @Query(sort: \DestinationGroup.orderIndex) private var groups: [DestinationGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: DestinationGroup?
    @State private var name = ""
    @State private var targetArrivalTime = Date.now
    @State private var hasTargetArrivalTime = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @StateObject private var addressViewModel = AddressAutocompleteViewModel()
    @State private var showAddressSearch = false

    init(initialGroup: DestinationGroup? = nil) {
        _selectedGroup = State(initialValue: initialGroup)
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
            .navigationTitle("Add Place")
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
            let coordinate: CLLocationCoordinate2D
            if let selectedCoordinate = addressViewModel.selectedCoordinate {
                coordinate = selectedCoordinate
            } else {
                coordinate = try await GeocodingService.shared.geocode(address: addressViewModel.addressField)
            }

            let nextIndex = try DestinationOrdering.nextDestinationIndex(
                in: selectedGroup,
                context: modelContext
            )
            let destination = Destination(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                address: addressViewModel.addressField,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                targetArrivalTime: hasTargetArrivalTime ? targetArrivalTime : nil,
                orderIndex: nextIndex,
                group: selectedGroup
            )
            modelContext.insert(destination)

            do {
                try modelContext.save()
            } catch {
                modelContext.delete(destination)
                throw error
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
