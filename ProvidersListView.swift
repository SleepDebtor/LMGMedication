import SwiftUI
import CoreData

struct ProvidersListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Provider.lastName, ascending: true),
            NSSortDescriptor(keyPath: \Provider.firstName, ascending: true)
        ],
        animation: .default)
    private var providers: FetchedResults<Provider>
    
    @State private var showingAddProvider = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(providers) { provider in
                    VStack(alignment: .leading) {
                        Text(provider.displayName)
                            .font(.headline)
                        if let degree = provider.degree, !degree.isEmpty,
                           let npi = provider.npi, !npi.isEmpty {
                            Text("\(degree) • NPI: \(npi)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if let degree = provider.degree, !degree.isEmpty {
                            Text(degree)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if let npi = provider.npi, !npi.isEmpty {
                            Text("NPI: \(npi)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteProviders)
            }
            .navigationTitle("Providers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddProvider = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Provider")
                }
            }
            .sheet(isPresented: $showingAddProvider) {
                AddProviderView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private func deleteProviders(offsets: IndexSet) {
        withAnimation {
            offsets.map { providers[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                // Handle error appropriately in production
                print("Failed to delete provider: \(error.localizedDescription)")
            }
        }
    }
}

private extension Provider {
    var displayName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    // Seed sample providers if none exist
    if (try? context.count(for: Provider.fetchRequest())) == 0 {
        let p1 = Provider(context: context)
        p1.firstName = "John"
        p1.lastName = "Doe"
        p1.degree = "MD"
        p1.npi = "1234567890"
        
        let p2 = Provider(context: context)
        p2.firstName = "Jane"
        p2.lastName = "Smith"
        p2.degree = "DO"
        p2.npi = "0987654321"
        
        try? context.save()
    }
    return ProvidersListView()
        .environment(\.managedObjectContext, context)
}
