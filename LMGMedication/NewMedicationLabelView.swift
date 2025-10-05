//
//  MedicationLabelView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import PDFKit
import CoreData

struct MedicationLabelView: View {
    let medication: DispencedMedication
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingPrintPreview = false
    @State private var isProcessing = false
    @State private var isEditing = false
    @State private var hasChanges = false
    
    // Editable properties
    @State private var editDose = ""
    @State private var editDoseUnit = "mg"
    @State private var editDispenceAmount: Int = 1
    @State private var editDispenceUnit = "syringes"
    @State private var editLotNumber = ""
    @State private var editExpirationDate = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Patient and medication summary
                VStack(spacing: 12) {
                    if let patient = medication.patient {
                        Text(patient.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(medication.displayName)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if let date = medication.dispenceDate {
                        Text("Dispensed: \(date, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if isEditing {
                        // Edit mode - show form fields
                        VStack(spacing: 8) {
                            HStack {
                                Text("Dose:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Dose", text: $editDose)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 60)
                                
                                Picker("Unit", selection: $editDoseUnit) {
                                    Text("mg").tag("mg")
                                    Text("mcg").tag("mcg")
                                    Text("ml").tag("ml")
                                    Text("units").tag("units")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }
                            
                            HStack {
                                Text("Quantity:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Stepper("\(editDispenceAmount)", value: $editDispenceAmount, in: 1...100)
                                    .onChange(of: editDispenceAmount) { _, _ in
                                        hasChanges = true
                                    }
                                TextField("Unit", text: $editDispenceUnit)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                            
                            HStack {
                                Text("Lot Number:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Lot Number", text: $editLotNumber)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Expires:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $editExpirationDate, displayedComponents: .date)
                                    .onChange(of: editExpirationDate) { _, _ in
                                        hasChanges = true
                                    }
                            }
                        }
                        .padding(.top, 8)
                        .onChange(of: editDose) { _, _ in hasChanges = true }
                        .onChange(of: editDoseUnit) { _, _ in hasChanges = true }
                        .onChange(of: editDispenceUnit) { _, _ in hasChanges = true }
                        .onChange(of: editLotNumber) { _, _ in hasChanges = true }
                    } else {
                        // Display mode - show current values
                        if let expDate = medication.expDate {
                            Text("Expires: \(expDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(expDate < Date() ? .red : .secondary)
                        }
                        
                        if let lotNum = medication.lotNum, !lotNum.isEmpty {
                            Text("Lot: \(lotNum)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Preview of the label
                VStack(spacing: 8) {
                    Text("Label Preview")
                        .font(.headline)
                    
                    MedicationLabelPreview(medication: medication)
                        .frame(width: 288, height: 144) // 2x1 inch at 144 DPI for preview
                        .border(Color.gray, width: 1)
                        .cornerRadius(4)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if isEditing {
                        // Edit mode buttons
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            
                            Button("Save Changes") {
                                saveChanges()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!hasChanges)
                        }
                    } else {
                        // Normal mode buttons
                        Button("Edit Medication") {
                            startEditing()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button(action: { 
                            Task { 
                                isProcessing = true
                                await MedicationPrintManager.shared.printLabel(for: medication)
                                isProcessing = false
                            }
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "printer.fill")
                                }
                                Text("Print Label")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isProcessing)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await MedicationPrintManager.shared.sharePDF(for: medication)
                                }
                            }) {
                                Label("Share PDF", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            
                            Button("Preview") {
                                showingPrintPreview = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            
                            ShareLabelButton(medication: medication)
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Medication Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(!hasChanges)
                    }
                } else {
                    Menu {
                        Button(action: {
                            startEditing()
                        }) {
                            Label("Edit Medication", systemImage: "pencil")
                        }
                        
                        Button(action: { 
                            Task { 
                                await MedicationPrintManager.shared.printLabel(for: medication)
                            }
                        }) {
                            Label("Print Label", systemImage: "printer")
                        }
                        
                        Button(action: {
                            Task {
                                await MedicationPrintManager.shared.sharePDF(for: medication)
                            }
                        }) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        
                        Button("Show Preview") {
                            showingPrintPreview = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPrintPreview) {
            PrintPreviewView(medication: medication)
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    // MARK: - Edit Functions
    private func loadCurrentValues() {
        editDose = medication.dose ?? ""
        editDoseUnit = medication.doseUnit ?? "mg"
        editDispenceAmount = Int(medication.dispenceAmt)
        editDispenceUnit = medication.dispenceUnit ?? "syringes"
        editLotNumber = medication.lotNum ?? ""
        editExpirationDate = medication.expDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60)
    }
    
    private func startEditing() {
        loadCurrentValues()
        isEditing = true
        hasChanges = false
    }
    
    private func cancelEditing() {
        loadCurrentValues()
        isEditing = false
        hasChanges = false
    }
    
    private func saveChanges() {
        guard hasChanges else { return }
        
        // Update the medication properties
        medication.dose = editDose.isEmpty ? nil : editDose
        medication.doseUnit = editDoseUnit
        medication.dispenceAmt = Int16(editDispenceAmount)
        medication.dispenceUnit = editDispenceUnit
        medication.lotNum = editLotNumber.isEmpty ? nil : editLotNumber
        medication.expDate = editExpirationDate
        
        // Save to Core Data
        do {
            try viewContext.save()
            isEditing = false
            hasChanges = false
        } catch {
            print("Error saving medication changes: \(error)")
            // You might want to show an alert here
        }
    }
}

struct MedicationLabelPreview: View {
    let medication: DispencedMedication
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
            
            HStack(spacing: 0) {
                // QR Code on left - reduced size to match PDF layout
                VStack {
                    if let qrData = medication.baseMedication?.qrImage, !qrData.isEmpty {
                        if let uiImage = UIImage(data: qrData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 86, height: 86) // Reduced from 120 to 86 (120/400 * 288 ≈ 86)
                        } else {
                            qrCodePlaceholder
                        }
                    } else {
                        qrCodePlaceholder
                    }
                }
                .frame(width: 86, height: 86)
                .padding(.leading, 4)
                
                // Text area on right - more space due to smaller QR code
                VStack(alignment: .leading, spacing: 1) {
                    // Patient name (matching PDF font proportions)
                    if let patient = medication.patient {
                        let lastName = patient.lastName ?? "Unknown"
                        let firstName = patient.firstName ?? "Patient"
                        let patientName = "\(lastName), \(firstName)"
                        Text(patientName)
                            .font(.system(size: 16, weight: .bold)) // 22/200*144 ≈ 16
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    // Medication name and dose
                    let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
                    let dose = medication.dose ?? ""
                    let doseUnit = medication.doseUnit ?? ""
                    let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
                    
                    Text(medicationTitle)
                        .font(.system(size: 14, weight: .bold)) // 19/200*144 ≈ 14
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Secondary ingredient
                    if let ingredient2 = medication.baseMedication?.ingredient2,
                       let concentration2 = medication.baseMedication?.concentration2,
                       !ingredient2.isEmpty, concentration2 > 0 {
                        let secondaryInfo = "\(ingredient2) \(String(format: "%.1f", concentration2))mg"
                        Text(secondaryInfo)
                            .font(.system(size: 12, weight: .regular)) // 17/200*144 ≈ 12
                            .italic()
                            .foregroundColor(Color(.darkGray))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    // Dispense information
                    let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
                    let dispenseUnit = medication.dispenceUnit ?? "units"
                    let dispenseInfo = "Disp: \(dispenseAmt) \(dispenseUnit)"
                    Text(dispenseInfo)
                        .font(.system(size: 12, weight: .bold)) // 17/200*144 ≈ 12
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Dosing instructions
                    let unitSingular = dispenseUnit.hasSuffix("s") ? String(dispenseUnit.dropLast()) : dispenseUnit
                    let dosingInstructions = "1 \(unitSingular) sq weekly"
                    Text(dosingInstructions)
                        .font(.system(size: 10, weight: .regular)) // 14/200*144 ≈ 10
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Prescriber information
                    if let prescriber = medication.prescriber {
                        let firstName = prescriber.firstName ?? ""
                        let lastName = prescriber.lastName ?? ""
                        let prescriberName = "\(firstName) \(lastName), MD".trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        Text("Prescriber: \(prescriberName)")
                            .font(.system(size: 10, weight: .bold)) // 14/200*144 ≈ 10
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .padding(.vertical, 2)
            }
            
            // Full-width bottom section for practice and pharmacy info
            VStack(alignment: .leading, spacing: 1) {
                // Practice information spanning full width
                Text("Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA")
                    .font(.system(size: 8, weight: .regular)) // 11/200*144 ≈ 8
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Pharmacy info with fill volume spanning full width
                if let pharmacy = medication.baseMedication?.pharmacy {
                    let fillAmount = medication.fillAmount
                    let fillText = String(format: "%.2f", fillAmount)
                    let fillTextUnits = String(format: "%.0f", fillAmount * 100)
                    let pharmacyText = "\(pharmacy) \(fillText)mL (\(fillTextUnits)U)"
                    
                    Text(pharmacyText)
                        .font(.system(size: 8, weight: .bold)) // 11/200*144 ≈ 8
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
        .frame(width: 288, height: 144) // 2x1 inch at 144 DPI for preview
    }
    
    private var qrCodePlaceholder: some View {
        Image(systemName: "qrcode")
            .font(.system(size: 60)) // Reduced size to match smaller QR code
            .foregroundColor(.black)
    }
}



struct PrintPreviewView: View {
    let medication: DispencedMedication
    @Environment(\.dismiss) private var dismiss
    @State private var isPrinting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Print Preview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Patient info summary
                VStack(spacing: 4) {
                    if let patient = medication.patient {
                        Text(patient.displayName)
                            .font(.headline)
                    }
                    
                    Text(medication.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Scaled up preview
                MedicationLabelPreview(medication: medication)
                    .scaleEffect(2.5) // Scale up for better visibility
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Spacer()
                
                // Print actions
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isPrinting = true
                            await MedicationPrintManager.shared.printLabel(for: medication)
                            isPrinting = false
                            dismiss()
                        }
                    }) {
                        HStack {
                            if isPrinting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "printer.fill")
                            }
                            Text("Print Label")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPrinting)
                    
                    Button(action: {
                        Task {
                            await MedicationPrintManager.shared.sharePDF(for: medication)
                        }
                    }) {
                        Label("Share as PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
        MedicationLabelView(medication: dispensedMedication)
    }
    .environment(\.managedObjectContext, context)
}
