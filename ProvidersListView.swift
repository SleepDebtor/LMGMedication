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
    
    // Custom colors - light theme with dark bronze accents
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2) // Dark bronze
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15) // Darker bronze
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97) // Light background with subtle gold tint
    private let textColor = Color.black // Black text
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light background
                lightBackgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Header section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Providers")
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
                                
                                Button("Done") {
                                    dismiss()
                                }
                                .font(.headline)
                                .foregroundColor(goldColor)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Add provider button
                            Button(action: {
                                showingAddProvider = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("Add New Provider")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
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
                                .cornerRadius(16)
                                .shadow(color: goldColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 20)
                            .accessibilityLabel("Add Provider")
                        }
                        
                        // Providers list
                        ForEach(providers) { provider in
                            NavigationLink(destination: EditProviderView(provider: provider)) {
                                ProviderCardView(provider: provider, goldColor: goldColor, darkGoldColor: darkGoldColor, textColor: textColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteProviders)
                        
                        if providers.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundColor(goldColor.opacity(0.6))
                                
                                Text("No Providers Yet")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(goldColor)
                                
                                Text("Tap the button above to add your first healthcare provider")
                                    .font(.body)
                                    .foregroundColor(textColor.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showingAddProvider) {
                AddProviderView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteProviders(offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.3)) {
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

struct ProviderCardView: View {
    let provider: Provider
    let goldColor: Color
    let darkGoldColor: Color
    let textColor: Color
    
    var body: some View {
        HStack {
            // Provider icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goldColor.opacity(0.2), darkGoldColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(goldColor)
            }
            
            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                
                if let degree = provider.degree, !degree.isEmpty,
                   let npi = provider.npi, !npi.isEmpty {
                    Text("\(degree) • NPI: \(npi)")
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                } else if let degree = provider.degree, !degree.isEmpty {
                    Text(degree)
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                } else if let npi = provider.npi, !npi.isEmpty {
                    Text("NPI: \(npi)")
                        .font(.subheadline)
                        .foregroundColor(goldColor.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(goldColor.opacity(0.6))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [goldColor.opacity(0.3), goldColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .shadow(color: goldColor.opacity(0.1), radius: 4, x: 0, y: 2)
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
        p1.firstName = "Dr. Sarah"
        p1.lastName = "Johnson"
        p1.degree = "MD"
        p1.npi = "1234567890"
        
        let p2 = Provider(context: context)
        p2.firstName = "Dr. Michael"
        p2.lastName = "Chen"
        p2.degree = "DO"
        p2.npi = "0987654321"
        
        let p3 = Provider(context: context)
        p3.firstName = "Dr. Emily"
        p3.lastName = "Rodriguez"
        p3.degree = "MD, PhD"
        p3.npi = "1122334455"
        
        try? context.save()
    }
    return ProvidersListView()
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.light)
}
