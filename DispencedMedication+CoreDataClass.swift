//
//  DispencedMedication+CoreDataClass.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//
//

public import Foundation
public import CoreData

public typealias DispencedMedicationCoreDataClassSet = NSSet

@objc(DispencedMedication)
public class DispencedMedication: NSManagedObject {
    
    public var displayName: String {
        guard let medName = baseMedication?.name else { return "Unknown Medication" }
        if let dose = dose, !dose.isEmpty {
            return "\(medName) \(dose)\(doseUnit ?? "")"
        }
        return medName
    }
    
    public var dispensedQuantityText: String {
        let qty = max(0, Int(dispenceAmt))
        guard qty > 0 else { return "" }
        let unit = dispenseUnitType
        return "\(qty) \(unit.label(for: qty))"
    }
    
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
    
    public var pharmacyInfo: String {
        return baseMedication?.pharmacy ?? ""
    }
}

