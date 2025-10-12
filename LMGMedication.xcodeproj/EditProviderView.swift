import SwiftUI
import CoreData

struct EditProviderView: View {
    @ObservedObject var provider: Provider

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
        .navigationTitle("Edit Provider")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    confirmSave()
                }
            }
        }
        .alert("Error", isPresented: $showingAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(alertMessage)
        })
        .onAppear {
            firstName = provider.firstName ?? ""
            lastName = provider.lastName ?? ""
            degree = provider.degree ?? ""
            npi = provider.npi ?? ""
            dea = provider.dea ?? ""
            license = provider.license ?? ""
        }
    }

    private func confirmSave() {
        // Trim whitespace from all fields
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDegree = degree.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNpi = npi.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDea = dea.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLicense = license.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate required fields
        guard !trimmedFirstName.isEmpty else {
            alertMessage = "First Name is required."
            showingAlert = true
            return
        }
        guard !trimmedLastName.isEmpty else {
            alertMessage = "Last Name is required."
            showingAlert = true
            return
        }
        guard !trimmedDegree.isEmpty else {
            alertMessage = "Degree is required."
            showingAlert = true
            return
        }

        // Assign values to provider
        provider.firstName = trimmedFirstName
        provider.lastName = trimmedLastName
        provider.degree = trimmedDegree

        provider.npi = trimmedNpi.isEmpty ? nil : trimmedNpi
        provider.dea = trimmedDea.isEmpty ? nil : trimmedDea
        provider.license = trimmedLicense.isEmpty ? nil : trimmedLicense

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save provider: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct EditProviderView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext

        let sampleProvider = Provider(context: context)
        sampleProvider.firstName = "Jane"
        sampleProvider.lastName = "Doe"
        sampleProvider.degree = "MD"
        sampleProvider.npi = "1234567890"
        sampleProvider.dea = "AB1234567"
        sampleProvider.license = "XYZ987654"

        return NavigationView {
            EditProviderView(provider: sampleProvider)
                .environment(\.managedObjectContext, context)
        }
    }
}
