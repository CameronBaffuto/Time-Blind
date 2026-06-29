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
    #Index<DestinationGroup>([\.orderIndex])

    var name: String
    var orderIndex: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Destination.group)
    var destinations: [Destination] = []

    init(name: String, orderIndex: Int = 0) {
        self.name = name
        self.orderIndex = orderIndex
    }
}
