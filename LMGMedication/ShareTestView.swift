//
//  ShareTestView.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import SwiftUI

/// Temporary view for testing share invitations
struct ShareTestView: View {
    @State private var testURLString = ""
    @StateObject private var urlHandler = ShareURLHandler.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share Invitation Test")
                .font(.title2)
                .fontWeight(.bold)
            
            #if targetEnvironment(simulator)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Simulator Mode")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Text("You may see sandbox extension errors in the simulator. This is normal and doesn't affect functionality on real devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            #endif
            
            Text("Paste your CloudKit share URL here to test the invitation flow:")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            TextField("CloudKit Share URL", text: $testURLString)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            Button("Test Share Invitation") {
                if let url = URL(string: testURLString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    Task {
                        print("🧪 Testing URL: \(url.absoluteString)")
                        print("🧪 Note: Sandbox extension errors are expected in simulator")
                        await urlHandler.handleIncomingURL(url)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(testURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Divider()
            
            Text("Or trigger a test invitation manually:")
                .foregroundColor(.secondary)
            
            Button("Show Test Invitation") {
                // Create a fake URL for testing
                if let testURL = URL(string: "https://www.icloud.com/share/test123") {
                    urlHandler.pendingShareURL = testURL
                    urlHandler.showingShareInvitation = true
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Share Test")
    }
}

#Preview {
    NavigationView {
        ShareTestView()
    }
}