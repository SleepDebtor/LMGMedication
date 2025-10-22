//
//  ContentView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import SwiftUI
import CoreData

/**
 * ContentView
 * 
 * Root view container that displays the main patients list interface.
 * Acts as a simple wrapper around PatientsListRootView.
 */
struct ContentView: View {
    var body: some View {
        PatientsListRootView()
    }
}

/**
 * PatientsListRootView
 * 
 * Main dashboard view that displays active patients organized by upcoming medication due dates.
 * 
 * Key Features:
 * - Organizes patients by week based on next medication dose due dates
 * - Provides quick actions for adding patients, managing templates, and providers
 * - Supports patient activation/deactivation via swipe actions
 * - Implements a light theme with bronze accent colors
 * - Real-time updates via Core Data change notifications
 * 
 * Architecture:
 * - Uses @FetchRequest for reactive Core Data integration
 * - State management for modal presentations and error handling
 * - Custom color scheme with consistent bronze/gold theming
 * - Grouped data presentation with computed properties for organization
 */
struct PatientsListRootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Core Data Fetch Requests
    
    /// Fetches all patients sorted by last name
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>

    /// Fetches all dispensed medications for real-time updates
    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var dispensedMeds: FetchedResults<DispencedMedication>

    // MARK: - State Management
    
    /// Triggers view updates when data changes
    @State private var dataVersion: Int = 0

    /// Modal presentation states
    @State private var showingAddPatient = false
    @State private var showingMedicationTemplates = false
    @State private var showingProviders = false
    
    /// Error handling
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    
    // MARK: - Theme Colors
    
    /// Custom color scheme for consistent app theming
    /// Light theme with dark bronze accents for professional healthcare appearance
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2) // Dark bronze
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15) // Darker bronze
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97) // Light background with subtle gold tint
    private let textColor = Color.black // Black text

    // MARK: - Helper Methods
    
    /**
     * Calculates the next dose due date for a patient
     * Uses the earliest upcoming nextDoseDue across all active dispensed medications
     * 
     * - Parameter patient: The patient to check
     * - Returns: The earliest next dose date, or nil if no active medications
     */
    private func nextDoseDueDate(for patient: Patient) -> Date? {
        // Use the earliest upcoming nextDoseDue across all active dispensed medications
        let dates = patient.dispensedMedicationsArray
            .filter { $0.isActive }
            .compactMap { $0.nextDoseDue }
        return dates.min()
    }

    /**
     * Groups active patients by the week their next medication dose is due
     * Creates sections for each week with patients sorted by due date then name
     * 
     * Algorithm:
     * 1. Filter to active patients with next dose dates
     * 2. Calculate week start date for each patient's next dose
     * 3. Group patients by week start date
     * 4. Sort patients within each group by due date, then by name
     * 5. Sort groups chronologically by week start date
     * 
     * - Returns: Array of (weekStart, patients) tuples sorted chronologically
     */
    private var groupedByWeek: [(weekStart: Date, patients: [Patient])] {
        let calendar = Calendar.current
        let pairs: [(Date, Patient)] = patients.compactMap { patient in
            guard patient.isActive else { return nil }
            guard let date = nextDoseDueDate(for: patient) else { return nil }
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                return (weekStart, patient)
            } else {
                return nil
            }
        }
        // Group by week start
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })
            .map { (weekStart, entries) -> (Date, [Patient]) in
                let uniquePatients = Array(Set(entries.map { $0.1 }))
                // Sort patients in each section by their nextDoseDue date then name
                let sorted = uniquePatients.sorted { lhs, rhs in
                    let lDate = nextDoseDueDate(for: lhs) ?? .distantFuture
                    let rDate = nextDoseDueDate(for: rhs) ?? .distantFuture
                    if lDate == rDate {
                        let lLast = lhs.lastName ?? ""
                        let rLast = rhs.lastName ?? ""
                        if lLast == rLast { return (lhs.firstName ?? "") < (rhs.firstName ?? "") }
                        return lLast < rLast
                    }
                    return lDate < rDate
                }
                return (weekStart, sorted)
            }
            .sorted { $0.0 < $1.0 }
        return grouped
    }

    /**
     * Returns active patients who don't have any upcoming medication doses scheduled
     * These patients appear in a separate section for manual review
     * Sorted alphabetically by last name, then first name
     * 
     * - Returns: Array of patients without scheduled doses, sorted by name
     */
    private var noNextDosePatients: [Patient] {
        Array(patients).filter { $0.isActive && nextDoseDueDate(for: $0) == nil }
            .sorted { lhs, rhs in
                let lLast = lhs.lastName ?? ""
                let rLast = rhs.lastName ?? ""
                if lLast == rLast { return (lhs.firstName ?? "") < (rhs.firstName ?? "") }
                return lLast < rLast
            }
    }

    /**
     * Toggles a patient's active status with animation and error handling
     * Updates Core Data and triggers UI refresh
     * 
     * - Parameters:
     *   - patient: The patient to update
     *   - active: New active status
     */
    private func togglePatientActive(_ patient: Patient, active: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            patient.isActive = active
            do {
                try viewContext.save()
                dataVersion += 1
            } catch {
                let nsError = error as NSError
                errorMessage = "Failed to update patient: \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Light background
                lightBackgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Header section
                        VStack(spacing: 20) {
                            HStack {
                                Text("Patients by Week")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [goldColor, darkGoldColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                // Add Patient button
                                Button(action: { showingAddPatient = true }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .font(.title3)
                                        Text("Add Patient")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [goldColor, darkGoldColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: goldColor.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                
                                // Medication Templates button
                                Button(action: { showingMedicationTemplates = true }) {
                                    HStack {
                                        Image(systemName: "pills")
                                            .font(.title3)
                                        Text("Templates")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(goldColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(goldColor, lineWidth: 1.5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                    )
                                }
                                
                                // Providers button
                                Button(action: { showingProviders = true }) {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.title3)
                                        Text("Providers")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(goldColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(goldColor, lineWidth: 1.5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Sections for each week
                        ForEach(groupedByWeek, id: \.weekStart) { section in
                            WeekSectionView(
                                weekStart: section.weekStart,
                                patients: section.patients,
                                goldColor: goldColor,
                                darkGoldColor: darkGoldColor,
                                textColor: textColor,
                                nextDoseDueDate: nextDoseDueDate,
                                onDelete: { offsets in
                                    deletePatientsFromSection(section.patients, offsets: offsets)
                                },
                                onToggleActive: { patient, active in
                                    togglePatientActive(patient, active: active)
                                }
                            )
                        }
                        
                        // Section for patients without a scheduled next dose
                        if !noNextDosePatients.isEmpty {
                            NoNextDoseSectionView(
                                patients: noNextDosePatients,
                                goldColor: goldColor,
                                darkGoldColor: darkGoldColor,
                                textColor: textColor,
                                onDelete: { offsets in
                                    deletePatientsFromSection(noNextDosePatients, offsets: offsets)
                                },
                                onToggleActive: { patient, active in
                                    togglePatientActive(patient, active: active)
                                }
                            )
                        }
                        
                        if groupedByWeek.isEmpty && noNextDosePatients.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(goldColor.opacity(0.6))
                                
                                Text("No Patients Yet")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(goldColor)
                                
                                Text("Tap 'Add Patient' above to get started")
                                    .font(.body)
                                    .foregroundColor(textColor.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .id(dataVersion)
            .animation(.easeInOut, value: dataVersion)
            .sheet(isPresented: $showingAddPatient) {
                AddPatientView()
            }
            .sheet(isPresented: $showingMedicationTemplates) {
                MedicationTemplatesView()
            }
            .sheet(isPresented: $showingProviders) {
                ProvidersListView()
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: viewContext)) { notification in
                var shouldRefresh = false
                if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>,
                   inserted.contains(where: { $0 is DispencedMedication }) {
                    shouldRefresh = true
                }
                if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
                   updated.contains(where: { $0 is DispencedMedication }) {
                    shouldRefresh = true
                }
                if let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
                   deleted.contains(where: { $0 is DispencedMedication }) {
                    shouldRefresh = true
                }
                if shouldRefresh {
                    dataVersion += 1
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EnvironmentBadgeView()
                }
            }
        }
    }

    private func deletePatientsFromSection(_ sectionPatients: [Patient], offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
            let toDelete = offsets.map { sectionPatients[$0] }
            toDelete.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                errorMessage = "Failed to delete patient(s): \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }

    private func deletePatients(offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
            offsets.map { patients[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                errorMessage = "Failed to delete patient(s): \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}

struct WeekSectionView: View {
    let weekStart: Date
    let patients: [Patient]
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    let nextDoseDueDate: (Patient) -> Date?
    let onDelete: (IndexSet) -> Void
    let onToggleActive: (Patient, Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Week of \(weekStart, style: .date)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(goldColor)
                Spacer()
                Text("\(patients.count) patient\(patients.count == 1 ? "" : "s")")
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
            
            // Patient cards
            ForEach(patients) { patient in
                NavigationLink(destination: PatientDetailView(patient: patient)) {
                    PatientCardView(
                        patient: patient,
                        goldColor: goldColor,
                        darkGoldColor: darkGoldColor,
                        textColor: textColor,
                        nextDoseDate: nextDoseDueDate(patient)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if patient.isActive {
                        Button(role: .destructive) {
                            onToggleActive(patient, false)
                        } label: {
                            Label("Deactivate", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            onToggleActive(patient, true)
                        } label: {
                            Label("Activate", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
            }
        }
    }
}

struct NoNextDoseSectionView: View {
    let patients: [Patient]
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    let onDelete: (IndexSet) -> Void
    let onToggleActive: (Patient, Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("No Next Dose Scheduled")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(goldColor.opacity(0.8))
                Spacer()
                Text("\(patients.count) patient\(patients.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(goldColor.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(goldColor.opacity(0.1))
                    )
            }
            .padding(.horizontal, 20)
            
            // Patient cards
            ForEach(patients) { patient in
                NavigationLink(destination: PatientDetailView(patient: patient)) {
                    PatientCardView(
                        patient: patient,
                        goldColor: goldColor,
                        darkGoldColor: darkGoldColor,
                        textColor: textColor,
                        nextDoseDate: nil,
                        showBirthdate: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if patient.isActive {
                        Button(role: .destructive) {
                            onToggleActive(patient, false)
                        } label: {
                            Label("Deactivate", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            onToggleActive(patient, true)
                        } label: {
                            Label("Activate", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
            }
        }
    }
}

struct PatientCardView: View {
    let patient: Patient
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    let nextDoseDate: Date?
    let showBirthdate: Bool
    
    init(patient: Patient, goldColor: Color, darkGoldColor: Color, textColor: Color, nextDoseDate: Date?, showBirthdate: Bool = false) {
        self.patient = patient
        self.goldColor = goldColor
        self.darkGoldColor = darkGoldColor
        self.textColor = textColor
        self.nextDoseDate = nextDoseDate
        self.showBirthdate = showBirthdate
    }
    
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
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(goldColor)
            }
            
            // Patient info
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                
                if let nextDose = nextDoseDate {
                    Text("Next dose due: \(nextDose, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                } else if showBirthdate, let birthdate = patient.birthdate {
                    Text("DOB: \(birthdate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                } else {
                    Text("No scheduled doses")
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(goldColor.opacity(0.6))
        }
        .padding(16)
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
}



#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.light)
}
