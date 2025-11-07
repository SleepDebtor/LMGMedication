//
//  SharingGroupEditView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/7/25.
//

import SwiftUI
import CoreData

/**
 * SharingGroupEditView
 * 
 * Provides an interface for creating and editing sharing groups.
 * Allows users to set group name, manage participants, and configure
 * automatic sharing settings.
 */
struct SharingGroupEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cloudManager = CloudKitManager.shared
    
    // Editing state
    let group: SharingGroup?
    @State private var groupName: String = ""
    @State private var participantEmails: [String] = [""]
    @State private var autoShareNewPatients: Bool = true
    
    // UI state
    @State private var isSaving = false
    @State private var validationErrors: [String] = []
    @State private var showingDeleteConfirmation = false
    
    private var isEditing: Bool {
        group != nil
    }
    
    private var title: String {
        isEditing ? "Edit Sharing Group" : "New Sharing Group"
    }
    
    private var canSave: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hasValidParticipants &&
        !isSaving
    }
    
    private var hasValidParticipants: Bool {
        participantEmails.contains { email in
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && isValidEmail(trimmed)
        }
    }
    
    init(group: SharingGroup? = nil) {
        self.group = group
        if let group = group {
            _groupName = State(initialValue: group.name ?? "")
            _participantEmails = State(initialValue: group.participantEmailsArray.isEmpty ? [""] : group.participantEmailsArray)
            _autoShareNewPatients = State(initialValue: group.autoShareNewPatients)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Group Name", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Group Information")
                } footer: {
                    Text("Choose a descriptive name for your sharing group (e.g., \"My Practice Team\" or \"Consultation Group\")")
                }
                
                Section {
                    ForEach(participantEmails.indices, id: \.self) { index in
                        HStack {
                            TextField("Email address", text: $participantEmails[index])
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textFieldStyle(.roundedBorder)
                            
                            if participantEmails.count > 1 {
                                Button(action: {
                                    removeEmailField(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: addEmailField) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add another email")
                        }
                    }
                } header: {
                    Text("Participants")
                } footer: {
                    Text("Add email addresses of people you want to automatically share patients with. They must have iCloud accounts.")
                }
                
                Section {
                    Toggle("Auto-share new patients", isOn: $autoShareNewPatients)
                } header: {
                    Text("Sharing Settings")
                } footer: {
                    Text("When enabled, new patients will automatically be shared with all participants in this group. Existing patients can be shared manually.")
                }
                
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Issues to Fix")
                    }
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Sharing Group")
                            }
                        }
                        .disabled(isSaving)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Automatic Sharing")
                            .font(.headline)
                        
                        Text("• Participants receive read/write access to shared patients")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Changes sync automatically across all devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• You can disable auto-sharing anytime without affecting existing shares")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await saveGroup()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .confirmationDialog("Delete Sharing Group", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the sharing group and stop automatic sharing for new patients. Existing shared patients will remain shared.")
        }
        .onChange(of: groupName) { _ in
            validateForm()
        }
        .onChange(of: participantEmails) { _ in
            validateForm()
        }
    }
    
    private func addEmailField() {
        participantEmails.append("")
    }
    
    private func removeEmailField(at index: Int) {
        participantEmails.remove(at: index)
        validateForm()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func validateForm() {
        validationErrors.removeAll()
        
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationErrors.append("Please enter a group name")
        }
        
        let validEmails = participantEmails.compactMap { email in
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.filter { isValidEmail($0) }
        
        if validEmails.isEmpty {
            validationErrors.append("Please add at least one valid email address")
        }
        
        // Check for duplicate emails
        let uniqueEmails = Set(validEmails)
        if uniqueEmails.count != validEmails.count {
            validationErrors.append("Remove duplicate email addresses")
        }
    }
    
    private func saveGroup() async {
        isSaving = true
        defer { isSaving = false }
        
        validateForm()
        guard validationErrors.isEmpty else { return }
        
        do {
            let groupToSave: SharingGroup
            
            if let existingGroup = group {
                groupToSave = existingGroup
            } else {
                groupToSave = SharingGroup(context: viewContext)
            }
            
            // Update group properties
            groupToSave.name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            groupToSave.autoShareNewPatients = autoShareNewPatients
            
            // Update participant emails
            let validEmails = participantEmails.compactMap { email in
                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }.filter { isValidEmail($0) }
            
            groupToSave.participantEmailsArray = Array(Set(validEmails)) // Remove duplicates
            
            // Save to Core Data
            try viewContext.save()
            
            // Save to CloudKit
            if isEditing {
                try await cloudManager.updateSharingGroup(groupToSave)
            } else {
                try await cloudManager.createSharingGroup(groupToSave)
            }
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                validationErrors.append("Failed to save: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteGroup() async {
        guard let group = group else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Delete from CloudKit first
            try await cloudManager.deleteSharingGroup(group)
            
            // Delete from Core Data
            await MainActor.run {
                viewContext.delete(group)
                do {
                    try viewContext.save()
                    dismiss()
                } catch {
                    validationErrors.append("Failed to delete: \(error.localizedDescription)")
                }
            }
        } catch {
            await MainActor.run {
                validationErrors.append("Failed to delete: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Preview for new group
    SharingGroupEditView()
        .environment(\.managedObjectContext, context)
}

#Preview("Editing Existing Group") {
    let context = PersistenceController.preview.container.viewContext
    
    let group = SharingGroup(context: context)
    group.name = "My Practice Team"
    group.participantEmailsArray = ["colleague1@example.com", "colleague2@example.com"]
    group.autoShareNewPatients = true
    
    return SharingGroupEditView(group: group)
        .environment(\.managedObjectContext, context)
}