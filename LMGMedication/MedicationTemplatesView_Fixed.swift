/**
 * MedicationTemplatesView.swift
 * LMGMedication
 *
 * A comprehensive medication template management interface for iOS.
 * 
 * This file provides a complete SwiftUI-based medication template management system that supports:
 * 
 * ## Key Features:
 * - **Dual Template Types**: Local Core Data templates and public CloudKit-synced templates
 * - **Search Functionality**: Real-time filtering across medication names and ingredients
 * - **QR Code Generation**: Automatic QR code creation and preview for medication URLs
 * - **Cloud Sync**: CloudKit integration for sharing public templates across users
 * - **Offline Support**: Full functionality when iCloud is unavailable
 * - **Error Handling**: Comprehensive error states and user feedback
 * 
 * ## Architecture:
 * - Uses MVVM pattern with SwiftUI and Combine
 * - Core Data for local persistence
 * - CloudKit for public template sharing
 * - Async/await for modern concurrency handling
 * 
 * ## Views Included:
 * - `MedicationTemplatesView`: Main container view with segmented control
 * - `CloudMedicationTemplateRow`: Display row for public templates
 * - `LocalMedicationTemplateRow`: Display row for local templates  
 * - `AddMedicationTemplateView`: Create new local templates
 * - `EditMedicationTemplateView`: Edit existing local templates
 * - `AddCloudMedicationTemplateView`: Create new public templates
 * - `CloudMedicationTemplateDetailView`: View public template details
 * - `EditCloudMedicationTemplateView`: Edit existing public templates
 * 
 * Created by Michael Lazar on 9/29/25.
 */

//
//  MedicationTemplatesView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import CoreData
import UIKit
import CloudKit

/**
 * `MedicationTemplatesView` - Main view for managing medication templates
 * 
 * This view provides functionality to view, create, edit, and manage both public (CloudKit-synced)
 * and local medication templates. It includes:
 * - Segmented control to switch between public and local templates
 * - Search functionality across template names and ingredients
 * - iCloud status monitoring and error handling
 * - Template creation and editing capabilities
 * - Integration with CloudKit for public template sharing
 * 
 * The view automatically handles iCloud authentication states and provides appropriate
 * UI feedback for network errors and connectivity issues.
 */
struct MedicationTemplatesView: View {
    // MARK: - Environment & State Properties
    
    /// Core Data managed object context for local data operations
    @Environment(\.managedObjectContext) private var viewContext
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    /// Shared CloudKit manager instance for public template operations
    @StateObject private var cloudManager = CloudKitManager.shared
    
    /// Fetch request for local medications sorted by name
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        animation: .default)
    private var localMedications: FetchedResults<Medication>
    
    /// Controls the presentation of the add medication sheet
    @State private var showingAddMedication = false
    /// User input for filtering templates by name/ingredients
    @State private var searchText = ""
    /// Segmented control state: 0 = Public Templates, 1 = Local Templates
    @State private var selectedSegment = 0
    
    // MARK: - UI Helpers
    
    /// Platform-appropriate gray background color for iOS
    private var platformSystemGray6: Color {
        Color(.systemGray6)
    }
    
    // MARK: - Computed Properties
    
    /// Filtered public templates based on search criteria
    /// Searches across template name and both ingredient fields
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
    
    /// Filtered local medications based on search criteria
    /// Searches across medication name and both ingredient fields
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: Template Source Selection
                // Segmented Control for Public/Local
                Picker("Template Source", selection: $selectedSegment) {
                    Text("Public Templates").tag(0)
                    Text("My Templates").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // MARK: iCloud Status Banner
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
                    .background(platformSystemGray6)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // MARK: Search Interface
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search medications...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // MARK: Error Display
                // Cloud error banner with retry functionality
                if let error = cloudManager.lastErrorMessage, selectedSegment == 0 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cloud Error")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Reload") {
                            Task { await cloudManager.loadPublicMedicationTemplates() }
                        }
                        .font(.caption)
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = error
                            #endif
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                        }
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
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
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if selectedSegment == 0 && cloudManager.isSignedInToiCloud {
                            Button("Add Public Template") { showingAddMedication = true }
                        } else {
                            Button("Add Local Template") { showingAddMedication = true }
                        }
                    } label: { Image(systemName: "plus") }
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
    
    // MARK: - Private Methods
    
    /// Deletes selected local medications from Core Data
    /// - Parameter offsets: Index set of medications to delete from the filtered list
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

