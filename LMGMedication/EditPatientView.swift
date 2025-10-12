//
//  EditPatientView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/12/25.
//

import SwiftUI
import CoreData

struct EditPatientView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var patient: Patient
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var middleName: String
    @State private var birthdate: Date
    
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    
    // Custom colors - matching the app
    private let goldColor = Color(red: 1.0, green: 0.843, blue: 0.0) // Pure gold
    private let darkGoldColor = Color(red: 0.8, green: 0.6, blue: 0.0) // Darker gold
    private let charcoalColor = Color(red: 0.1, green: 0.1, blue: 0.1) // Near black
    
    init(patient: Patient) {
        self.patient = patient
        self._firstName = State(initialValue: patient.firstName ?? "")
        self._lastName = State(initialValue: patient.lastName ?? "")
        self._middleName = State(initialValue: patient.middleName ?? "")
        self._birthdate = State(initialValue: patient.birthdate ?? Date())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [charcoalColor, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            HStack {
                                Text("Edit Patient")
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
                            
                            // Patient preview
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [goldColor.opacity(0.3), darkGoldColor.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(goldColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if !firstName.isEmpty || !lastName.isEmpty {
                                        Text("\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces))
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Patient Name")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("DOB: \(birthdate, style: .date)")
                                        .font(.subheadline)
                                        .foregroundColor(goldColor.opacity(0.8))
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.03)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(goldColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Form Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Patient Information")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(goldColor)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 16) {
                                // First Name
                                CustomTextField(
                                    title: "First Name",
                                    text: $firstName,
                                    goldColor: goldColor,
                                    isRequired: true
                                )
                                
                                // Middle Name
                                CustomTextField(
                                    title: "Middle Name",
                                    text: $middleName,
                                    goldColor: goldColor
                                )
                                
                                // Last Name
                                CustomTextField(
                                    title: "Last Name",
                                    text: $lastName,
                                    goldColor: goldColor,
                                    isRequired: true
                                )
                                
                                // Date of Birth
                                CustomDatePicker(
                                    title: "Date of Birth",
                                    selection: $birthdate,
                                    goldColor: goldColor
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(goldColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(goldColor, lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.05))
                                    )
                            )
                    }
                    
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
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
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                    .opacity((firstName.isEmpty || lastName.isEmpty) ? 0.6 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [charcoalColor, Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveChanges() {
        withAnimation {
            patient.firstName = firstName.trimmingCharacters(in: .whitespaces)
            patient.lastName = lastName.trimmingCharacters(in: .whitespaces)
            patient.middleName = middleName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : middleName.trimmingCharacters(in: .whitespaces)
            patient.birthdate = birthdate
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                errorMessage = "Failed to update patient: \(nsError.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let goldColor: Color
    let isRequired: Bool
    
    init(title: String, text: Binding<String>, goldColor: Color, isRequired: Bool = false) {
        self.title = title
        self._text = text
        self.goldColor = goldColor
        self.isRequired = isRequired
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(goldColor)
                if isRequired {
                    Text("*")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
            
            TextField("Enter \(title.lowercased())", text: $text)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    text.isEmpty && isRequired ? Color.red.opacity(0.5) : goldColor.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
                .foregroundColor(.white)
                .font(.body)
        }
    }
}

struct CustomDatePicker: View {
    let title: String
    @Binding var selection: Date
    let goldColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(goldColor)
            
            DatePicker("", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(goldColor.opacity(0.3), lineWidth: 1)
                        )
                )
                .colorScheme(.dark)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let patient = Patient(context: context)
    patient.firstName = "John"
    patient.lastName = "Doe"
    patient.birthdate = Calendar.current.date(byAdding: .year, value: -30, to: Date())
    
    return EditPatientView(patient: patient)
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.dark)
}