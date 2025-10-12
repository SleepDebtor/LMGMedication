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

    private func nextDoseDueDate(for patient: Patient) -> Date? {
        // Use the earliest upcoming nextDoseDue across all dispensed medications
        let dates = patient.dispensedMedicationsArray.compactMap { $0.nextDoseDue }
        return dates.min()
    }

    private var groupedByWeek: [(weekStart: Date, patients: [Patient])] {
        let calendar = Calendar.current
        let pairs: [(Date, Patient)] = patients.compactMap { patient in
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
        Array(patients).filter { nextDoseDueDate(for: $0) == nil }
            .sorted { lhs, rhs in
                let lLast = lhs.lastName ?? ""
                let rLast = rhs.lastName ?? ""
                if lLast == rLast { return (lhs.firstName ?? "") < (rhs.firstName ?? "") }
                return lLast < rLast
            }
    }

    var body: some View {
        NavigationStack {
            List {
                // Sections for each week
                ForEach(groupedByWeek, id: \.weekStart) { section in
                    Section(header: Text("Week of \(section.weekStart, style: .date)")) {
                        ForEach(section.patients) { patient in
                            NavigationLink(destination: PatientDetailView(patient: patient)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(patient.displayName)
                                        .font(.headline)
                                    if let due = nextDoseDueDate(for: patient) {
                                        Text("Next dose due: \(due, style: .date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { offsets in
                            deletePatientsFromSection(section.patients, offsets: offsets)
                        }
                    }
                }

                // Section for patients without a scheduled next dose
                if !noNextDosePatients.isEmpty {
                    Section(header: Text("No Next Dose Scheduled")) {
                        ForEach(noNextDosePatients) { patient in
                            NavigationLink(destination: PatientDetailView(patient: patient)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(patient.displayName)
                                        .font(.headline)
                                    if let birthdate = patient.birthdate {
                                        Text("DOB: \(birthdate, style: .date)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { offsets in
                            deletePatientsFromSection(noNextDosePatients, offsets: offsets)
                        }
                    }
                }
            }
            .id(dataVersion)
            .animation(.easeInOut, value: dataVersion)
            .navigationTitle("Patients by Week")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingProviders = true }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel("Manage Providers")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingMedicationTemplates = true }) {
                        Image(systemName: "pills")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
#endif
            }
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
        withAnimation {
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
        withAnimation {
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

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
