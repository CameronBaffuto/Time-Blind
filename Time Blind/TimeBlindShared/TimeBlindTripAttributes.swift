//
//  TimeBlindTripAttributes.swift
//  Time Blind
//
//  Created by Codex on 10/28/25.
//

import ActivityKit
import Foundation

struct TimeBlindTripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var leaveBy: Date
        var targetTime: Date
        var travelMinutes: Int
    }

    var destinationName: String
    var destinationAddress: String
    var groupName: String?
}
