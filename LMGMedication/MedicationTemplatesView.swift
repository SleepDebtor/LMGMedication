//
//  MedicationTemplatesView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData

struct MedicationTemplatesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        animation: .default)
    private var medications: FetchedResults<Medication>
    
    @State private var showingAddMedication = false
    @State private var searchText = ""
    
    var filteredMedications: [Medication] {
        if searchText.isEmpty {
            return Array(medications)
        } else {
            return medications.filter { medication in
                (medication.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (medication.ingredient1?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (medication.ingredient2?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search medications...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                List {
                    ForEach(filteredMedications, id: \.objectID) { medication in
                        MedicationTemplateRow(medication: medication)
                    }
                    .onDelete(perform: deleteMedications)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Medication Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddMedication = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationTemplateView()
            }
        }
    }
    
    private func deleteMedications(offsets: IndexSet) {
        withAnimation {
            let medicationsToDelete = offsets.map { filteredMedications[$0] }
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

struct MedicationTemplateRow: View {
    let medication: Medication
    @State private var showingEditTemplate = false
    
    var body: some View {
        Button(action: {
            showingEditTemplate = true
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(medication.name ?? "Unknown Medication")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if medication.injectable {
                        Image(systemName: "syringe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if let ingredient1 = medication.ingredient1, !ingredient1.isEmpty {
                    Text("\(ingredient1): \(medication.concentration1, specifier: "%.1f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let ingredient2 = medication.ingredient2, !ingredient2.isEmpty {
                    Text("\(ingredient2): \(medication.concentration2, specifier: "%.1f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let pharmacy = medication.pharmacy, !pharmacy.isEmpty {
                    HStack {
                        Image(systemName: "building.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(pharmacy)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show how many times this medication has been dispensed
                if let dispensedCount = medication.dispenced?.count, dispensedCount > 0 {
                    HStack {
                        Image(systemName: "pills")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Dispensed \(dispensedCount) time\(dispensedCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditTemplate) {
            EditMedicationTemplateView(medication: medication)
        }
    }
}

struct AddMedicationTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var medicationName = ""
    @State private var pharmacy = "Beaker Pharmacy"
    @State private var ingredient1 = ""
    @State private var concentration1: Double = 0
    @State private var ingredient2 = ""
    @State private var concentration2: Double = 0
    @State private var injectable = false
    @State private var pharmacyURL = ""
    @State private var urlForQR = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Medication Name", text: $medicationName)
                    TextField("Pharmacy", text: $pharmacy)
                    
                    Toggle("Injectable", isOn: $injectable)
                }
                
                Section(header: Text("Ingredients")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredient 1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ingredient name", text: $ingredient1)
                        HStack {
                            Text("Concentration:")
                            TextField("0.0", value: $concentration1, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredient 2 (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ingredient name", text: $ingredient2)
                        HStack {
                            Text("Concentration:")
                            TextField("0.0", value: $concentration2, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                Section(header: Text("URLs (Optional)")) {
                    TextField("Pharmacy URL", text: $pharmacyURL)
                    TextField("QR Code URL", text: $urlForQR)
                }
            }
            .navigationTitle("New Medication Template")
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
                    .disabled(medicationName.isEmpty)
                }
            }
        }
    }
    
    private func saveMedication() {
        let newMedication = Medication(context: viewContext)
        newMedication.name = medicationName
        newMedication.pharmacy = pharmacy
        newMedication.ingredient1 = ingredient1.isEmpty ? nil : ingredient1
        newMedication.concentration1 = concentration1
        newMedication.ingredient2 = ingredient2.isEmpty ? nil : ingredient2
        newMedication.concentration2 = concentration2
        newMedication.injectable = injectable
        newMedication.prarmacyURL = pharmacyURL.isEmpty ? nil : pharmacyURL
        newMedication.urlForQR = urlForQR.isEmpty ? nil : urlForQR
        newMedication.timestamp = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct EditMedicationTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let medication: Medication
    
    @State private var medicationName: String
    @State private var pharmacy: String
    @State private var ingredient1: String
    @State private var concentration1: Double
    @State private var ingredient2: String
    @State private var concentration2: Double
    @State private var injectable: Bool
    @State private var pharmacyURL: String
    @State private var urlForQR: String
    
    init(medication: Medication) {
        self.medication = medication
        _medicationName = State(initialValue: medication.name ?? "")
        _pharmacy = State(initialValue: medication.pharmacy ?? "")
        _ingredient1 = State(initialValue: medication.ingredient1 ?? "")
        _concentration1 = State(initialValue: medication.concentration1)
        _ingredient2 = State(initialValue: medication.ingredient2 ?? "")
        _concentration2 = State(initialValue: medication.concentration2)
        _injectable = State(initialValue: medication.injectable)
        _pharmacyURL = State(initialValue: medication.prarmacyURL ?? "")
        _urlForQR = State(initialValue: medication.urlForQR ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Medication Name", text: $medicationName)
                    TextField("Pharmacy", text: $pharmacy)
                    
                    Toggle("Injectable", isOn: $injectable)
                }
                
                Section(header: Text("Ingredients")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredient 1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ingredient name", text: $ingredient1)
                        HStack {
                            Text("Concentration:")
                            TextField("0.0", value: $concentration1, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredient 2 (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ingredient name", text: $ingredient2)
                        HStack {
                            Text("Concentration:")
                            TextField("0.0", value: $concentration2, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                Section(header: Text("URLs (Optional)")) {
                    TextField("Pharmacy URL", text: $pharmacyURL)
                    TextField("QR Code URL", text: $urlForQR)
                }
                
                if let dispensedCount = medication.dispenced?.count, dispensedCount > 0 {
                    Section(header: Text("Usage")) {
                        HStack {
                            Image(systemName: "pills")
                                .foregroundColor(.green)
                            Text("This medication has been dispensed \(dispensedCount) time\(dispensedCount == 1 ? "" : "s")")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Medication")
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
                    .disabled(medicationName.isEmpty)
                }
            }
        }
    }
    
    private func saveMedication() {
        medication.name = medicationName
        medication.pharmacy = pharmacy
        medication.ingredient1 = ingredient1.isEmpty ? nil : ingredient1
        medication.concentration1 = concentration1
        medication.ingredient2 = ingredient2.isEmpty ? nil : ingredient2
        medication.concentration2 = concentration2
        medication.injectable = injectable
        medication.prarmacyURL = pharmacyURL.isEmpty ? nil : pharmacyURL
        medication.urlForQR = urlForQR.isEmpty ? nil : urlForQR
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create some sample medications
    let med1 = Medication(context: context)
    med1.name = "Tirzepatide"
    med1.ingredient1 = "vitamin B6"
    med1.concentration1 = 25.0
    med1.pharmacy = "Beaker Pharmacy"
    med1.injectable = true
    
    let med2 = Medication(context: context)
    med2.name = "Semaglutide"
    med2.ingredient1 = "vitamin B12"
    med2.concentration1 = 50.0
    med2.pharmacy = "Compounding Plus"
    med2.injectable = true
    
    return MedicationTemplatesView()
        .environment(\.managedObjectContext, context)
}