// MARK: - CloudMedicationTemplateRow

/**
 * `CloudMedicationTemplateRow` - Row view for displaying public medication templates
 * 
 * Displays essential information about a CloudKit-synced medication template including:
 * - Template name and concentration information
 * - Pharmacy information if available
 * - Visual indicators for injectable medications and cloud sync status
 * - Creation/modification timestamps
 * 
 * Tapping the row presents a detailed view of the template.
 */
struct CloudMedicationTemplateRow: View {
    /// The cloud medication template to display
    let template: CloudMedicationTemplate
    /// Controls presentation of the template detail sheet
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

// MARK: - LocalMedicationTemplateRow

/**
 * `LocalMedicationTemplateRow` - Row view for displaying local medication templates
 * 
 * Displays information about locally stored medication templates including:
 * - Medication name and ingredient concentrations
 * - Pharmacy information if available
 * - Usage statistics (how many times the medication has been dispensed)
 * - Visual indicators for injectable medications and local storage
 * 
 * Tapping the row presents an edit view for the template.
 */
struct LocalMedicationTemplateRow: View {
    /// The local medication template to display
    let medication: Medication
    /// Controls presentation of the edit template sheet
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

// MARK: - EditMedicationTemplateView

/**
 * `EditMedicationTemplateView` - Modal view for editing existing local medication templates
 * 
 * Provides a comprehensive form interface for modifying all aspects of a local medication template:
 * - Basic information (name, pharmacy, injectable status)
 * - Ingredient details (names and concentrations for up to 2 ingredients)
 * - URL fields for pharmacy website and QR code destinations
 * - QR code generation and preview functionality
 * 
 * Changes are saved directly to Core Data and the view automatically updates
 * the modification timestamp when changes are made.
 */
struct EditMedicationTemplateView: View {
    // MARK: - Environment & Properties
    
    /// Core Data managed object context for saving changes
    @Environment(\.managedObjectContext) private var viewContext
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    
    /// The medication template being edited
    let medication: Medication
    
    // MARK: - Form State
    
    /// Editable medication name
    @State private var medicationName = ""
    /// Editable pharmacy name
    @State private var pharmacy = ""
    /// Editable first ingredient name
    @State private var ingredient1 = ""
    /// Editable first ingredient concentration
    @State private var concentration1: Double = 0
    /// Editable second ingredient name (optional)
    @State private var ingredient2 = ""
    /// Editable second ingredient concentration (optional)
    @State private var concentration2: Double = 0
    /// Whether the medication is injectable
    @State private var injectable = false
    /// Optional pharmacy website URL
    @State private var pharmacyURL = ""
    /// URL to be encoded in QR code
    @State private var urlForQR = ""
    /// Generated QR code image for preview
    @State private var qrCodeImage: UIImage?
    
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
                        .onChange(of: urlForQR) { _, newValue in
                            updateQRCodePreview()
                        }
                }
                
                Section(header: Text("QR Code Preview")) {
                    VStack(spacing: 12) {
                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 150, height: 150)
                                .border(Color.gray.opacity(0.3), width: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 150, height: 150)
                                .overlay(
                                    VStack {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("QR Code Preview")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                )
                        }

                        Button("Generate QR Code") { generateQRCode() }
                            .buttonStyle(.bordered)

                        Text("URL: \(urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : urlForQR)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { saveMedication() }.disabled(medicationName.isEmpty) }
            }
            .onAppear {
                loadFromMedication()
                loadExistingQRCode()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the QR code preview when the URL changes
    /// Uses default URL if urlForQR is empty
    private func updateQRCodePreview() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 150, height: 150))
    }
    
