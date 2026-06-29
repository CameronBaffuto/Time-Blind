//
//  DestinationGroupListView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import SwiftData
import SwiftUI

struct DestinationGroupListView: View {
    @Query(sort: \DestinationGroup.orderIndex) private var groups: [DestinationGroup]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddGroup = false
    @State private var editingGroup: DestinationGroup?

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Lists", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a list to organize the places you need to reach on time.")
                    } actions: {
                        Button("Create List", systemImage: "plus", action: showAddGroup)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(groups) { group in
                            NavigationLink(value: group) {
                                LabeledContent {
                                    Text(group.destinations.count, format: .number)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("\(group.destinations.count) destinations")
                                } label: {
                                    Label(group.name, systemImage: group.name == "Uncategorized" ? "tray" : "list.bullet")
                                        .font(.headline)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if group.name != "Uncategorized" {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        delete(group)
                                    }
                                    Button("Edit", systemImage: "square.and.pencil") {
                                        editingGroup = group
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .onMove(perform: moveGroups)
                    }
                }
            }
            .navigationTitle("Time Blind")
            .navigationDestination(for: DestinationGroup.self) { group in
                DestinationListView(group: group)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(.logo)
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !groups.isEmpty {
                        EditButton()
                    }
                    Button("Add List", systemImage: "plus", action: showAddGroup)
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddEditGroupView()
            }
            .sheet(item: $editingGroup, content: AddEditGroupView.init)
        }
        .task {
            prepareInitialData()
        }
    }

    private func showAddGroup() {
        showingAddGroup = true
    }

    private func delete(_ group: DestinationGroup) {
        guard group.name != "Uncategorized" else { return }
        let uncategorized = uncategorizedGroup()
        let startingIndex = uncategorized.destinations.map(\.orderIndex).max() ?? -1

        let destinationsToMove = group.destinations.sorted {
            $0.orderIndex < $1.orderIndex
        }
        for (offset, destination) in destinationsToMove.enumerated() {
            destination.group = uncategorized
            destination.orderIndex = startingIndex + offset + 1
        }

        modelContext.delete(group)
        saveChanges()
    }

    private func prepareInitialData() {
        let uncategorized = uncategorizedGroup()
        let descriptor = FetchDescriptor<Destination>(
            predicate: #Predicate { destination in
                destination.group == nil
            }
        )

        if let ungrouped = try? modelContext.fetch(descriptor) {
            let startingIndex = uncategorized.destinations.map(\.orderIndex).max() ?? -1
            for (offset, destination) in ungrouped.enumerated() {
                destination.group = uncategorized
                destination.orderIndex = startingIndex + offset + 1
            }
        }

        ensureGroupOrderInitialized(including: uncategorized)
        saveChanges()
    }

    private func uncategorizedGroup() -> DestinationGroup {
        if let existing = groups.first(where: { $0.name == "Uncategorized" }) {
            return existing
        }

        let nextIndex = (groups.map(\.orderIndex).max() ?? -1) + 1
        let group = DestinationGroup(name: "Uncategorized", orderIndex: nextIndex)
        modelContext.insert(group)
        return group
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.orderIndex = index
        }
        saveChanges()
    }

    private func ensureGroupOrderInitialized(including uncategorized: DestinationGroup) {
        var allGroups = groups
        if !allGroups.contains(where: { $0 === uncategorized }) {
            allGroups.append(uncategorized)
        }

        let indices = allGroups.map(\.orderIndex)
        guard Set(indices).count != indices.count || allGroups.allSatisfy({ $0.orderIndex == 0 }) else {
            return
        }

        for (index, group) in allGroups.sorted(by: groupNameSort).enumerated() {
            group.orderIndex = index
        }
    }

    private func groupNameSort(_ lhs: DestinationGroup, _ rhs: DestinationGroup) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save destination groups: \(error.localizedDescription)")
        }
    }
}
