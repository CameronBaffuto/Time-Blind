//
//  DestinationGroup.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import Foundation
import SwiftData

@Model
class DestinationGroup {
    var name: String
    @Relationship(deleteRule: .cascade) var destinations: [Destination] = []

    init(name: String) {
        self.name = name
    }
}
