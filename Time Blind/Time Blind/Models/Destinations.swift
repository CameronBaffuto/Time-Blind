//
//  Destinations.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/22/25.
//

import Foundation
import SwiftData

@Model
class Destination {
    var name: String
    var address: String
    var latitude: Double?
    var longitude: Double?
    var targetArrivalTime: Date?
    var lastGeocoded: Date?
    var orderIndex: Int = 0
    @Relationship(inverse: \DestinationGroup.destinations) var group: DestinationGroup?

    init(
        name: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        targetArrivalTime: Date? = nil,
        orderIndex: Int = 0,
        group: DestinationGroup? = nil,
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.targetArrivalTime = targetArrivalTime
        self.orderIndex = orderIndex
        self.group = group
    }
}