    /// Generates a higher resolution QR code for saving
    private func generateQRCode() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 200, height: 200))
    }
    
    /// Loads existing QR code from the medication entity or generates a new preview
    private func loadExistingQRCode() {
        if let qrData = medication.qrImage,
           let image = UIImage(data: qrData) {
            qrCodeImage = image
        } else {
            updateQRCodePreview()
        }
    }
    
    /// Loads medication data into form fields for editing
    private func loadFromMedication() {
        medicationName = medication.name ?? ""
        pharmacy = medication.pharmacy ?? ""
        ingredient1 = medication.ingredient1 ?? ""
        concentration1 = medication.concentration1
        ingredient2 = medication.ingredient2 ?? ""
        concentration2 = medication.concentration2
        injectable = medication.injectable
        pharmacyURL = medication.prarmacyURL ?? ""
        urlForQR = medication.urlForQR ?? "https://hushmedicalspa.com/medications"
    }
    
    /// Saves the edited medication template to Core Data
    /// Automatically updates the modification timestamp and regenerates QR code if needed
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
        
        // Ensure QR code exists - generate if needed and save to Core Data
        if qrCodeImage == nil { generateQRCode() }
        if let qrImage = qrCodeImage, let qrData = qrImage.pngData() { medication.qrImage = qrData }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - AddMedicationTemplateView

/**
 * `AddMedicationTemplateView` - Modal view for creating new local medication templates
 * 
 * Provides a comprehensive form interface for creating new local medication templates with:
 * - Basic information (name, pharmacy with default "Beaker Pharmacy", injectable status)
 * - Ingredient details (names and concentrations for up to 2 ingredients)
 * - URL fields for pharmacy website and QR code destinations
 * - Real-time QR code generation and preview
 * 
 * Templates are saved to Core Data with automatic timestamp generation.
 * The QR code defaults to "https://hushmedicalspa.com/medications" if no custom URL is provided.
 */
struct AddMedicationTemplateView: View {
    // MARK: - Environment & State
    
    /// Core Data managed object context for saving new templates
    @Environment(\.managedObjectContext) private var viewContext
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Form State
    
    /// New medication name (required)
    @State private var medicationName = ""
    /// Pharmacy name with default value
    @State private var pharmacy = "Beaker Pharmacy"
    /// First ingredient name
    @State private var ingredient1 = ""
    /// First ingredient concentration
    @State private var concentration1: Double = 0
    /// Second ingredient name (optional)
    @State private var ingredient2 = ""
    /// Second ingredient concentration (optional)
    @State private var concentration2: Double = 0
    /// Whether the medication is injectable
    @State private var injectable = false
    /// Optional pharmacy website URL
    @State private var pharmacyURL = ""
    /// URL to be encoded in QR code (defaults to company website)
    @State private var urlForQR = "https://hushmedicalspa.com/medications"
    /// Generated QR code image for preview
    @State private var qrCodeImage: UIImage?
    
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
                        .onChange(of: urlForQR) { _, newValue in
                            updateQRCodePreview()
                        }
                }
                
                Section(header: Text("QR Code Preview")) {
                    VStack(spacing: 12) {
                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 150, height: 150)
                                .border(Color.gray.opacity(0.3), width: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 150, height: 150)
                                .overlay(
                                    VStack {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("QR Code Preview")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        
                        Button("Generate QR Code") {
                            generateQRCode()
                        }
                        .buttonStyle(.bordered)
                        
                        Text("URL: \(urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : urlForQR)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Local Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { saveMedication() }.disabled(medicationName.isEmpty) }
            }
            .onAppear {
                // Generate initial QR code with default URL
                updateQRCodePreview()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the QR code preview when the URL changes
    private func updateQRCodePreview() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 150, height: 150))
    }
    
    /// Generates a higher resolution QR code for saving
    private func generateQRCode() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 200, height: 200))
    }
    
    /// Creates and saves a new medication template to Core Data
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
        
        // Ensure QR code exists - generate if needed and save to Core Data
        if qrCodeImage == nil { generateQRCode() }
        if let qrImage = qrCodeImage, let qrData = qrImage.pngData() { newMedication.qrImage = qrData }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - AddCloudMedicationTemplateView

