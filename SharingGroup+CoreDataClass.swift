//
//  SharingGroup+CoreDataClass.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/7/25.
//

import Foundation
import CoreData
import CloudKit

/**
 * SharingGroup
 * 
 * Core Data entity representing a group of users who automatically share patients.
 * This enables persistent sharing relationships where new patients are automatically
 * shared with all group members.
 * 
 * Key Features:
 * - Persistent sharing relationships
 * - Automatic patient sharing for group members
 * - CloudKit synchronization for cross-device sharing groups
 * - Email-based participant management
 * 
 * Usage:
 * ```swift
 * let group = SharingGroup(context: viewContext)
 * group.name = "My Practice Group"
 * group.addParticipantEmail("colleague@example.com")
 * ```
 */
@objc(SharingGroup)
public class SharingGroup: NSManagedObject {
    
    /**
     * Called when a new SharingGroup entity is inserted into Core Data
     */
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.isActive = true
        self.createdDate = Date()
        self.cloudKitRecordID = UUID().uuidString
    }
    
    /**
     * Array of participant email addresses
     */
    public var participantEmailsArray: [String] {
        get {
            guard let emailsString = participantEmails, !emailsString.isEmpty else { return [] }
            return emailsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            participantEmails = newValue.joined(separator: ",")
        }
    }
    
    /**
     * Adds an email address to the sharing group
     */
    public func addParticipantEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else { return }
        
        var emails = participantEmailsArray
        if !emails.contains(trimmedEmail) {
            emails.append(trimmedEmail)
            participantEmailsArray = emails
        }
    }
    
    /**
     * Removes an email address from the sharing group
     */
    public func removeParticipantEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        var emails = participantEmailsArray
        emails.removeAll { $0 == trimmedEmail }
        participantEmailsArray = emails
    }
    
    /**
     * Display name for the sharing group
     */
    public var displayName: String {
        return name ?? "Unnamed Group"
    }
    
    /**
     * Number of participants in the group
     */
    public var participantCount: Int {
        return participantEmailsArray.count
    }
}