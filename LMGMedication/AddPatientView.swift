//
//  AddPatientView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData

struct AddPatientView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var middleName = ""
    @State private var birthdate = Date()
    
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    @State private var isSaving = false
    
    private var isValidInput: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                    TextField("Middle Name", text: $middleName)
                        .textContentType(.middleName)
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                    DatePicker("Date of Birth", selection: $birthdate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                Section {
                    if !isValidInput {
                        Text("Please enter both first and last name")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePatient()
                    }
                    .disabled(!isValidInput || isSaving)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePatient() {
        guard !isSaving else { return }
        guard isValidInput else { return }
        
        isSaving = true
        
        // Validate inputs
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMiddleName = middleName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedFirstName.isEmpty, !trimmedLastName.isEmpty else {
            isSaving = false
            errorMessage = "Please enter both first and last name"
            showingErrorAlert = true
            return
        }
        
        // Use a simple, synchronous approach to avoid threading issues
        do {
            // Temporarily disable automatic merging to prevent conflicts
            let originalMergePolicy = viewContext.mergePolicy
            viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            
            let newPatient = Patient(context: viewContext)
            newPatient.firstName = trimmedFirstName
            newPatient.lastName = trimmedLastName
            newPatient.middleName = trimmedMiddleName.isEmpty ? nil : trimmedMiddleName
            newPatient.birthdate = birthdate
            newPatient.timeStamp = Date()
            newPatient.isActive = true
            
            // Validate the object before saving
            try newPatient.validateForInsert()
            
            // Save with error handling
            try viewContext.save()
            
            // Restore original merge policy
            viewContext.mergePolicy = originalMergePolicy
            
            #if DEBUG
            print("Successfully created patient: \(newPatient.displayName)")
            #endif
            
            // Dismiss on success
            DispatchQueue.main.async {
                self.dismiss()
            }
            
        } catch let validationError as NSError where validationError.domain == NSCocoaErrorDomain {
            isSaving = false
            handleValidationError(validationError)
            
        } catch let error as NSError {
            isSaving = false
            
            // Restore merge policy if it was changed
            viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            handleSaveError(error)
        }
    }
    
    private func handleValidationError(_ error: NSError) {
        var message = "Invalid patient information"
        
        switch error.code {
        case NSValidationMissingMandatoryPropertyError:
            message = "Missing required patient information"
        case NSValidationStringTooShortError:
            message = "Patient name is too short"
        case NSValidationStringTooLongError:
            message = "Patient name is too long"
        case NSValidationDateTooLateError:
            message = "Birth date cannot be in the future"
        case NSValidationDateTooSoonError:
            message = "Birth date is too far in the past"
        default:
            message = "Invalid patient information: \(error.localizedDescription)"
        }
        
        errorMessage = message
        showingErrorAlert = true
        
        #if DEBUG
        print("Validation Error: \(error)")
        print("Error Info: \(error.userInfo)")
        #endif
    }
    
    private func handleSaveError(_ error: Error) {
        isSaving = false
        
        let nsError = error as NSError
        
        // Handle specific Core Data errors
        var userFriendlyMessage = "Failed to save patient"
        
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSValidationMissingMandatoryPropertyError:
                userFriendlyMessage = "Missing required patient information"
            case NSValidationStringTooShortError, NSValidationStringTooLongError:
                userFriendlyMessage = "Patient name is invalid"
            case NSManagedObjectConstraintMergeError:
                userFriendlyMessage = "A patient with this information already exists"
            default:
                userFriendlyMessage = "Failed to save patient: \(nsError.localizedDescription)"
            }
        } else if nsError.domain == "CKErrorDomain" {
            // CloudKit specific errors
            userFriendlyMessage = "Cloud sync is temporarily unavailable. Patient saved locally."
        }
        
        errorMessage = userFriendlyMessage
        showingErrorAlert = true
        
        // Comprehensive error logging for debugging
        #if DEBUG
        print("Core Data Save Error: \(nsError)")
        print("Error Domain: \(nsError.domain)")
        print("Error Code: \(nsError.code)")
        print("Error Info: \(nsError.userInfo)")
        
        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for detailedError in detailedErrors {
                print("Detailed error: \(detailedError)")
                print("Detailed error object: \(detailedError.userInfo)")
            }
        }
        
        if let validationErrorObject = nsError.userInfo[NSValidationObjectErrorKey] {
            print("Validation error object: \(validationErrorObject)")
        }
        
        if let validationErrorKey = nsError.userInfo[NSValidationKeyErrorKey] {
            print("Validation error key: \(validationErrorKey)")
        }
        #endif
    }
}

#Preview {
    AddPatientView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
