//
//  PatientDetailView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData
import CloudKit
#if os(iOS)
import UIKit
#endif

struct PatientDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var patient: Patient
    
    @State private var showingAddMedication = false
    @State private var selectedMedication: DispencedMedication?
    @State private var showingBulkPrint = false
    @State private var selectedMedicationsForPrint: Set<DispencedMedication> = []
    
    @State private var isSharing = false
    @State private var shareErrorMessage: String?
    @State private var showingErrorAlert = false
    
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
                                Label("Print and Update Next Dose (Selected)", systemImage: "printer")
                            }
                            
                            Button(action: { printAllLabels() }) {
                                Label("Print and Update Next Dose (All)", systemImage: "printer.fill")
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
        .animation(.easeInOut, value: sortedMedications.count)
        .navigationTitle(patient.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddMedication = true }) {
                    Label("Dispense", systemImage: "pills.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddMedication = true }) {
                        Label("Dispense Medication", systemImage: "plus")
                    }
                    
                    if !sortedMedications.isEmpty {
                        Button(action: { printAllLabels() }) {
                            Label("Print and Update Next Dose (All)", systemImage: "printer.fill")
                        }
                    }
                    
                    SharePatientButton(patient: patient)
                    
                    Button(action: { Task { await sharePatient() } }) {
                        Label("Share Patient", systemImage: "square.and.arrow.up")
                    }
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
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareErrorMessage ?? "Unknown error")
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
    
    private func sharePatient() async {
        isSharing = true
        defer { isSharing = false }
        
        do {
            // Resolve participants: for now, create an empty share with no participants.
            // In a real flow, you'd present UI to pick participants. We'll create the share root and present the CKShare via UIActivityViewController on iOS, or simply complete silently.
            let share = try await CloudKitManager.shared.sharePatient(patient, with: [])
            #if os(iOS)
            // Present the share URL via standard share sheet if available
            if let url = share.url {
                await MainActor.run {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        rootVC.present(av, animated: true)
                    }
                }
            }
            #endif
        } catch {
            await MainActor.run {
                shareErrorMessage = error.localizedDescription
                showingErrorAlert = true
            }
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
                    
                    let fillAmount = medication.fillAmount
                    if fillAmount > 0 {
                        Text("Fill: \(String(format: "%.2f", fillAmount)) mL (\(String(format: "%.0f", fillAmount * 100))U)")
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
                    Button("Print and Update Next Dose (Selected)") {
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
    dispensedMedication.doseNum = 10.0 // Parse dose for fillAmount calculation
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
