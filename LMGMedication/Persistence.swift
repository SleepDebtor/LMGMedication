//
//  Persistence.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import Foundation
import CoreData
import CloudKit

struct PersistenceController {
    static let persistentStoreLoadFailedNotification = Notification.Name("PersistentStoreLoadFailed")
    static let shared = PersistenceController()

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
        dispensed1.creationDate = Date()
        dispensed1.isActive = true
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
        dispensed2.creationDate = Date()
        dispensed2.isActive = true
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
        dispensed3.creationDate = Date()
        dispensed3.isActive = true
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
                let containerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.lazarmedicalgroup.LMGMedication"
                )
                
                // Use development environment for debug builds
                #if DEBUG
                containerOptions.databaseScope = .private
                print("🔧 Using CloudKit development environment")
                #else
                // Production environment for release builds
                containerOptions.databaseScope = .private
                print("🚀 Using CloudKit production environment")
                #endif
                
                description.cloudKitContainerOptions = containerOptions
            }
        }
        
        container.loadPersistentStores(completionHandler: { [container] (storeDescription, error) in
            if let error = error as NSError? {
                // Log detailed CloudKit error information
                print("🚨 Core Data CloudKit Error Details:")
                print("Error Code: \(error.code)")
                print("Error Domain: \(error.domain)")
                print("Error Description: \(error.localizedDescription)")
                print("User Info: \(error.userInfo)")
                
                // Check for specific CloudKit errors
                if error.domain == "NSCocoaErrorDomain" {
                    switch error.code {
                    case 134060: // CloudKit account not available
                        print("❌ CloudKit account not available - user not signed into iCloud")
                    case 134070: // CloudKit container not found
                        print("❌ CloudKit container not found - check container identifier")
                    case 134080: // CloudKit network failure
                        print("❌ CloudKit network failure - check internet connection")
                    case 134090: // CloudKit quota exceeded
                        print("❌ CloudKit quota exceeded")
                    case 134100: // CloudKit zone not found
                        print("❌ CloudKit zone not found")
                    default:
                        print("❌ Other CloudKit Core Data error: \(error.code)")
                    }
                } else if error.domain == CKError.errorDomain {
                    // Handle CloudKit specific errors
                    if let ckError = error as? CKError {
                        switch ckError.code {
                        case .accountTemporarilyUnavailable:
                            print("❌ CloudKit account temporarily unavailable")
                        case .networkUnavailable:
                            print("❌ CloudKit network unavailable")
                        case .quotaExceeded:
                            print("❌ CloudKit quota exceeded")
                        case .managedAccountRestricted:
                            print("❌ CloudKit managed account restricted")
                        default:
                            print("❌ CloudKit error: \(ckError.localizedDescription)")
                        }
                    }
                }
                
                #if DEBUG
                assertionFailure("Failed to load persistent store: \(error), \(error.userInfo)")
                #else
                print("Failed to load persistent store: \(error), \(error.userInfo)")
                #endif
                
                // Post notification for error handling in the app
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: PersistenceController.persistentStoreLoadFailedNotification,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
                
                // Try to recover by removing the problematic store and recreating
                Task {
                    await PersistenceController.handlePersistentStoreLoadFailure(container: container, error: error)
                }
            } else {
                #if DEBUG
                print("✅ Successfully loaded persistent store: \(storeDescription)")
                print("📱 CloudKit container: \(storeDescription.cloudKitContainerOptions?.containerIdentifier ?? "none")")
                #endif
                
                // Enable remote notifications after successful store load
                DispatchQueue.main.async {
                    do {
                        try container.initializeCloudKitSchema(options: [])
                        print("✅ CloudKit schema initialized")
                    } catch {
                        print("⚠️ CloudKit schema initialization failed: \(error)")
                    }
                }
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
    
    private static func handlePersistentStoreLoadFailure(container: NSPersistentCloudKitContainer, error: NSError) async {
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
            await withCheckedContinuation { continuation in
                container.loadPersistentStores { (_, secondError) in
                    if let secondError = secondError {
                        print("Failed to recover from store corruption: \(secondError.localizedDescription)")
                        // Post another notification about the final failure
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: PersistenceController.persistentStoreLoadFailedNotification,
                                object: nil,
                                userInfo: ["error": secondError, "recoveryAttempted": true]
                            )
                        }
                    } else {
                        print("Successfully recovered from store corruption")
                    }
                    continuation.resume()
                }
            }
            
        } catch {
            print("Failed to remove corrupted store files: \(error.localizedDescription)")
        }
    }
}

