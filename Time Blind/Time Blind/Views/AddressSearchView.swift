//
//  AddressSearchView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 7/14/25.
//

import MapKit
import SwiftUI

struct AddressSearchView: View {
    @ObservedObject var viewModel: AddressAutocompleteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isSelecting = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        select(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .disabled(isSelecting)
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Address or place"
            )
            .onChange(of: searchText) {
                viewModel.updateQuery(searchText)
            }
            .overlay {
                if viewModel.isSearching || isSelecting {
                    ProgressView(isSelecting ? "Selecting place…" : "Searching…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                } else if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search for a Place",
                        systemImage: "magnifyingglass",
                        description: Text("Enter an address, business, or landmark.")
                    )
                }
            }
            .navigationTitle("Select Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
            .task {
                viewModel.updateQuery("")
                if let location = try? await DestinationETAService.shared.getCurrentLocation() {
                    viewModel.setSearchRegion(using: location)
                }
            }
        }
    }

    private func select(_ suggestion: MKLocalSearchCompletion) {
        Task {
            isSelecting = true
            defer { isSelecting = false }
            if await viewModel.selectSuggestion(suggestion) {
                dismiss()
            }
        }
    }
}
