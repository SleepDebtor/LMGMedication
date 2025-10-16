//
//  Medication+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/16/25.
//
//

public import Foundation
public import CoreData


public typealias MedicationCoreDataPropertiesSet = NSSet

extension Medication {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Medication> {
        return NSFetchRequest<Medication>(entityName: "Medication")
    }

    @NSManaged public var concentration1: Double
    @NSManaged public var concentration2: Double
    @NSManaged public var ingredient1: String?
    @NSManaged public var ingredient2: String?
    @NSManaged public var injectable: Bool
    @NSManaged public var name: String?
    @NSManaged public var pharmacy: String?
    @NSManaged public var prarmacyURL: String?
    @NSManaged public var qrImage: Data?
    @NSManaged public var timestamp: Date?
    @NSManaged public var urlForQR: String?
    @NSManaged public var dispenced: NSSet?

}

// MARK: Generated accessors for dispenced
extension Medication {

    @objc(addDispencedObject:)
    @NSManaged public func addToDispenced(_ value: DispencedMedication)

    @objc(removeDispencedObject:)
    @NSManaged public func removeFromDispenced(_ value: DispencedMedication)

    @objc(addDispenced:)
    @NSManaged public func addToDispenced(_ values: NSSet)

    @objc(removeDispenced:)
    @NSManaged public func removeFromDispenced(_ values: NSSet)

}

extension Medication : Identifiable {

}
