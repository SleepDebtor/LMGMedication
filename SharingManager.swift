//
//  SharingManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import Foundation
import SwiftUI
import CloudKit

struct SharingManager {
    static let shared = SharingManager()
    private let cloudManager = CloudKitManager.shared
    
    private init() {}
    
    // MARK: - Patient Sharing
    
    func sharePatient(_ patient: Patient) async throws -> CKShare {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        // Create participants (in a real app, you'd have a way to select users)
        let participants: [CKShare.Participant] = []
        
        return try await cloudManager.sharePatient(patient, with: participants)
    }
    
    func generatePatientShareLink(_ patient: Patient) async throws -> URL {
        let share = try await sharePatient(patient)
        return share.url ?? URL(string: "about:blank")!
    }
    
    // MARK: - Label PDF Sharing
    
    func shareLabelPDF(data: Data, for medication: DispencedMedication) async throws -> CKShare {
        guard cloudManager.isSignedInToiCloud else {
            throw SharingError.notSignedInToiCloud
        }
        
        return try await cloudManager.shareLabelPDF(data: data, for: medication)
    }
    
    func generateLabelPDFShareLink(data: Data, for medication: DispencedMedication) async throws -> URL {
        let share = try await shareLabelPDF(data: data, for: medication)
        return share.url ?? URL(string: "about:blank")!
    }
}

enum SharingError: LocalizedError {
    case notSignedInToiCloud
    case sharingNotAvailable
    case invalidShareURL
    
    var errorDescription: String? {
        switch self {
        case .notSignedInToiCloud:
            return "Please sign in to iCloud to share patient data"
        case .sharingNotAvailable:
            return "Sharing is not available on this device"
        case .invalidShareURL:
            return "Failed to generate share URL"
        }
    }
}

// MARK: - SwiftUI View Extensions for Sharing

struct SharePatientButton: View {
    let patient: Patient
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        Button(action: {
            Task {
                await sharePatient()
            }
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Patient")
            }
        }
        .disabled(isSharing)
        .sheet(item: Binding<ShareURLItem?>(
            get: { shareURL.map(ShareURLItem.init) },
            set: { _ in shareURL = nil }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Sharing Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func sharePatient() async {
        isSharing = true
        
        do {
            let url = try await SharingManager.shared.generatePatientShareLink(patient)
            await MainActor.run {
                shareURL = url
                isSharing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSharing = false
            }
        }
    }
}

struct ShareLabelButton: View {
    let medication: DispencedMedication
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        Button(action: {
            Task {
                await shareLabel()
            }
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up.on.square")
                Text("Share Label")
            }
        }
        .disabled(isSharing)
        .sheet(item: Binding<ShareURLItem?>(
            get: { shareURL.map(ShareURLItem.init) },
            set: { _ in shareURL = nil }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Sharing Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func shareLabel() async {
        isSharing = true
        
        do {
            // Generate PDF data
            guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
                throw SharingError.sharingNotAvailable
            }
            
            let url = try await SharingManager.shared.generateLabelPDFShareLink(data: pdfData, for: medication)
            await MainActor.run {
                shareURL = url
                isSharing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSharing = false
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