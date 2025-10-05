//
//  SharingManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import Foundation
import SwiftUI
import CloudKit
import Combine

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
    
    private init() {}
    
    // MARK: - Patient Sharing
    
    func sharePatient(_ patient: Patient, with emailAddresses: [String] = []) async throws -> CKShare {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        shareProgress = "Creating participants..."
        let participants = try await createParticipants(from: emailAddresses)
        
        shareProgress = "Creating share..."
        return try await cloudManager.sharePatient(patient, with: participants)
    }
    
    func generatePatientShareLink(_ patient: Patient, with emailAddresses: [String] = []) async throws -> URL {
        let share = try await sharePatient(patient, with: emailAddresses)
        guard let url = share.url else {
            throw SharingError.invalidShareURL
        }
        return url
    }
    
    private func createParticipants(from emailAddresses: [String]) async throws -> [CKShare.Participant] {
        let container = CKContainer(identifier: "iCloud.com.lazarmedical.LMGMedication")
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
                var mutableParticipant = participant
                mutableParticipant.permission = CKShare.ParticipantPermission.readWrite
                participants.append(mutableParticipant)
            } catch {
                print("Failed to create participant for \(email): \(error)")
                // Continue with other participants
            }
        }
        
        return participants
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

struct ShareLabelButton: View {
    let medication: DispencedMedication
    @StateObject private var sharingManager = SharingManager.shared
    @State private var shareURL: URL?
    @State private var showLocalShare = false
    
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
            if let pdfData = shareURL?.data {
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
            
            // Create a temporary URL for local sharing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("medication_label_\(UUID().uuidString)")
                .appendingPathExtension("pdf")
            
            try pdfData.write(to: tempURL)
            
            await MainActor.run {
                shareURL = tempURL
                showLocalShare = true
            }
        } catch {
            await MainActor.run {
                sharingManager.lastError = SharingErrorWrapper(error)
            }
        }
    }
}

// MARK: - Helper Types

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - URL Extension for PDF Data

extension URL {
    var data: Data? {
        return try? Data(contentsOf: self)
    }
}

