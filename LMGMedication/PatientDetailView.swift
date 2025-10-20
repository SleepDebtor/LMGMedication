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
    @State private var showingEditPatient = false
    
    @State private var isSharing = false
    @State private var shareErrorMessage: String?
    @State private var showingErrorAlert = false
    
    // Custom colors - light theme with dark bronze accents
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2) // Dark bronze
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15) // Darker bronze
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97) // Light background with subtle gold tint
    private let textColor = Color.black // Black text
    
    var sortedMedications: [DispencedMedication] {
        patient.dispensedMedicationsArray.sorted { med1, med2 in
            guard let date1 = med1.dispenceDate, let date2 = med2.dispenceDate else {
                return false
            }
            return date1 > date2 // Most recent first
        }
    }
    
    var body: some View {
        ZStack {
            // Light background
            lightBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header and actions
                VStack(spacing: 20) {
                    // Patient Header Card
                    PatientHeaderCard(
                        patient: patient,
                        goldColor: goldColor,
                        darkGoldColor: darkGoldColor,
                        textColor: textColor,
                        onEditTapped: { showingEditPatient = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Action Buttons Section
                    HStack(spacing: 12) {
                        // Dispense Medication button
                        Button(action: { showingAddMedication = true }) {
                            HStack {
                                Image(systemName: "pills.fill")
                                    .font(.title3)
                                Text("Dispense")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [goldColor, darkGoldColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: goldColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        }

                        // Print All button (if medications exist)
                        if !sortedMedications.isEmpty {
                            Button(action: { printAllLabels() }) {
                                HStack {
                                    Image(systemName: "printer.fill")
                                        .font(.title3)
                                    Text("Print All")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(goldColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(goldColor, lineWidth: 1.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.8))
                                        )
                                )
                            }
                        }

                        // Share button
                        Button(action: { Task { await sharePatient() } }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                Text("Share")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(goldColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(goldColor, lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.8))
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Section header
                    HStack {
                        Text("Dispensed Medications")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(goldColor)
                        Spacer()
                        if !sortedMedications.isEmpty {
                            Button(action: { showingBulkPrint = true }) {
                                Text("Select & Print")
                                    .font(.caption)
                                    .foregroundColor(goldColor.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(goldColor.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                // Medications list with swipe actions
                List {
                    if sortedMedications.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "pills")
                                .font(.system(size: 50))
                                .foregroundColor(goldColor.opacity(0.6))

                            Text("No Medications Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(goldColor)

                            Text("Tap 'Dispense' above to add medication")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(sortedMedications, id: \.objectID) { medication in
                            NavigationLink(destination: MedicationLabelView(medication: medication)) {
                                MedicationCardView(
                                    medication: medication,
                                    goldColor: goldColor,
                                    darkGoldColor: darkGoldColor,
                                    textColor: textColor,
                                    onPrintTapped: { printSingleLabel(medication) },
                                    onDeactivate: { toggleMedicationActive(medication, active: false) },
                                    onActivate: { toggleMedicationActive(medication, active: true) }
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if medication.isActive {
                                    Button(role: .destructive) {
                                        toggleMedicationActive(medication, active: false)
                                    } label: {
                                        Label("Deactivate", systemImage: "xmark.circle")
                                    }
                                } else {
                                    Button {
                                        toggleMedicationActive(medication, active: true)
                                    } label: {
                                        Label("Activate", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }

                                Button {
                                    printSingleLabel(medication)
                                } label: {
                                    Label("Print", systemImage: "printer")
                                }
                                .tint(.blue)
                                
                                Button(role: .destructive) {
                                    deleteMedication(medication)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(lightBackgroundColor, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationView(patient: patient)
        }
        .sheet(isPresented: $showingEditPatient) {
            EditPatientView(patient: patient)
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
                shareErrorMessage = "Failed to delete medication(s): \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
    
    private func deleteMedication(_ medication: DispencedMedication) {
        withAnimation {
            viewContext.delete(medication)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                shareErrorMessage = "Failed to delete medication: \(nsError.localizedDescription)"
                showingErrorAlert = true
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
    
    private func toggleMedicationActive(_ medication: DispencedMedication, active: Bool) {
        withAnimation {
            medication.isActive = active
            do { try viewContext.save() } catch { print("Failed to update isActive: \(error)") }
        }
    }
}

struct PatientHeaderCard: View {
    let patient: Patient
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    let onEditTapped: () -> Void
    
    var body: some View {
        HStack {
            // Patient icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goldColor.opacity(0.3), darkGoldColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundColor(goldColor)
            }
            
            // Patient info
            VStack(alignment: .leading, spacing: 6) {
                Text(patient.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
                
                if let birthdate = patient.birthdate {
                    Text("DOB: \(birthdate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                }
                
                if let timestamp = patient.timeStamp {
                    Text("Added: \(timestamp, style: .date)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEditTapped) {
                Image(systemName: "pencil")
                    .font(.title2)
                    .foregroundColor(goldColor)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(goldColor.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [goldColor.opacity(0.4), goldColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: goldColor.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct MedicationCardView: View {
    let medication: DispencedMedication
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    let onPrintTapped: () -> Void
    let onDeactivate: () -> Void
    let onActivate: () -> Void
    
    var body: some View {
        HStack {
            // Medication icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [goldColor.opacity(0.2), darkGoldColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundColor(goldColor)
            }
            
            // Medication info
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(medication.isActive ? textColor : textColor.opacity(0.6))
                    .lineLimit(1)
                
                let fillAmount = medication.fillAmount
                if (medication.baseMedication?.injectable == true) && fillAmount > 0 {
                    Text("Fill: \(String(format: "%.2f", fillAmount)) mL (\(String(format: "%.0f", fillAmount * 100))U)")
                        .font(.subheadline)
                        .foregroundColor(medication.isActive ? goldColor.opacity(0.8) : .gray)
                        .lineLimit(1)
                }
                
                HStack {
                    if !medication.dispensedQuantityText.isEmpty {
                        Text("Disp: \(medication.dispensedQuantityText)")
                            .font(.caption)
                            .foregroundColor(medication.isActive ? .gray : .gray.opacity(0.6))
                    }
                    
                    if let date = medication.dispenceDate {
                        Text("• \(date, style: .date)")
                            .font(.caption)
                            .foregroundColor(medication.isActive ? .gray : .gray.opacity(0.6))
                    }
                }
                
                if let lotNum = medication.lotNum, !lotNum.isEmpty {
                    Text("Lot: \(lotNum)")
                        .font(.caption2)
                        .foregroundColor(medication.isActive ? .gray : .gray.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [goldColor.opacity(0.3), goldColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .shadow(color: goldColor.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
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
                        .foregroundColor(medication.isActive ? .primary : .gray)
                    
                    let fillAmount = medication.fillAmount
                    if (medication.baseMedication?.injectable == true) && fillAmount > 0 {
                        Text("Fill: \(String(format: "%.2f", fillAmount)) mL (\(String(format: "%.0f", fillAmount * 100))U)")
                            .font(.subheadline)
                            .foregroundColor(medication.isActive ? .secondary : .gray)
                    }
                    
                    HStack {
                        if !medication.dispensedQuantityText.isEmpty {
                            Text("Disp: \(medication.dispensedQuantityText)")
                                .font(.caption)
                                .foregroundColor(medication.isActive ? .secondary : .gray)
                        }
                        
                        if let date = medication.dispenceDate {
                            Text("• \(date, style: .date)")
                                .font(.caption)
                                .foregroundColor(medication.isActive ? .secondary : .gray)
                        }
                        
                        if let lotNum = medication.lotNum, !lotNum.isEmpty {
                            Text("• Lot: \(lotNum)")
                                .font(.caption2)
                                .foregroundColor(medication.isActive ? .secondary : .gray)
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
    
    // Custom colors - light theme with dark bronze accents
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2) // Dark bronze
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15) // Darker bronze
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97) // Light background with subtle gold tint
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light background
                lightBackgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(medications, id: \.objectID) { medication in
                            Button(action: {
                                if selectedMedications.contains(medication) {
                                    selectedMedications.remove(medication)
                                } else {
                                    selectedMedications.insert(medication)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedMedications.contains(medication) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(selectedMedications.contains(medication) ? goldColor : goldColor.opacity(0.5))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(medication.displayName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.black)
                                        
                                        if !medication.concentrationInfo.isEmpty {
                                            Text(medication.concentrationInfo)
                                                .font(.subheadline)
                                                .foregroundColor(goldColor.opacity(0.8))
                                        }
                                        
                                        if let date = medication.dispenceDate {
                                            Text("Dispensed: \(date, style: .date)")
                                                .font(.caption)
                                                .foregroundColor(.black.opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            selectedMedications.contains(medication) ?
                                            LinearGradient(
                                                colors: [goldColor.opacity(0.1), goldColor.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedMedications.contains(medication) ?
                                                    goldColor.opacity(0.5) : goldColor.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Select Labels to Print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(lightBackgroundColor, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Print Selected") {
                        Task {
                            await MedicationPrintManager.shared.printLabels(for: Array(selectedMedications))
                            dismiss()
                        }
                    }
                    .foregroundColor(selectedMedications.isEmpty ? .gray : goldColor)
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
    .preferredColorScheme(.light)
}

