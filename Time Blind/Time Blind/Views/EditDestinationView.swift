//
//  EditDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData
import MapKit

struct EditDestinationView: View {
    @Query(sort: \DestinationGroup.orderIndex) var groups: [DestinationGroup]
    @State private var selectedGroup: DestinationGroup?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var destination: Destination
    private let originalGroupID: PersistentIdentifier?

    @State private var name: String
    @State private var targetArrivalTime: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @StateObject private var addressVM = AddressAutocompleteViewModel()
    @State private var addressChanged = false
    @State private var showAddressSearch = false

    init(destination: Destination) {
        self.destination = destination
        _name = State(initialValue: destination.name)
        _targetArrivalTime = State(initialValue: destination.targetArrivalTime)
        originalGroupID = destination.group?.id
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)

                    Button {
                        showAddressSearch = true
                    } label: {
                        HStack {
                            Text(addressVM.addressField.isEmpty ? "Tap to search address" : addressVM.addressField)
                                .foregroundColor(addressVM.addressField.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                        }
                    }

                    if let region = addressVM.mapRegion {
                        Map(position: .constant(.region(region))) {
                            if let coordinate = addressVM.selectedCoordinate ?? addressVM.mapRegion?.center {
                                Marker("Destination", coordinate: coordinate)
                            }
                        }
                        .frame(height: 180)
                        .cornerRadius(10)
                        .padding(.vertical, 4)
                    }

                    Picker("Group", selection: $selectedGroup) {
                        ForEach(groups) { group in
                            Text(group.name).tag(group as DestinationGroup?)
                        }
                    }

                    DatePicker(
                        "Target Arrival Time (optional)",
                        selection: Binding(
                            get: { targetArrivalTime ?? Date() },
                            set: { targetArrivalTime = $0 }
                        ),
                        displayedComponents: [.hourAndMinute, .date]
                    )
                    .labelsHidden()
                    .opacity(targetArrivalTime == nil ? 0.5 : 1)
                    Toggle("Set Target Arrival Time", isOn: Binding(
                        get: { targetArrivalTime != nil },
                        set: { newValue in targetArrivalTime = newValue ? Date() : nil }
                    ))
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Destination")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(name.isEmpty || addressVM.addressField.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showAddressSearch) {
                AddressSearchView(viewModel: addressVM)
            }
            .onAppear {
                addressVM.addressField = destination.address
                if let lat = destination.latitude, let lng = destination.longitude {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    addressVM.selectedCoordinate = coord
                    addressVM.mapRegion = MKCoordinateRegion(center: coord, latitudinalMeters: 1000, longitudinalMeters: 1000)
                } else {
                    addressVM.selectedCoordinate = nil
                    addressVM.mapRegion = nil
                }
                addressVM.showSuggestions = false
                if selectedGroup == nil {
                    selectedGroup = destination.group ?? groups.first(where: { $0.name == "Uncategorized" }) ?? groups.first
                }
            }
            .onChange(of: addressVM.addressField) {
                addressChanged = (addressVM.addressField != destination.address)
            }
        }
    }

    private func save() {
        Task {
            isSaving = true
            errorMessage = nil
            do {
                destination.name = name
                destination.address = addressVM.addressField
                destination.targetArrivalTime = targetArrivalTime
                destination.group = selectedGroup
                if selectedGroup?.id != originalGroupID {
                    destination.orderIndex = nextDestinationOrderIndex(for: selectedGroup)
                }

                if addressChanged {
                    let coord: CLLocationCoordinate2D
                    if let c = addressVM.selectedCoordinate {
                        coord = c
                    } else {
                        coord = try await GeocodingService.shared.geocode(address: addressVM.addressField)
                    }
                    destination.latitude = coord.latitude
                    destination.longitude = coord.longitude
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func nextDestinationOrderIndex(for group: DestinationGroup?) -> Int {
        let descriptor: FetchDescriptor<Destination>
        if let groupID = group?.id {
            descriptor = FetchDescriptor(predicate: #Predicate { destination in
                destination.group?.id == groupID
            })
        } else {
            descriptor = FetchDescriptor(predicate: #Predicate { destination in
                destination.group == nil
            })
        }
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let maxIndex = existing.map(\.orderIndex).max() ?? -1
        return maxIndex + 1
    }
}
