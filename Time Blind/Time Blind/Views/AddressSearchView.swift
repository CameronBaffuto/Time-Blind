//
//  AddressSearchView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 7/14/25.
//

import SwiftUI
import MapKit

struct AddressSearchView: View {
    @ObservedObject var viewModel: AddressAutocompleteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                TextField("Search for address or place", text: $viewModel.addressField)
                    .onChange(of: viewModel.addressField) {
                        viewModel.updateQuery(viewModel.addressField)
                    }

                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    VStack(alignment: .leading) {
                        Text(suggestion.title)
                            .font(.headline)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectSuggestion(suggestion)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Address")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    if let location = try? await DestinationETAService.shared.getCurrentLocation() {
                        viewModel.setSearchRegion(using: location)
                    }
                }
            }
        }
    }
}

