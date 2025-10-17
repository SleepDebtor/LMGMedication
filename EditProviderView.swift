import SwiftUI
import CoreData

struct EditProviderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var provider: Provider

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var middleName: String = ""
    @State private var degree: Degree? = nil
    @State private var npi: String = ""
    @State private var dea: String = ""
    @State private var license: String = ""
    @State private var isActive: Bool = true
    @State private var birthdate: Date = Date()

    init(provider: Provider) {
        self.provider = provider
        // _state initialization happens in onAppear to ensure Core Data values are loaded in the correct context lifecycle
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Middle Name", text: $middleName)
                    .textContentType(.middleName)
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
            }

            Section(header: Text("Personal Information")) {
                DatePicker("Birth Date", selection: $birthdate, displayedComponents: .date)
                Toggle("Active", isOn: $isActive)
            }

            Section(header: Text("Professional Details")) {
                Picker("Degree", selection: $degree) {
                    Text("None").tag(nil as Degree?)
                    ForEach(Degree.allCases) { d in
                        Text(d.displayName).tag(d as Degree?)
                    }
                }
                .pickerStyle(.menu)

                TextField("NPI", text: $npi)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                TextField("DEA Number", text: $dea)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                
                TextField("License Number", text: $license)
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
            middleName = provider.middleName ?? ""
            degree = provider.degreeEnum
            npi = provider.npi ?? ""
            dea = provider.dea ?? ""
            license = provider.license ?? ""
            isActive = provider.isActive
            birthdate = provider.birthdate ?? Date()
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
        provider.middleName = middleName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.degreeEnum = degree
        provider.npi = npi.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.dea = dea.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.isActive = isActive
        provider.birthdate = birthdate

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
        p.middleName = "Marie"
        p.degree = "MD"
        p.npi = "1234567890"
        p.dea = "BJ1234567"
        p.license = "MD123456"
        p.isActive = true
        p.birthdate = Calendar.current.date(from: DateComponents(year: 1980, month: 5, day: 15))
        return p
    }()

    return NavigationView {
        EditProviderView(provider: provider)
            .environment(\.managedObjectContext, context)
    }
}
