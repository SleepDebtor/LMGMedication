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

/**
 * PatientDetailView
 * 
 * Detailed view for a specific patient showing their information and medication history.
 * Provides functionality for managing patient medications, printing labels, and sharing data.
 * 
 * Key Features:
 * - Patient information display with edit capability
 * - Chronological medication history (most recent first)
 * - Individual medication label printing (single/dual)
 * - Bulk label printing for multiple medications  
 * - Medication dispensing workflow
 * - Patient data sharing functionality
 * - Consistent bronze/gold theming
 * 
 * Architecture:
 * - Observes patient Core Data object for real-time updates
 * - State management for modal presentations and selections
 * - Async operations for printing and sharing
 * - Error handling with user-friendly alerts
 * 
 * Navigation:
 * - Accessed via NavigationLink from main patient list
 * - Modal presentations for medication dispensing and editing
 * - Native sharing interface integration
 */
struct PatientDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var patient: Patient
    
    @State private var showingAddMedication = false
    @State private var selectedMedication: DispencedMedication?
    @State private var showingBulkPrint = false
    @State private var selectedMedicationsForPrint: Set<DispencedMedication> = []
    @State private var showingEditPatient = false
    @State private var showingLabLabelPrint = false
    
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
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(lightBackgroundColor, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingLabLabelPrint = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "testtube.2")
                            .font(.body)
                        Text("Lab Label")
                            .font(.subheadline)
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationView(patient: patient)
        }
        .sheet(isPresented: $showingEditPatient) {
            EditPatientView(patient: patient)
        }
        .sheet(isPresented: $showingLabLabelPrint) {
            LabLabelPrintView(patient: patient)
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
    @ObservedObject var medication: DispencedMedication
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
            
            // Print button
            Button(action: onPrintTapped) {
                Image(systemName: "printer")
                    .font(.title3)
                    .foregroundColor(goldColor)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(goldColor.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(goldColor.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                if medication.isActive {
                    Button(role: .destructive) { onDeactivate() } label: {
                        Label("Deactivate", systemImage: "xmark.circle")
                    }
                } else {
                    Button { onActivate() } label: {
                        Label("Activate", systemImage: "checkmark.circle")
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(goldColor.opacity(0.6))
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
    }
}

struct PatientMedicationRow: View {
    @ObservedObject var medication: DispencedMedication
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

/**
 * LabLabelPrintView
 * 
 * View for printing blood draw test tube labels (2" x 1")
 * Displays patient information formatted for lab specimen labels
 * 
 * Label Format:
 * - Line 1: Patient name (Last, First)
 * - Line 2: Date of Birth
 * - Line 3: Drawn on: [current date]
 * - Line 4: Lazar Medical Group
 */
struct LabLabelPrintView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var patient: Patient
    
    @State private var showingPrintPreview = false
    
    // Custom colors - matching patient detail view
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    private let textColor = Color.black
    
    var body: some View {
        NavigationStack {
            ZStack {
                lightBackgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Info header
                        VStack(spacing: 12) {
                            Image(systemName: "testtube.2")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [goldColor, darkGoldColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Lab Draw Label")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(goldColor)
                            
                            Text("Print a label for blood draw test tubes")
                                .font(.subheadline)
                                .foregroundColor(textColor.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Label preview
                        VStack(spacing: 16) {
                            Text("Label Preview")
                                .font(.headline)
                                .foregroundColor(goldColor)
                            
                            LabLabelPreview(patient: patient, textColor: textColor)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Print button
                        Button(action: {
                            printLabLabel()
                        }) {
                            HStack {
                                Image(systemName: "printer.fill")
                                    .font(.title3)
                                Text("Print Lab Label")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
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
                        .padding(.horizontal, 20)
                        
                        // Info section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Label Specifications")
                                .font(.headline)
                                .foregroundColor(goldColor)
                            
                            InfoRow(icon: "ruler", text: "Size: 2 inches × 1 inch")
                            InfoRow(icon: "paintbrush", text: "Format: Blood draw specimen label")
                            InfoRow(icon: "checkmark.circle", text: "Includes patient name, DOB, and draw date")
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(goldColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Lab Draw Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
    }
    
    private func printLabLabel() {
        Task {
            let success = await LabLabelPrintManager.shared.printLabLabel(for: patient)
            // Only dismiss if print was completed successfully
            if success {
                dismiss()
            }
        }
    }
}

/**
 * LabLabelPreview
 * 
 * Preview component showing how the lab label will appear when printed
 * Matches the 2" x 1" label format
 */
struct LabLabelPreview: View {
    let patient: Patient
    let textColor: Color
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: Date())
    }
    
    private var birthDateString: String {
        guard let birthdate = patient.birthdate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: birthdate)
    }
    
    var body: some View {
        // Simulating a 2" x 1" label (144 pts x 72 pts at 72 DPI)
        // Using a 2:1 aspect ratio
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Patient name
            Text("\(patient.lastName ?? "Unknown"), \(patient.firstName ?? "Unknown")")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(textColor)
            
            // Line 2: Date of birth
            Text("DOB: \(birthDateString)")
                .font(.system(size: 12))
                .foregroundColor(textColor)
            
            // Line 3: Drawn on date
            Text("Drawn on: \(currentDate)")
                .font(.system(size: 12))
                .foregroundColor(textColor)
            
            Divider()
                .padding(.vertical, 2)
            
            // Line 4: Lazar Medical Group
            Text("Lazar Medical Group")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textColor)
            
            // Line 5: Initials line
            Text("Initials: ________")
                .font(.system(size: 11))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

/**
 * InfoRow
 * 
 * Helper view for displaying specification information
 */
struct InfoRow: View {
    let icon: String
    let text: String
    
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(goldColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
}

/**
 * LabLabelPrintManager
 * 
 * Manages printing of lab draw specimen labels
 * Formats labels to 2" x 1" size for blood draw test tubes
 */
class LabLabelPrintManager {
    static let shared = LabLabelPrintManager()
    
    private init() {}
    
    @MainActor
    func printLabLabel(for patient: Patient) async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo.printInfo()
            
            printInfo.outputType = .general
            printInfo.jobName = "Lab Label - \(patient.displayName)"
            printInfo.duplex = .none
            
            // Create the label renderer
            let renderer = LabLabelRenderer(patient: patient)
            
            printController.printInfo = printInfo
            printController.printFormatter = nil
            printController.printPageRenderer = renderer
            
            printController.present(animated: true) { _, completed, error in
                if let error = error {
                    print("Print error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: completed)
                }
            }
        }
        #else
        return false
        #endif
    }
}

#if os(iOS)
/**
 * LabLabelRenderer
 * 
 * Custom page renderer for lab draw labels
 * Formats content to fit 2" x 1" label dimensions
 */
class LabLabelRenderer: UIPrintPageRenderer {
    let patient: Patient
    
    init(patient: Patient) {
        self.patient = patient
        super.init()
        
        // 2 inches x 1 inch at 72 points per inch = 144 x 72 points
        let labelWidth: CGFloat = 144
        let labelHeight: CGFloat = 72
        
        // Set paper rect to label size
        let paperRect = CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight)
        setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        
        // Printable rect with small margins
        let printableRect = CGRect(x: 4, y: 4, width: labelWidth - 8, height: labelHeight - 8)
        setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
    }
    
    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Set up fonts
        let nameFontSize: CGFloat = 11
        let regularFontSize: CGFloat = 9
        let smallFontSize: CGFloat = 8
        
        let nameFont = UIFont.boldSystemFont(ofSize: nameFontSize)
        let regularFont = UIFont.systemFont(ofSize: regularFontSize)
        let smallFont = UIFont.systemFont(ofSize: smallFontSize)
        let boldFont = UIFont.boldSystemFont(ofSize: regularFontSize)
        
        let textColor = UIColor.black
        
        var yPosition: CGFloat = printableRect.minY
        let lineSpacing: CGFloat = 2
        
        // Line 1: Patient name (Last, First)
        let patientName = "\(patient.lastName ?? "Unknown"), \(patient.firstName ?? "Unknown")"
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: textColor
        ]
        let nameString = NSAttributedString(string: patientName, attributes: nameAttributes)
        nameString.draw(at: CGPoint(x: printableRect.minX, y: yPosition))
        yPosition += nameFontSize + lineSpacing
        
        // Line 2: Date of Birth
        let dobString: String
        if let birthdate = patient.birthdate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            dobString = "DOB: \(formatter.string(from: birthdate))"
        } else {
            dobString = "DOB: N/A"
        }
        let dobAttributes: [NSAttributedString.Key: Any] = [
            .font: regularFont,
            .foregroundColor: textColor
        ]
        let dobAttributedString = NSAttributedString(string: dobString, attributes: dobAttributes)
        dobAttributedString.draw(at: CGPoint(x: printableRect.minX, y: yPosition))
        yPosition += regularFontSize + lineSpacing
        
        // Line 3: Drawn on date
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let drawnOnString = "Drawn on: \(dateFormatter.string(from: currentDate))"
        let drawnAttributes: [NSAttributedString.Key: Any] = [
            .font: regularFont,
            .foregroundColor: textColor
        ]
        let drawnAttributedString = NSAttributedString(string: drawnOnString, attributes: drawnAttributes)
        drawnAttributedString.draw(at: CGPoint(x: printableRect.minX, y: yPosition))
        yPosition += regularFontSize + lineSpacing + 2
        
        // Draw separator line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: printableRect.minX, y: yPosition))
        context.addLine(to: CGPoint(x: printableRect.maxX, y: yPosition))
        context.strokePath()
        yPosition += 3
        
        // Line 4: Lazar Medical Group
        let groupString = "Lazar Medical Group"
        let groupAttributes: [NSAttributedString.Key: Any] = [
            .font: boldFont,
            .foregroundColor: textColor
        ]
        let groupAttributedString = NSAttributedString(string: groupString, attributes: groupAttributes)
        groupAttributedString.draw(at: CGPoint(x: printableRect.minX, y: yPosition))
        
        // Line 5: Initials line
        yPosition += regularFontSize + lineSpacing
        let initialsString = "Initials: ________"
        let initialsAttributes: [NSAttributedString.Key: Any] = [
            .font: regularFont,
            .foregroundColor: textColor
        ]
        let initialsAttributedString = NSAttributedString(string: initialsString, attributes: initialsAttributes)
        initialsAttributedString.draw(at: CGPoint(x: printableRect.minX, y: yPosition))
    }
}
#endif


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

