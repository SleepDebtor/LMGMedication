//
//  ParticipantSelectionView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import SwiftUI
import CloudKit

struct ParticipantSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var emailAddresses: [String] = [""]
    @State private var isValidatingEmails = false
    @State private var validationErrors: [String] = []
    
    let onParticipantsSelected: ([String]) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter email addresses of people you want to share with. They must have iCloud accounts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Share With")
                }
                
                Section {
                    ForEach(emailAddresses.indices, id: \.self) { index in
                        HStack {
                            TextField("Email address", text: $emailAddresses[index])
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if emailAddresses.count > 1 {
                                Button(action: {
                                    removeEmail(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: addEmailField) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add another email")
                        }
                    }
                } header: {
                    Text("Email Addresses")
                }
                
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    } header: {
                        Text("Validation Errors")
                    }
                }
            }
            .navigationTitle("Select Recipients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareWithSelectedParticipants()
                    }
                    .disabled(isValidatingEmails || !hasValidEmails)
                }
            }
        }
    }
    
    private var hasValidEmails: Bool {
        emailAddresses.contains { !$0.isEmpty && isValidEmail($0) }
    }
    
    private func addEmailField() {
        emailAddresses.append("")
    }
    
    private func removeEmail(at index: Int) {
        emailAddresses.remove(at: index)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func shareWithSelectedParticipants() {
        isValidatingEmails = true
        validationErrors.removeAll()
        
        let validEmails = emailAddresses.compactMap { email in
            email.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty && isValidEmail($0) }
        
        if validEmails.isEmpty {
            validationErrors.append("Please enter at least one valid email address")
            isValidatingEmails = false
            return
        }
        
        // Validate that emails can be found in iCloud
        Task {
            do {
                let validatedEmails = try await validateiCloudEmails(validEmails)
                await MainActor.run {
                    onParticipantsSelected(validatedEmails)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    validationErrors.append("Unable to validate some email addresses: \(error.localizedDescription)")
                    isValidatingEmails = false
                }
            }
        }
    }
    
    private func validateiCloudEmails(_ emails: [String]) async throws -> [String] {
        // In a production app, you might want to validate that these emails
        // correspond to iCloud users, but for now we'll just return them
        // CloudKit will handle validation when creating participants
        return emails
    }
}

#Preview {
    ParticipantSelectionView { emails in
        print("Selected emails: \(emails)")
    }
}