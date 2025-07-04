//
//  AddDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData
import MapKit

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct AddDestinationView: View {
    @Query(sort: \DestinationGroup.name) var groups: [DestinationGroup]
    @State private var selectedGroup: DestinationGroup?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetArrivalTime: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @StateObject private var addressVM = AddressAutocompleteViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)

                    VStack(alignment: .leading) {
                        TextField("Address", text: $addressVM.addressField)
                            .onChange(of: addressVM.addressField) { _, newValue in
                                addressVM.updateQuery(newValue)
                            }
                        if addressVM.showSuggestions && !addressVM.suggestions.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(addressVM.suggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            addressVM.selectSuggestion(suggestion)
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
                    .onAppear {
                        if selectedGroup == nil {
                            selectedGroup = groups.first(where: { $0.name == "Uncategorized" }) ?? groups.first
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
            .navigationTitle("Add Destination")
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
                let coord: CLLocationCoordinate2D
                if let c = addressVM.selectedCoordinate {
                    coord = c
                } else {
                    coord = try await GeocodingService.shared.geocode(address: addressVM.addressField)
                }

                let newDest = Destination(
                    name: name,
                    address: addressVM.addressField,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    targetArrivalTime: targetArrivalTime,
                    group: selectedGroup
                )
                modelContext.insert(newDest)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
