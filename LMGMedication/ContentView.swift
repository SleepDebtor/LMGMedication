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
        MainDashboardView()
    }
}

struct MainDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        animation: .default)
    private var baseMedications: FetchedResults<Medication>
    
    @State private var selectedPatient: Patient?
    @State private var showingPatientList = false
    @State private var showingAddPatient = false
    @State private var showingMedicationTemplates = false
    @State private var showingAddMedication = false
    @State private var showingProviders = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("LMG Medication")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Medication Management System")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Main Actions
                VStack(spacing: 16) {
                    // Patient Selection Dropdown
                    Menu {
                        ForEach(patients) { patient in
                            Button(patient.displayName) {
                                selectedPatient = patient
                            }
                        }
                        
                        Divider()
                        
                        Button("View All Patients") {
                            showingPatientList = true
                        }
                        
                        Button("Add New Patient") {
                            showingAddPatient = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Patient")
                                    .font(.headline)
                                if let patient = selectedPatient {
                                    Text(patient.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Choose a patient to dispense medication")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Quick Actions
                    HStack(spacing: 16) {
                        // Dispense Medication
                        Button(action: {
                            if selectedPatient != nil {
                                showingAddMedication = true
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "pills.fill")
                                    .font(.title2)
                                Text("Dispense\nMedication")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(selectedPatient != nil ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(selectedPatient != nil ? Color.blue : Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        .disabled(selectedPatient == nil)
                        
                        // Medication Templates
                        Button(action: {
                            showingMedicationTemplates = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                Text("Medication\nTemplates")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                    
                    // New Providers Button
                    Button(action: {
                        showingProviders = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.title2)
                            Text("Providers\nManage prescribers")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    
                    // Recent Activity
                    if let patient = selectedPatient, !patient.dispensedMedicationsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Medications for \(patient.displayName)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(patient.dispensedMedicationsArray.prefix(3)), id: \.objectID) { medication in
                                        VStack(spacing: 8) {
                                            NavigationLink(destination: MedicationLabelView(medication: medication)) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(medication.displayName)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(2)
                                                    
                                                    if let date = medication.dispenceDate {
                                                        Text(date, style: .date)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(8)
                                                .frame(width: 120, height: 50)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // Quick print button
                                            Button(action: {
                                                Task {
                                                    await MedicationPrintManager.shared.printLabel(for: medication)
                                                }
                                            }) {
                                                Image(systemName: "printer")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    // View all medications button
                                    NavigationLink(destination: PatientDetailView(patient: patient)) {
                                        VStack(spacing: 4) {
                                            Text("View All")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.blue)
                                            
                                            Image(systemName: "arrow.right.circle")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                        .frame(width: 80, height: 58)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPatientList) {
            PatientListView()
        }
        .sheet(isPresented: $showingAddPatient) {
            AddPatientView()
        }
        .sheet(isPresented: $showingMedicationTemplates) {
            MedicationTemplatesView()
        }
        .sheet(isPresented: $showingAddMedication) {
            if let patient = selectedPatient {
                AddMedicationView(patient: patient)
            }
        }
        .sheet(isPresented: $showingProviders) {
            ProvidersListView()
        }
        .onChange(of: showingAddPatient) { _, isShowing in
            if !isShowing {
                // Refresh patients list after adding
                selectedPatient = nil
            }
        }
    }
}

struct PatientListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    @State private var showingAddPatient = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(patients) { patient in
                    NavigationLink(destination: PatientDetailView(patient: patient)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(patient.displayName)
                                .font(.headline)
                            if let birthdate = patient.birthdate {
                                Text("DOB: \(birthdate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Show medication count
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
            .navigationTitle("All Patients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
            }
            .sheet(isPresented: $showingAddPatient) {
                AddPatientView()
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
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
