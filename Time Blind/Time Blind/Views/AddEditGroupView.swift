//
//  AddEditGroupView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import SwiftData
import SwiftUI

struct AddEditGroupView: View {
    @Query private var groups: [DestinationGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    private let group: DestinationGroup?

    init(group: DestinationGroup? = nil) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(group == nil ? "New List" : "Edit List") {
                    TextField("List name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(group == nil ? "Add List" : "Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        errorMessage = nil

        if groups.contains(where: {
            $0.persistentModelID != group?.persistentModelID
                && $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            errorMessage = "A list with this name already exists."
            return
        }

        do {
            if let group {
                let originalName = group.name
                group.name = trimmedName
                do {
                    try modelContext.save()
                } catch {
                    group.name = originalName
                    throw error
                }
            } else {
                let nextIndex = try DestinationOrdering.nextGroupIndex(context: modelContext)
                let newGroup = DestinationGroup(name: trimmedName, orderIndex: nextIndex)
                modelContext.insert(newGroup)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.delete(newGroup)
                    throw error
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
