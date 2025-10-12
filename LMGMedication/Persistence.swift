//
//  Persistence.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import CoreData

struct PersistenceController {
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
        dispensed3.baseMedication = medication3
        dispensed3.patient = patient2
        dispensed3.prescriber = provider1
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "LMGMedication")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
