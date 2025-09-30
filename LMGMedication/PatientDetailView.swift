//
//  PatientDetailView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData

struct PatientDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let patient: Patient
    
    @State private var showingAddMedication = false
    
    var body: some View {
        List {
            Section(header: Text("Patient Information")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let birthdate = patient.birthdate {
                        Text("DOB: \(birthdate, style: .date)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let timestamp = patient.timeStamp {
                        Text("Added: \(timestamp, style: .date)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Dispensed Medications")) {
                if patient.dispensedMedicationsArray.isEmpty {
                    Text("No medications dispensed")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(patient.dispensedMedicationsArray, id: \.objectID) { medication in
                        NavigationLink(destination: MedicationLabelView(medication: medication)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(medication.displayName)
                                    .font(.headline)
                                
                                if !medication.concentrationInfo.isEmpty {
                                    Text(medication.concentrationInfo)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !medication.dispensedQuantityText.isEmpty {
                                    Text("Disp: \(medication.dispensedQuantityText)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let date = medication.dispenceDate {
                                    Text("Dispensed: \(date, style: .date)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteMedications)
                }
            }
        }
        .navigationTitle(patient.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddMedication = true }) {
                        Label("Dispense Medication", systemImage: "plus")
                    }
                    
                    SharePatientButton(patient: patient)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationView(patient: patient)
        }
    }
    
    private func deleteMedications(offsets: IndexSet) {
        withAnimation {
            let medicationsToDelete = offsets.map { patient.dispensedMedicationsArray[$0] }
            medicationsToDelete.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let patient = Patient(context: context)
    patient.firstName = "Brittany"
    patient.lastName = "Kratzer"
    patient.birthdate = Calendar.current.date(byAdding: .year, value: -35, to: Date())
    
    return NavigationView {
        PatientDetailView(patient: patient)
    }
    .environment(\.managedObjectContext, context)
}