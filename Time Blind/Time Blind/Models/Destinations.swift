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
    @Relationship(inverse: \DestinationGroup.destinations) var group: DestinationGroup?

    init(
        name: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        targetArrivalTime: Date? = nil,
        group: DestinationGroup? = nil
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.targetArrivalTime = targetArrivalTime
        self.group = group
    }
}

