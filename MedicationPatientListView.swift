//
//  MedicationPatientListView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/13/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

/**
 * MedicationPatientListView
 * 
 * View that displays all patients grouped by their medications.
 * Allows sorting by medication name and exporting results to CSV format.
 * 
 * Key Features:
 * - Groups patients by medication
 * - Shows medication name, patient name, and birthdate
 * - Export functionality to CSV format
 * - Search and filter capabilities
 * - Consistent theming with main app
 * 
 * Usage:
 * Present this view as a sheet or navigation destination from the main menu.
 */
struct MedicationPatientListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Core Data Fetch Requests
    
    /// Fetches all active dispensed medications with their relationships
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DispencedMedication.baseMedication?.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var dispensedMedications: FetchedResults<DispencedMedication>
    
    // MARK: - State Management
    
    @State private var searchText = ""
    @State private var isExporting = false
    @State private var csvDocument: CSVDocument?
    @State private var showingExportSuccess = false
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    
    // MARK: - Theme Colors
    
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    private let textColor = Color.black
    
    // MARK: - Computed Properties
    
    /**
     * Groups dispensed medications by medication name
     * Returns sorted array of medication names with their associated patient info
     */
    private var groupedByMedication: [(medicationName: String, entries: [MedicationPatientEntry])] {
        // Create dictionary grouping by medication name
        var groups: [String: [MedicationPatientEntry]] = [:]
        
        for dispensed in dispensedMedications {
            guard let patient = dispensed.patient, patient.isActive else { continue }
            let medicationName = dispensed.baseMedication?.name ?? "Unknown Medication"
            
            let entry = MedicationPatientEntry(
                medicationName: medicationName,
                patientFirstName: patient.firstName ?? "",
                patientLastName: patient.lastName ?? "",
                patientBirthdate: patient.birthdate,
                dispensedMedication: dispensed
            )
            
            if groups[medicationName] == nil {
                groups[medicationName] = []
            }
            groups[medicationName]?.append(entry)
        }
        
        // Sort patients within each medication group by last name, then first name
        for (key, value) in groups {
            groups[key] = value.sorted { lhs, rhs in
                if lhs.patientLastName == rhs.patientLastName {
                    return lhs.patientFirstName < rhs.patientFirstName
                }
                return lhs.patientLastName < rhs.patientLastName
            }
        }
        
        // Convert to sorted array by medication name
        return groups.map { (medicationName: $0.key, entries: $0.value) }
            .sorted { $0.medicationName < $1.medicationName }
    }
    
    /**
     * Filters grouped medications based on search text
     */
    private var filteredGroups: [(medicationName: String, entries: [MedicationPatientEntry])] {
        guard !searchText.isEmpty else { return groupedByMedication }
        
        return groupedByMedication.compactMap { group in
            // Filter by medication name or patient name
            let matchingEntries = group.entries.filter { entry in
                let searchLower = searchText.lowercased()
                return group.medicationName.lowercased().contains(searchLower) ||
                       entry.patientFirstName.lowercased().contains(searchLower) ||
                       entry.patientLastName.lowercased().contains(searchLower)
            }
            
            if matchingEntries.isEmpty {
                return nil
            }
            
            return (medicationName: group.medicationName, entries: matchingEntries)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                lightBackgroundColor
                    .ignoresSafeArea()
                
                if filteredGroups.isEmpty {
                    emptyStateView
                } else {
                    medicationListView
                }
            }
            .navigationTitle("Patients by Medication")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        exportToCSV()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .foregroundColor(goldColor)
                        .fontWeight(.semibold)
                    }
                    .disabled(groupedByMedication.isEmpty)
                }
            }
            .searchable(text: $searchText, prompt: "Search medications or patients")
            .fileExporter(
                isPresented: $isExporting,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "medication-patients-\(formattedDate()).csv"
            ) { result in
                handleExportResult(result)
            }
            .alert("Success", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Patient medication list has been exported successfully.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var medicationListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Summary card
                summaryCard
                
                // Medication sections
                ForEach(filteredGroups, id: \.medicationName) { group in
                    MedicationGroupView(
                        medicationName: group.medicationName,
                        entries: group.entries,
                        goldColor: goldColor,
                        darkGoldColor: darkGoldColor,
                        textColor: textColor
                    )
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Medications")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                    Text("\(filteredGroups.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [goldColor, darkGoldColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Patients")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                    Text("\(totalPatientCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [goldColor, darkGoldColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .padding(20)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 60))
                .foregroundColor(goldColor.opacity(0.6))
            
            Text(searchText.isEmpty ? "No Active Medications" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(goldColor)
            
            Text(searchText.isEmpty ?
                 "Active patients with medications will appear here" :
                 "Try adjusting your search terms")
                .font(.body)
                .foregroundColor(textColor.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var totalPatientCount: Int {
        var uniquePatients = Set<String>()
        for group in filteredGroups {
            for entry in group.entries {
                let patientKey = "\(entry.patientFirstName)_\(entry.patientLastName)_\(entry.patientBirthdate?.timeIntervalSince1970 ?? 0)"
                uniquePatients.insert(patientKey)
            }
        }
        return uniquePatients.count
    }
    
    // MARK: - Export Functions
    
    /**
     * Generates CSV content from grouped medication data
     */
    private func generateCSVContent() -> String {
        var csv = "Medication Name,Patient First Name,Patient Last Name,Date of Birth\n"
        
        for group in groupedByMedication {
            for entry in group.entries {
                let dateString = entry.patientBirthdate != nil ?
                    formatDateForCSV(entry.patientBirthdate!) : ""
                
                // Escape values that might contain commas or quotes
                let medicationName = escapeCSVField(group.medicationName)
                let firstName = escapeCSVField(entry.patientFirstName)
                let lastName = escapeCSVField(entry.patientLastName)
                
                csv += "\(medicationName),\(firstName),\(lastName),\(dateString)\n"
            }
        }
        
        return csv
    }
    
    /**
     * Escapes CSV field values to handle commas and quotes
     */
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    /**
     * Formats date for CSV export
     */
    private func formatDateForCSV(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    /**
     * Generates filename-friendly date string
     */
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /**
     * Initiates CSV export process
     */
    private func exportToCSV() {
        let csvContent = generateCSVContent()
        csvDocument = CSVDocument(content: csvContent)
        isExporting = true
    }
    
    /**
     * Handles the result of the file export operation
     */
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showingExportSuccess = true
        case .failure(let error):
            errorMessage = "Export failed: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

// MARK: - Supporting Views

/**
 * MedicationGroupView
 * 
 * Displays a group of patients taking the same medication
 */
struct MedicationGroupView: View {
    let medicationName: String
    let entries: [MedicationPatientEntry]
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(medicationName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(goldColor)
                
                Spacer()
                
                Text("\(entries.count) patient\(entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(goldColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(goldColor.opacity(0.1))
                    )
            }
            .padding(.horizontal, 20)
            
            // Patient rows
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    if let patient = entry.dispensedMedication.patient {
                        NavigationLink(destination: PatientDetailView(patient: patient)) {
                            MedicationPatientRow(
                                entry: entry,
                                goldColor: goldColor,
                                darkGoldColor: darkGoldColor,
                                textColor: textColor
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

/**
 * MedicationPatientRow
 * 
 * Individual row displaying patient information for a medication
 */
struct MedicationPatientRow: View {
    let entry: MedicationPatientEntry
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    
    var body: some View {
        HStack {
            // Patient icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goldColor.opacity(0.2), darkGoldColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.fill")
                    .font(.body)
                    .foregroundColor(goldColor)
            }
            
            // Patient info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.patientLastName), \(entry.patientFirstName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                
                if let birthdate = entry.patientBirthdate {
                    Text("DOB: \(birthdate, style: .date)")
                        .font(.caption)
                        .foregroundColor(goldColor.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(goldColor.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
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
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [goldColor.opacity(0.2), goldColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .shadow(color: goldColor.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Data Models

/**
 * MedicationPatientEntry
 * 
 * Represents a single patient-medication relationship for display and export
 */
struct MedicationPatientEntry: Identifiable {
    let id = UUID()
    let medicationName: String
    let patientFirstName: String
    let patientLastName: String
    let patientBirthdate: Date?
    let dispensedMedication: DispencedMedication
}

// MARK: - CSV Document

/**
 * CSVDocument
 * 
 * Document type for CSV file export using FileDocument protocol
 */
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(decoding: data, as: UTF8.self)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    MedicationPatientListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
