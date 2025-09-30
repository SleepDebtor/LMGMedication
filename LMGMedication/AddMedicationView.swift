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
    private var medicationTemplates: FetchedResults<Medication>
    
    @State private var selectedTemplate: Medication?
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Source")) {
                    Toggle("Use Medication Template", isOn: $useTemplate)
                    
                    if useTemplate {
                        if medicationTemplates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No medication templates available")
                                    .foregroundColor(.secondary)
                                Text("Create templates in the main menu to speed up dispensing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Picker("Select Template", selection: $selectedTemplate) {
                                Text("Choose a medication...").tag(nil as Medication?)
                                ForEach(medicationTemplates) { template in
                                    Text(template.name ?? "Unknown").tag(template as Medication?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                Section(header: Text("Medication Details")) {
                    if !useTemplate || selectedTemplate == nil {
                        TextField("Medication Name", text: $medicationName)
                    } else {
                        HStack {
                            Text("Medication Name")
                            Spacer()
                            Text(selectedTemplate?.name ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        TextField("Dose", text: $dose)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            Text("mg").tag("mg")
                            Text("mcg").tag("mcg")
                            Text("ml").tag("ml")
                            Text("units").tag("units")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if !useTemplate || selectedTemplate == nil {
                        Toggle("Injectable", isOn: $injectable)
                    } else {
                        HStack {
                            Text("Injectable")
                            Spacer()
                            Text(selectedTemplate?.injectable == true ? "Yes" : "No")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !useTemplate || selectedTemplate == nil {
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
                } else if let template = selectedTemplate {
                    Section(header: Text("Ingredients")) {
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
                
                Section(header: Text("Dispensing Information")) {
                    Stepper("Quantity: \(dispenceAmount)", value: $dispenceAmount, in: 1...100)
                    
                    TextField("Dispense Unit", text: $dispenceUnit)
                    
                    DatePicker("Dispense Date", selection: $dispenceDate, displayedComponents: .date)
                    
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    
                    TextField("Lot Number", text: $lotNumber)
                }
                
                Section(header: Text("Pharmacy")) {
                    if !useTemplate || selectedTemplate == nil {
                        TextField("Pharmacy Name", text: $pharmacy)
                    } else {
                        HStack {
                            Text("Pharmacy Name")
                            Spacer()
                            Text(selectedTemplate?.pharmacy ?? pharmacy)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Prescriber")) {
                    TextField("First Name", text: $prescriberFirstName)
                    TextField("Last Name", text: $prescriberLastName)
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
                    .disabled((useTemplate && selectedTemplate == nil) || (!useTemplate && medicationName.isEmpty))
                }
            }
            .onChange(of: selectedTemplate) { _, newTemplate in
                if let template = newTemplate {
                    loadFromTemplate(template)
                }
            }
            .onAppear {
                if useTemplate && !medicationTemplates.isEmpty {
                    selectedTemplate = medicationTemplates.first
                }
            }
        }
    }
    
    private func loadFromTemplate(_ template: Medication) {
        medicationName = template.name ?? ""
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
            if useTemplate, let template = selectedTemplate {
                medication = template
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
            
            // Link relationships
            dispensedMedication.baseMedication = medication
            dispensedMedication.patient = patient
            dispensedMedication.prescriber = provider
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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