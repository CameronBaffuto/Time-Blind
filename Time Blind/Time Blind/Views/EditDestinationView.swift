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
    @Query(sort: \DestinationGroup.name) var groups: [DestinationGroup]
    @State private var selectedGroup: DestinationGroup?

    @Environment(\.dismiss) private var dismiss
    @Bindable var destination: Destination

    @State private var name: String
    @State private var targetArrivalTime: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @StateObject private var addressVM = AddressAutocompleteViewModel()
    @State private var addressChanged = false

    init(destination: Destination) {
        self.destination = destination
        _name = State(initialValue: destination.name)
        _targetArrivalTime = State(initialValue: destination.targetArrivalTime)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)

                    VStack(alignment: .leading) {
                        TextField("Address", text: $addressVM.addressField)
                            .onChange(of: addressVM.addressField) { _, newValue in
                                addressVM.showSuggestions = (!newValue.isEmpty && newValue != destination.address)
                                addressVM.updateQuery(newValue)
                                addressChanged = (newValue != destination.address)
                            }
                        if addressVM.showSuggestions && !addressVM.suggestions.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(addressVM.suggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            addressVM.selectSuggestion(suggestion)
                                            addressChanged = (addressVM.addressField != destination.address)
                                        }) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(suggestion.title)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                if !suggestion.subtitle.isEmpty {
                                                    Text(suggestion.subtitle)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemBackground))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .contentShape(Rectangle())
                                        Divider()
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                            }
                            .frame(maxHeight: 200)
                            .padding(.vertical, 4)
                            .padding(.horizontal, -16)
                        }
                    }
                    .padding(.vertical, 2)
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

                    if let region = addressVM.mapRegion {
                        Map(
                            position: .constant(.region(region))
                        ) {
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
}