/**
 * `AddCloudMedicationTemplateView` - Modal view for creating new public medication templates
 * 
 * Provides a comprehensive form interface for creating CloudKit-synced public medication templates.
 * Features include:
 * - iCloud authentication status checking and user guidance
 * - Complete medication information entry (name, pharmacy, ingredients, concentrations)
 * - QR code generation and preview functionality
 * - URL management for pharmacy websites and QR code destinations
 * - Async CloudKit operations with error handling
 * 
 * Public templates are visible to all app users and require iCloud authentication.
 * The view handles network errors gracefully and provides user feedback during submission.
 */
struct AddCloudMedicationTemplateView: View {
    // MARK: - Environment & State
    
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    /// Shared CloudKit manager for public template operations
    @StateObject private var cloudManager = CloudKitManager.shared
    
    // MARK: - Form State
    
    /// New medication name (required)
    @State private var medicationName = ""
    /// Pharmacy name with default value
    @State private var pharmacy = "Beaker Pharmacy"
    /// First ingredient name
    @State private var ingredient1 = ""
    /// First ingredient concentration
    @State private var concentration1: Double = 0
    /// Second ingredient name (optional)
    @State private var ingredient2 = ""
    /// Second ingredient concentration (optional)
    @State private var concentration2: Double = 0
    /// Whether the medication is injectable
    @State private var injectable = false
    /// Optional pharmacy website URL
    @State private var pharmacyURL = ""
    /// URL to be encoded in QR code (defaults to company website)
    @State private var urlForQR = "https://hushmedicalspa.com/medications"
    /// Generated QR code image for preview
    @State private var qrCodeImage: UIImage?
    /// Tracks submission state to prevent double-submission
    @State private var isSubmitting = false
    /// Error message for display to user
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
                            .onChange(of: urlForQR) { _, newValue in
                                updateQRCodePreview()
                            }
                    }
                    
                    Section(header: Text("QR Code Preview")) {
                        VStack(spacing: 12) {
                            if let qrImage = qrCodeImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 150, height: 150)
                                    .border(Color.gray.opacity(0.3), width: 1)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "qrcode")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("QR Code Preview")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            Button("Generate QR Code") {
                                generateQRCode()
                            }
                            .buttonStyle(.bordered)
                            
                            Text("URL: \(urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : urlForQR)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveTemplate() }
                    }
                    .disabled(medicationName.isEmpty || !cloudManager.isSignedInToiCloud || isSubmitting)
                }
            }
            .onAppear {
                // Generate initial QR code with default URL
                updateQRCodePreview()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the QR code preview when the URL changes
    private func updateQRCodePreview() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 150, height: 150))
    }
    
    /// Generates a higher resolution QR code for saving
    private func generateQRCode() {
        let urlToUse = urlForQR.isEmpty ? "https://hushmedicalspa.com/medications" : QRCodeGenerator.formatURL(urlForQR)
        qrCodeImage = QRCodeGenerator.generateQRCode(from: urlToUse, size: CGSize(width: 200, height: 200))
    }
    
    /// Saves the new template to CloudKit as a public medication template
    /// Handles async CloudKit operations with proper error handling
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
            await cloudManager.loadPublicMedicationTemplates()
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

// MARK: - CloudMedicationTemplateDetailView

/**
 * `CloudMedicationTemplateDetailView` - Detail view for public medication templates
 * 
 * Displays comprehensive read-only information about a public medication template including:
 * - Basic information (name, pharmacy, injectable status)
 * - Ingredient details with concentrations
 * - Creation and modification timestamps
 * - Template type indication (public/cloud)
 * 
 * Provides navigation to edit the template if the user has appropriate permissions.
 */
