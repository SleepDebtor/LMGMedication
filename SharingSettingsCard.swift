//
//  SharingSettingsCard.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/7/25.
//

import SwiftUI
import CoreData

/**
 * SharingSettingsCard
 * 
 * A compact card component that shows sharing groups status and provides
 * quick access to sharing management. Can be easily integrated into 
 * settings screens or main dashboards.
 */
struct SharingSettingsCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SharingGroup.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var sharingGroups: FetchedResults<SharingGroup>
    
    @StateObject private var cloudManager = CloudKitManager.shared
    @State private var showingSharingGroups = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Automatic Sharing")
                        .font(.headline)
                    Text("Manage sharing groups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Manage") {
                    showingSharingGroups = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Divider()
            
            // Status
            if !cloudManager.isSignedInToiCloud {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Sign in to iCloud to enable sharing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if sharingGroups.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("No sharing groups configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    let activeGroups = sharingGroups.filter { $0.autoShareNewPatients }
                    
                    if activeGroups.isEmpty {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                            Text("Auto-sharing paused for all groups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(activeGroups.count) group\(activeGroups.count == 1 ? "" : "s") with auto-sharing enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if activeGroups.count > 0 {
                            let totalParticipants = activeGroups.reduce(0) { $0 + $1.participantCount }
                            Text("New patients automatically shared with \(totalParticipants) participant\(totalParticipants == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingSharingGroups) {
            SharingGroupsView()
        }
    }
}

#Preview {
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
    
    return VStack {
        SharingSettingsCard()
        Spacer()
    }
    .padding()
    .environment(\.managedObjectContext, context)
}