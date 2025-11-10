//
//  SharingManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import Foundation
import SwiftUI
import Combine
import CloudKit
import UIKit
internal import CoreData

// MARK: - Error Wrapper for ObservableObject Conformance

struct SharingErrorWrapper: Identifiable, Equatable {
    let id = UUID()
    let error: Error
    let localizedDescription: String
    
    init(_ error: Error) {
        self.error = error
        self.localizedDescription = error.localizedDescription
    }
    
    static func == (lhs: SharingErrorWrapper, rhs: SharingErrorWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class SharingManager: ObservableObject {
    static let shared = SharingManager()
    private let cloudManager = CloudKitManager.shared
    
    @Published var isSharing = false
    @Published var lastError: SharingErrorWrapper?
    @Published var shareProgress: String = ""
    @Published var sharedPatients: [CKRecord] = []
    @Published var hasSharedContent = false
    
    private init() {}
    
    // MARK: - Sharing Groups Integration
    
    /// Shares all existing patients with a newly created sharing group
    func shareExistingPatientsWithGroup(_ group: SharingGroup) async throws {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        guard group.autoShareNewPatients else { return }
        
        shareProgress = "Fetching existing patients..."
        
        // Use a background context for the patient fetch to avoid blocking UI
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        await backgroundContext.perform {
            let request: NSFetchRequest<Patient> = Patient.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            
            do {
                let patients = try backgroundContext.fetch(request)
                
                Task {
                    await self.sharePatients(patients, with: group.participantEmailsArray)
                }
            } catch {
                Task {
                    await MainActor.run {
                        self.lastError = SharingErrorWrapper(error)
                    }
                }
            }
        }
    }
    
    /// Shares multiple patients with a list of email addresses
    private func sharePatients(_ patients: [Patient], with emailAddresses: [String]) async {
        guard !emailAddresses.isEmpty else { return }
        
        let totalPatients = patients.count
        
        for (index, patient) in patients.enumerated() {
            shareProgress = "Sharing patient \(index + 1) of \(totalPatients)..."
            
            do {
                _ = try await sharePatient(patient, with: emailAddresses)
                
                // Add delay to avoid overwhelming CloudKit
                if index < patients.count - 1 {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } catch {
                print("Failed to share patient \(patient.displayName): \(error)")
                // Continue with other patients rather than failing completely
            }
        }
        
        await MainActor.run {
            shareProgress = ""
            isSharing = false
        }
    }
    
    // MARK: - Patient Sharing
    
    func sharePatient(_ patient: Patient, with emailAddresses: [String] = []) async throws -> CKShare {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        print("🔄 SharingManager: Starting to share patient \(patient.displayName) with \(emailAddresses.count) email(s)")
        
        shareProgress = "Creating participants..."
        let participants = try await createParticipants(from: emailAddresses)
        
        shareProgress = "Creating share..."
        do {
            let share = try await cloudManager.sharePatient(patient, with: participants)
            print("✅ SharingManager: Successfully created share for patient \(patient.displayName)")
            return share
        } catch {
            print("❌ SharingManager: Failed to share patient \(patient.displayName): \(error)")
            
            // Provide more specific error messages
            if let ckError = error as? CKError {
                switch ckError.code {
                case .quotaExceeded:
                    throw SharingError.quotaExceeded
                case .networkUnavailable, .networkFailure:
                    throw SharingError.networkError
                case .partialFailure:
                    // Get details about what failed
                    var failureDetails = "Unknown partial failure"
                    if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                        let errorCount = partialErrors.count
                        failureDetails = "\(errorCount) record(s) failed to save"
                    }
                    throw SharingError.partialFailure(details: failureDetails)
                case .unknownItem:
                    throw SharingError.recordNotFound
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    func generatePatientShareLink(_ patient: Patient, with emailAddresses: [String] = []) async throws -> URL {
        let share = try await sharePatient(patient, with: emailAddresses)
        guard let url = share.url else {
            throw SharingError.invalidShareURL
        }
        return url
    }
    
    private func createParticipants(from emailAddresses: [String]) async throws -> [CKShare.Participant] {
        let container = CKContainer(identifier: CloudKitConstants.containerIdentifier)
        var participants: [CKShare.Participant] = []
        
        func fetchParticipant(for email: String) async throws -> CKShare.Participant {
            try await withCheckedThrowingContinuation { continuation in
                container.fetchShareParticipant(withEmailAddress: email) { participant, error in
                    if let participant = participant {
                        continuation.resume(returning: participant)
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: SharingError.userNotFound(email: email))
                    }
                }
            }
        }
        
        for email in emailAddresses {
            do {
                let participant = try await fetchParticipant(for: email)
                let mutableParticipant = participant
                mutableParticipant.permission = CKShare.ParticipantPermission.readWrite
                participants.append(mutableParticipant)
            } catch {
                print("Failed to create participant for \(email): \(error)")
                // Continue with other participants
            }
        }
        
        return participants
    }
    
    // MARK: - Shared Records Management
    
    /// Fetches shared patient records from the shared database
    func fetchSharedPatients() async throws -> [CKRecord] {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        let query = CKQuery(recordType: "Patient", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        do {
            // Use CloudKitManager's method to access shared database
            return try await cloudManager.fetchSharedPatients()
        } catch {
            print("Failed to fetch shared patients: \(error)")
            throw error
        }
    }
    
    /// Accepts a share by processing the share URL
    func acceptShare(from url: URL) async throws {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        print("🔗 Attempting to accept share from URL: \(url.absoluteString)")
        shareProgress = "Accepting share invitation..."
        
        do {
            // Try to get access to the URL first
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                print("✅ Successfully gained access to security-scoped resource")
            } else {
                print("⚠️ Could not access security-scoped resource, continuing anyway...")
            }
            
            // Use CloudKitManager's method to accept shares
            try await cloudManager.acceptShare(from: url)
            print("✅ Successfully accepted share: \(url.absoluteString)")
            
            // Refresh shared content after acceptance
            await refreshSharedContent()
            
        } catch {
            print("❌ Failed to accept share: \(error)")
            
            // Handle specific sandbox/security errors
            if let nsError = error as NSError? {
                if nsError.domain == "NSCocoaErrorDomain" && nsError.code == 257 {
                    // Sandbox extension error
                    throw SharingError.shareAcceptanceFailed
                }
            }
            
            if let ckError = error as? CKError {
                switch ckError.code {
                case .networkUnavailable, .networkFailure:
                    throw SharingError.networkError
                case .quotaExceeded:
                    throw SharingError.quotaExceeded
                case .unknownItem:
                    throw SharingError.recordNotFound
                default:
                    throw error
                }
            }
            
            throw error
        }
    }
    
    /// Refreshes shared content from all accepted shares
    private func refreshSharedContent() async {
        do {
            let sharedPatientRecords = try await fetchSharedPatients()
            
            await MainActor.run {
                self.sharedPatients = sharedPatientRecords
                self.hasSharedContent = !sharedPatientRecords.isEmpty
                self.shareProgress = ""
            }
        } catch {
            await MainActor.run {
                self.lastError = SharingErrorWrapper(error)
                self.shareProgress = ""
            }
        }
    }
    
    /// Loads shared content on app startup
    func loadSharedContent() async {
        guard cloudManager.isSignedInToiCloud else { return }
        
        await refreshSharedContent()
    }
    
    /// Converts a CloudKit patient record to displayable information
    func patientInfo(from record: CKRecord) -> (name: String, id: String) {
        let firstName = record["firstName"] as? String ?? ""
        let lastName = record["lastName"] as? String ?? ""
        let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let recordID = record.recordID.recordName
        
        return (name: displayName.isEmpty ? "Unknown Patient" : displayName, id: recordID)
    }
    
    /// Checks if the current user can modify a shared record
    func canModifySharedRecord(_ record: CKRecord) -> Bool {
        // Check if the current user has write permissions
        // This is a simplified check - you might need more sophisticated logic
        return record.creatorUserRecordID != nil
    }
    
    // MARK: - Label PDF Sharing
    
    func shareLabelPDF(data: Data, for medication: DispencedMedication) async throws -> CKShare {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        shareProgress = "Creating PDF share..."
        return try await cloudManager.shareLabelPDF(data: data, for: medication)
    }
    
    func generateLabelPDFShareLink(data: Data, for medication: DispencedMedication) async throws -> URL {
        let share = try await shareLabelPDF(data: data, for: medication)
        guard let url = share.url else {
            throw SharingError.invalidShareURL
        }
        return url
    }
    
    func generateAndShareLabelPDF(for medication: DispencedMedication) async throws -> URL {
        shareProgress = "Generating PDF..."
        guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
            throw SharingError.pdfGenerationFailed
        }
        
        shareProgress = "Creating share..."
        return try await generateLabelPDFShareLink(data: pdfData, for: medication)
    }
}

// MARK: - Sharing Error

enum SharingError: LocalizedError {
    case notSignedInToiCloud
    case sharingNotAvailable
    case invalidShareURL
    case pdfGenerationFailed
    case userNotFound(email: String)
    case participantCreationFailed
    case shareAcceptanceFailed
    case sharedContentUnavailable
    case recordNotFound
    case networkError
    case quotaExceeded
    case partialFailure(details: String)
    
    var errorDescription: String? {
        switch self {
        case .notSignedInToiCloud:
            return "Please sign in to iCloud to share patient data"
        case .sharingNotAvailable:
            return "Sharing is not available on this device"
        case .invalidShareURL:
            return "Failed to generate share URL"
        case .pdfGenerationFailed:
            return "Failed to generate PDF label"
        case .userNotFound(let email):
            return "User with email \(email) not found in iCloud"
        case .participantCreationFailed:
            return "Failed to create sharing participants"
        case .shareAcceptanceFailed:
            return "Failed to accept share invitation"
        case .sharedContentUnavailable:
            return "Shared content is not available"
        case .recordNotFound:
            return "Patient record not found in iCloud. Please try syncing first."
        case .networkError:
            return "Network connection required for sharing. Please check your connection."
        case .quotaExceeded:
            return "iCloud storage limit reached. Please free up space or upgrade your plan."
        case .partialFailure(let details):
            return "Some records couldn't be shared: \(details)"
        }
    }
}

// MARK: - SwiftUI View Extensions for Sharing

struct SharePatientButton: View {
    let patient: Patient
    @StateObject private var sharingManager = SharingManager.shared
    @State private var showingParticipantSelection = false
    @State private var shareURL: URL?
    @State private var selectedEmails: [String] = []
    
    var body: some View {
        Button(action: {
            showingParticipantSelection = true
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Patient")
                if sharingManager.isSharing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .disabled(sharingManager.isSharing)
        .opacity(sharingManager.isSharing ? 0.6 : 1.0)
        .sheet(isPresented: $showingParticipantSelection) {
            ParticipantSelectionView { emails in
                selectedEmails = emails
                Task {
                    await sharePatient()
                }
            }
        }
        .sheet(item: Binding<ShareURLItem?>(
            get: { shareURL.map { ShareURLItem(url: $0) } },
            set: { _ in shareURL = nil }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Sharing Error", isPresented: .constant(sharingManager.lastError != nil)) {
            Button("OK") {
                sharingManager.lastError = nil
            }
        } message: {
            if let errorWrapper = sharingManager.lastError {
                Text(errorWrapper.localizedDescription)
            }
        }
        .overlay(alignment: .bottom) {
            if sharingManager.isSharing && !sharingManager.shareProgress.isEmpty {
                Text(sharingManager.shareProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .offset(y: 30)
            }
        }
    }
    
    private func sharePatient() async {
        do {
            let url = try await sharingManager.generatePatientShareLink(patient, with: selectedEmails)
            await MainActor.run {
                shareURL = url
            }
        } catch {
            await MainActor.run {
                sharingManager.lastError = SharingErrorWrapper(error)
            }
        }
    }
}

// MARK: - Share Invitation Acceptance View

struct ShareInvitationView: View {
    let shareURL: URL
    @StateObject private var sharingManager = SharingManager.shared
    @State private var showingAcceptanceResult = false
    @State private var acceptanceSuccessful = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Share Invitation")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You've been invited to access shared patient data. Accept this invitation to collaborate with your colleagues.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if sharingManager.isSharing {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
            }
            
            HStack(spacing: 15) {
                Button("Decline") {
                    // Handle decline - just dismiss
                }
                .buttonStyle(.bordered)
                
                Button("Accept") {
                    Task {
                        await acceptInvitation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sharingManager.isSharing)
            }
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .alert("Invitation Result", isPresented: $showingAcceptanceResult) {
            Button("OK") { }
        } message: {
            Text(acceptanceSuccessful ? "Successfully joined the sharing group!" : "Failed to accept invitation. Please try again.")
        }
    }
    
    private func acceptInvitation() async {
        do {
            try await sharingManager.acceptShare(from: shareURL)
            await MainActor.run {
                acceptanceSuccessful = true
                showingAcceptanceResult = true
            }
        } catch {
            await MainActor.run {
                acceptanceSuccessful = false
                showingAcceptanceResult = true
                sharingManager.lastError = SharingErrorWrapper(error)
            }
        }
    }
}

// MARK: - Shared Patients View

struct SharedPatientsView: View {
    @StateObject private var sharingManager = SharingManager.shared
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading shared patients...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sharingManager.sharedPatients.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Shared Patients")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You haven't accepted any shared patient invitations yet.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sharingManager.sharedPatients, id: \.recordID.recordName) { record in
                            SharedPatientRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("Shared Patients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await refreshSharedContent()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            Task {
                await loadSharedPatients()
            }
        }
        .alert("Error", isPresented: .constant(sharingManager.lastError != nil)) {
            Button("OK") {
                sharingManager.lastError = nil
            }
        } message: {
            if let errorWrapper = sharingManager.lastError {
                Text(errorWrapper.localizedDescription)
            }
        }
    }
    
    private func loadSharedPatients() async {
        isLoading = true
        await sharingManager.loadSharedContent()
        isLoading = false
    }
    
    private func refreshSharedContent() async {
        isLoading = true
        await sharingManager.loadSharedContent()
        isLoading = false
    }
}

struct SharedPatientRow: View {
    let record: CKRecord
    @StateObject private var sharingManager = SharingManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                let patientInfo = sharingManager.patientInfo(from: record)
                
                Text(patientInfo.name)
                    .font(.headline)
                
                Text("Shared Patient")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let modificationDate = record.modificationDate {
                    Text("Modified: \(modificationDate, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                
                if sharingManager.canModifySharedRecord(record) {
                    Text("Can Edit")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Read Only")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Label Button

struct ShareLabelButton: View {
    let medication: DispencedMedication
    @StateObject private var sharingManager = SharingManager.shared
    @State private var shareURL: URL?
    @State private var showLocalShare = false
    @State private var localPDFData: Data?
    
    var body: some View {
        Menu {
            Button(action: {
                Task {
                    await shareToCloud()
                }
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("Share via iCloud")
                }
            }
            .disabled(sharingManager.isSharing)
            
            Button(action: {
                Task {
                    await shareLocally()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square")
                    Text("Share PDF Locally")
                }
            }
            .disabled(sharingManager.isSharing)
            
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up.on.square")
                Text("Share Label")
                if sharingManager.isSharing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .disabled(sharingManager.isSharing)
        .opacity(sharingManager.isSharing ? 0.6 : 1.0)
        .sheet(item: Binding<ShareURLItem?>(
            get: { shareURL.map { ShareURLItem(url: $0) } },
            set: { _ in shareURL = nil }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showLocalShare) {
            if let pdfData = localPDFData {
                ShareSheet(activityItems: [pdfData])
            }
        }
        .alert("Sharing Error", isPresented: .constant(sharingManager.lastError != nil)) {
            Button("OK") {
                sharingManager.lastError = nil
            }
        } message: {
            if let errorWrapper = sharingManager.lastError {
                Text(errorWrapper.localizedDescription)
            }
        }
        .overlay(alignment: .bottom) {
            if sharingManager.isSharing && !sharingManager.shareProgress.isEmpty {
                Text(sharingManager.shareProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .offset(y: 30)
            }
        }
    }
    
    private func shareToCloud() async {
        do {
            let url = try await sharingManager.generateAndShareLabelPDF(for: medication)
            await MainActor.run {
                shareURL = url
            }
        } catch {
            await MainActor.run {
                sharingManager.lastError = SharingErrorWrapper(error)
            }
        }
    }
    
    private func shareLocally() async {
        do {
            guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
                throw SharingError.pdfGenerationFailed
            }
            
            await MainActor.run {
                localPDFData = pdfData
                showLocalShare = true
            }
        } catch {
            await MainActor.run {
                sharingManager.lastError = SharingErrorWrapper(error)
            }
        }
    }
}

// MARK: - Helper Classes for Sharing

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}