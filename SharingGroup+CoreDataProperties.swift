//
//  SharingGroup+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/7/25.
//
//

public import Foundation
public import CoreData


public typealias SharingGroupCoreDataPropertiesSet = NSSet

extension SharingGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharingGroup> {
        return NSFetchRequest<SharingGroup>(entityName: "SharingGroup")
    }

    @NSManaged public var name: String?
    @NSManaged public var participantEmails: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var autoShareNewPatients: Bool
    @NSManaged public var createdDate: Date?
    @NSManaged public var cloudKitRecordID: String?

}

extension SharingGroup : Identifiable {

}
