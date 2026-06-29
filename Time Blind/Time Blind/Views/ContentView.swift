//
//  ContentView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var destinationListViewModel = DestinationListViewModel()

    var body: some View {
        DestinationGroupListView()
            .environment(destinationListViewModel)
            .task {
                LiveActivityManager.shared.startMonitoring(modelContainer: modelContext.container)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Destination.self, DestinationGroup.self], inMemory: true)
}
