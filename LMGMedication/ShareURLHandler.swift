//
//  ShareURLHandler.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import SwiftUI
import CloudKit
import Combine

/// Handles incoming URLs for CloudKit sharing
@MainActor
class ShareURLHandler: ObservableObject {
    static let shared = ShareURLHandler()
    
    @Published var pendingShareURL: URL?
    @Published var showingShareInvitation = false
    
    private init() {}
    
    /// Processes incoming URLs from the system
    func handleIncomingURL(_ url: URL) async {
        print("🔗 ShareURLHandler: Received URL: \(url.absoluteString)")
        
        // Check if this is a CloudKit share URL
        if isCloudKitShareURL(url) {
            print("✅ ShareURLHandler: Detected as CloudKit share URL")
            
            // Handle sandbox extension issues for simulator
            #if targetEnvironment(simulator)
            print("🧪 Running in simulator - attempting to work around sandbox extension issues")
            #endif
            
            pendingShareURL = url
            showingShareInvitation = true
        } else {
            print("❌ ShareURLHandler: Not a CloudKit share URL")
            // Handle other URL types if needed
            await handleOtherURLTypes(url)
        }
    }
    
    /// Determines if a URL is a CloudKit share invitation
    private func isCloudKitShareURL(_ url: URL) -> Bool {
        // CloudKit share URLs typically contain "cloudkit" or use your app's custom scheme
        return url.absoluteString.contains("cloudkit") || 
               url.scheme == "lmgmedication" ||
               url.host?.contains("icloud.com") == true
    }
    
    /// Handles non-CloudKit URLs (extend as needed)
    private func handleOtherURLTypes(_ url: URL) async {
        // Add handling for other URL schemes your app supports
        print("Unhandled URL type: \(url)")
    }
    
    /// Dismisses the share invitation UI
    func dismissShareInvitation() {
        pendingShareURL = nil
        showingShareInvitation = false
    }
}

// MARK: - SwiftUI Integration

/// View modifier to handle share invitations
struct ShareInvitationHandler: ViewModifier {
    @StateObject private var urlHandler = ShareURLHandler.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $urlHandler.showingShareInvitation) {
                if let shareURL = urlHandler.pendingShareURL {
                    ShareInvitationView(shareURL: shareURL)
                        .onDisappear {
                            urlHandler.dismissShareInvitation()
                        }
                }
            }
    }
}

extension View {
    /// Adds share invitation handling to any view
    func handleShareInvitations() -> some View {
        self.modifier(ShareInvitationHandler())
    }
}

// MARK: - Usage Example

/*
 Add this to your main App file:

 @main
 struct LMGMedicationApp: App {
     let persistenceController = PersistenceController.shared
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environment(\.managedObjectContext, persistenceController.container.viewContext)
                 .handleShareInvitations() // Add this line
                 .onOpenURL { url in
                     Task {
                         await ShareURLHandler.shared.handleIncomingURL(url)
                     }
                 }
         }
     }
 }
 */