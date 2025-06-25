//
//  AddEditGroupView.swift
//  Time Blind
//
//  Created by Cameron Baffuto on 6/24/25.
//

import SwiftUI
import SwiftData

struct AddEditGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    var group: DestinationGroup?

    init(group: DestinationGroup? = nil) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(group == nil ? "New Group" : "Edit Group")) {
                    TextField("Group Name", text: $name)
                }
            }
            .navigationTitle(group == nil ? "Add Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let group = group {
            group.name = trimmedName
        } else {
            let newGroup = DestinationGroup(name: trimmedName)
            modelContext.insert(newGroup)
        }
        dismiss()
    }
}
