//
//  ContentView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/28/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        PatientsListRootView()
    }
}

struct PatientsListRootView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>

    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var dispensedMeds: FetchedResults<DispencedMedication>

    @State private var dataVersion: Int = 0

    @State private var showingAddPatient = false
    @State private var showingMedicationTemplates = false
    @State private var showingProviders = false
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    
    // Custom colors - matching ProvidersListView
    private let goldColor = Color(red: 1.0, green: 0.843, blue: 0.0) // Pure gold
    private let darkGoldColor = Color(red: 0.8, green: 0.6, blue: 0.0) // Darker gold
    private let charcoalColor = Color(red: 0.1, green: 0.1, blue: 0.1) // Near black

    private func nextDoseDueDate(for patient: Patient) -> Date? {
        // Use the earliest upcoming nextDoseDue across all active dispensed medications
        let dates = patient.dispensedMedicationsArray
            .filter { $0.isActive }
            .compactMap { $0.nextDoseDue }
        return dates.min()
    }

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

    private var noNextDosePatients: [Patient] {
        Array(patients).filter { $0.isActive && nextDoseDueDate(for: $0) == nil }
            .sorted { lhs, rhs in
                let lLast = lhs.lastName ?? ""
                let rLast = rhs.lastName ?? ""
                if lLast == rLast { return (lhs.firstName ?? "") < (rhs.firstName ?? "") }
                return lLast < rLast
            }
    }

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
                // Background gradient
                LinearGradient(
                    colors: [charcoalColor, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
                                                    .fill(Color.white.opacity(0.05))
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
                                                    .fill(Color.white.opacity(0.05))
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
                                    .foregroundColor(.gray)
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
    let nextDoseDate: Date?
    let showBirthdate: Bool
    
    init(patient: Patient, goldColor: Color, darkGoldColor: Color, nextDoseDate: Date?, showBirthdate: Bool = false) {
        self.patient = patient
        self.goldColor = goldColor
        self.darkGoldColor = darkGoldColor
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
                    .foregroundColor(.white)
                
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
                        .foregroundColor(.gray)
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
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
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
        .preferredColorScheme(.dark)
}

