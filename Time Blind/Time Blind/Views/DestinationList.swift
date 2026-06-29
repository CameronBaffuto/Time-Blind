//
//  DestinationList.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftData
import SwiftUI

struct DestinationListView: View {
    @Query private var destinations: [Destination]
    @Environment(\.modelContext) private var modelContext
    @Environment(DestinationListViewModel.self) private var viewModel
    @State private var showingAdd = false
    @State private var editingDestination: Destination?

    let group: DestinationGroup

    init(group: DestinationGroup) {
        self.group = group
        let groupID = group.persistentModelID
        _destinations = Query(
            filter: #Predicate { destination in
                destination.group?.persistentModelID == groupID
            },
            sort: \Destination.orderIndex
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if destinations.isEmpty {
                ContentUnavailableView {
                    Label("No Places", systemImage: "mappin.and.ellipse")
                } description: {
                    Text("Add a place to see when you’ll arrive and when you need to leave.")
                } actions: {
                    Button("Add Place", systemImage: "plus", action: showAddDestination)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(destinations) { destination in
                        Button {
                            editingDestination = destination
                        } label: {
                            DestinationRowView(
                                destination: destination,
                                eta: viewModel.result(for: destination),
                                isLoading: viewModel.isLoading(destination)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this place for editing")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(destination)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                refresh(destination)
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove(perform: moveDestinations)
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !destinations.isEmpty {
                    EditButton()
                }
                Button("Add Place", systemImage: "plus", action: showAddDestination)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddDestinationView(initialGroup: group)
        }
        .sheet(item: $editingDestination, content: EditDestinationView.init)
        .refreshable {
            normalizeTargetArrivalTimes()
            await viewModel.refreshETAs(
                for: destinations,
                context: modelContext,
                force: true
            )
            LiveActivityManager.shared.syncNow(modelContainer: modelContext.container)
        }
        .task(id: refreshToken) {
            normalizeTargetArrivalTimes()
            ensureDestinationOrderInitialized()
            await viewModel.refreshETAs(for: destinations, context: modelContext)
            LiveActivityManager.shared.syncNow(modelContainer: modelContext.container)
        }
        .alert(item: $viewModel.presentedError) { error in
            Alert(
                title: Text("Unable to Refresh"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var refreshToken: [DestinationRefreshToken] {
        destinations.map {
            DestinationRefreshToken(
                id: $0.persistentModelID,
                address: $0.address
            )
        }
    }

    private func showAddDestination() {
        showingAdd = true
    }

    private func delete(_ destination: Destination) {
        viewModel.removeResult(for: destination)
        modelContext.delete(destination)
        saveChanges()
    }

    private func refresh(_ destination: Destination) {
        if let target = destination.targetArrivalTime,
           !Calendar.current.isDateInToday(target) {
            destination.targetArrivalTime = nil
        }

        Task {
            await viewModel.refreshETA(for: destination, context: modelContext)
            LiveActivityManager.shared.syncNow(modelContainer: modelContext.container)
        }
    }

    private func normalizeTargetArrivalTimes() {
        var didChange = false
        for destination in destinations {
            if let target = destination.targetArrivalTime,
               !Calendar.current.isDateInToday(target) {
                destination.targetArrivalTime = nil
                didChange = true
            }
        }
        if didChange {
            saveChanges()
        }
    }

    private func moveDestinations(from source: IndexSet, to destination: Int) {
        var reordered = destinations
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, destination) in reordered.enumerated() {
            destination.orderIndex = index
        }
        saveChanges()
    }

    private func ensureDestinationOrderInitialized() {
        guard !destinations.isEmpty else { return }
        let indices = destinations.map(\.orderIndex)
        guard Set(indices).count != indices.count || destinations.allSatisfy({ $0.orderIndex == 0 }) else {
            return
        }

        let initialOrder = destinations.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        for (index, destination) in initialOrder.enumerated() {
            destination.orderIndex = index
        }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            viewModel.presentedError = ETARefreshError(
                message: "Your changes could not be saved. \(error.localizedDescription)"
            )
        }
    }
}

private struct DestinationRefreshToken: Hashable {
    let id: PersistentIdentifier
    let address: String
}
