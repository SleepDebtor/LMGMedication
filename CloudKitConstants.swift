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
    static let containerIdentifier = "iCloud.LMGMedication"
    
    /// Custom zone name for shareable records
    static let sharedPatientsZoneName = "SharedPatients"
    
    /// Record type names
    enum RecordType {
        static let patient = "Patient"
        static let dispensedMedication = "DispensedMedication"
        static let sharingGroup = "SharingGroup"
        static let publicMedicationTemplate = "PublicMedicationTemplate"
    }
    
    /// Subscription identifiers
    enum Subscription {
        static let publicTemplates = "publicMedicationTemplates"
    }
}