import SwiftUI
import CoreData

struct AddProviderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var degree: String = ""
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
                        .autocapitalization(.words)
                    TextField("Last Name", text: $lastName)
                        .autocapitalization(.words)
                }
                Section(header: Text("Credentials")) {
                    TextField("Degree", text: $degree)
                        .autocapitalization(.allCharacters)
                    TextField("NPI", text: $npi)
                        .keyboardType(.numberPad)
                    TextField("DEA", text: $dea)
                        .autocapitalization(.allCharacters)
                    TextField("License", text: $license)
                        .autocapitalization(.allCharacters)
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
        let trimmedDegree = degree.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard !trimmedDegree.isEmpty else {
            alertMessage = "Degree is required."
            showingAlert = true
            return
        }

        // Removed validation for NPI, DEA, and License per request

        let newProvider = Provider(context: viewContext)
        newProvider.firstName = trimmedFirstName
        newProvider.lastName = trimmedLastName
        newProvider.degree = trimmedDegree
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
