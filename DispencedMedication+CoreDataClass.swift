//
//  DispencedMedication+CoreDataClass.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

public import Foundation
public import CoreData

public typealias DispencedMedicationCoreDataClassSet = NSSet

/**
 * DispencedMedication
 * 
 * Core Data entity representing a specific instance of medication dispensed to a patient.
 * Links a base Medication template with specific dosage, quantity, and timing information.
 * 
 * Key Features:
 * - Links to base Medication for template information
 * - Stores patient-specific dosage and dispensing details
 * - Calculates display names with dose information
 * - Tracks expiration dates and lot numbers
 * - Supports both injectable and non-injectable medications
 * 
 * Relationships:
 * - baseMedication: Many-to-one with Medication (template)
 * - patient: Many-to-one with Patient
 * - prescriber: Many-to-one with Provider
 * 
 * Usage:
 * ```swift
 * let dispensed = DispencedMedication(context: viewContext)
 * dispensed.baseMedication = medicationTemplate
 * dispensed.patient = selectedPatient
 * dispensed.dose = "10"
 * dispensed.doseUnit = "mg"
 * ```
 */
@objc(DispencedMedication)
public class DispencedMedication: NSManagedObject {
    
    /**
     * Returns a formatted display name combining medication name with dose
     * Handles cases where dose information might be missing
     * 
     * - Returns: "Medication Name Dose Unit" or "Unknown Medication" if base medication is missing
     */
    public var displayName: String {
        guard let medName = baseMedication?.name else { return "Unknown Medication" }
        if let dose = dose, !dose.isEmpty {
            return "\(medName) \(dose)\(doseUnit ?? "")"
        }
        return medName
    }
    /**
     * Returns formatted text describing the dispensed quantity
     * Combines quantity with appropriate unit labels (singular/plural)
     * 
     * - Returns: "X unit(s)" where X is the quantity and unit is appropriately pluralized
     */
    public var dispensedQuantityText: String {
        let qty = max(0, Int(dispenceAmt))
        guard qty > 0 else { return "" }
        let unit = dispenseUnitType
        return "\(qty) \(unit.label(for: qty))"
    }
    /**
     * Returns detailed concentration information for the medication
     * Combines all ingredients with their concentrations from the base medication
     * 
     * - Returns: Comma-separated list of "Ingredient Xmg" or empty string if no ingredients
     */
    public var concentrationInfo: String {
        guard let medication = baseMedication else { return "" }
        
        var info: [String] = []
        
        if let ingredient1 = medication.ingredient1, !ingredient1.isEmpty, medication.concentration1 > 0 {
            info.append("\(ingredient1) \(medication.concentration1)mg")
        }
        
        if let ingredient2 = medication.ingredient2, !ingredient2.isEmpty, medication.concentration2 > 0 {
            info.append("\(ingredient2) \(medication.concentration2)mg")
        }
        
        return info.joined(separator: ", ")
    }
    /**
     * Returns the formatted name of the prescribing provider
     * Handles various combinations of first/last name availability
     * 
     * - Returns: "First Last, MD" format or empty string if no prescriber
     */
    public var prescriberName: String {
        guard let prescriber = prescriber else { return "" }
        let first = prescriber.firstName ?? ""
        let last = prescriber.lastName ?? ""
        if !first.isEmpty && !last.isEmpty {
            return "\(first) \(last), MD"
        } else if !last.isEmpty {
            return "\(last), MD"
        } else if !first.isEmpty {
            return "\(first), MD"
        }
        return ""
    }
    /**
     * Returns the pharmacy information from the base medication
     * 
     * - Returns: Pharmacy name string or empty string if not available
     */
    public var pharmacyInfo: String {
        return baseMedication?.pharmacy ?? ""
    }
}

