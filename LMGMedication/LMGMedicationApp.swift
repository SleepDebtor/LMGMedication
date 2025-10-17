//
//  LMGMedicationApp.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import SwiftUI
import CoreData

@main
struct LMGMedicationApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showingCoreDataError = false
    @State private var coreDataErrorMessage = ""

    var body: some Scene {
        WindowGroup {
            AuthenticationGateView {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: PersistenceController.persistentStoreLoadFailedNotification)) { notification in
                if let error = notification.userInfo?["error"] as? NSError {
                    coreDataErrorMessage = "Database initialization failed: \(error.localizedDescription)"
                    showingCoreDataError = true
                }
            }
            .alert("Database Error", isPresented: $showingCoreDataError) {
                Button("OK") { 
                    // App will likely need to be restarted
                }
            } message: {
                Text(coreDataErrorMessage)
            }
        }
    }
}
