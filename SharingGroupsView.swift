//
//  SharingGroupsView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/7/25.
//

import SwiftUI
import CoreData

/**
 * SharingGroupsView
 * 
 * Provides a comprehensive interface for managing sharing groups.
 * Allows users to create, edit, and delete sharing groups that automatically
 * share new patients with invited participants.
 * 
 * Key Features:
 * - List of all sharing groups
 * - Create new sharing groups
 * - Edit existing groups and participants
 * - Toggle automatic sharing for groups
 * - Real-time sync status indicators
 * - CloudKit integration for cross-device synchronization
 */
struct SharingGroupsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SharingGroup.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var sharingGroups: FetchedResults<SharingGroup>
    
    @StateObject private var cloudManager = CloudKitManager.shared
    @State private var showingAddGroup = false
    @State private var selectedGroup: SharingGroup?
    @State private var showingEditGroup = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if !cloudManager.isSignedInToiCloud {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("iCloud Required")
                                    .font(.headline)
                            }
                            Text("Sign in to iCloud to create and manage sharing groups for automatic patient sharing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if sharingGroups.isEmpty {
                    Section {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No Sharing Groups")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create a sharing group to automatically share new patients with colleagues or team members.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        ForEach(sharingGroups) { group in
                            SharingGroupRowView(group: group) {
                                selectedGroup = group
                                showingEditGroup = true
                            }
                        }
                        .onDelete(perform: deleteGroups)
                    } header: {
                        Text("Sharing Groups")
                    } footer: {
                        Text("Groups with auto-sharing enabled will automatically share new patients with all participants.")
                            .font(.caption)
                    }
                }
                
                if cloudManager.isSignedInToiCloud && !sharingGroups.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How Automatic Sharing Works")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("When you create a new patient, they're automatically shared with all active sharing groups")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "2.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Group members receive read/write access and can view and edit patient data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "3.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Changes sync automatically across all devices and group members")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Information")
                    }
                }
            }
            .navigationTitle("Sharing Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(!cloudManager.isSignedInToiCloud)
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            SharingGroupEditView()
        }
        .sheet(isPresented: $showingEditGroup) {
            if let group = selectedGroup {
                SharingGroupEditView(group: group)
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onReceive(cloudManager.$lastErrorMessage) { errorMessage in
            if let error = errorMessage {
                self.errorMessage = error
                self.showingErrorAlert = true
            }
        }
    }
    
    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let group = sharingGroups[index]
                
                // Delete from CloudKit
                Task {
                    do {
                        try await cloudManager.deleteSharingGroup(group)
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to delete sharing group: \(error.localizedDescription)"
                            showingErrorAlert = true
                        }
                    }
                }
                
                // Delete from Core Data
                viewContext.delete(group)
            }
            
            do {
                try viewContext.save()
            } catch {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}

struct SharingGroupRowView: View {
    let group: SharingGroup
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayName)
                        .font(.headline)
                    
                    if group.participantCount > 0 {
                        Text("\(group.participantCount) participant\(group.participantCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No participants")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if group.autoShareNewPatients {
                        Label("Auto-share ON", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Auto-share OFF", systemImage: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if group.participantCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(group.participantEmailsArray, id: \.self) { email in
                            Text(email)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

#Preview {
    // Create preview data
    let context = PersistenceController.preview.container.viewContext
    
    let group1 = SharingGroup(context: context)
    group1.name = "My Practice Team"
    group1.participantEmailsArray = ["colleague1@example.com", "colleague2@example.com"]
    group1.autoShareNewPatients = true
    
    let group2 = SharingGroup(context: context)
    group2.name = "Consulting Group"
    group2.participantEmailsArray = ["consultant@example.com"]
    group2.autoShareNewPatients = false
    
    try? context.save()
    
    return SharingGroupsView()
        .environment(\.managedObjectContext, context)
}