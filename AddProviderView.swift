import SwiftUI
import CoreData

struct AddProviderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var degree: Degree? = nil
    @State private var npi: String = ""
    @State private var dea: String = ""
    @State private var license: String = ""

    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("First Name", text: $firstName)
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif
                    TextField("Last Name", text: $lastName)
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif
                }
                Section(header: Text("Credentials")) {
                    Picker("Degree", selection: $degree) {
                        Text("Select...").tag(nil as Degree?)
                        ForEach(Degree.allCases) { d in
                            Text(d.displayName).tag(d as Degree?)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("NPI", text: $npi)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                    TextField("DEA", text: $dea)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                    TextField("License", text: $license)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                }
            }
            .navigationTitle("Add Provider")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProvider()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Validation Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func saveProvider() {
        // Validate required fields (keep only name and degree requirements)
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNPI = npi.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDEA = dea.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLicense = license.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirstName.isEmpty else {
            alertMessage = "First name is required."
            showingAlert = true
            return
        }
        guard !trimmedLastName.isEmpty else {
            alertMessage = "Last name is required."
            showingAlert = true
            return
        }
        guard let selectedDegree = degree else {
            alertMessage = "Degree is required."
            showingAlert = true
            return
        }

        // Removed validation for NPI, DEA, and License per request

        let newProvider = Provider(context: viewContext)
        newProvider.firstName = trimmedFirstName
        newProvider.lastName = trimmedLastName
        newProvider.degreeEnum = selectedDegree
        // Store optional identifiers only if provided
        newProvider.npi = trimmedNPI.isEmpty ? nil : trimmedNPI
        newProvider.dea = trimmedDEA.isEmpty ? nil : trimmedDEA
        newProvider.license = trimmedLicense.isEmpty ? nil : trimmedLicense

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save provider: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct AddProviderView_Previews: PreviewProvider {
    static var previews: some View {
        AddProviderView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
