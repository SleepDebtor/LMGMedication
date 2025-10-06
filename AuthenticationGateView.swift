//
//  AuthenticationGateView.swift
//  LMGMedication
//
//  Created by Assistant on 10/5/25.
//

import SwiftUI

struct AuthenticationGateView<Content: View>: View {
    @StateObject private var auth = BiometricAuth()
    let content: () -> Content

    var body: some View {
        Group {
            if auth.isUnlocked {
                content()
            } else {
                lockScreen
            }
        }
        .onAppear {
            // Trigger authentication on appear
            auth.authenticate()
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("Face ID Required")
                .font(.headline)
            if let message = auth.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button {
                auth.authenticate()
            } label: {
                Label("Unlock", systemImage: "faceid")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
