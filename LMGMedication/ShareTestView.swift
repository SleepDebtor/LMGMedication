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