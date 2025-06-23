//
//  Time_BlindApp.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import SwiftUI
import SwiftData

@main
struct TimeBlindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Destination.self)
    }
}
