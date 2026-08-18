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
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Provider.lastName, ascending: true),
            NSSortDescriptor(keyPath: \Provider.firstName, ascending: true)
        ],
        animation: .default)
    private var providers: FetchedResults<Provider>
    
    @StateObject private var cloudManager = CloudKitManager.shared
    
    @State private var selectedLocalTemplate: Medication?
    @State private var selectedCloudTemplate: CloudMedicationTemplate?
    @State private var showingEditTemplate = false
    @State private var templateSource = 0 // 0 = Local, 1 = Public
    @State private var medicationName = ""
    @State private var dose = ""
    @State private var doseUnit = "mg"
    @State private var dispenceAmount: Int = 1
    @State private var dispenceUnitType: DispenseUnit = .syringe
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
    @State private var dosingFrequency: DosingFrequency = .daily
    @State private var amtEachTime: Int = 1
    @State private var additionalSig: String = ""
    @State private var useTemplate = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var selectedProvider: Provider?
    
    private var medicationDetailsSectionTitle: String {
        useTemplate && hasValidTemplate ? "Medication Details" : "New Medication Details"
    }
    
    private var ingredientsSectionTitle: String {
        useTemplate && hasValidTemplate ? "Ingredients" : "New Medication Ingredients"
    }
    
    private var primarySaveButtonTitle: String {
        useTemplate ? "Save Medication" : "Create & Dispense"
    }
    
    private var sortedLocalMedicationTemplates: [Medication] {
        Array(localMedicationTemplates).sorted { lhs, rhs in
            let lhsName = lhs.name ?? ""
            let rhsName = rhs.name ?? ""
            let nameComparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            
            if lhs.concentration1 != rhs.concentration1 {
                return lhs.concentration1 < rhs.concentration1
            }
            
            if lhs.concentration2 != rhs.concentration2 {
                return lhs.concentration2 < rhs.concentration2
            }
            
            return (lhs.pharmacy ?? "").localizedCaseInsensitiveCompare(rhs.pharmacy ?? "") == .orderedAscending
        }
    }
    
    private var sortedPublicMedicationTemplates: [CloudMedicationTemplate] {
        cloudManager.publicMedicationTemplates.sorted { lhs, rhs in
            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            
            if lhs.concentration1 != rhs.concentration1 {
                return lhs.concentration1 < rhs.concentration1
            }
            
            if lhs.concentration2 != rhs.concentration2 {
                return lhs.concentration2 < rhs.concentration2
            }
            
            return (lhs.pharmacy ?? "").localizedCaseInsensitiveCompare(rhs.pharmacy ?? "") == .orderedAscending
        }
    }
    
    private var selectedTemplateConcentrationInfo: String? {
        guard useTemplate else { return nil }
        
        let concentrationInfo: String?
        if templateSource == 0, let template = selectedLocalTemplate {
            concentrationInfo = template.concentrationInfo
        } else if templateSource == 1, let template = selectedCloudTemplate {
            concentrationInfo = template.concentrationInfo
        } else {
            return nil
        }
        
        let trimmedInfo = concentrationInfo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedInfo.isEmpty ? "No concentration entered" : trimmedInfo
    }
    
    private var selectedTemplatePharmacyInfo: String? {
        guard useTemplate else { return nil }
        
        if templateSource == 0 {
            return selectedLocalTemplate?.pharmacy
        } else {
            return selectedCloudTemplate?.pharmacy
        }
    }
    
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
    
    private var generatedSig: String { "\(amtEachTime) \(dispenceUnitType.label(for: amtEachTime)) \(dosingFrequency.instructionsSuffix)" }
    
    var body: some View {
        Form {
                Section(header: Text("Medication")) {
                    Picker("Medication Entry", selection: $useTemplate) {
                        Text("Select Template").tag(true)
                        Text("Create New").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if useTemplate {
                        Picker("Template Source", selection: $templateSource) {
                            Text("My Templates").tag(0)
                            Text("Public Templates").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if templateSource == 0 {
                            // Local templates
                            if sortedLocalMedicationTemplates.isEmpty {
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
                                    ForEach(sortedLocalMedicationTemplates) { template in
                                        Text(template.selectionDisplayValue).tag(template as Medication?)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                // Edit selected local template
                                if selectedLocalTemplate != nil {
                                    Button(action: { showingEditTemplate = true }) {
                                        Label("Edit Selected Template", systemImage: "pencil")
                                    }
                                }
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
                            } else if sortedPublicMedicationTemplates.isEmpty {
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
                                    ForEach(sortedPublicMedicationTemplates) { template in
                                        Text(template.selectionDisplayValue).tag(template as CloudMedicationTemplate?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        if let concentrationInfo = selectedTemplateConcentrationInfo {
                            SelectedTemplateConcentrationSummaryView(
                                concentrationInfo: concentrationInfo,
                                pharmacy: selectedTemplatePharmacyInfo
                            )
                        }
                        
                        Button(action: prepareNewMedicationEntry) {
                            Label("Create New Medication", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Label("Creating New Medication", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text(medicationDetailsSectionTitle)) {
                    if !useTemplate || (templateSource == 0 && selectedLocalTemplate == nil) || (templateSource == 1 && selectedCloudTemplate == nil) {
                        TextField(useTemplate ? "Medication Name" : "New Medication Name", text: $medicationName)
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
                    Section(header: Text(ingredientsSectionTitle)) {
                        HStack {
                            TextField("Ingredient 1", text: $ingredient1)
                            TextField("mg/mL", value: $concentration1, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                        }
                        
                        HStack {
                            TextField("Ingredient 2 (optional)", text: $ingredient2)
                            TextField("mg/mL", value: $concentration2, format: .number)
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
                                        Text("\(template.concentration1, specifier: "%.1f") mg/mL")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let ingredient2 = template.ingredient2, !ingredient2.isEmpty {
                                    HStack {
                                        Text(ingredient2)
                                        Spacer()
                                        Text("\(template.concentration2, specifier: "%.1f") mg/mL")
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
                                        Text("\(template.concentration1, specifier: "%.1f") mg/mL")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let ingredient2 = template.ingredient2, !ingredient2.isEmpty {
                                    HStack {
                                        Text(ingredient2)
                                        Spacer()
                                        Text("\(template.concentration2, specifier: "%.1f") mg/mL")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Dispensing Information")) {
                    Stepper("Quantity: \(dispenceAmount)", value: $dispenceAmount, in: 1...100)
                    
                    Picker("Dispense Unit", selection: $dispenceUnitType) {
                        ForEach(DispenseUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Frequency", selection: $dosingFrequency) {
                        ForEach(DosingFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    DatePicker("Dispense Date", selection: $dispenceDate, displayedComponents: .date)
                    
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    
                    TextField("Lot Number", text: $lotNumber)
                }
                
//                Section(header: Text("Frequency")) {
//                    Picker("Frequency", selection: $dosingFrequency) {
//                        ForEach(DosingFrequency.allCases) { freq in
//                            Text(freq.rawValue).tag(freq)
//                        }
//                    }
//                    .pickerStyle(.menu)
//                }
                
                Section(header: Text("Directions")) {
                    Stepper("Amount each time: \(amtEachTime)", value: $amtEachTime, in: 1...10)

                    // Non-editable Sig generated automatically
                    HStack {
                        Text("Sig")
                        Spacer()
                        TextField("Sig", text: .constant(generatedSig))
                            .disabled(true)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    TextField("Additional Sig (optional)", text: $additionalSig)
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
                    if providers.isEmpty {
                        HStack {
                            Text("No providers found. A default provider will be created.")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(providers) { provider in
                                let first = provider.firstName ?? ""
                                let last = provider.lastName ?? ""
                                let degree = provider.degree?.isEmpty == false ? ", \(provider.degree!)" : ""
                                Text("\(first) \(last)\(degree)")
                                    .tag(provider as Provider?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
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
                            Text(primarySaveButtonTitle)
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
            .onChange(of: useTemplate) { _, newValue in
                if newValue {
                    selectDefaultTemplateIfNeeded()
                } else {
                    prepareNewMedicationEntry()
                }
            }
            .onChange(of: templateSource) { _, _ in
                if useTemplate {
                    selectDefaultTemplateIfNeeded()
                }
            }
            .onAppear {
                // Auto-switch to manual entry if no templates exist
                if sortedLocalMedicationTemplates.isEmpty {
                    useTemplate = false
                } else if useTemplate && templateSource == 0 {
                    selectDefaultTemplateIfNeeded()
                }
                
                // Ensure a provider exists and default-select the first one
                if providers.isEmpty {
                    createDefaultProvider()
                } else if selectedProvider == nil {
                    selectedProvider = providers.first
                }
            }
            .sheet(isPresented: $showingEditTemplate) {
                if let template = selectedLocalTemplate {
                    EditMedicationTemplateView(medication: template)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("Error Saving Medication", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }
    
    private func selectDefaultTemplateIfNeeded() {
        if templateSource == 0 {
            let template = selectedLocalTemplate ?? sortedLocalMedicationTemplates.first
            selectedLocalTemplate = template
            
            if let template = template {
                loadFromLocalTemplate(template)
            }
        } else {
            let template = selectedCloudTemplate ?? sortedPublicMedicationTemplates.first
            selectedCloudTemplate = template
            
            if let template = template {
                loadFromCloudTemplate(template)
            }
        }
    }
    
    private func prepareNewMedicationEntry() {
        useTemplate = false
        selectedLocalTemplate = nil
        selectedCloudTemplate = nil
        medicationName = ""
        ingredient1 = ""
        concentration1 = 0
        ingredient2 = ""
        concentration2 = 0
        injectable = false
        pharmacy = "Beaker Pharmacy"
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
            dispensedMedication.isActive = true
            dispensedMedication.dose = dose.isEmpty ? nil : dose
            dispensedMedication.doseUnit = doseUnit
            dispensedMedication.dispenceAmt = Int16(dispenceAmount)
            dispensedMedication.dispenceUnit = dispenceUnitType.rawValue
            dispensedMedication.dispenceDate = dispenceDate
            dispensedMedication.expDate = expirationDate
            dispensedMedication.lotNum = lotNumber.isEmpty ? nil : lotNumber
            dispensedMedication.createdDate = Date()
            dispensedMedication.dosingFrequency = dosingFrequency
            dispensedMedication.sig = generatedSig
            dispensedMedication.additionalSg = additionalSig.isEmpty ? nil : additionalSig
            
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
            patient.addToMedicationsPrescribed(dispensedMedication)
            
            do {
                try viewContext.save()
                let count = patient.dispensedMedicationsArray.count
                print("✅ Successfully saved dispensed medication for \(patient.displayName). Now patient has \(count) dispensed medication(s).")
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
        let normalizedMedicationName = normalizedMedicationText(medicationName)
        let request: NSFetchRequest<Medication> = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", normalizedMedicationName)
        
        if let existingMedication = (try? viewContext.fetch(request))?.first(where: medicationMatchesCurrentEntry) {
            return existingMedication
        }
        
        let newMedication = Medication(context: viewContext)
        newMedication.name = normalizedMedicationName
        newMedication.ingredient1 = normalizedOptionalMedicationText(ingredient1)
        newMedication.concentration1 = concentration1
        newMedication.ingredient2 = normalizedOptionalMedicationText(ingredient2)
        newMedication.concentration2 = concentration2
        newMedication.pharmacy = normalizedOptionalMedicationText(pharmacy)
        newMedication.injectable = injectable
        newMedication.timestamp = Date()
        return newMedication
    }
    
    private func medicationMatchesCurrentEntry(_ medication: Medication) -> Bool {
        normalizedMedicationComparisonText(medication.name) == normalizedMedicationComparisonText(medicationName) &&
        normalizedMedicationComparisonText(medication.pharmacy) == normalizedMedicationComparisonText(pharmacy) &&
        normalizedMedicationComparisonText(medication.ingredient1) == normalizedMedicationComparisonText(ingredient1) &&
        normalizedMedicationComparisonText(medication.ingredient2) == normalizedMedicationComparisonText(ingredient2) &&
        medication.injectable == injectable &&
        concentrationsMatch(medication.concentration1, concentration1) &&
        concentrationsMatch(medication.concentration2, concentration2)
    }
    
    private func concentrationsMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.0001
    }
    
    private func normalizedOptionalMedicationText(_ value: String) -> String? {
        let normalizedValue = normalizedMedicationText(value)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }
    
    private func normalizedMedicationComparisonText(_ value: String?) -> String {
        normalizedMedicationText(value).lowercased()
    }
    
    private func normalizedMedicationText(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func findOrCreateProvider() -> Provider {
        if let selected = selectedProvider {
            return selected
        }
        if let first = providers.first {
            return first
        }
        // If no providers exist, create a default one
        let provider = Provider(context: viewContext)
        provider.firstName = "Default"
        provider.lastName = "Provider"
        provider.timeStamp = Date()
        return provider
    }
    
    private func createDefaultProvider() {
        let defaultProvider = Provider(context: viewContext)
        defaultProvider.firstName = "Default"
        defaultProvider.lastName = "Provider"
        defaultProvider.timeStamp = Date()
        do {
            try viewContext.save()
            selectedProvider = defaultProvider
        } catch {
            print("Failed to create default provider: \(error)")
        }
    }
}

private struct SelectedTemplateConcentrationSummaryView: View {
    let concentrationInfo: String
    let pharmacy: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Concentration")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(concentrationInfo)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let pharmacy = pharmacy, !pharmacy.isEmpty {
                Text(pharmacy)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
