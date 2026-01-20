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
    
    var group: DestinationGroup
    
    init(group: DestinationGroup) {
        self.group = group
        let groupID = group.id
        _destinations = Query(filter: #Predicate { destination in
            destination.group?.id == groupID
        }, sort: \Destination.orderIndex)
    }
    
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
                    let leaveBy = eta != nil && destination.targetArrivalTime != nil
                        ? destination.targetArrivalTime!.addingTimeInterval(TimeInterval(-eta!.travelMinutes * 60))
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(eta.travelMinutes) min drive")
                                    if let leaveBy = leaveBy {
                                        Text("Leave by \(leaveBy.formatted(date: .omitted, time: .shortened))")
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingDestination = destination
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(destination)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            refresh(destination)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .tint(.green)
                    }
                }
                .onMove(perform: moveDestinations)
            }
            .navigationTitle(group.name) 
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAdd = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddDestinationView()
            }
            .sheet(item: $editingDestination) { dest in
                EditDestinationView(destination: dest)
            }
            .refreshable {
                normalizeTargetArrivalTimes()
                await viewModel.refreshETAs(for: destinations, context: modelContext)
            }
            .onAppear {
                Task { await viewModel.refreshETAs(for: destinations, context: modelContext) }
                normalizeTargetArrivalTimes()
                ensureDestinationOrderInitialized()
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

    private func refresh(_ destination: Destination) {
        if let target = destination.targetArrivalTime,
           !Calendar.current.isDateInToday(target) {
            destination.targetArrivalTime = nil
        }
        Task { await viewModel.refreshETA(for: destination, context: modelContext) }
    }

    private func normalizeTargetArrivalTimes() {
        for destination in destinations {
            if let target = destination.targetArrivalTime,
               !Calendar.current.isDateInToday(target) {
                destination.targetArrivalTime = nil
            }
        }
    }

    private func moveDestinations(from source: IndexSet, to destination: Int) {
        var reordered = destinations
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, destination) in reordered.enumerated() {
            destination.orderIndex = index
        }
    }

    private func ensureDestinationOrderInitialized() {
        guard !destinations.isEmpty else { return }
        let indices = destinations.map(\.orderIndex)
        if Set(indices).count != indices.count || destinations.allSatisfy({ $0.orderIndex == 0 }) {
            let initialOrder = destinations.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            for (index, destination) in initialOrder.enumerated() {
                destination.orderIndex = index
            }
        }
    }

    private func diffText(_ minutes: Int) -> String {
        if minutes == 0 {
            return "On Time"
        }

        let absMinutes = abs(minutes)
        let hours = absMinutes / 60
        let remainingMinutes = absMinutes % 60

        var timeString = ""
        if hours > 0 {
            timeString += "\(hours) hr"
            if hours > 1 { timeString += "s" }
        }

        if remainingMinutes > 0 {
            if !timeString.isEmpty { timeString += " " }
            timeString += "\(remainingMinutes) min"
        }

        if minutes < 0 {
            return "\(timeString) early"
        } else {
            return "\(timeString) late"
        }
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


//#Preview {
//    DestinationListView(group: <#DestinationGroup#>)
//        .modelContainer(for: Destination.self)
//}