struct CloudMedicationTemplateDetailView: View {
    /// The cloud medication template to display
    let template: CloudMedicationTemplate
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    /// Controls presentation of the edit sheet
    @State private var showingEdit = false
    
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
                ToolbarItem(placement: .navigationBarLeading) { Button("Edit") { showingEdit = true } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditCloudMedicationTemplateView(template: template)
            }
        }
    }
}

// MARK: - EditCloudMedicationTemplateView

/**
 * `EditCloudMedicationTemplateView` - Modal view for editing existing public medication templates
 * 
 * Provides a form interface for modifying CloudKit-synced public medication templates.
 * Features include:
 * - Complete medication information editing (name, pharmacy, ingredients, concentrations)
 * - URL management for pharmacy websites and QR code destinations
 * - Async CloudKit update operations with error handling
 * - Prevention of double-submission during save operations
 * 
 * Changes are synchronized to CloudKit and propagated to all app users.
 * The view preserves the original template's creation metadata while updating modification timestamps.
 */
struct EditCloudMedicationTemplateView: View {
    // MARK: - Environment & Properties
    
    /// Dismiss action for modal presentation
    @Environment(\.dismiss) private var dismiss
    /// Shared CloudKit manager for public template operations
    @StateObject private var cloudManager = CloudKitManager.shared
    
    /// The template being edited (read-only reference)
    let template: CloudMedicationTemplate
    
    // MARK: - Form State
    
    /// Editable medication name
    @State private var medicationName: String = ""
    /// Editable pharmacy name
    @State private var pharmacy: String = ""
    /// Editable first ingredient name
    @State private var ingredient1: String = ""
    /// Editable first ingredient concentration
    @State private var concentration1: Double = 0
    /// Editable second ingredient name (optional)
    @State private var ingredient2: String = ""
    /// Editable second ingredient concentration (optional)
    @State private var concentration2: Double = 0
    /// Whether the medication is injectable
    @State private var injectable: Bool = false
    /// Optional pharmacy website URL
    @State private var pharmacyURL: String = ""
    /// URL to be encoded in QR code
    @State private var urlForQR: String = ""
    
    /// Tracks submission state to prevent double-submission
    @State private var isSubmitting = false
    /// Error message for display to user
    @State private var errorMessage: String?
    
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
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Public Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { Task { await saveChanges() } }
                        .disabled(medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .onAppear { loadFromTemplate() }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads template data into form fields for editing
    private func loadFromTemplate() {
        medicationName = template.name
        pharmacy = template.pharmacy ?? ""
        ingredient1 = template.ingredient1 ?? ""
        concentration1 = template.concentration1
        ingredient2 = template.ingredient2 ?? ""
        concentration2 = template.concentration2
        injectable = template.injectable
        pharmacyURL = template.pharmacyURL ?? ""
        urlForQR = template.urlForQR ?? ""
    }
    
    /// Saves changes to the CloudKit public template
    /// Creates an updated template preserving original metadata while updating modification time
    private func saveChanges() async {
        isSubmitting = true
        errorMessage = nil
        
        // Construct an updated template preserving identifiers
        let updated = CloudMedicationTemplate(
            id: template.id,
            recordID: template.recordID,
            name: medicationName,
            pharmacy: pharmacy.isEmpty ? nil : pharmacy,
            ingredient1: ingredient1.isEmpty ? nil : ingredient1,
            concentration1: concentration1,
            ingredient2: ingredient2.isEmpty ? nil : ingredient2,
            concentration2: concentration2,
            injectable: injectable,
            pharmacyURL: pharmacyURL.isEmpty ? nil : pharmacyURL,
            urlForQR: urlForQR.isEmpty ? nil : urlForQR,
            createdDate: template.createdDate,
            modifiedDate: Date(),
            createdBy: template.createdBy
        )
        
        do {
            _ = try await cloudManager.updatePublicMedicationTemplate(updated)
            await cloudManager.loadPublicMedicationTemplates()
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update template: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

// MARK: - Preview

/// SwiftUI preview with sample medication data for testing and development
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
