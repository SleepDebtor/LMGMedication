//
//  StateLicense+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/16/25.
//
//

public import Foundation
public import CoreData


public typealias StateLicenseCoreDataPropertiesSet = NSSet

extension StateLicense {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StateLicense> {
        return NSFetchRequest<StateLicense>(entityName: "StateLicense")
    }

    @NSManaged public var controlledSub: String?
    @NSManaged public var number: String?
    @NSManaged public var state: String?
    @NSManaged public var provider: Provider?

}

extension StateLicense : Identifiable {

}
