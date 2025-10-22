//
//  LMGMedicationApp.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import SwiftUI
import CoreData

/**
 * LMGMedicationApp
 * 
 * Main application entry point for the LMGMedication app.
 * This healthcare management application helps providers track patients and their dispensed medications.
 * 
 * Key Features:
 * - Patient management with medication tracking
 * - Core Data persistence with CloudKit synchronization
 * - Medication label printing and PDF generation
 * - Weekly patient organization by next dose due dates
 * - Authentication-gated access to patient data
 * 
 * Architecture:
 * - SwiftUI for modern, declarative UI
 * - Core Data + CloudKit for data persistence and sync
 * - Async/await for concurrency
 * - MVVM pattern with ObservableObject view models
 */
@main
struct LMGMedicationApp: App {
    /// Core Data persistence controller for the application
    let persistenceController = PersistenceController.shared
    
    /// State for showing Core Data error alerts
    @State private var showingCoreDataError = false
    @State private var coreDataErrorMessage = ""

    var body: some Scene {
        WindowGroup {
            // Authentication gate protects patient data access
            AuthenticationGateView {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
            // Handle Core Data initialization failures
            .onReceive(NotificationCenter.default.publisher(for: PersistenceController.persistentStoreLoadFailedNotification)) { notification in
                if let error = notification.userInfo?["error"] as? NSError {
                    coreDataErrorMessage = "Database initialization failed: \(error.localizedDescription)"
                    showingCoreDataError = true
                }
            }
            .alert("Database Error", isPresented: $showingCoreDataError) {
                Button("OK") { 
                    // App will likely need to be restarted if Core Data fails
                }
            } message: {
                Text(coreDataErrorMessage)
            }
        }
    }
}
