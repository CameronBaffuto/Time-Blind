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
    var orderIndex: Int = 0
    @Relationship(deleteRule: .cascade) var destinations: [Destination] = []

    init(name: String, orderIndex: Int = 0) {
        self.name = name
        self.orderIndex = orderIndex
    }
}
