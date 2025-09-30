//
//  Patient+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//
//

public import Foundation
public import CoreData


public typealias PatientCoreDataPropertiesSet = NSSet

extension Patient {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Patient> {
        return NSFetchRequest<Patient>(entityName: "Patient")
    }

    @NSManaged public var medicationsPrescribed: NSSet?

}

// MARK: Generated accessors for medicationsPrescribed
extension Patient {

    @objc(addMedicationsPrescribedObject:)
    @NSManaged public func addToMedicationsPrescribed(_ value: DispencedMedication)

    @objc(removeMedicationsPrescribedObject:)
    @NSManaged public func removeFromMedicationsPrescribed(_ value: DispencedMedication)

    @objc(addMedicationsPrescribed:)
    @NSManaged public func addToMedicationsPrescribed(_ values: NSSet)

    @objc(removeMedicationsPrescribed:)
    @NSManaged public func removeFromMedicationsPrescribed(_ values: NSSet)

}
