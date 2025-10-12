import SwiftUI
import CoreData

struct EditProviderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var provider: Provider

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var degree: String = ""
    @State private var npi: String = ""

    init(provider: Provider) {
        self.provider = provider
        // _state initialization happens in onAppear to ensure Core Data values are loaded in the correct context lifecycle
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
            }

            Section(header: Text("Details")) {
                TextField("Degree (e.g., MD, DO)", text: $degree)
                TextField("NPI", text: $npi)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("Edit Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveChanges() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            // Load current values into local state for an editable buffer
            firstName = provider.firstName ?? ""
            lastName = provider.lastName ?? ""
            degree = provider.degree ?? ""
            npi = provider.npi ?? ""
        }
    }

    private var canSave: Bool {
        // Require at least one of the name fields to avoid creating an empty record
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveChanges() {
        provider.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.degree = degree.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.npi = npi.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error appropriately in production
            print("Failed to save provider: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext

    // Create a sample provider for preview
    let provider: Provider = {
        let p = Provider(context: context)
        p.firstName = "Alex"
        p.lastName = "Johnson"
        p.degree = "MD"
        p.npi = "1234567890"
        return p
    }()

    return NavigationView {
        EditProviderView(provider: provider)
            .environment(\.managedObjectContext, context)
    }
}
