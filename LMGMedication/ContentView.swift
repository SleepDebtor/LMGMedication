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
    @State private var showingAppInfo = false
    
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
     * 4. Sort patients within each group by due date (latest first), then by name
     * 5. Sort groups reverse chronologically by week start date (latest weeks first)
     * 
     * - Returns: Array of (weekStart, patients) tuples sorted with latest weeks first
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
                // Sort patients in each section by their nextDoseDue date (latest first) then name
                let sorted = uniquePatients.sorted { lhs, rhs in
                    let lDate = nextDoseDueDate(for: lhs) ?? .distantPast
                    let rDate = nextDoseDueDate(for: rhs) ?? .distantPast
                    if lDate == rDate {
                        let lLast = lhs.lastName ?? ""
                        let rLast = rhs.lastName ?? ""
                        if lLast == rLast { return (lhs.firstName ?? "") < (rhs.firstName ?? "") }
                        return lLast < rLast
                    }
                    return lDate > rDate // Changed from < to > for latest first
                }
                return (weekStart, sorted)
            }
            .sorted { $0.0 > $1.0 } // Changed from < to > for latest weeks first
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
                                // Add Patient button (remains as primary action)
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
                                
                                // Settings dropdown menu (Templates & Providers)
                                Menu {
                                    Button(action: { showingMedicationTemplates = true }) {
                                        Label("Medication Templates", systemImage: "pills")
                                    }
                                    
                                    Button(action: { showingProviders = true }) {
                                        Label("Providers", systemImage: "person.crop.circle.badge.plus")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: { showingAppInfo = true }) {
                                        Label("About App", systemImage: "info.circle")
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                        Text("Settings")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
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
            .sheet(isPresented: $showingAppInfo) {
                AppInfoView()
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

/**
 * AppInfoView
 * 
 * Information screen that provides users with a brief description of the app,
 * its purpose, and key features. Displayed as a modal sheet from the settings menu.
 */
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Use the same theme colors as the main view
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    private let textColor = Color.black
    
    var body: some View {
        NavigationStack {
            ZStack {
                lightBackgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App icon and title
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [goldColor, darkGoldColor],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: goldColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                            
                            Text("LMG Medication")
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
                        
                        // App description
                        VStack(alignment: .leading, spacing: 20) {
                            Text("About This App")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(goldColor)
                            
                            Text("LMG Medication is a comprehensive patient medication management system designed for healthcare professionals. The app helps you track patients, manage medication schedules, and maintain organized records for better patient care.")
                                .font(.body)
                                .foregroundColor(textColor)
                                .lineSpacing(4)
                            
                            // Key features
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Key Features")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(goldColor)
                                
                                FeatureRowView(
                                    icon: "calendar",
                                    title: "Schedule Tracking",
                                    description: "Organize patients by medication due dates",
                                    goldColor: goldColor
                                )
                                
                                FeatureRowView(
                                    icon: "person.3.fill",
                                    title: "Patient Management",
                                    description: "Add, edit, and track patient information",
                                    goldColor: goldColor
                                )
                                
                                FeatureRowView(
                                    icon: "pills",
                                    title: "Medication Templates",
                                    description: "Pre-configured medication templates for efficiency",
                                    goldColor: goldColor
                                )
                                
                                FeatureRowView(
                                    icon: "person.crop.circle.badge.plus",
                                    title: "Provider Network",
                                    description: "Manage healthcare provider information",
                                    goldColor: goldColor
                                )
                                
                                FeatureRowView(
                                    icon: "doc.text",
                                    title: "Professional Reports",
                                    description: "Generate comprehensive medication reports",
                                    goldColor: goldColor
                                )
                            }
                            
                            // Version info
                            VStack(spacing: 8) {
                                Divider()
                                    .background(goldColor.opacity(0.3))
                                
                                HStack {
                                    Text("Version 1.0")
                                        .font(.caption)
                                        .foregroundColor(textColor.opacity(0.6))
                                    
                                    Spacer()
                                    
                                    Text("© 2024 LMG Healthcare")
                                        .font(.caption)
                                        .foregroundColor(textColor.opacity(0.6))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(goldColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("App Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/**
 * FeatureRowView
 * 
 * Reusable component for displaying app features in the info screen
 */
struct FeatureRowView: View {
    let icon: String
    let title: String
    let description: String
    let goldColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(goldColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(goldColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}



#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.light)
}
