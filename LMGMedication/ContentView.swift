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

    @State private var showingAddPatient = false
    @State private var showingMedicationTemplates = false
    @State private var showingProviders = false
    @State private var sortSelection: Int = 0 // 0 = Name, 1 = Most Recent
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""

    private var patientsForDisplay: [Patient] {
        let list = Array(patients)
        if sortSelection == 1 {
            // Sort by most recent dispensed medication date (descending)
            return list.sorted { p1, p2 in
                let d1 = p1.dispensedMedicationsArray.compactMap { $0.dispenceDate }.max() ?? Date.distantPast
                let d2 = p2.dispensedMedicationsArray.compactMap { $0.dispenceDate }.max() ?? Date.distantPast
                return d1 > d2
            }
        } else {
            // Default by last name, then first name
            return list.sorted { lhs, rhs in
                let lLast = lhs.lastName ?? ""
                let rLast = rhs.lastName ?? ""
                if lLast == rLast {
                    return (lhs.firstName ?? "") < (rhs.firstName ?? "")
                }
                return lLast < rLast
            }
        }
    }

    var body: some View {
        NavigationStack {
            Picker("Sort", selection: $sortSelection) {
                Text("Name").tag(0)
                Text("Most Recent").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                ForEach(patientsForDisplay) { patient in
                    NavigationLink(destination: PatientDetailView(patient: patient)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(patient.displayName)
                                .font(.headline)
                            if let birthdate = patient.birthdate {
                                Text("DOB: \(birthdate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            let medicationCount = patient.dispensedMedicationsArray.count
                            if medicationCount > 0 {
                                Text("\(medicationCount) medication\(medicationCount == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: deletePatients)
            }
            .navigationTitle("Patients")
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
