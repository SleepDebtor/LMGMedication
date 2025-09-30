//
//  Patient+CoreDataClass.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//
//

public import Foundation
public import CoreData

public typealias PatientCoreDataClassSet = NSSet

@objc(Patient)
public class Patient: Person {
    
    public var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(last), \(first)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var displayName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        if !first.isEmpty && !last.isEmpty {
            return "\(first) \(last)"
        } else if !last.isEmpty {
            return last
        } else if !first.isEmpty {
            return first
        }
        return "Unknown Patient"
    }
    
    public var dispensedMedicationsArray: [DispencedMedication] {
        let set = medicationsPrescribed as? Set<DispencedMedication> ?? []
        return set.sorted { med1, med2 in
            let date1 = med1.dispenceDate ?? Date.distantPast
            let date2 = med2.dispenceDate ?? Date.distantPast
            return date1 > date2
        }
    }
}
