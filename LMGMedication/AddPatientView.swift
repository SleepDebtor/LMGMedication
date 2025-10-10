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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Middle Name", text: $middleName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $birthdate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePatient()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
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
        withAnimation {
            let newPatient = Patient(context: viewContext)
            newPatient.firstName = firstName
            newPatient.lastName = lastName
            newPatient.middleName = middleName.isEmpty ? nil : middleName
            newPatient.birthdate = birthdate
            newPatient.timeStamp = Date()
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                errorMessage = "Failed to save patient: \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    AddPatientView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
