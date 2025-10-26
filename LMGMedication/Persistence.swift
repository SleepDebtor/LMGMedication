//
//  Persistence.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import CoreData

/**
 * PersistenceController
 * 
 * Manages Core Data stack with CloudKit integration for the LMGMedication app.
 * Provides both production and preview configurations with comprehensive error handling.
 * 
 * Key Features:
 * - CloudKit synchronization with iCloud.LMGMedication container
 * - Automatic lightweight migration support
 * - Robust error handling with recovery mechanisms
 * - Preview data generation for SwiftUI previews and testing
 * - Persistent store failure recovery via notification system
 * 
 * Architecture:
 * - NSPersistentCloudKitContainer for CloudKit integration
 * - Singleton pattern for shared instance across app
 * - Automatic merge policy configuration for conflict resolution
 * - Remote change notifications for real-time sync
 * 
 * Usage:
 * ```swift
 * let controller = PersistenceController.shared
 * let context = controller.container.viewContext
 * ```
 */
struct PersistenceController {
    /// Notification sent when persistent store loading fails
    static let persistentStoreLoadFailedNotification = Notification.Name("PersistentStoreLoadFailed")
    
    /// Shared singleton instance for app-wide Core Data access
    static let shared = PersistenceController()

    /**
     * Preview instance configured with in-memory storage and sample data
     * Used for SwiftUI previews and testing scenarios
     * 
     * Creates sample patients, providers, medications, and dispensed medications
     * for development and preview purposes.
     */
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample patients
        let patient1 = Patient(context: viewContext)
        patient1.firstName = "Brittany"
        patient1.lastName = "Kratzer"
        patient1.birthdate = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()
        patient1.timeStamp = Date()
        
        let patient2 = Patient(context: viewContext)
        patient2.firstName = "John"
        patient2.lastName = "Smith"
        patient2.birthdate = Calendar.current.date(byAdding: .year, value: -42, to: Date()) ?? Date()
        patient2.timeStamp = Date()
        
        // Create sample providers
        let provider1 = Provider(context: viewContext)
        provider1.firstName = "Krista"
        provider1.lastName = "Lazar"
        provider1.timeStamp = Date()
        
        // Create sample medications
        let medication1 = Medication(context: viewContext)
        medication1.name = "Tirzepatide"
        medication1.ingredient1 = "vitamin B6"
        medication1.concentration1 = 25.0
        medication1.pharmacy = "Beaker Pharmacy"
        medication1.injectable = true
        medication1.timestamp = Date()
        
        let medication2 = Medication(context: viewContext)
        medication2.name = "Semaglutide"
        medication2.ingredient1 = "semaglutide"
        medication2.concentration1 = 1.0
        medication2.pharmacy = "Beaker Pharmacy"
        medication2.injectable = true
        medication2.timestamp = Date()
        
        let medication3 = Medication(context: viewContext)
        medication3.name = "Metformin"
        medication3.ingredient1 = "metformin"
        medication3.concentration1 = 500.0
        medication3.pharmacy = "Local Pharmacy"
        medication3.injectable = false
        medication3.timestamp = Date()
        
        // Create sample dispensed medications
        let dispensed1 = DispencedMedication(context: viewContext)
        dispensed1.dose = "10"
        dispensed1.doseNum = 10.0
        dispensed1.doseUnit = "mg"
        dispensed1.dispenceAmt = 4
        dispensed1.dispenceUnit = "syringes"
        dispensed1.dispenceDate = Date()
        dispensed1.expDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        dispensed1.lotNum = "LOT123456"
        dispensed1.createdDate = Date()
        dispensed1.baseMedication = medication1
        dispensed1.patient = patient1
        dispensed1.prescriber = provider1
        
        let dispensed2 = DispencedMedication(context: viewContext)
        dispensed2.dose = "1"
        dispensed2.doseNum = 1.0
        dispensed2.doseUnit = "mg"
        dispensed2.dispenceAmt = 1
        dispensed2.dispenceUnit = "pen"
        dispensed2.dispenceDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        dispensed2.expDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        dispensed2.createdDate = Date()
        dispensed2.baseMedication = medication2
        dispensed2.patient = patient1
        dispensed2.prescriber = provider1
        
