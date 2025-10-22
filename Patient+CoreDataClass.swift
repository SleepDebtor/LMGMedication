//
//  Patient+CoreDataClass.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import Foundation
import CoreData

public typealias PatientCoreDataClassSet = NSSet

/**
 * Patient
 * 
 * Core Data entity representing a patient in the medication management system.
 * Inherits from Person base class to share common properties like firstName, lastName, etc.
 * 
 * Key Features:
 * - Automatic activation and timestamp setting on creation
 * - Computed properties for display names and full names
 * - Relationship management with dispensed medications
 * - Active/inactive status tracking for patient management
 * 
 * Relationships:
 * - medicationsPrescribed: One-to-many relationship with DispencedMedication entities
 * 
 * Usage:
 * ```swift
 * let patient = Patient(context: viewContext)
 * patient.firstName = "John"
 * patient.lastName = "Doe"
 * // Patient is automatically set as active with current timestamp
 * ```
 */
@objc(Patient)
public class Patient: Person {
    
    /**
     * Called when a new Patient entity is inserted into Core Data
     * Automatically sets default values for new patients
     */
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.isActive = true
        self.timeStamp = Date()
    }
    
    /**
     * Returns the patient's name in "Last, First" format
     * Handles cases where first or last name might be nil
     * 
     * - Returns: Formatted name string, trimmed of whitespace
     */
    public var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(last), \(first)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /**
     * Returns the patient's name in a user-friendly "First Last" format
     * Handles edge cases gracefully and provides fallback for missing names
     * 
     * - Returns: Formatted display name or "Unknown Patient" if both names are missing
     */
    public var displayName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        if !first.isEmpty && !last.isEmpty {
            return "\(first) \(last)"
        } else if !last.isEmpty {
            return last
        } else if !first.isEmpty {
            return first
        }
        return "Unknown Patient"
    }
    
    /**
     * Returns all dispensed medications for this patient as a sorted array
     * Medications are sorted by dispense date (most recent first)
     * 
     * - Returns: Array of DispencedMedication objects sorted by dispense date
     */
    public var dispensedMedicationsArray: [DispencedMedication] {
        let set = medicationsPrescribed as? Set<DispencedMedication> ?? []
        return set.sorted { med1, med2 in
            let date1 = med1.dispenceDate ?? Date.distantPast
            let date2 = med2.dispenceDate ?? Date.distantPast
            return date1 > date2
        }
    }
}

