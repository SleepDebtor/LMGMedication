//
//  AlphabeticalPatientListView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 11/13/25.
//

import SwiftUI
import CoreData

/**
 * AlphabeticalPatientListView
 * 
 * View that displays all patients in an alphabetical list grouped by the first letter of their last name.
 * Provides a quick way to browse and find patients alphabetically.
 * 
 * Key Features:
 * - Groups patients by first letter of last name (A-Z)
 * - Shows patient name and birthdate
 * - Navigation to patient detail view
 * - Search and filter capabilities
 * - Consistent theming with main app
 * - Section headers with patient counts
 * 
 * Usage:
 * Present this view as a sheet or navigation destination from the main menu.
 */
struct AlphabeticalPatientListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Core Data Fetch Requests
    
    /// Fetches all active patients sorted by last name
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Patient.lastName, ascending: true),
            NSSortDescriptor(keyPath: \Patient.firstName, ascending: true)
        ],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    // MARK: - State Management
    
    @State private var searchText = ""
    
    // MARK: - Theme Colors
    
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    private let textColor = Color.black
    
    // MARK: - Computed Properties
    
    /**
     * Groups patients by the first letter of their last name
     * Returns sorted array of letters with their associated patients
     */
    private var groupedByLetter: [(letter: String, patients: [Patient])] {
        // Create dictionary grouping by first letter
        var groups: [String: [Patient]] = [:]
        
        for patient in patients {
            let lastName = patient.lastName ?? ""
            let firstLetter = String(lastName.prefix(1)).uppercased()
            
            // Use "#" for patients without a last name or non-alphabetic characters
            let isLetter = !firstLetter.isEmpty && firstLetter.rangeOfCharacter(from: CharacterSet.letters) != nil
            let letter = isLetter ? firstLetter : "#"
            
            if groups[letter] == nil {
                groups[letter] = []
            }
            groups[letter]?.append(patient)
        }
        
        // Sort patients within each group by last name, then first name
        for (key, value) in groups {
            groups[key] = value.sorted { lhs, rhs in
                let lLastName = lhs.lastName ?? ""
                let rLastName = rhs.lastName ?? ""
                
                if lLastName == rLastName {
                    return (lhs.firstName ?? "") < (rhs.firstName ?? "")
                }
                return lLastName < rLastName
            }
        }
        
        // Convert to sorted array - # comes last, then A-Z
        let sortedGroups = groups.map { (letter: $0.key, patients: $0.value) }
            .sorted { lhs, rhs in
                // Put "#" at the end
                if lhs.letter == "#" { return false }
                if rhs.letter == "#" { return true }
                return lhs.letter < rhs.letter
            }
        
        return sortedGroups
    }
    
    /**
     * Filters grouped patients based on search text
     */
    private var filteredGroups: [(letter: String, patients: [Patient])] {
        guard !searchText.isEmpty else { return groupedByLetter }
        
        return groupedByLetter.compactMap { group in
            let matchingPatients = group.patients.filter { patient in
                let searchLower = searchText.lowercased()
                let firstName = (patient.firstName ?? "").lowercased()
                let lastName = (patient.lastName ?? "").lowercased()
                
                return firstName.contains(searchLower) || lastName.contains(searchLower)
            }
            
            if matchingPatients.isEmpty {
                return nil
            }
            
            return (letter: group.letter, patients: matchingPatients)
        }
    }
    
    private var totalPatientCount: Int {
        filteredGroups.reduce(0) { $0 + $1.patients.count }
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
                    patientListView
                }
            }
            .navigationTitle("Alphabetical Patient List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
            }
            .searchable(text: $searchText, prompt: "Search patients")
        }
    }
    
    // MARK: - View Components
    
    private var patientListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Summary card
                summaryCard
                
                // Letter sections
                ForEach(filteredGroups, id: \.letter) { group in
                    LetterSectionView(
                        letter: group.letter,
                        patients: group.patients,
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
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Letter Groups")
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
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(goldColor.opacity(0.6))
            
            Text(searchText.isEmpty ? "No Active Patients" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(goldColor)
            
            Text(searchText.isEmpty ?
                 "Active patients will appear here" :
                 "Try adjusting your search terms")
                .font(.body)
                .foregroundColor(textColor.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Supporting Views

/**
 * LetterSectionView
 * 
 * Displays a group of patients whose last names start with the same letter
 */
struct LetterSectionView: View {
    let letter: String
    let patients: [Patient]
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with large letter indicator
            HStack(alignment: .center, spacing: 16) {
                // Large letter circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [goldColor, darkGoldColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: goldColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(letter)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Patient count
                VStack(alignment: .leading, spacing: 2) {
                    Text(letter == "#" ? "Other" : "Letter \(letter)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(goldColor)
                    
                    Text("\(patients.count) patient\(patients.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(goldColor.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Patient rows
            VStack(spacing: 8) {
                ForEach(patients) { patient in
                    NavigationLink(destination: PatientDetailView(patient: patient)) {
                        AlphabeticalPatientRow(
                            patient: patient,
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

/**
 * AlphabeticalPatientRow
 * 
 * Individual row displaying patient information in the alphabetical list
 */
struct AlphabeticalPatientRow: View {
    let patient: Patient
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
                    .frame(width: 44, height: 44)
                
                Image(systemName: "person.fill")
                    .font(.body)
                    .foregroundColor(goldColor)
            }
            
            // Patient info
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                
                HStack(spacing: 12) {
                    if let birthdate = patient.birthdate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(goldColor.opacity(0.6))
                            Text("DOB: \(birthdate, style: .date)")
                                .font(.caption)
                                .foregroundColor(goldColor.opacity(0.8))
                        }
                    }
                    
                    // Show medication count if available
                    let medCount = patient.dispensedMedicationsArray.filter { $0.isActive }.count
                    if medCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "pills.fill")
                                .font(.caption2)
                                .foregroundColor(goldColor.opacity(0.6))
                            Text("\(medCount) med\(medCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(goldColor.opacity(0.8))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(goldColor.opacity(0.6))
        }
        .padding(14)
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

// MARK: - Preview

#Preview {
    AlphabeticalPatientListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
