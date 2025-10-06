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
        VStack(spacing: 20) {
            Spacer()

            // Branding image
            Image("HushIconE")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
                .padding(.horizontal, 32)

            // Title and message
            VStack(spacing: 8) {
                Text("Welcome to Hush")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Face ID or Passcode required to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let message = auth.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)

            // Unlock button
            Button {
                auth.authenticate()
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Spacer()

            // Small footer branding
            Text("Lazar Medical Group")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

