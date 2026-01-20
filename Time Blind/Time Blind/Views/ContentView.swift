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

    var body: some View {
        DestinationGroupListView()
            .onAppear {
                LiveActivityManager.shared.startMonitoring(modelContainer: modelContext.container)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Destination.self) 
}
