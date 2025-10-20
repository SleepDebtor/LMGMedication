//
//  CloudKitManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import Foundation
import CloudKit
import SwiftUI
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isSignedInToiCloud = false
    @Published var publicMedicationTemplates: [CloudMedicationTemplate] = []
    @Published var lastErrorMessage: String? = nil
    
    private init() {
        container = CKContainer(identifier: "iCloud.LMGMedications")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        checkAccountStatus()
        setupSubscriptions()
    }
    
    // MARK: - Account Management
    
    func checkAccountStatus() {
        Task {
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    self.accountStatus = status
                    self.isSignedInToiCloud = status == .available
                }
                
                if status == .available {
                    try await requestPermissions()
                    await loadPublicMedicationTemplates()
                }
            } catch {
                print("Error checking account status: \(error)")
                await MainActor.run { self.lastErrorMessage = error.localizedDescription }
            }
        }
    }
    
    private func requestPermissions() async throws {
        let status = try await container.requestApplicationPermission(.userDiscoverability)
        print("User discoverability permission: \(status)")
    }
    
    // MARK: - Public Medication Templates
    
    func loadPublicMedicationTemplates() async {
        let query = CKQuery(recordType: "PublicMedicationTemplate", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let templates = matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return CloudMedicationTemplate(from: record)
                case .failure(let error):
                    print("Error loading template: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.publicMedicationTemplates = templates
            }
        } catch {
            print("Error loading public medication templates: \(error)")
            await MainActor.run { self.lastErrorMessage = error.localizedDescription }
        }
    }
    
    func createPublicMedicationTemplate(_ template: CloudMedicationTemplate) async throws -> CloudMedicationTemplate {
        let record = template.toCKRecord()
         do {
             let savedRecord = try await publicDatabase.save(record)
             let newTemplate = CloudMedicationTemplate(from: savedRecord)
             await MainActor.run {
                 self.publicMedicationTemplates.append(newTemplate)
                 self.publicMedicationTemplates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
             }
             return newTemplate
         } catch {
             await MainActor.run { self.lastErrorMessage = error.localizedDescription }
             throw error
         }
    }
    
    func updatePublicMedicationTemplate(_ template: CloudMedicationTemplate) async throws -> CloudMedicationTemplate {
        do {
            // Fetch the existing record to obtain the current change tag
            let existing = try await publicDatabase.record(for: template.recordID)
            
            // Update fields on the fetched record
            existing["name"] = template.name as CKRecordValue
            existing["pharmacy"] = template.pharmacy as CKRecordValue?
            existing["ingredient1"] = template.ingredient1 as CKRecordValue?
            existing["concentration1"] = template.concentration1 as CKRecordValue
            existing["ingredient2"] = template.ingredient2 as CKRecordValue?
            existing["concentration2"] = template.concentration2 as CKRecordValue
            existing["injectable"] = template.injectable as CKRecordValue
            existing["pharmacyURL"] = template.pharmacyURL as CKRecordValue?
            existing["urlForQR"] = template.urlForQR as CKRecordValue?
            
            // Save the updated record (CloudKit will validate using the change tag)
            let savedRecord = try await publicDatabase.save(existing)
            let updated = CloudMedicationTemplate(from: savedRecord)
            await MainActor.run {
                if let idx = self.publicMedicationTemplates.firstIndex(where: { $0.recordID == updated.recordID }) {
                    self.publicMedicationTemplates[idx] = updated
                } else {
                    self.publicMedicationTemplates.append(updated)
                }
                self.publicMedicationTemplates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            return updated
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            await MainActor.run {
                self.lastErrorMessage = "This template was modified elsewhere. Please reload and try again."
            }
            throw ckError
        } catch {
            await MainActor.run { self.lastErrorMessage = error.localizedDescription }
            throw error
        }
    }
    
    func deletePublicMedicationTemplate(_ template: CloudMedicationTemplate) async throws {
         do {
             try await publicDatabase.deleteRecord(withID: template.recordID)
             await MainActor.run {
                 self.publicMedicationTemplates.removeAll { $0.recordID == template.recordID }
             }
         } catch {
             await MainActor.run { self.lastErrorMessage = error.localizedDescription }
             throw error
         }
    }

    /// Returns true if the current iCloud user is the creator of the template and can delete it.
    func canCurrentUserDeletePublicTemplate(_ template: CloudMedicationTemplate) async -> Bool {
        do {
            // Fetch the most recent record to inspect creator
            let record = try await publicDatabase.record(for: template.recordID)
            guard let creator = record.creatorUserRecordID else { return false }
            let currentUser = try await container.userRecordID()
            return creator == currentUser
        } catch {
            print("Failed to determine delete permission: \(error)")
            return false
        }
    }

    /// Attempts to delete the template only if the current user is allowed to do so.
    /// Throws a CKError(.permissionFailure) if not permitted.
    func deletePublicMedicationTemplateIfAllowed(_ template: CloudMedicationTemplate) async throws {
        let canDelete = await canCurrentUserDeletePublicTemplate(template)
        guard canDelete else {
            await MainActor.run { self.lastErrorMessage = "You don't have permission to delete this template." }
            throw CKError(.permissionFailure)
        }
        try await deletePublicMedicationTemplate(template)
    }
    
    // MARK: - Patient Sharing
    
    func sharePatient(_ patient: Patient, with participants: [CKShare.Participant]) async throws -> CKShare {
        // Ensure a custom zone exists for shareable records
        let zoneID = try await ensureSharedPatientsZoneExists()

        // Build patient record in the custom zone (do not save yet)
        let patientRecord = try createPatientRecord(from: patient, in: zoneID)

        // Build dispensed medication records in the same zone and parent them to the patient
        var medicationRecords: [CKRecord] = []
        for medication in patient.dispensedMedicationsArray {
            let medicationRecord = try createDispensedMedicationRecord(from: medication, patientRecordID: patientRecord.recordID, in: zoneID)
            medicationRecords.append(medicationRecord)
        }

        // Create a share for the patient record and configure participants
        let share = CKShare(rootRecord: patientRecord)
        share.publicPermission = .none
        for participant in participants {
            share.addParticipant(participant)
        }

        // Save patient + meds + share together so CloudKit can validate the hierarchy
        let recordsToSave: [CKRecord] = [patientRecord] + medicationRecords + [share]
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys

        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    print("Per-record save failure for \(recordID): \(error)")
                }
            }

            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .partialFailure,
                       let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                        for (rid, perRecordError) in partialErrors {
                            print("Partial failure for record \(rid): \(perRecordError)")
                        }
                    }
                    continuation.resume(throwing: error)
                    return
                }

                if let share = savedRecords.compactMap({ $0 as? CKShare }).first {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }

            self.privateDatabase.add(operation)
        }
    }

    // MARK: - Convenience Sharing by Email / Phone

    func sharePatient(_ patient: Patient, withEmailAddresses emails: [String]) async throws -> CKShare {
        let participants = try await participants(forEmails: emails, permission: .readWrite)
        return try await sharePatient(patient, with: participants)
    }

    func sharePatient(_ patient: Patient, withPhoneNumbers phoneNumbers: [String]) async throws -> CKShare {
        let participants = try await participants(forPhoneNumbers: phoneNumbers, permission: .readWrite)
        return try await sharePatient(patient, with: participants)
    }

    func resolveParticipants(emails: [String] = [], phoneNumbers: [String] = [], permission: CKShare.ParticipantPermission = .readWrite) async throws -> [CKShare.Participant] {
        let emailParts = try await participants(forEmails: emails, permission: permission)
        let phoneParts = try await participants(forPhoneNumbers: phoneNumbers, permission: permission)
        return emailParts + phoneParts
    }

    private func participant(forEmail email: String, permission: CKShare.ParticipantPermission = .readWrite) async throws -> CKShare.Participant {
        let fetched = try await fetchShareParticipant(email: email)
        var participant = fetched
        participant.permission = permission
        return participant
    }

    private func participants(forEmails emails: [String], permission: CKShare.ParticipantPermission = .readWrite) async throws -> [CKShare.Participant] {
        var results: [CKShare.Participant] = []
        for email in emails {
            do {
                let p = try await participant(forEmail: email, permission: permission)
                results.append(p)
            } catch {
                print("Failed to resolve participant for email \(email): \(error)")
                await MainActor.run { self.lastErrorMessage = error.localizedDescription }
                throw error
            }
        }
        return results
    }

    private func participant(forPhoneNumber phone: String, permission: CKShare.ParticipantPermission = .readWrite) async throws -> CKShare.Participant {
        let fetched = try await fetchShareParticipant(phoneNumber: phone)
        var participant = fetched
        participant.permission = permission
        return participant
    }

    private func participants(forPhoneNumbers phones: [String], permission: CKShare.ParticipantPermission = .readWrite) async throws -> [CKShare.Participant] {
        var results: [CKShare.Participant] = []
        for phone in phones {
            do {
                let p = try await participant(forPhoneNumber: phone, permission: permission)
                results.append(p)
            } catch {
                print("Failed to resolve participant for phone \(phone): \(error)")
                await MainActor.run { self.lastErrorMessage = error.localizedDescription }
                throw error
            }
        }
        return results
    }
    
    // MARK: - Share Participant Fetch Helpers (Async wrappers)
    private func fetchShareParticipant(email: String) async throws -> CKShare.Participant {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchShareParticipant(withEmailAddress: email) { participant, error in
                if let participant = participant {
                    continuation.resume(returning: participant)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }

    private func fetchShareParticipant(phoneNumber: String) async throws -> CKShare.Participant {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchShareParticipant(withPhoneNumber: phoneNumber) { participant, error in
                if let participant = participant {
                    continuation.resume(returning: participant)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }
    
    private func ensureSharedPatientsZoneExists() async throws -> CKRecordZone.ID {
        let zoneID = CKRecordZone.ID(zoneName: "SharedPatients", ownerName: CKCurrentUserDefaultName)
        // Try to fetch the zone; if it doesn't exist, create it
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
            return zoneID
        } catch {
            // Create the zone
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await privateDatabase.save(zone)
            return zoneID
        }
    }
    
    private func createPatientRecord(from patient: Patient, in zoneID: CKRecordZone.ID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SharedPatient", recordID: recordID)
        record["firstName"] = patient.firstName
        record["lastName"] = patient.lastName
        record["birthdate"] = patient.birthdate
        record["timeStamp"] = patient.timeStamp
        return record
    }
    
    private func createDispensedMedicationRecord(from medication: DispencedMedication, patientRecordID: CKRecord.ID, in zoneID: CKRecordZone.ID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SharedDispensedMedication", recordID: recordID)

        // Parent the medication to the patient so it is included in the share hierarchy
        record.parent = CKRecord.Reference(recordID: patientRecordID, action: .none)

        record["dose"] = medication.dose
        record["doseUnit"] = medication.doseUnit
        record["dispenceAmt"] = medication.dispenceAmt
        record["dispenceUnit"] = medication.dispenceUnit
        record["dispenceDate"] = medication.dispenceDate
        record["expDate"] = medication.expDate
        record["lotNum"] = medication.lotNum
        // record["creationDate"] = medication.creationDate

        // Medication details
        if let baseMedication = medication.baseMedication {
            record["medicationName"] = baseMedication.name
            record["ingredient1"] = baseMedication.ingredient1
            record["concentration1"] = baseMedication.concentration1
            record["ingredient2"] = baseMedication.ingredient2
            record["concentration2"] = baseMedication.concentration2
            record["pharmacy"] = baseMedication.pharmacy
            record["injectable"] = baseMedication.injectable
        }

        // Prescriber details
        if let prescriber = medication.prescriber {
            record["prescriberFirstName"] = prescriber.firstName
            record["prescriberLastName"] = prescriber.lastName
        }

        return record
    }
    
    // MARK: - PDF Sharing
    
    func shareLabelPDF(data: Data, for medication: DispencedMedication, participants: [CKShare.Participant] = []) async throws -> CKShare {
        // Create a temporary file for the PDF data
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        try data.write(to: tempFileURL)
        
        // Create a CloudKit record for the PDF
        let pdfRecord = CKRecord(recordType: "SharedLabelPDF")
        pdfRecord["pdfData"] = CKAsset(fileURL: tempFileURL)
        pdfRecord["medicationName"] = medication.displayName
        pdfRecord["patientName"] = medication.patient?.displayName
        pdfRecord["createdDate"] = Date()
        
        let savedPDFRecord = try await privateDatabase.save(pdfRecord)
        
        // Clean up the temporary file
        try? FileManager.default.removeItem(at: tempFileURL)
        
        // Create a share for the PDF
        let share = CKShare(rootRecord: savedPDFRecord)
        // Configure sharing: if participants are provided, restrict to selected users; otherwise allow read-only public access for backward compatibility
        if participants.isEmpty {
            share.publicPermission = .readOnly
        } else {
            share.publicPermission = .none
            for participant in participants {
                share.addParticipant(participant)
            }
        }
        
        // Save the share and PDF record together
        let operation = CKModifyRecordsOperation(recordsToSave: [savedPDFRecord, share], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { recordID, result in
                if case .success(let record) = result {
                    savedRecords.append(record)
                }
            }

            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let share = savedRecords.compactMap({ $0 as? CKShare }).first {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }

            privateDatabase.add(operation)
        }
    }
    
    func shareLabelPDF(data: Data, for medication: DispencedMedication, emailAddresses: [String]) async throws -> CKShare {
        let participants = try await participants(forEmails: emailAddresses, permission: .readOnly)
        return try await shareLabelPDF(data: data, for: medication, participants: participants)
    }

    func shareLabelPDF(data: Data, for medication: DispencedMedication, phoneNumbers: [String]) async throws -> CKShare {
        let participants = try await participants(forPhoneNumbers: phoneNumbers, permission: .readOnly)
        return try await shareLabelPDF(data: data, for: medication, participants: participants)
    }
    
    // MARK: - Subscription Management
    
    private func setupSubscriptions() {
        Task {
            await setupPublicTemplateSubscription()
        }
    }
    
    private func setupPublicTemplateSubscription() async {
        let subscriptionID = "public-medication-templates-subscription"
        
        do {
            // Check if subscription already exists
            let existingSubscriptions = try await publicDatabase.allSubscriptions()
            if existingSubscriptions.contains(where: { $0.subscriptionID == subscriptionID }) {
                print("Subscription already exists")
                return
            }
            
            // Create new subscription
            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(
                recordType: "PublicMedicationTemplate",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let notification = CKSubscription.NotificationInfo()
            notification.shouldBadge = false
            notification.shouldSendContentAvailable = true
            subscription.notificationInfo = notification
            
            _ = try await publicDatabase.save(subscription)
            print("Successfully created subscription")
        } catch {
            print("Error setting up subscription: \(error)")
            await MainActor.run { self.lastErrorMessage = error.localizedDescription }
        }
    }
    
    // MARK: - Helper Methods
    

    
    private func saveRecords(_ records: [CKRecord], to database: CKDatabase) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: savedRecords ?? [])
                }
            }
            database.add(operation)
        }
    }
    
    // MARK: - Notification Handling
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        if let queryNotification = notification as? CKQueryNotification {
            if queryNotification.subscriptionID == "public-medication-templates-subscription" {
                Task {
                    await loadPublicMedicationTemplates()
                }
            }
        }
    }
}

