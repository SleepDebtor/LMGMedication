//
//  AddMedicationView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData

struct AddMedicationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let patient: Patient
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        animation: .default)
    private var localMedicationTemplates: FetchedResults<Medication>
    
    @StateObject private var cloudManager = CloudKitManager.shared
    
    @State private var selectedLocalTemplate: Medication?
    @State private var selectedCloudTemplate: CloudMedicationTemplate?
    @State private var templateSource = 0 // 0 = Local, 1 = Public
    @State private var medicationName = ""
    @State private var dose = ""
    @State private var doseUnit = "mg"
    @State private var dispenceAmount: Int = 1
    @State private var dispenceUnit = "syringes"
    @State private var dispenceDate = Date()
    @State private var expirationDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
    @State private var lotNumber = ""
    @State private var pharmacy = "Beaker Pharmacy"
    @State private var ingredient1 = ""
    @State private var concentration1: Double = 0
    @State private var ingredient2 = ""
    @State private var concentration2: Double = 0
    @State private var prescriberFirstName = ""
    @State private var prescriberLastName = ""
    @State private var injectable = false
    @State private var useTemplate = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var hasValidTemplate: Bool {
        if templateSource == 0 {
            return selectedLocalTemplate != nil
        } else {
            return selectedCloudTemplate != nil
        }
    }
    
    private var canSave: Bool {
        let validDose = dose.isEmpty || Double(dose) != nil
        
        if useTemplate {
            return hasValidTemplate && validDose
        } else {
            return !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validDose
        }
    }
    
    private var saveButtonStatusText: String {
        if !dose.isEmpty && Double(dose) == nil {
            return "Please enter a valid dose number"
        } else if useTemplate && !hasValidTemplate {
            return templateSource == 0 ? "Please select a local template" : "Please select a public template"
        } else if !useTemplate && medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please enter a medication name"
        } else {
            return "Ready to save"
        }
    }
    
    var body: some View {
        Form {
                Section(header: Text("Medication Source")) {
                    Toggle("Use Medication Template", isOn: $useTemplate)
                    
                    if useTemplate {
                        Picker("Template Source", selection: $templateSource) {
                            Text("My Templates").tag(0)
                            Text("Public Templates").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if templateSource == 0 {
                            // Local templates
                            if localMedicationTemplates.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No local templates available")
                                        .foregroundColor(.secondary)
                                    Text("Create templates in the main menu to speed up dispensing")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Picker("Select Local Template", selection: $selectedLocalTemplate) {
                                    Text("Choose a medication...").tag(nil as Medication?)
                                    ForEach(localMedicationTemplates) { template in
                                        Text(template.name ?? "Unknown").tag(template as Medication?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        } else {
                            // Public templates
                            if !cloudManager.isSignedInToiCloud {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sign in to iCloud to access public templates")
                                        .foregroundColor(.secondary)
                                    Text("Public templates are shared by healthcare professionals")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if cloudManager.publicMedicationTemplates.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No public templates available")
                                        .foregroundColor(.secondary)
                                    Text("Public templates are shared by the community")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Picker("Select Public Template", selection: $selectedCloudTemplate) {
                                    Text("Choose a medication...").tag(nil as CloudMedicationTemplate?)
                                    ForEach(cloudManager.publicMedicationTemplates) { template in
                                        Text(template.name).tag(template as CloudMedicationTemplate?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
                
                Section(header: Text("Medication Details")) {
                    if !useTemplate || (templateSource == 0 && selectedLocalTemplate == nil) || (templateSource == 1 && selectedCloudTemplate == nil) {
                        TextField("Medication Name", text: $medicationName)
                    } else {
                        HStack {
                            Text("Medication Name")
                            Spacer()
                            if templateSource == 0 {
                                Text(selectedLocalTemplate?.name ?? "")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(selectedCloudTemplate?.name ?? "")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Dose", text: $dose)
                            .keyboardType(.decimalPad)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        (!dose.isEmpty && Double(dose) == nil) ? Color.red : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        Picker("Unit", selection: $doseUnit) {
                            Text("mg").tag("mg")
                            Text("mcg").tag("mcg")
                            Text("ml").tag("ml")
                            Text("units").tag("units")
                        }
                        .pickerStyle(.menu)
                        
                        // Show parsed dose value for validation
                        if !dose.isEmpty {
                            if let parsedDose = Double(dose) {
                                Text("(\(String(format: "%.1f", parsedDose)))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("(Invalid)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    if !useTemplate || !hasValidTemplate {
                        Toggle("Injectable", isOn: $injectable)
                    } else {
                        HStack {
                            Text("Injectable")
                            Spacer()
                            if templateSource == 0 {
                                Text(selectedLocalTemplate?.injectable == true ? "Yes" : "No")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(selectedCloudTemplate?.injectable == true ? "Yes" : "No")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if !useTemplate || !hasValidTemplate {
                    Section(header: Text("Ingredients")) {
                        HStack {
                            TextField("Ingredient 1", text: $ingredient1)
                            TextField("mg", value: $concentration1, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                        }
                        
                        HStack {
                            TextField("Ingredient 2 (optional)", text: $ingredient2)
                            TextField("mg", value: $concentration2, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                        }
                    }
                } else {
                    Section(header: Text("Ingredients")) {
                        if templateSource == 0 {
                            if let template = selectedLocalTemplate {
                                if let ingredient1 = template.ingredient1, !ingredient1.isEmpty {
                                    HStack {
                                        Text(ingredient1)
                                        Spacer()
                                        Text("\(template.concentration1, specifier: "%.1f")")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let ingredient2 = template.ingredient2, !ingredient2.isEmpty {
                                    HStack {
                                        Text(ingredient2)
                                        Spacer()
                                        Text("\(template.concentration2, specifier: "%.1f")")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            if let template = selectedCloudTemplate {
                                if let ingredient1 = template.ingredient1, !ingredient1.isEmpty {
                                    HStack {
                                        Text(ingredient1)
                                        Spacer()
                                        Text("\(template.concentration1, specifier: "%.1f")")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let ingredient2 = template.ingredient2, !ingredient2.isEmpty {
                                    HStack {
                                        Text(ingredient2)
                                        Spacer()
                                        Text("\(template.concentration2, specifier: "%.1f")")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Dispensing Information")) {
                    Stepper("Quantity: \(dispenceAmount)", value: $dispenceAmount, in: 1...100)
                    
                    TextField("Dispense Unit", text: $dispenceUnit)
                    
                    DatePicker("Dispense Date", selection: $dispenceDate, displayedComponents: .date)
                    
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    
                    TextField("Lot Number", text: $lotNumber)
                }
                
                Section(header: Text("Pharmacy")) {
                    if !useTemplate || !hasValidTemplate {
                        TextField("Pharmacy Name", text: $pharmacy)
                    } else {
                        HStack {
                            Text("Pharmacy Name")
                            Spacer()
                            if templateSource == 0 {
                                Text(selectedLocalTemplate?.pharmacy ?? pharmacy)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(selectedCloudTemplate?.pharmacy ?? pharmacy)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Prescriber")) {
                    TextField("First Name", text: $prescriberFirstName)
                    TextField("Last Name", text: $prescriberLastName)
                }
                
                // Debug/Status section
                Section {
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(saveButtonStatusText)
                            .font(.caption)
                            .foregroundColor(canSave ? .green : .orange)
                    }
                    
                    // Prominent Save Button
                    Button(action: {
                        saveMedication()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Medication")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!canSave)
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Dispense Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMedication()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedLocalTemplate) { _, newTemplate in
                if let template = newTemplate, templateSource == 0 {
                    loadFromLocalTemplate(template)
                }
            }
            .onChange(of: selectedCloudTemplate) { _, newTemplate in
                if let template = newTemplate, templateSource == 1 {
                    loadFromCloudTemplate(template)
                }
            }
            .onAppear {
                // Auto-switch to manual entry if no templates exist
                if localMedicationTemplates.isEmpty {
                    useTemplate = false
                } else if useTemplate && templateSource == 0 {
                    selectedLocalTemplate = localMedicationTemplates.first
                }
            }
            .alert("Error Saving Medication", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }
    
    private func loadFromLocalTemplate(_ template: Medication) {
        medicationName = template.name ?? ""
        pharmacy = template.pharmacy ?? pharmacy
        ingredient1 = template.ingredient1 ?? ""
        concentration1 = template.concentration1
        ingredient2 = template.ingredient2 ?? ""
        concentration2 = template.concentration2
        injectable = template.injectable
    }
    
    private func loadFromCloudTemplate(_ template: CloudMedicationTemplate) {
        medicationName = template.name
        pharmacy = template.pharmacy ?? pharmacy
        ingredient1 = template.ingredient1 ?? ""
        concentration1 = template.concentration1
        ingredient2 = template.ingredient2 ?? ""
        concentration2 = template.concentration2
        injectable = template.injectable
    }
    
    private func saveMedication() {
        withAnimation {
            // Use selected template or create/find medication
            let medication: Medication
            if useTemplate && hasValidTemplate {
                if templateSource == 0, let template = selectedLocalTemplate {
                    medication = template
                } else {
                    // For cloud templates, we need to create/find a local medication
                    medication = findOrCreateMedication()
                }
            } else {
                medication = findOrCreateMedication()
            }
            
            // Create or find existing provider
            let provider = findOrCreateProvider()
            
            // Create dispensed medication record
            let dispensedMedication = DispencedMedication(context: viewContext)
            dispensedMedication.dose = dose.isEmpty ? nil : dose
            dispensedMedication.doseUnit = doseUnit
            dispensedMedication.dispenceAmt = Int16(dispenceAmount)
            dispensedMedication.dispenceUnit = dispenceUnit
            dispensedMedication.dispenceDate = dispenceDate
            dispensedMedication.expDate = expirationDate
            dispensedMedication.lotNum = lotNumber.isEmpty ? nil : lotNumber
            dispensedMedication.creationDate = Date()
            
            // Parse dose string to populate doseNum for fill amount calculations
            if !dose.isEmpty, let doseValue = Double(dose) {
                dispensedMedication.doseNum = doseValue
            } else {
                dispensedMedication.doseNum = 0.0
            }
            
            // Link relationships
            dispensedMedication.baseMedication = medication
            dispensedMedication.patient = patient
            dispensedMedication.prescriber = provider
            
            do {
                try viewContext.save()
                print("✅ Successfully saved dispensed medication for \(patient.displayName ?? "Unknown Patient")")
                dismiss()
            } catch {
                let nsError = error as NSError
                print("❌ Error saving medication: \(nsError), \(nsError.userInfo)")
                errorMessage = "Failed to save medication: \(nsError.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func findOrCreateMedication() -> Medication {
        // Try to find existing medication with the same name
        let request: NSFetchRequest<Medication> = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", medicationName)
        
        if let existingMedication = try? viewContext.fetch(request).first {
            // Update existing medication if needed
            existingMedication.ingredient1 = ingredient1.isEmpty ? nil : ingredient1
            existingMedication.concentration1 = concentration1
            existingMedication.ingredient2 = ingredient2.isEmpty ? nil : ingredient2
            existingMedication.concentration2 = concentration2
            existingMedication.pharmacy = pharmacy
            existingMedication.injectable = injectable
            return existingMedication
        } else {
            // Create new medication
            let newMedication = Medication(context: viewContext)
            newMedication.name = medicationName
            newMedication.ingredient1 = ingredient1.isEmpty ? nil : ingredient1
            newMedication.concentration1 = concentration1
            newMedication.ingredient2 = ingredient2.isEmpty ? nil : ingredient2
            newMedication.concentration2 = concentration2
            newMedication.pharmacy = pharmacy
            newMedication.injectable = injectable
            newMedication.timestamp = Date()
            return newMedication
        }
    }
    
    private func findOrCreateProvider() -> Provider {
        // Try to find existing provider
        let request: NSFetchRequest<Provider> = Provider.fetchRequest()
        request.predicate = NSPredicate(format: "firstName == %@ AND lastName == %@", 
                                       prescriberFirstName, prescriberLastName)
        
        if let existingProvider = try? viewContext.fetch(request).first {
            return existingProvider
        } else {
            // Create new provider
            let newProvider = Provider(context: viewContext)
            newProvider.firstName = prescriberFirstName.isEmpty ? nil : prescriberFirstName
            newProvider.lastName = prescriberLastName.isEmpty ? nil : prescriberLastName
            newProvider.timeStamp = Date()
            return newProvider
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let patient = Patient(context: context)
    patient.firstName = "Brittany"
    patient.lastName = "Kratzer"
    
    return AddMedicationView(patient: patient)
        .environment(\.managedObjectContext, context)
}
