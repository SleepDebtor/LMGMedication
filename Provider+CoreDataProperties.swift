//
//  Provider+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//
//

public import Foundation
public import CoreData


public typealias ProviderCoreDataPropertiesSet = NSSet

extension Provider {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Provider> {
        return NSFetchRequest<Provider>(entityName: "Provider")
    }

    @NSManaged public var relationship: NSSet?

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
