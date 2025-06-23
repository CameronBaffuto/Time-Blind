//
//  AddDestinationView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct AddDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var targetArrivalTime: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
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
                let coord = try await GeocodingService.shared.geocode(address: address)
                let newDest = Destination(
                    name: name,
                    address: address,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    targetArrivalTime: targetArrivalTime
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

