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
        
        withAnimation {
            do {
                let newPatient = Patient(context: viewContext)
                newPatient.firstName = trimmedFirstName
                newPatient.lastName = trimmedLastName
                newPatient.middleName = trimmedMiddleName.isEmpty ? nil : trimmedMiddleName
                newPatient.birthdate = birthdate
                newPatient.timeStamp = Date()
                newPatient.isActive = true  // Ensure new patients are active by default
                
                try viewContext.save()
                
                #if DEBUG
                print("Successfully created patient: \(newPatient.displayName)")
                #endif
                
                dismiss()
            } catch {
                let nsError = error as NSError
                isSaving = false
                errorMessage = "Failed to save patient: \(nsError.localizedDescription)"
                showingErrorAlert = true
                
                // Additional error logging for debugging
                #if DEBUG
                print("Core Data Save Error: \(nsError)")
                print("Error Info: \(nsError.userInfo)")
                if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    for detailedError in detailedErrors {
                        print("Detailed error: \(detailedError)")
                    }
                }
                #endif
            }
        }
    }
}

#Preview {
    AddPatientView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
