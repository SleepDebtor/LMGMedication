//
//  SharingTests.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import XCTest
import Foundation
import CoreData
@testable import LMGMedication

// Explicitly qualify the SharingGroup to avoid ambiguity with CloudKit types
typealias LMGSharingGroup = SharingGroup

class SharingGroupTests: XCTestCase {
    
    var persistentContainer: NSPersistentContainer {
        let container = NSPersistentContainer(name: "LMGMedication")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        return container
    }
    
    func testCreateSharingGroup() async throws {
        let context = persistentContainer.viewContext
        
        let sharingGroup = LMGSharingGroup(context: context)
        sharingGroup.name = "Test Group"
        sharingGroup.addParticipantEmail("test@example.com")
        
        XCTAssertEqual(sharingGroup.name, "Test Group")
        XCTAssertTrue(sharingGroup.participantEmailsArray.contains("test@example.com"))
        XCTAssertTrue(sharingGroup.isActive) // Should be set in awakeFromInsert
        XCTAssertEqual(sharingGroup.participantCount, 1)
    }
    
    func testManageParticipantEmails() async throws {
        let context = persistentContainer.viewContext
        
        let sharingGroup = LMGSharingGroup(context: context)
        
        // Test adding emails
        sharingGroup.addParticipantEmail("user1@example.com")
        sharingGroup.addParticipantEmail("user2@example.com")
        
        XCTAssertEqual(sharingGroup.participantCount, 2)
        XCTAssertTrue(sharingGroup.participantEmailsArray.contains("user1@example.com"))
        XCTAssertTrue(sharingGroup.participantEmailsArray.contains("user2@example.com"))
        
        // Test removing email
        sharingGroup.removeParticipantEmail("user1@example.com")
        
        XCTAssertEqual(sharingGroup.participantCount, 1)
        XCTAssertFalse(sharingGroup.participantEmailsArray.contains("user1@example.com"))
        XCTAssertTrue(sharingGroup.participantEmailsArray.contains("user2@example.com"))
    }
    
    func testDisplayName() async throws {
        let context = persistentContainer.viewContext
        
        let namedGroup = LMGSharingGroup(context: context)
        namedGroup.name = "My Practice"
        XCTAssertEqual(namedGroup.displayName, "My Practice")
        
        let unnamedGroup = LMGSharingGroup(context: context)
        XCTAssertEqual(unnamedGroup.displayName, "Unnamed Group")
    }
}