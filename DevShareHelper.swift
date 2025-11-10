//
//  DevShareHelper.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import SwiftUI
import CloudKit

#if DEBUG
/// Development helper for testing CloudKit shares when sandbox extensions fail
struct DevShareHelper {
    
    /// Simulates the share invitation flow for development testing
    static func simulateShareInvitation() {
        print("🧪 DevShareHelper: Simulating share invitation for development")
        
        // Create a mock share URL for testing the UI flow
        if let mockURL = URL(string: "https://www.icloud.com/share/mock-dev-share-123") {
            Task {
                await ShareURLHandler.shared.handleIncomingURL(mockURL)
            }
        }
    }
    
    /// Shows information about simulator limitations
    static func showSimulatorLimitations() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Simulator Limitations")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• CloudKit share URLs may show sandbox extension errors")
                Text("• Share invitation UI will still display and function")
                Text("• Full functionality works on physical devices")
                Text("• This is a known iOS Simulator limitation")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button("Test Share UI Anyway") {
                simulateShareInvitation()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

/// View modifier to show simulator warnings in development
struct SimulatorWarningModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
        #if targetEnvironment(simulator)
            .safeAreaInset(edge: .bottom) {
                DevShareHelper.showSimulatorLimitations()
                    .padding()
            }
        #endif
    }
}

extension View {
    /// Shows simulator limitations warning in debug builds
    func showSimulatorWarnings() -> some View {
        self.modifier(SimulatorWarningModifier())
    }
}
#endif