// MARK: - CloudMedicationTemplate Model

struct CloudMedicationTemplate: Identifiable, Codable, Hashable {
    let id: String
    let recordID: CKRecord.ID
    let name: String
    let pharmacy: String?
    let ingredient1: String?
    let concentration1: Double
    let ingredient2: String?
    let concentration2: Double
    let injectable: Bool
    let pharmacyURL: String?
    let urlForQR: String?
    let createdDate: Date
    let modifiedDate: Date
    let createdBy: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case id
        case recordName
        case name
        case pharmacy
        case ingredient1
        case concentration1
        case ingredient2
        case concentration2
        case injectable
        case pharmacyURL
        case urlForQR
        case createdDate
        case modifiedDate
        case createdBy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        let recordName = try container.decode(String.self, forKey: .recordName)
        recordID = CKRecord.ID(recordName: recordName)
        name = try container.decode(String.self, forKey: .name)
        pharmacy = try container.decodeIfPresent(String.self, forKey: .pharmacy)
        ingredient1 = try container.decodeIfPresent(String.self, forKey: .ingredient1)
        concentration1 = try container.decode(Double.self, forKey: .concentration1)
        ingredient2 = try container.decodeIfPresent(String.self, forKey: .ingredient2)
        concentration2 = try container.decode(Double.self, forKey: .concentration2)
        injectable = try container.decode(Bool.self, forKey: .injectable)
        pharmacyURL = try container.decodeIfPresent(String.self, forKey: .pharmacyURL)
        urlForQR = try container.decodeIfPresent(String.self, forKey: .urlForQR)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(recordID.recordName, forKey: .recordName)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(pharmacy, forKey: .pharmacy)
        try container.encodeIfPresent(ingredient1, forKey: .ingredient1)
        try container.encode(concentration1, forKey: .concentration1)
        try container.encodeIfPresent(ingredient2, forKey: .ingredient2)
        try container.encode(concentration2, forKey: .concentration2)
        try container.encode(injectable, forKey: .injectable)
        try container.encodeIfPresent(pharmacyURL, forKey: .pharmacyURL)
        try container.encodeIfPresent(urlForQR, forKey: .urlForQR)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
    }
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.recordID = record.recordID
        self.name = record["name"] as? String ?? ""
        self.pharmacy = record["pharmacy"] as? String
        self.ingredient1 = record["ingredient1"] as? String
        self.concentration1 = record["concentration1"] as? Double ?? 0.0
        self.ingredient2 = record["ingredient2"] as? String
        self.concentration2 = record["concentration2"] as? Double ?? 0.0
        self.injectable = record["injectable"] as? Bool ?? false
        self.pharmacyURL = record["pharmacyURL"] as? String
        self.urlForQR = record["urlForQR"] as? String
        // Use current date as fallback for unsaved records
        let currentDate = Date()
        self.createdDate = record.creationDate ?? currentDate
        self.modifiedDate = record.modificationDate ?? currentDate
        self.createdBy = record.creatorUserRecordID?.recordName
    }
    
    init(
        id: String,
        recordID: CKRecord.ID,
        name: String,
        pharmacy: String?,
        ingredient1: String?,
        concentration1: Double,
        ingredient2: String?,
        concentration2: Double,
        injectable: Bool,
        pharmacyURL: String?,
        urlForQR: String?,
        createdDate: Date,
        modifiedDate: Date,
        createdBy: String?
    ) {
        self.id = id
        self.recordID = recordID
        self.name = name
        self.pharmacy = pharmacy
        self.ingredient1 = ingredient1
        self.concentration1 = concentration1
        self.ingredient2 = ingredient2
        self.concentration2 = concentration2
        self.injectable = injectable
        self.pharmacyURL = pharmacyURL
        self.urlForQR = urlForQR
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.createdBy = createdBy
    }
    
    init(name: String, pharmacy: String? = nil, ingredient1: String? = nil, concentration1: Double = 0.0, ingredient2: String? = nil, concentration2: Double = 0.0, injectable: Bool = false, pharmacyURL: String? = nil, urlForQR: String? = nil) {
        self.id = UUID().uuidString
        self.recordID = CKRecord.ID(recordName: id)
        self.name = name
        self.pharmacy = pharmacy
        self.ingredient1 = ingredient1
        self.concentration1 = concentration1
        self.ingredient2 = ingredient2
        self.concentration2 = concentration2
        self.injectable = injectable
        self.pharmacyURL = pharmacyURL
        self.urlForQR = urlForQR
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.createdBy = nil
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "PublicMedicationTemplate", recordID: recordID)
        record["name"] = name
        record["pharmacy"] = pharmacy
        record["ingredient1"] = ingredient1
        record["concentration1"] = concentration1
        record["ingredient2"] = ingredient2
        record["concentration2"] = concentration2
        record["injectable"] = injectable
        record["pharmacyURL"] = pharmacyURL
        record["urlForQR"] = urlForQR
        return record
    }
    
    // MARK: - Hashable Implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CloudMedicationTemplate, rhs: CloudMedicationTemplate) -> Bool {
        return lhs.id == rhs.id
    }
}

extension CloudMedicationTemplate {
    var displayName: String {
        return name
    }
    
    var concentrationInfo: String {
        var parts: [String] = []
        
        if let ingredient1 = ingredient1, !ingredient1.isEmpty, concentration1 > 0 {
            parts.append("\(ingredient1): \(String(format: "%.1f", concentration1))")
        }
        
        if let ingredient2 = ingredient2, !ingredient2.isEmpty, concentration2 > 0 {
            parts.append("\(ingredient2): \(String(format: "%.1f", concentration2))")
        }
        
        return parts.joined(separator: ", ")
    }
}

