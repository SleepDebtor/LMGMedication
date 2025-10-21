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
    @State private var isUpdatingNextDose = false
    @State private var isEditing = false
    @State private var hasChanges = false
    
    // Editable properties
    @State private var editDose = ""
    @State private var editDoseUnit = "mg"
    @State private var editDispenceAmount: Int = 1
    @State private var editDispenceUnitType: DispenseUnit = .syringe
    @State private var editLotNumber = ""
    @State private var editExpirationDate = Date()
    
    // Providers for selection
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Provider.lastName, ascending: true),
            NSSortDescriptor(keyPath: \Provider.firstName, ascending: true)
        ],
        animation: .default)
    private var providers: FetchedResults<Provider>

    // Additional editable fields to reach parity with creation page
    @State private var editDosingFrequency: DosingFrequency = .daily
    @State private var editAmtEachTime: Int = 1
    @State private var editAdditionalSig: String = ""
    @State private var editDispenceDate: Date = Date()
    @State private var editSelectedProvider: Provider?
    
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
                                
                                Picker("Unit", selection: $editDispenceUnitType) {
                                    ForEach(DispenseUnit.allCases) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Frequency:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Frequency", selection: $editDosingFrequency) {
                                    ForEach(DosingFrequency.allCases) { freq in
                                        Text(freq.rawValue).tag(freq)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: editDosingFrequency) { _, _ in hasChanges = true }
                            }

                            HStack {
                                Text("Amount each time:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Stepper("\(editAmtEachTime)", value: $editAmtEachTime, in: 1...10)
                                    .onChange(of: editAmtEachTime) { _, _ in hasChanges = true }
                            }

                            // Optional Sig preview (read-only)
                            HStack {
                                Text("Sig:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let sigPreview = "\(editAmtEachTime) \(editDispenceUnitType.label(for: editAmtEachTime)) \(editDosingFrequency.instructionsSuffix)"
                                Text(sigPreview)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }

                            HStack {
                                Text("Additional Sig:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Additional Sig (optional)", text: $editAdditionalSig)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: editAdditionalSig) { _, _ in hasChanges = true }
                            }

                            HStack {
                                Text("Dispense Date:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $editDispenceDate, displayedComponents: .date)
                                    .onChange(of: editDispenceDate) { _, _ in hasChanges = true }
                            }

                            // Provider selection
                            if providers.isEmpty {
                                HStack {
                                    Text("No providers found")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Text("Provider:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Picker("Provider", selection: $editSelectedProvider) {
                                        ForEach(providers) { provider in
                                            let first = provider.firstName ?? ""
                                            let last = provider.lastName ?? ""
                                            let degree = provider.degree?.isEmpty == false ? ", \(provider.degree!)" : ""
                                            Text("\(first) \(last)\(degree)").tag(provider as Provider?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: editSelectedProvider) { _, _ in hasChanges = true }
                                }
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
                        .onChange(of: editDispenceUnitType) { _, _ in hasChanges = true }
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
                    
                    if medication.baseMedication?.injectable == true {
                        // Injectable medication preview (400x200 scaled to 288x144)
                        InjectableLabelPreview(medication: medication)
                            .frame(width: 288, height: 144) // 2x1 inch at 144 DPI for preview
                            .border(Color.gray, width: 1)
                            .cornerRadius(4)
                    } else {
                        // Non-injectable medication preview (216x144 at actual size)
                        NonInjectableLabelPreview(medication: medication)
                            .frame(width: 216, height: 144) // 3x2 inch at 72 DPI for preview
                            .border(Color.gray, width: 1)
                            .cornerRadius(4)
                    }
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
                        
                        VStack(spacing: 12) {
                            // Print and update button (full width, green)
                            Button(action: {
                                Task {
                                    isProcessing = true
                                    await MedicationPrintManager.shared.printLabel(for: medication)
                                    isProcessing = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isProcessing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "printer.fill")
                                    }
                                    Text("Print and Update Next Dose")
                                        .font(.system(size: 16, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                            .disabled(isProcessing || isUpdatingNextDose)
                            
                            Button(action: {
                                Task {
                                    isProcessing = true
                                    await MedicationPrintManager.shared.reprintLabel(for: medication)
                                    isProcessing = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "printer")
                                    Text("Reprint (No Update)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(isProcessing || isUpdatingNextDose)

                            // Update-only button (full width, tan)
                            Button(action: {
                                Task {
                                    isUpdatingNextDose = true
                                    // Update next dose without printing
                                    medication.updateNextDoseDueOnPrint()
                                    do {
                                        try viewContext.save()
                                    } catch {
                                        print("Failed to save next dose update: \(error)")
                                    }
                                    isUpdatingNextDose = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isUpdatingNextDose {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "calendar.badge.plus")
                                    }
                                    Text("Update Next Dose")
                                        .font(.system(size: 16, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(Color(red: 210/255, green: 180/255, blue: 140/255))
                            .disabled(isProcessing || isUpdatingNextDose)
                        }
                        
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
                            Label("Print and Update Next Dose", systemImage: "printer")
                        }
                        
                        Button(action: {
                            Task {
                                await MedicationPrintManager.shared.reprintLabel(for: medication)
                            }
                        }) {
                            Label("Reprint (No Update)", systemImage: "printer")
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
        editDispenceUnitType = medication.dispenseUnitType
        editLotNumber = medication.lotNum ?? ""
        editExpirationDate = medication.expDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60)
        
        editDosingFrequency = medication.dosingFrequency
        editAmtEachTime = max(1, Int(medication.amtEachTime))
        editAdditionalSig = medication.additionalSg ?? ""
        editDispenceDate = medication.dispenceDate ?? Date()
        editSelectedProvider = medication.prescriber ?? providers.first
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
        
        // Keep numeric dose in sync with string dose for fill amount calculations
        if let text = medication.dose, let numeric = Double(text) {
            medication.doseNum = numeric
        } else {
            medication.doseNum = 0.0
        }
        
        medication.doseUnit = editDoseUnit
        medication.dispenceAmt = Int16(editDispenceAmount)
        medication.dispenseUnitType = editDispenceUnitType
        medication.lotNum = editLotNumber.isEmpty ? nil : editLotNumber
        medication.expDate = editExpirationDate

        // Update additional editable fields
        medication.dosingFrequency = editDosingFrequency
        medication.amtEachTime = Int16(editAmtEachTime)
        medication.additionalSg = editAdditionalSig.isEmpty ? nil : editAdditionalSig
        medication.dispenceDate = editDispenceDate
        if let selected = editSelectedProvider { medication.prescriber = selected }

        // Regenerate Sig from current fields
        let regeneratedSig = "\(editAmtEachTime) \(medication.dispenseUnitType.label(for: editAmtEachTime)) \(editDosingFrequency.instructionsSuffix)"
        medication.sig = regeneratedSig
        
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

struct InjectableLabelPreview: View {
    let medication: DispencedMedication
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
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
                    let dispenseUnit = medication.dispenseUnitType.label(for: dispenseAmt)
                    let dispenseInfo = "Disp: \(dispenseAmt) \(dispenseUnit)"
                    Text(dispenseInfo)
                        .font(.system(size: 12, weight: .bold)) // 17/200*144 ≈ 12
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Dosing instructions
                    let sig = medication.sig ?? "Take as directed."
                    let additionalSig = medication.additionalSg.flatMap { $0.isEmpty ? nil : " \($0)" } ?? ""
                    let dosingInstructions = sig + additionalSig
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
                
                // Practice information spanning full width
                Text("Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA")
                    .font(.system(size: 8, weight: .regular)) // 11/200*144 ≈ 8
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Pharmacy info with fill volume spanning full width
                if let pharmacy = medication.baseMedication?.pharmacy {
                    let pharmacyText: String = {
                        let fillAmount = medication.fillAmount
                        let fillText = String(format: "%.2f", fillAmount)
                        let fillTextUnits = String(format: "%.0f", fillAmount * 100)
                        var text = "\(pharmacy) \(fillText)mL (\(fillTextUnits)U)"
                        if let lot = medication.lotNum, !lot.isEmpty {
                            text += " • Lot: \(lot)"
                        }
                        if let exp = medication.expDate {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            text += " • Exp: \(formatter.string(from: exp))"
                        }
                        return text
                    }()
                    
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
        .background(Color.white)
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

struct NonInjectableLabelPreview: View {
    let medication: DispencedMedication
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
            
            VStack(spacing: 0) {
                // Practice header - centered and prominent
                VStack(spacing: 1) {
                    Text("LAZAR MEDICAL GROUP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("400 Market St, Suite 5, Williamsport, PA 17701")
                        .font(.system(size: 8))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("Phone: (570) 933-5507")
                        .font(.system(size: 8))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                
                Spacer(minLength: 4)
                
                // Patient and medication info
                VStack(alignment: .leading, spacing: 2) {
                    // Patient name
                    if let patient = medication.patient {
                        let firstName = patient.firstName ?? "Patient"
                        let lastName = patient.lastName ?? "Unknown"
                        Text("Patient: \(firstName) \(lastName)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    // Date of birth (if available)
                    if let patient = medication.patient, let birthdate = patient.birthdate {
                        Text("DOB: \(birthdate, style: .date)")
                            .font(.system(size: 9))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    // Prescription date
                    if let dispenseDate = medication.dispenceDate {
                        Text("Date: \(dispenseDate, style: .date)")
                            .font(.system(size: 9))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    
                    // Medication name and strength
                    let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
                    let dose = medication.dose ?? ""
                    let doseUnit = medication.doseUnit ?? ""
                    let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
                    
                    Text(medicationTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 2)
                    
                    // Generic name or secondary ingredient (if different)
                    if let ingredient1 = medication.baseMedication?.ingredient1,
                       !ingredient1.isEmpty,
                       ingredient1.lowercased() != medicationName.lowercased() {
                        Text("Generic: \(ingredient1)")
                            .font(.system(size: 9))
                            .italic()
                            .foregroundColor(Color(.darkGray))
                            .lineLimit(1)
                    }
                    
                    // Quantity dispensed
                    let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
                    let dispenseUnit = medication.dispenseUnitType.label(for: dispenseAmt)
                    Text("Qty: \(dispenseAmt) \(dispenseUnit)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    //Sig
                    let sig = medication.sig ?? "Take as directed."
                    let additionalSig = medication.additionalSg.flatMap { $0.isEmpty ? nil : " \($0)" } ?? ""
                    let dosingInstructions = sig + additionalSig
                    Text("Sig: \(dosingInstructions)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    // Prescriber information
                    if let prescriber = medication.prescriber {
                        let firstName = prescriber.firstName ?? ""
                        let lastName = prescriber.lastName ?? ""
                        let prescriberName = "\(firstName) \(lastName), MD".trimmingCharacters(in: .whitespacesAndNewlines)
                        Text("Prescriber: \(prescriberName)")
                            .font(.system(size: 9))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    // Pharmacy information (if available)
                    if let pharmacy = medication.baseMedication?.pharmacy {
                        Text("Pharmacy: \(pharmacy)")
                            .font(.system(size: 8))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                
                Spacer()
                
                // Lot and Expiration at bottom right
                HStack {
                    Spacer()
                    let lotText: String? = {
                        if let lot = medication.lotNum, !lot.isEmpty { return "Lot: \(lot)" } else { return nil }
                    }()
                    let expText: String? = {
                        if let exp = medication.expDate {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            return "Exp: \(formatter.string(from: exp))"
                        } else { return nil }
                    }()
                    let combined = [lotText, expText].compactMap { $0 }.joined(separator: " • ")
                    if !combined.isEmpty {
                        Text(combined)
                            .font(.system(size: 7))
                            .foregroundColor(Color(.darkGray))
                            .padding(.trailing, 4)
                            .padding(.bottom, 2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
        .frame(width: 216, height: 144) // 3x2 inch at 72 DPI
    }
}



struct PrintPreviewView: View {
    let medication: DispencedMedication
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPrinting = false
    @State private var isUpdatingNextDose = false
    
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
                if medication.baseMedication?.injectable == true {
                    InjectableLabelPreview(medication: medication)
                        .scaleEffect(2.5) // Scale up for better visibility
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                } else {
                    NonInjectableLabelPreview(medication: medication)
                        .scaleEffect(2.5) // Scale up for better visibility  
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Print actions
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        let spacing: CGFloat = 12
                        let totalWidth = max(0, geo.size.width - spacing)
                        let leftWidth = totalWidth * 0.75
                        let rightWidth = totalWidth * 0.25

                        HStack(spacing: spacing) {
                            // Print and update button (75% width, green)
                            Button(action: {
                                Task {
                                    isPrinting = true
                                    await MedicationPrintManager.shared.printLabel(for: medication)
                                    isPrinting = false
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isPrinting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "printer.fill")
                                    }
                                    Text("Print and Update Next Dose")
                                        .font(.system(size: 16, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.75)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(width: leftWidth, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                            .disabled(isPrinting || isUpdatingNextDose)

                            // Update-only button (25% width, tan)
                            Button(action: {
                                Task {
                                    isUpdatingNextDose = true
                                    medication.updateNextDoseDueOnPrint()
                                    do {
                                        try viewContext.save()
                                    } catch {
                                        print("Failed to save next dose update: \(error)")
                                    }
                                    isUpdatingNextDose = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isUpdatingNextDose {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "calendar.badge.plus")
                                    }
                                    Text("Update Next Dose")
                                        .font(.system(size: 15, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(width: rightWidth, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(Color(red: 210/255, green: 180/255, blue: 140/255))
                            .disabled(isPrinting || isUpdatingNextDose)
                        }
                    }
                    .frame(height: 60)

                    Button(action: {
                        Task {
                            isPrinting = true
                            await MedicationPrintManager.shared.reprintLabel(for: medication)
                            isPrinting = false
                            dismiss()
                        }
                    }) {
                        Label("Reprint (No Update)", systemImage: "printer")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isPrinting || isUpdatingNextDose)

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
    
    private func viewContextSaveIfAvailable() throws {
        // Attempt to save via environment context if available
        if let context = try? _viewContext.wrappedValue { // fallback not typically needed
            if context.hasChanges {
                try context.save()
            }
        } else {
            // If no environment context, do nothing
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
