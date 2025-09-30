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
    @StateObject private var cloudManager = CloudKitManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        animation: .default)
    private var localMedications: FetchedResults<Medication>
    
    @State private var showingAddMedication = false
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0 = Public, 1 = Local
    
    var filteredPublicTemplates: [CloudMedicationTemplate] {
        if searchText.isEmpty {
            return cloudManager.publicMedicationTemplates
        } else {
            return cloudManager.publicMedicationTemplates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                (template.ingredient1?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (template.ingredient2?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var filteredLocalMedications: [Medication] {
        if searchText.isEmpty {
            return Array(localMedications)
        } else {
            return localMedications.filter { medication in
                (medication.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (medication.ingredient1?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (medication.ingredient2?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Segmented Control for Public/Local
                Picker("Template Source", selection: $selectedSegment) {
                    Text("Public Templates").tag(0)
                    Text("My Templates").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // iCloud Status Banner
                if !cloudManager.isSignedInToiCloud && selectedSegment == 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "icloud.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Sign in to iCloud to access public medication templates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search medications...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                List {
                    if selectedSegment == 0 {
                        // Public Templates
                        if cloudManager.isSignedInToiCloud {
                            ForEach(filteredPublicTemplates, id: \.id) { template in
                                CloudMedicationTemplateRow(template: template)
                            }
                            
                            if filteredPublicTemplates.isEmpty && !searchText.isEmpty {
                                Text("No public templates match your search")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else if cloudManager.publicMedicationTemplates.isEmpty {
                                Text("No public templates available")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    } else {
                        // Local Templates
                        ForEach(filteredLocalMedications, id: \.objectID) { medication in
                            LocalMedicationTemplateRow(medication: medication)
                        }
                        .onDelete(perform: deleteLocalMedications)
                        
                        if filteredLocalMedications.isEmpty && !searchText.isEmpty {
                            Text("No local templates match your search")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    if selectedSegment == 0 {
                        await cloudManager.loadPublicMedicationTemplates()
                    }
                }
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
                    Menu {
                        if selectedSegment == 0 && cloudManager.isSignedInToiCloud {
                            Button("Add Public Template") {
                                showingAddMedication = true
                            }
                        } else {
                            Button("Add Local Template") {
                                showingAddMedication = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                if selectedSegment == 0 {
                    AddCloudMedicationTemplateView()
                } else {
                    AddMedicationTemplateView()
                }
            }
            .onAppear {
                if cloudManager.isSignedInToiCloud {
                    Task {
                        await cloudManager.loadPublicMedicationTemplates()
                    }
                }
            }
        }
    }
    
    private func deleteLocalMedications(offsets: IndexSet) {
        withAnimation {
            let medicationsToDelete = offsets.map { filteredLocalMedications[$0] }
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

struct CloudMedicationTemplateRow: View {
    let template: CloudMedicationTemplate
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            showingDetails = true
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        if template.injectable {
                            Image(systemName: "syringe")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                
                if !template.concentrationInfo.isEmpty {
                    Text(template.concentrationInfo)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let pharmacy = template.pharmacy, !pharmacy.isEmpty {
                    HStack {
                        Image(systemName: "building.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(pharmacy)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "person.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Public template")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(template.modifiedDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            CloudMedicationTemplateDetailView(template: template)
        }
    }
}

struct LocalMedicationTemplateRow: View {
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
                    
                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        if medication.injectable {
                            Image(systemName: "syringe")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
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
                        
                        Spacer()
                        
                        Text("Local template")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("Local template")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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

struct EditMedicationTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let medication: Medication
    
    @State private var medicationName = ""
    @State private var pharmacy = ""
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
            .navigationTitle("Edit Template")
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
            .onAppear {
                loadFromMedication()
            }
        }
    }
    
    private func loadFromMedication() {
        medicationName = medication.name ?? ""
        pharmacy = medication.pharmacy ?? ""
        ingredient1 = medication.ingredient1 ?? ""
        concentration1 = medication.concentration1
        ingredient2 = medication.ingredient2 ?? ""
        concentration2 = medication.concentration2
        injectable = medication.injectable
        pharmacyURL = medication.prarmacyURL ?? ""
        urlForQR = medication.urlForQR ?? ""
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
        medication.timestamp = Date() // Update the timestamp to reflect the edit
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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
            .navigationTitle("New Local Template")
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

struct AddCloudMedicationTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudManager = CloudKitManager.shared
    
    @State private var medicationName = ""
    @State private var pharmacy = "Beaker Pharmacy"
    @State private var ingredient1 = ""
    @State private var concentration1: Double = 0
    @State private var ingredient2 = ""
    @State private var concentration2: Double = 0
    @State private var injectable = false
    @State private var pharmacyURL = ""
    @State private var urlForQR = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                if !cloudManager.isSignedInToiCloud {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "icloud.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("iCloud Required")
                                .font(.headline)
                            Text("Sign in to iCloud to create public medication templates that can be shared with other healthcare professionals.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } else {
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
                    
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public Template Notice")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("This template will be visible to all users of the app and can be used by other healthcare professionals to speed up medication dispensing.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("New Public Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveTemplate()
                        }
                    }
                    .disabled(medicationName.isEmpty || !cloudManager.isSignedInToiCloud || isSubmitting)
                }
            }
        }
    }
    
    private func saveTemplate() async {
        isSubmitting = true
        errorMessage = nil
        
        let template = CloudMedicationTemplate(
            name: medicationName,
            pharmacy: pharmacy.isEmpty ? nil : pharmacy,
            ingredient1: ingredient1.isEmpty ? nil : ingredient1,
            concentration1: concentration1,
            ingredient2: ingredient2.isEmpty ? nil : ingredient2,
            concentration2: concentration2,
            injectable: injectable,
            pharmacyURL: pharmacyURL.isEmpty ? nil : pharmacyURL,
            urlForQR: urlForQR.isEmpty ? nil : urlForQR
        )
        
        do {
            let _ = try await cloudManager.createPublicMedicationTemplate(template)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save template: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

struct CloudMedicationTemplateDetailView: View {
    let template: CloudMedicationTemplate
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(template.name)
                            .foregroundColor(.secondary)
                    }
                    
                    if let pharmacy = template.pharmacy {
                        HStack {
                            Text("Pharmacy")
                            Spacer()
                            Text(pharmacy)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Injectable")
                        Spacer()
                        Text(template.injectable ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }
                }
                
                if template.ingredient1 != nil || template.ingredient2 != nil {
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
                
                Section(header: Text("Details")) {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(template.createdDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Modified")
                        Spacer()
                        Text(template.modifiedDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text("Public Template")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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