        let dispensed3 = DispencedMedication(context: viewContext)
        dispensed3.dose = "500"
        dispensed3.doseNum = 500.0
        dispensed3.doseUnit = "mg"
        dispensed3.dispenceAmt = 60
        dispensed3.dispenceUnit = "tablets"
        dispensed3.dispenceDate = Date()
        dispensed3.expDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        dispensed3.createdDate = Date()
        dispensed3.baseMedication = medication3
        dispensed3.patient = patient2
        dispensed3.prescriber = provider1
        
        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            assertionFailure("Preview seeding failed: \(error)")
            #else
            print("Preview seeding failed: \(error)")
            #endif
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "LMGMedication")
        
        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            
            // Configure CloudKit options
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable automatic lightweight migration
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            // CloudKit specific options - be more permissive in TestFlight
            if !inMemory {
                // Configure CloudKit container options
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.LMGMedication"
                )
            }
        }
        
        container.loadPersistentStores(completionHandler: { [container] (storeDescription, error) in
            if let error = error as NSError? {
                #if DEBUG
                assertionFailure("Failed to load persistent store: \(error), \(error.userInfo)")
                #else
                print("Failed to load persistent store: \(error), \(error.userInfo)")
                #endif
                
                // Post notification for error handling in the app
                NotificationCenter.default.post(
                    name: PersistenceController.persistentStoreLoadFailedNotification,
                    object: nil,
                    userInfo: ["error": error]
                )
                
                // Try to recover by removing the problematic store and recreating
                PersistenceController.handlePersistentStoreLoadFailure(container: container, error: error)
            } else {
                #if DEBUG
                print("Successfully loaded persistent store: \(storeDescription)")
                #endif
            }
        })
        
        // Configure the view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Set a reasonable timeout for CloudKit operations
        if let cloudKitContainer = container.persistentStoreDescriptions.first {
            cloudKitContainer.timeout = 30.0 // 30 seconds timeout
        }
    }
    
    private static func handlePersistentStoreLoadFailure(container: NSPersistentCloudKitContainer, error: NSError) {
        // This is a recovery mechanism for corrupted stores
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { 
            print("No store URL found for recovery")
            return 
        }
        
        print("Attempting to recover from persistent store failure: \(error.localizedDescription)")
        
        do {
            // Remove the corrupted store files
            let fileManager = FileManager.default
            
            // Remove main store file
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
                print("Removed main store file")
            }
            
            // Remove WAL files
            let walURL = storeURL.appendingPathExtension("sqlite-wal")
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
                print("Removed WAL file")
            }
            
            // Remove SHM files
            let shmURL = storeURL.appendingPathExtension("sqlite-shm")
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
                print("Removed SHM file")
            }
            
            print("Removed corrupted store files, attempting to recreate...")
            
            // Try to load stores again
            container.loadPersistentStores { (_, secondError) in
                if let secondError = secondError {
                    print("Failed to recover from store corruption: \(secondError.localizedDescription)")
                    // Post another notification about the final failure
                    NotificationCenter.default.post(
                        name: PersistenceController.persistentStoreLoadFailedNotification,
                        object: nil,
                        userInfo: ["error": secondError, "recoveryAttempted": true]
                    )
                } else {
                    print("Successfully recovered from store corruption")
                }
            }
            
        } catch {
            print("Failed to remove corrupted store files: \(error.localizedDescription)")
        }
    }
}

// MARK: - Medication Extension

extension Medication {
    /// Computed property for template selection display in format "Medication name Pharmacy, Concentration 1/Concentration2"
    var selectionDisplayValue: String {
        var components: [String] = []
        
        // Add medication name
        components.append(name ?? "Unknown Medication")
        
        // Add pharmacy if available
        if let pharmacy = pharmacy, !pharmacy.isEmpty {
            components.append(pharmacy)
        }
        
        // Add concentrations in format "Concentration 1/Concentration2"
        var concentrations: [String] = []
        
        if let ingredient1 = ingredient1, !ingredient1.isEmpty, concentration1 > 0 {
            concentrations.append(String(format: "%.1f", concentration1))
        }
        
        if let ingredient2 = ingredient2, !ingredient2.isEmpty, concentration2 > 0 {
            concentrations.append(String(format: "%.1f", concentration2))
        }
        
        if !concentrations.isEmpty {
            components.append(concentrations.joined(separator: "/"))
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Computed property providing detailed concentration information similar to CloudMedicationTemplate
    var concentrationInfo: String {
        var parts: [String] = []
        
        if let ingredient1 = ingredient1, !ingredient1.isEmpty, concentration1 > 0 {
            parts.append("\(ingredient1): \(String(format: "%.1f", concentration1))")
        }
        
        if let ingredient2 = ingredient2, !ingredient2.isEmpty, concentration2 > 0 {
            parts.append("\(ingredient2): \(String(format: "%.1f", concentration2))")
        }
        
        return parts.joined(separator: ", ")
    }
}

