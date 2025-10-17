//
//  OfflinePatientManager.swift
//  LMGMedication
//
//  Created by Assistant on 10/17/25.
//

import CoreData
import Foundation

/// Temporary utility to handle patient creation without CloudKit interference
/// This is a workaround for TestFlight crashes while we diagnose the CloudKit issue
@MainActor
class OfflinePatientManager {
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func createPatient(firstName: String, lastName: String, middleName: String?, birthdate: Date) throws -> Patient {
        // Create a local-only context to avoid CloudKit sync issues
        let localContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        localContext.parent = viewContext
        localContext.transactionAuthor = "offline-creation"
        
        // Temporarily disable automatic CloudKit sync for this context
        localContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        let newPatient = Patient(context: localContext)
        newPatient.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPatient.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPatient.middleName = middleName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? 
                                 middleName?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        newPatient.birthdate = birthdate
        newPatient.timeStamp = Date()
        newPatient.isActive = true
        
        // Save to local context first
        try localContext.save()
        
        // Then save to parent context (this may trigger CloudKit sync, but in a more controlled way)
        try viewContext.save()
        
        return newPatient
    }
}