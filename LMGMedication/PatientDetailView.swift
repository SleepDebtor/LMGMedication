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
    @State private var selectedMedication: DispencedMedication?
    @State private var showingBulkPrint = false
    @State private var selectedMedicationsForPrint: Set<DispencedMedication> = []
    
    var sortedMedications: [DispencedMedication] {
        patient.dispensedMedicationsArray.sorted { med1, med2 in
            guard let date1 = med1.dispenceDate, let date2 = med2.dispenceDate else {
                return false
            }
            return date1 > date2 // Most recent first
        }
    }
    
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
            
            Section(header: 
                HStack {
                    Text("Dispensed Medications")
                    Spacer()
                    if !sortedMedications.isEmpty {
                        Menu {
                            Button(action: { showingBulkPrint = true }) {
                                Label("Print Selected", systemImage: "printer")
                            }
                            
                            Button(action: { printAllLabels() }) {
                                Label("Print All Labels", systemImage: "printer.fill")
                            }
                        } label: {
                            Image(systemName: "printer")
                                .font(.caption)
                        }
                    }
                }
            ) {
                if sortedMedications.isEmpty {
                    Text("No medications dispensed")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(sortedMedications, id: \.objectID) { medication in
                        PatientMedicationRow(
                            medication: medication,
                            onPrintTapped: { printSingleLabel(medication) }
                        )
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
                    
                    if !sortedMedications.isEmpty {
                        Button(action: { printAllLabels() }) {
                            Label("Print All Labels", systemImage: "printer.fill")
                        }
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
        .sheet(isPresented: $showingBulkPrint) {
            BulkPrintSelectionView(
                medications: sortedMedications,
                selectedMedications: $selectedMedicationsForPrint
            )
        }
    }
    
    private func deleteMedications(offsets: IndexSet) {
        withAnimation {
            let medicationsToDelete = offsets.map { sortedMedications[$0] }
            medicationsToDelete.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func printSingleLabel(_ medication: DispencedMedication) {
        Task {
            await MedicationPrintManager.shared.printLabel(for: medication)
        }
    }
    
    private func printAllLabels() {
        Task {
            await MedicationPrintManager.shared.printLabels(for: sortedMedications)
        }
    }
}

struct PatientMedicationRow: View {
    let medication: DispencedMedication
    let onPrintTapped: () -> Void
    
    var body: some View {
        NavigationLink(destination: MedicationLabelView(medication: medication)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.displayName)
                        .font(.headline)
                    
                    if !medication.concentrationInfo.isEmpty {
                        Text(medication.concentrationInfo)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if !medication.dispensedQuantityText.isEmpty {
                            Text("Disp: \(medication.dispensedQuantityText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let date = medication.dispenceDate {
                            Text("• \(date, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lotNum = medication.lotNum, !lotNum.isEmpty {
                            Text("• Lot: \(lotNum)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let expDate = medication.expDate {
                        Text("Expires: \(expDate, style: .date)")
                            .font(.caption2)
                            .foregroundColor(expDate < Date() ? .red : .secondary)
                    }
                }
                .padding(.vertical, 2)
                
                Spacer()
                
                Button(action: onPrintTapped) {
                    Image(systemName: "printer")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BulkPrintSelectionView: View {
    let medications: [DispencedMedication]
    @Binding var selectedMedications: Set<DispencedMedication>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(medications, id: \.objectID) { medication in
                    HStack {
                        Button(action: {
                            if selectedMedications.contains(medication) {
                                selectedMedications.remove(medication)
                            } else {
                                selectedMedications.insert(medication)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedMedications.contains(medication) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMedications.contains(medication) ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(medication.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if !medication.concentrationInfo.isEmpty {
                                        Text(medication.concentrationInfo)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let date = medication.dispenceDate {
                                        Text("Dispensed: \(date, style: .date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Labels to Print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Print Selected") {
                        Task {
                            await MedicationPrintManager.shared.printLabels(for: Array(selectedMedications))
                            dismiss()
                        }
                    }
                    .disabled(selectedMedications.isEmpty)
                }
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
    
    // Add some sample medications
    let medication = Medication(context: context)
    medication.name = "Tirzepatide"
    medication.ingredient1 = "vitamin B6"
    medication.concentration1 = 25.0
    medication.pharmacy = "Beaker Pharmacy"
    medication.injectable = true
    
    let provider = Provider(context: context)
    provider.firstName = "Krista"
    provider.lastName = "Lazar"
    
    let dispensedMedication = DispencedMedication(context: context)
    dispensedMedication.dose = "10"
    dispensedMedication.doseUnit = "mg"
    dispensedMedication.dispenceAmt = 4
    dispensedMedication.dispenceUnit = "syringes"
    dispensedMedication.baseMedication = medication
    dispensedMedication.patient = patient
    dispensedMedication.prescriber = provider
    dispensedMedication.dispenceDate = Date()
    
    return NavigationView {
        PatientDetailView(patient: patient)
    }
    .environment(\.managedObjectContext, context)
}
