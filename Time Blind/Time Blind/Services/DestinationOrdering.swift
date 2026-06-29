//
//  DestinationOrdering.swift
//  Time Blind
//

import Foundation
import SwiftData

@MainActor
enum DestinationOrdering {
    static func nextDestinationIndex(
        in group: DestinationGroup?,
        context: ModelContext
    ) throws -> Int {
        let descriptor: FetchDescriptor<Destination>
        if let groupID = group?.persistentModelID {
            descriptor = FetchDescriptor(
                predicate: #Predicate { destination in
                    destination.group?.persistentModelID == groupID
                },
                sortBy: [SortDescriptor(\Destination.orderIndex, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { destination in
                    destination.group == nil
                },
                sortBy: [SortDescriptor(\Destination.orderIndex, order: .reverse)]
            )
        }

        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = 1
        return (try context.fetch(limitedDescriptor).first?.orderIndex ?? -1) + 1
    }

    static func nextGroupIndex(context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<DestinationGroup>(
            sortBy: [SortDescriptor(\DestinationGroup.orderIndex, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.orderIndex ?? -1) + 1
    }
}
