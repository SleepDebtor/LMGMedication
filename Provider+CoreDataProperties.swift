//
//  Provider+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/20/25.
//
//

public import Foundation
public import CoreData


public typealias ProviderCoreDataPropertiesSet = NSSet

extension Provider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Provider> {
        return NSFetchRequest<Provider>(entityName: "Provider")
    }

    @NSManaged public var dea: String?
    @NSManaged public var degree: String?
    @NSManaged public var license: String?
    @NSManaged public var npi: String?
    @NSManaged public var relationship: NSSet?
    @NSManaged public var stateLicenses: NSSet?

}

// MARK: Generated accessors for relationship
extension Provider {

    @objc(addRelationshipObject:)
    @NSManaged public func addToRelationship(_ value: DispencedMedication)

    @objc(removeRelationshipObject:)
    @NSManaged public func removeFromRelationship(_ value: DispencedMedication)

    @objc(addRelationship:)
    @NSManaged public func addToRelationship(_ values: NSSet)

    @objc(removeRelationship:)
    @NSManaged public func removeFromRelationship(_ values: NSSet)

}

// MARK: Generated accessors for stateLicenses
extension Provider {

    @objc(addStateLicensesObject:)
    @NSManaged public func addToStateLicenses(_ value: StateLicense)

    @objc(removeStateLicensesObject:)
    @NSManaged public func removeFromStateLicenses(_ value: StateLicense)

    @objc(addStateLicenses:)
    @NSManaged public func addToStateLicenses(_ values: NSSet)

    @objc(removeStateLicenses:)
    @NSManaged public func removeFromStateLicenses(_ values: NSSet)

}
