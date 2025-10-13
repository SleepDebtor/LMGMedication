//
//  Person+CoreDataProperties.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//
//

public import Foundation
public import CoreData


public typealias PersonCoreDataPropertiesSet = NSSet

extension Person {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Person> {
        return NSFetchRequest<Person>(entityName: "Person")
    }

    @NSManaged public var birthdate: Date?
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var middleName: String?
    @NSManaged public var timeStamp: Date?
    @NSManaged public var isActive: Bool

}

extension Person : Identifiable {

}
