//
//  DispencedMedication+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/11/25.
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
    @NSManaged public var doseNum: Double
    @NSManaged public var doseUnit: String?
    @NSManaged public var expDate: Date?
    @NSManaged public var lotNum: String?
    @NSManaged public var nextDoseDue: Date?
    @NSManaged public var baseMedication: Medication?
    @NSManaged public var patient: Patient?
    @NSManaged public var prescriber: Provider?

}

extension DispencedMedication : Identifiable {

}
