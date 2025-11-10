//
//  CloudKitConstants.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import Foundation

/// Constants for CloudKit configuration to ensure consistency across the app
enum CloudKitConstants {
    /// The CloudKit container identifier - must match the identifier in your Apple Developer account
    static let containerIdentifier = "iCloud.LMGMedications"
    
    /// Custom zone name for shareable records
    static let sharedPatientsZoneName = "SharedPatients"
    
    /// Record type names
    enum RecordType {
        // Regular record types (for queries)
        static let patient = "Patient"
        static let dispensedMedication = "DispencedMedication"
        static let publicMedicationTemplate = "PublicMedicationTemplate"
        static let sharingGroup = "SharingGroup"
        
        // Shared record types (for sharing)
        static let sharedPatient = "SharedPatient"
        static let sharedDispensedMedication = "SharedDispensedMedication"
        static let sharedLabelPDF = "SharedLabelPDF"
    }
    
    /// Subscription identifiers
    enum Subscription {
        static let publicTemplates = "publicMedicationTemplates"
    }
}