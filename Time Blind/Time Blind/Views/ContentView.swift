//
//  ContentView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        DestinationGroupListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Destination.self) 
}
