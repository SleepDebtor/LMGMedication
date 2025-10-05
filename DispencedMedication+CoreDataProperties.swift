//
//  DispencedMedication+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/30/25.
//
//

public import Foundation
public import CoreData


public typealias DispencedMedicationCoreDataPropertiesSet = NSSet

extension DispencedMedication {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DispencedMedication> {
        return NSFetchRequest<DispencedMedication>(entityName: "DispencedMedication")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var dispenceAmt: Int16
    @NSManaged public var dispenceDate: Date?
    @NSManaged public var dispenceUnit: String?
    @NSManaged public var dose: String?
    @NSManaged public var doseUnit: String?
    @NSManaged public var expDate: Date?
    @NSManaged public var lotNum: String?
    @NSManaged public var doseNum: Double
    @NSManaged public var baseMedication: Medication?
    @NSManaged public var patient: Patient?
    @NSManaged public var prescriber: Provider?

}

extension DispencedMedication : Identifiable {
    var doseMedication2: String {
        if let ingredient2 = baseMedication?.ingredient2, 
           let concentration2 = baseMedication?.concentration2,
           concentration2 > 0, 
           !ingredient2.isEmpty {
            let secondCompoundDose = fillAmount * concentration2
            return "\(String(format: "%.1f", secondCompoundDose))mg \(ingredient2)"
        }
        return ""
    }
    
    var fillAmount: Double {
        if let concentration = baseMedication?.concentration1 {
            return doseNum / concentration
        } else {
            return 0
        }
    }
}
