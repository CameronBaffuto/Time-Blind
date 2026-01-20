//
//  DestinationGroupListView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import SwiftUI
import SwiftData

struct DestinationGroupListView: View {
    @Query(sort: \DestinationGroup.orderIndex) var groups: [DestinationGroup]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddGroup = false
    @State private var editingGroup: DestinationGroup?

    var body: some View {
        NavigationView {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: DestinationListView(group: group)) {
                        HStack {
                            Text(group.name)
                                .font(.headline)
                            Spacer()
                            Text("\(group.destinations.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("\(group.destinations.count) destinations")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(group)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingGroup = group
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onMove(perform: moveGroups)
            }
            .navigationTitle("Time Blind")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddEditGroupView()
            }
            .sheet(item: $editingGroup) { group in
                AddEditGroupView(group: group)
            }
        }
        .onAppear {
            ensureUncategorizedGroupExists()
            assignExistingDestinationsToUncategorized()
            ensureGroupOrderInitialized()
        }
    }

    private func delete(_ group: DestinationGroup) {
        // Prevent deleting "Uncategorized"
        if group.name == "Uncategorized" { return }
        modelContext.delete(group)
    }

    private func ensureUncategorizedGroupExists() {
        if !groups.contains(where: { $0.name == "Uncategorized" }) {
            let maxIndex = groups.map(\.orderIndex).max() ?? -1
            let uncategorized = DestinationGroup(name: "Uncategorized", orderIndex: maxIndex + 1)
            modelContext.insert(uncategorized)
        }
    }
    
    private func assignExistingDestinationsToUncategorized() {
        guard let uncategorized = groups.first(where: { $0.name == "Uncategorized" }) else { return }
        let allDestinations = try? modelContext.fetch(FetchDescriptor<Destination>())
        allDestinations?.forEach { dest in
            if dest.group == nil {
                dest.group = uncategorized
            }
        }
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.orderIndex = index
        }
    }

    private func ensureGroupOrderInitialized() {
        guard !groups.isEmpty else { return }
        let indices = groups.map(\.orderIndex)
        if Set(indices).count != indices.count || groups.allSatisfy({ $0.orderIndex == 0 }) {
            let initialOrder = groups.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            for (index, group) in initialOrder.enumerated() {
                group.orderIndex = index
            }
        }
    }
}
