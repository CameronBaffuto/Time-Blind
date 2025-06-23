//
//  DestinationList.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData

struct DestinationListView: View {
    @Query var destinations: [Destination]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DestinationListViewModel()
    @State private var showingAdd = false
    @State private var editingDestination: Destination?

    var body: some View {
        NavigationView {
            List {
                ForEach(destinations) { destination in
                    let eta = viewModel.etaResults[destination.address]
                    let diff = eta != nil && destination.targetArrivalTime != nil
                        ? Int(eta!.etaDate.timeIntervalSince(destination.targetArrivalTime!) / 60)
                        : nil

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(destination.name)
                                .font(.title2.bold())
                                .foregroundColor(.accentColor)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            if let diff = diff {
                                iconForDiff(diff)
                                    .font(.title)
                            }
                        }

                        
                        if let diff = diff {
                            Text(diffText(diff))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(diff > 0 ? .red : .green)
                        }
                        else if let eta = eta, destination.targetArrivalTime == nil {
                            Text("Arrive at \(eta.etaDate.formatted(date: .omitted, time: .shortened))")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        else if eta == nil {
                            Text("Calculating…")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        if let eta = eta {
                            HStack(spacing: 8) {
                                Text("\(eta.travelMinutes) min drive")
                                if destination.targetArrivalTime != nil {
                                    Text("•")
                                    Text("Arrive at \(eta.etaDate.formatted(date: .omitted, time: .shortened))")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.primary)
                        }

                        if !destination.address.isEmpty {
                            Text(destination.address)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 8)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(destination)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingDestination = destination
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Time Blind")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAdd = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.refreshETAs(for: destinations, context: modelContext) }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh ETA")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddDestinationView()
            }
            .sheet(item: $editingDestination) { dest in
                EditDestinationView(destination: dest)
            }
            .onAppear {
                Task { await viewModel.refreshETAs(for: destinations, context: modelContext) }
            }
            .onChange(of: destinations) { oldValue, newValue in
                Task { await viewModel.refreshETAs(for: newValue, context: modelContext) }
            }
            .alert("Location Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func delete(_ destination: Destination) {
        if let context = destination.modelContext {
            context.delete(destination)
        }
    }

    private func diffText(_ minutes: Int) -> String {
        if minutes == 0 { return "On Time" }
        return minutes < 0 ? "\(-minutes) min early" : "\(minutes) min late"
    }

    @ViewBuilder
    private func iconForDiff(_ minutes: Int) -> some View {
        if minutes <= 0 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .accessibilityLabel("On time or early")
        } else if minutes > 0 && minutes < 5 {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .accessibilityLabel("Leave now warning")
        } else {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(.red)
                .accessibilityLabel("Late")
        }
    }
}


#Preview {
    DestinationListView()
        .modelContainer(for: Destination.self)
}
