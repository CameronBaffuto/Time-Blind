//
//  EditDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData

struct EditDestinationView: View {
    @Query(sort: \DestinationGroup.name) var groups: [DestinationGroup]
    @State private var selectedGroup: DestinationGroup?
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var destination: Destination

    @State private var name: String
    @State private var address: String
    @State private var targetArrivalTime: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var addressChanged = false

    init(destination: Destination) {
        self.destination = destination
        _name = State(initialValue: destination.name)
        _address = State(initialValue: destination.address)
        _targetArrivalTime = State(initialValue: destination.targetArrivalTime)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                        .onChange(of: address) { oldValue, newValue in
                            addressChanged = (newValue != destination.address)
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
                            .disabled(name.isEmpty || address.isEmpty)
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
                destination.address = address
                destination.targetArrivalTime = targetArrivalTime
                destination.group = selectedGroup

                if addressChanged {
                    let coord = try await GeocodingService.shared.geocode(address: address)
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
